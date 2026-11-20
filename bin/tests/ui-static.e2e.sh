#!/usr/bin/env bash
# Docker-backed proof of the ui's runtime image: how its nginx serves the app
# and the component gallery; not part of fast script tests. CI runs it in the
# ui-static-proof job.
set -euo pipefail
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
  cat <<'HELP'
usage: bin/tests/ui-static.e2e.sh

Requires Docker. Builds services/ui's checks image and its default (runtime)
image, starts the runtime on a free loopback port and proves:
  - the checks image runs the pinned Bun 1.4.3;
  - the runtime is the last stage, pinned unprivileged nginx, with only the
    built files;
  - / and a client-side deep link answer the app's entry page, uncached;
  - a built asset answers with a far-future cache, and its source map 404;
  - /storybook/ answers Storybook's page, its files uncached, and an unknown
    file under it 404;
  - /storybook and a directory under it without the slash redirect relatively;
  - the container's own health probe (wget) succeeds.

No host Bun or Node and no credentials needed. Prints PASS lines; logs remain
in tmp/ui-proof/.
HELP
  exit 0
fi
[ "$#" -eq 0 ] || { echo 'Use --help for usage' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
mkdir -p "$root/tmp/ui-proof"
output="$(mktemp -d "$root/tmp/ui-proof/run.$$.XXXXXX")"
id="$(printf '%s' "${output##*.}" | tr '[:upper:]' '[:lower:]')"
name="factory-ui-proof-$id"
ui="$root/services/ui"

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  docker rm -f "$name" > /dev/null 2>&1 || true
  docker image rm "$name:checks" "$name:runtime" > /dev/null 2>&1 || true
  echo "E2E artifacts: $output"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { echo "FAIL: $*; see $output" >&2; exit 1; }
pass() { echo "PASS: $*"; }

docker build --target checks -t "$name:checks" "$ui" > "$output/checks-build.log" 2>&1 || fail 'checks image build'
docker build -t "$name:runtime" "$ui" > "$output/runtime-build.log" 2>&1 || fail 'runtime image build'
docker run --rm "$name:checks" bun -e 'if (Bun.version !== "1.4.3") process.exit(1)' || fail 'checks image Bun version'
last="$(grep '^FROM ' "$ui/Dockerfile" | tail -n 1)"
[[ "$last" =~ ^FROM\ nginxinc/nginx-unprivileged:[0-9.]+-alpine[0-9.]+@sha256:[0-9a-f]{64}\ AS\ runtime$ ]] || fail "last stage: $last"
docker run --rm --entrypoint sh "$name:runtime" -c 'ls /usr/share/nginx/html' > "$output/html.txt" || fail 'list the served files'
# 50x.html is the nginx image's own error page.
served="$(grep -vx 50x.html "$output/html.txt" | tr '\n' ' ')"
[ "$served" = "assets index.html storybook " ] || fail "served files: $served"
# The uid, not the configured name: an image without USER, or with USER 0, is root too.
uid="$(docker run --rm --entrypoint id "$name:runtime" -u)" || fail 'read the runtime uid'
[ "$uid" != 0 ] || fail 'runtime runs as root'
pass '[service-checks-44a61a] checks on Bun 1.4.3; the runtime serves only its build from pinned unprivileged nginx'

docker run -d --name "$name" -p 127.0.0.1::3000 "$name:runtime" > /dev/null || fail 'runtime container start'
port="$(docker port "$name" 3000/tcp | sed -n 's/^127\.0\.0\.1:\([0-9]*\)$/\1/p' | tail -n 1)"
[ -n "$port" ] || fail 'no published port'
for _ in $(seq 1 40); do curl -fsS "http://127.0.0.1:$port/" > /dev/null 2>&1 && break; sleep 0.25; done
status() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port$1"; }
headers() { curl -fsS -D - -o /dev/null "http://127.0.0.1:$port$1"; }

for path in / /some/deep/link; do
  [ "$(status "$path")" = 200 ] || fail "$path status"
  out="$(curl -fsS "http://127.0.0.1:$port$path")" || fail "$path request"
  grep -q '<div id="root">' <<< "$out" || fail "$path body"
  out="$(headers "$path")" || fail "$path request"
  grep -qi '^cache-control: no-cache' <<< "$out" || fail "$path is cached"
done
asset="$(docker exec "$name" ls /usr/share/nginx/html/assets | grep '\.js$' | sed -n 1p)"
[ -n "$asset" ] || fail 'no built script'
out="$(headers "/assets/$asset")" || fail 'asset request'
grep -qi '^expires: .*20[3-9][0-9]' <<< "$out" || fail 'asset has no far-future Expires'
pass '[app-shell-a2332b] / and a deep link answer the uncached entry page; assets are cached far ahead'

[ "$(status "/assets/$asset.map")" = 404 ] || fail 'source map served'
pass '[app-shell-6554e2] a source map answers 404'

[ "$(status /storybook/)" = 200 ] || fail '/storybook/ status'
out="$(curl -fsS "http://127.0.0.1:$port/storybook/")" || fail '/storybook/ request'
grep -qi '<title>[^<]*storybook' <<< "$out" || fail '/storybook/ is not Storybook'
[ "$(status /storybook/nope.html)" = 404 ] || fail 'an unknown Storybook file does not 404'
pass '[design-system-f3c957] /storybook/ serves the component gallery'

# location <path>: the Location header of an unfollowed request.
location() { curl -sS -D - -o /dev/null "http://127.0.0.1:$port$1" | tr -d '\r' | sed -n 's/^[Ll]ocation: //p'; }
[ "$(status /storybook)" = 301 ] || fail '/storybook does not redirect'
[ "$(location /storybook)" = /storybook/ ] || fail "/storybook redirects to $(location /storybook)"
dir="$(docker exec "$name" find /usr/share/nginx/html/storybook -mindepth 1 -maxdepth 1 -type d | sed -n 1p)"
dir="${dir#/usr/share/nginx/html}"
[ -n "$dir" ] || fail 'no directory under /storybook/'
[ "$(status "$dir")" = 301 ] || fail "$dir does not redirect"
[ "$(location "$dir")" = "$dir/" ] || fail "$dir redirects to $(location "$dir")"
pass '[design-system-a0c386] /storybook and a slashless directory under it redirect relatively'

for path in /storybook/ /storybook/index.json; do
  out="$(headers "$path")" || fail "$path request"
  grep -qi '^cache-control: no-cache' <<< "$out" || fail "$path is cached"
done
pass "[design-system-e78a6b] Storybook's files are served uncached"

docker exec "$name" wget -q --spider http://127.0.0.1:3000/ || fail 'health probe'
pass 'the container health probe succeeds'
