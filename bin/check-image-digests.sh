#!/usr/bin/env bash
# Fail on a Docker image reference that is not pinned by digest.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: bin/check-image-digests.sh [<root>]
       bin/check-image-digests.sh --help

Fail on an image reference without a digest in the tracked files of <root>
(default: this repository): every Dockerfile*, every *compose*.yml, the
workflows under .github/workflows/, the scripts directly under bin/ and the
end-to-end scripts bin/tests/*.e2e.sh. A reference is a FROM or COPY --from
image (not an earlier build stage, not scratch), a Compose image:, the image
of a docker run, or an assignment to a name ending in IMAGE or image. Each
one must read <name>:<tag>@sha256:<64 hex digits>: Docker pulls by the
digest, the tag says which version it is. An image a variable names, in a
run or an assignment, is skipped: it is built here, or its assignment is
checked. A variable in a FROM cannot be checked and fails. Comment lines are
skipped.

Prints <file>:<line>: <image> is not pinned by digest for each, and exits 1.

To pin or bump an image: choose the tag, resolve the digest of its
multi-platform index with
  docker buildx imagetools inspect <name>:<tag>
and write the reference as <name>:<tag>@<the Digest it prints>, in every
place that uses the image.
EOF
}

[ "${1:-}" = --help ] && { usage; exit 0; }
[ "$#" -le 1 ] || { usage >&2; exit 2; }
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
cd "$ROOT"

# Prints "<line> <image>" for every image reference in one file.
references() {
  awk -v quote="'" '
    # Options of docker run that take a value as the next word.
    BEGIN {
      split("-v -w -e -u -p --volume --workdir --env --user --name --platform --network --entrypoint --mount --publish", list, " ")
      for (i in list) valued[list[i]] = 1
    }
    # A word without its quotes and a trailing semicolon.
    function clean(word) {
      gsub("^[\"" quote "]|[\"" quote ";]$", "", word)
      return word
    }
    # A continued line joins the next one, reported at its first line.
    {
      if (pending != "") { text = pending " " $0 } else { text = $0; start = NR }
      if (text ~ /\\$/) { pending = substr(text, 1, length(text) - 1); next }
      pending = ""
      n = split(text, w, /[ \t]+/)
      first = (w[1] == "") ? 2 : 1
      if (w[first] ~ /^#/) next
    }
    toupper(w[first]) == "FROM" {
      i = first + 1
      while (i <= n && w[i] ~ /^--/) i++
      image = w[i]
      if (tolower(w[i + 1]) == "as") stage[tolower(w[i + 2])] = 1
      if (image != "scratch" && !(tolower(image) in stage)) print start, image
      next
    }
    toupper(w[first]) == "COPY" {
      for (i = first + 1; i <= n && w[i] ~ /^--/; i++) {
        if (w[i] !~ /^--from=/) continue
        image = substr(w[i], 8)
        if (image !~ /^[0-9]+$/ && !(tolower(image) in stage)) print start, image
      }
      next
    }
    w[first] == "image:" || w[first] == "-" && w[first + 1] == "image:" {
      print start, clean(w[first] == "image:" ? w[first + 1] : w[first + 2])
    }
    {
      for (i = first; i <= n; i++) {
        if (w[i] ~ /^[A-Za-z_]*(IMAGE|image)=/) {
          value = clean(substr(w[i], index(w[i], "=") + 1))
          if (value !~ /\$/) print start, value
        }
        if (w[i] == "docker" && w[i + 1] == "run") {
          for (j = i + 2; j <= n; j++) {
            if (w[j] in valued) { j++; continue }
            if (w[j] ~ /^-/) continue
            image = clean(w[j])
            # An image named through a variable is checked where it is
            # assigned, or is built here rather than pulled.
            if (image !~ /\$/) print start, image
            break
          }
        }
      }
    }
  ' "$1"
}

PINNED='^[^@]+:[^@/]+@sha256:[0-9a-f]{64}$'
FAILED=0
while IFS= read -r file; do
  case "$file" in
    */Dockerfile* | Dockerfile* | *compose*.yml | *compose*.yaml | .github/workflows/*.yml | .github/workflows/*.yaml) ;;
    bin/tests/*.e2e.sh) ;;
    bin/*/*) continue ;;
    bin/*) ;;
    *) continue ;;
  esac
  [ -f "$file" ] || continue
  while read -r line image; do
    [[ "$image" =~ $PINNED ]] && continue
    echo "$file:$line: $image is not pinned by digest"
    FAILED=1
  done < <(references "$file")
done < <(git ls-files)

if [ "$FAILED" -ne 0 ]; then
  echo "fix: pin it as <name>:<tag>@sha256:<digest>, the digest from docker buildx imagetools inspect <name>:<tag> (bin/check-image-digests.sh --help)" >&2
  exit 1
fi
