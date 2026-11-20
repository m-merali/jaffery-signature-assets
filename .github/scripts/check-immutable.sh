#!/bin/sh
# Fails if a file in a version folder (academy/v1/, kebs/v2/ ...) differs from the
# version first committed, or has been deleted, moved or renamed. Sent signatures link
# to those files by their full path, so a published file must stay byte-for-byte the same.
# Adding new files is allowed. A mistaken change passes again once it is reverted.
# A file added by mistake whose deploy was blocked, so it never went live, can be listed
# (one path per line, # for comments) in .github/never-published.txt and is then skipped.
# Needs the full history (checkout with fetch-depth: 0).
set -eu
cd "$(git rev-parse --show-toplevel)"

if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Shallow clone: fetch the full history first (fetch-depth: 0)." >&2
  exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Blob of each file when it was first added, and blob of each file now.
git log --reverse --diff-filter=A --no-renames --format= --raw --no-abbrev >"$tmp/added"
git ls-tree -r --full-tree HEAD >"$tmp/now"
skip=.github/never-published.txt
[ -f "$skip" ] || skip=/dev/null

awk -F'\t' '
  function versioned(p) { return p ~ /^[^\/]+\/v[0-9]+\// && p !~ /(^|\/)\.gitkeep$/ && !(p in skip) }
  FILENAME == ARGV[1] { sub(/[ \t]*#.*/, ""); sub(/[ \t]+$/, ""); if ($0 != "") skip[$0] = 1; next }
  FILENAME == ARGV[2] { split($1, m, " "); if (versioned($2) && !($2 in first)) first[$2] = m[4]; next }
  { split($1, m, " "); if (versioned($2)) now[$2] = m[3] }
  END {
    for (p in first) {
      total++
      if (!(p in now)) print "missing  " p
      else if (now[p] != first[p]) print "changed  " p
    }
    print total > "/dev/stderr"
  }' "$skip" "$tmp/added" "$tmp/now" 2>"$tmp/total" | sort >"$tmp/problems"

if [ -s "$tmp/problems" ]; then
  echo "Published files in a version folder differ from the version first committed:" >&2
  cat "$tmp/problems" >&2
  echo "Restore them, and put corrected files in the next version folder (v2/, v3/ ...)." >&2
  exit 1
fi

echo "OK: all $(cat "$tmp/total") files in version folders match the version first committed."
