# shellcheck shell=bash
# Sourced by bin/check-lint-disables.sh and bin/check-disables.sh:
# compare each service's count of one kind of suppression with its committed
# baseline, which only goes down.

# compare_suppressions <baseline-file> <noun> <matches>
# <matches> holds one services/<service>/<path>:<line> per suppression. Every
# service tracked under services/ and every service in the baseline (lines of
# `<service> <count>`) needs a line. A higher count fails and lists the
# service's suppressions; a lower one fails until it is committed. Returns 1
# on any difference.
compare_suppressions() {
  local baseline_file="$1" noun="$2" matches="$3" services
  services="$(git ls-files -- services | cut -d/ -f2 | sort -u | tr '\n' ' ')"
  printf '%s\n' "$matches" | awk -v services="$services" -v baseline_file="$baseline_file" -v noun="$noun" '
    BEGIN {
      n = split(services, list, " ")
      for (i = 1; i <= n; i++) if (list[i] != "") { count[list[i]] = 0; known[list[i]] = 1 }
      while ((getline line < baseline_file) > 0) {
        split(line, field, " ")
        if (field[1] == "") continue
        baseline[field[1]] = field[2]
        known[field[1]] = 1
        if (!(field[1] in count)) count[field[1]] = 0
      }
    }
    $0 != "" {
      split($0, part, "/")
      count[part[2]]++
      where[part[2]] = where[part[2]] "  " $0 "\n"
    }
    END {
      failed = 0
      for (service in known) {
        if (!(service in baseline)) {
          printf "%s: no line in %s, add %s %d\n", service, baseline_file, service, count[service]
          failed = 1
        } else if (count[service] > baseline[service]) {
          printf "%s: %d > %d %s in %s; each one, new ones among them:\n%s", service, count[service], baseline[service], noun, baseline_file, where[service]
          failed = 1
        } else if (count[service] < baseline[service]) {
          printf "%s: %d < %d, commit %s with %s %d\n", service, count[service], baseline[service], baseline_file, service, count[service]
          failed = 1
        }
      }
      exit failed
    }
  '
}
