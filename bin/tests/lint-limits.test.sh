# shellcheck shell=bash disable=SC2016 # literal rule names in single quotes
# Every linted service carries the same complexity and size limits, between the
# lint-limits markers of its eslint.config.mjs.

# The lines from the start marker to the end marker of <service>'s config.
limits_block() {
  sed -n '/\/\/ lint-limits:start/,/\/\/ lint-limits:end/p' "$ROOT/services/$1/eslint.config.mjs"
}

# [service-checks-b1556d]
test_service_checks_b1556d_every_service_sets_the_same_limits() {
  local reference config service block phrase
  reference="$(limits_block backend)"
  [ -n "$reference" ] || fail "backend's eslint.config.mjs has no lint-limits block"
  for phrase in 'complexity: ["error", 10]' '"max-depth": ["error", 3]' '"max-params": ["error", 3]' \
    '"max-params": ["error", 4]' '"max-lines-per-function": "off"' 'files: ["**/*.tsx"]' \
    'files: ["tests/**", "**/*.stories.*"]' 'max: 50,' 'max: 80,' 'max: 300,' 'max: 400,' 'max: 500,' \
    'skipBlankLines: true, skipComments: true' '// lint-limits:end'; do
    [[ "$reference" == *"$phrase"* ]] || fail "backend's limits do not say: $phrase"
  done
  for config in "$ROOT"/services/*/eslint.config.mjs; do
    service="${config%/eslint.config.mjs}"
    service="${service##*/}"
    block="$(limits_block "$service")"
    [ -n "$block" ] || fail "$service: eslint.config.mjs has no lint-limits block"
    [ "$block" = "$reference" ] || fail "$service: its lint-limits block differs from backend's"
  done
}
