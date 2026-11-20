# shellcheck shell=bash disable=SC2154
# The services' layout, pinned runtimes, standard scripts and container
# targets, read from the files of every folder under services/.

# Every service folder with a package.json, except services/e2e, which ships no
# application code.
app_services() {
  local manifest service
  for manifest in "$ROOT"/services/*/package.json; do
    [ -f "$manifest" ] || continue
    service="${manifest%/package.json}"
    service="${service##*/}"
    [ "$service" = e2e ] || printf '%s\n' "$service"
  done
}

# [service-checks-8d88cc]
test_service_checks_8d88cc_each_service_owns_its_layout() {
  local service other file services
  services="$(app_services)"
  [ -n "$services" ] || fail 'no service under services/'
  for service in $services; do
    for file in package.json bun.lock Dockerfile AGENTS.md; do
      [ -f "$ROOT/services/$service/$file" ] || fail "services/$service has no $file"
    done
    for other in $services; do
      [ "$other" != "$service" ] || continue
      if grep -rEn "from ['\"](\.\./)+$other/|services/$other/" "$ROOT/services/$service/src" 2> /dev/null; then
        fail "services/$service imports from services/$other"
      fi
    done
  done
}

# [service-checks-e156cb]
test_service_checks_e156cb_engine_matches_image() {
  local service engine images image
  for service in $(app_services); do
    engine="$(sed -nE 's/^ *"bun": "([^"]*)".*/\1/p' "$ROOT/services/$service/package.json" | head -n 1)"
    [[ "$engine" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "services/$service: engines.bun is not an exact version: '$engine'"
    images="$(sed -nE 's/^FROM (oven\/bun[^ ]*).*/\1/p' "$ROOT/services/$service/Dockerfile")"
    [ -n "$images" ] || fail "services/$service/Dockerfile has no oven/bun base image"
    while IFS= read -r image; do
      [[ "$image" =~ ^oven/bun:${engine//./\\.}@sha256:[0-9a-f]{64}$ ]] || fail "services/$service: $image is not oven/bun:$engine@sha256:<digest>"
    done <<< "$images"
  done
}

# [service-checks-56c271]
test_service_checks_56c271_standard_scripts() {
  local service script
  for service in $(app_services); do
    grep -qE '^FROM .* AS checks$' "$ROOT/services/$service/Dockerfile" || continue
    for script in lint format typecheck test:unit test:integration coverage duplicates unused imports; do
      grep -q "\"$script\":" "$ROOT/services/$service/package.json" || fail "services/$service has no $script script"
    done
  done
}

# [service-checks-5897ce]
test_service_checks_5897ce_checks_and_runtime_targets() {
  local service file checks runtime user
  for service in $(app_services); do
    file="$ROOT/services/$service/Dockerfile"
    # The lines of one stage: from its FROM to the next FROM.
    checks="$(awk '/^FROM / { on = / AS checks$/ } on' "$file")"
    runtime="$(awk '/^FROM / { on = / AS runtime$/ } on' "$file")"
    [ -n "$checks" ] || fail "services/$service has no checks target"
    [ -n "$runtime" ] || fail "services/$service has no runtime target"
    [[ "$checks" == *"--frozen-lockfile"* ]] || fail "services/$service: checks does not install --frozen-lockfile"
    # A static site serves its build from an unprivileged web server image,
    # which installs nothing and runs as its non-root user.
    if [[ "$runtime" =~ ^FROM\ nginxinc/nginx-unprivileged: ]]; then
      [[ "$runtime" != *"RUN "* ]] || fail "services/$service: static runtime runs a command"
      continue
    fi
    [[ "$runtime" == *"--production"* ]] || fail "services/$service: runtime does not install --production"
    user="$(printf '%s\n' "$runtime" | sed -nE 's/^USER +([^ ]+).*/\1/p' | tail -n 1)"
    [ -n "$user" ] && [ "$user" != root ] && [ "$user" != 0 ] || fail "services/$service: runtime runs as root"
  done
}

# [service-checks-44a61a]
test_service_checks_44a61a_static_runtime_serves_only_its_build() {
  local file runtime copies
  file="$ROOT/services/ui/Dockerfile"
  [ -f "$file" ] || fail 'services/ui has no Dockerfile'
  [[ "$(grep '^FROM ' "$file" | tail -n 1)" =~ ^FROM\ nginxinc/nginx-unprivileged:[0-9]+\.[0-9]+\.[0-9]+-alpine[0-9]+\.[0-9]+@sha256:[0-9a-f]{64}\ AS\ runtime$ ]] ||
    fail 'the last stage of services/ui is not a pinned unprivileged nginx runtime'
  runtime="$(awk '/^FROM / { on = / AS runtime$/ } on' "$file")"
  [[ "$runtime" != *"RUN "* ]] || fail 'the ui runtime runs a command'
  copies="$(printf '%s\n' "$runtime" | sed -nE 's/^COPY +(--from=[^ ]+ +)?([^ ]+) .*/\1\2/p' | sed 's/ *$//' | sort | tr '\n' ' ')"
  [ "$copies" = "--from=build /app/dist --from=storybook-build /app/storybook-static nginx/nginx.conf " ] ||
    fail "the ui runtime copies more than its build: $copies"
}
