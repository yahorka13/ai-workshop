# shellcheck shell=bash
# Sourced by bin/check: reads services/<consumer>/consumes.txt, the producers
# whose committed contracts/ the consumer reads. One service name per line;
# `#` starts a comment and blank lines are ignored. Pure Bash 3.2, no external
# tools, so it behaves the same on macOS and Linux.

# load_consumes ROOT CONSUMER: set CONSUMES_PRODUCERS to the declared producers
# and CONSUMES_MOUNTS to the matching read-only `docker create` mount arguments.
# A missing consumes.txt declares nothing. Prints a diagnostic naming the
# consumer, the declared name and consumes.txt, and returns 1, when a name is
# invalid or is not a service with its own contracts/ folder.
load_consumes() {
  local root="$1" consumer="$2" file line number=0 name contracts
  file="$root/services/$consumer/consumes.txt"
  CONSUMES_PRODUCERS=()
  CONSUMES_MOUNTS=()
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    number=$((number + 1))
    name="${line%%#*}"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [ -n "$name" ] || continue
    contracts="$root/services/$name/contracts"
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]] || [ ! -d "$contracts" ] ||
      [ "$(cd "$contracts" && pwd -P)" != "$contracts" ]; then
      echo "$consumer: services/$consumer/consumes.txt line $number declares '$name', which is not a service with a contracts/ folder" >&2
      return 1
    fi
    case " ${CONSUMES_PRODUCERS[*]-} " in *" $name "*) continue ;; esac
    CONSUMES_PRODUCERS+=("$name")
    CONSUMES_MOUNTS+=(-v "$contracts:/contracts/$name:ro")
  done < "$file"
}
