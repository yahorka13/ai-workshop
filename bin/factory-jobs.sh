# shellcheck shell=bash
# Sourced by bin/check: resolve FACTORY_JOBS, the number of parallel jobs a
# check may use. An exported value wins, else a FACTORY_JOBS=<n> line in the
# machine env file (FACTORY_ENV_FILE, default ~/.factory/env), else the
# machine's cores. The file is parsed, never executed, and refused unless only
# its owner can read it. A value that is not a positive integer exits 2.

resolve_factory_jobs() {
  local file mode value
  if [ -z "${FACTORY_JOBS:-}" ]; then
    file="${FACTORY_ENV_FILE:-$HOME/.factory/env}"
    if [ -f "$file" ]; then
      # ls -l is the one mode listing shared by BSD and GNU; columns 5-10 are group and others.
      # shellcheck disable=SC2012
      mode="$(ls -l "$file" | cut -c5-10)"
      if [ "$mode" != '------' ]; then
        echo "ERROR: $file is accessible by other users. Run: chmod 600 '$file'" >&2
        exit 1
      fi
      value="$(sed -n 's/^FACTORY_JOBS=//p' "$file" | tail -n 1)"
      case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
      esac
      FACTORY_JOBS="$value"
    fi
  fi
  if [ -z "${FACTORY_JOBS:-}" ]; then
    FACTORY_JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
  fi
  if [[ ! "$FACTORY_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "FACTORY_JOBS must be a positive integer, not '$FACTORY_JOBS'" >&2
    exit 2
  fi
  export FACTORY_JOBS
}
