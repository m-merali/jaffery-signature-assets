#!/usr/bin/env bash
# Requests every published asset on the primary and the fallback address and checks
# the HTTP status (200, no redirect), the content type, and that the bytes served
# match the file in this repository. Also checks the 404 page, the http-to-https
# redirects, and that the primary repository's github.io address redirects to the
# custom domain.
#
# Usage: .github/scripts/check-urls.sh [report.md]
# Env:   PRIMARY_BASE, FALLBACK_BASE, PRIMARY_GITHUB_IO  override the addresses
#        DOH_URL  resolve names over DNS-over-HTTPS (e.g. https://cloudflare-dns.com/dns-query)
#                 instead of the local resolver
# Exit:  0 when every check passes, 1 otherwise. Runs on bash 3.2 (macOS) and later.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

PRIMARY_BASE=${PRIMARY_BASE:-https://assets.jafferyacademy.org}
FALLBACK_BASE=${FALLBACK_BASE:-https://m-merali.github.io/jaffery-signature-assets-fallback}
PRIMARY_GITHUB_IO=${PRIMARY_GITHUB_IO:-https://m-merali.github.io/jaffery-signature-assets}
REPORT=${1:-}

curl_opts=(-sS --max-time 30 --retry 2 --retry-delay 2 --retry-all-errors --max-redirs 0)
if [ -n "${DOH_URL:-}" ]; then curl_opts+=(--doh-url "$DOH_URL"); fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

rows=()
passes=0
fails=0
record() { # result check url expected got
  rows+=("| $1 | $2 | \`$3\` | $4 | $5 |")
  if [ "$1" = PASS ]; then passes=$((passes + 1)); else fails=$((fails + 1)); fi
}

# Sets code, ctype, size, location, ip; the body goes to $tmp/body.
fetch() {
  local out
  rm -f "$tmp/body"
  out=$(curl "${curl_opts[@]}" -o "$tmp/body" \
    -w '%{http_code}|%{content_type}|%{size_download}|%{redirect_url}|%{remote_ip}' "$1" 2>"$tmp/err")
  IFS='|' read -r code ctype size location ip <<<"$out"
  code=${code:-000}
  if [ "$code" = 000 ]; then ctype="error: $(tr '\n' ' ' <"$tmp/err" | cut -c1-120)"; fi
}

check_file() { # label base path expected-type
  local url="$2/$3" want=$4 match="bytes differ"
  fetch "$url"
  if [ -f "$tmp/body" ] && [ "$(sha "$tmp/body")" = "$(sha "$3")" ]; then match="bytes match"; fi
  local got="$code, ${ctype:-no type}, ${size:-0} B, $match"
  if [ "$code" = 200 ] && [ "${ctype%%;*}" = "$want" ] && [ "$match" = "bytes match" ]; then
    record PASS "$1" "$url" "200, $want, same bytes" "$got"
  else
    record FAIL "$1" "$url" "200, $want, same bytes" "$got"
  fi
}

check_404() { # label base
  local url="$2/no-such-file-404-check.png"
  fetch "$url"
  local got="$code, ${ctype:-no type}"
  if [ "$code" = 404 ] && [ "${ctype%%;*}" = text/html ] && grep -q 'class="code">Error 404<' "$tmp/body" 2>/dev/null; then
    record PASS "$1" "$url" "404, text/html, own 404 page" "$got, own 404 page"
  else
    record FAIL "$1" "$url" "404, text/html, own 404 page" "$got"
  fi
}

check_redirect() { # label url expected-location-prefix
  fetch "$2"
  local got="$code -> ${location:-none}"
  case "$code:$location" in
    30[178]:"$3"*) record PASS "$1" "$2" "301 -> $3..." "$got" ;;
    *)             record FAIL "$1" "$2" "301 -> $3..." "$got" ;;
  esac
}

paths=$(git ls-files -- ':(glob)*/v[0-9]*/**/*.png' | sort)
count=$(printf '%s\n' "$paths" | grep -c .)

ips=""
for pair in "Primary|$PRIMARY_BASE" "Fallback|$FALLBACK_BASE"; do
  label=${pair%%|*}
  base=${pair#*|}
  check_file "$label" "$base" index.html text/html
  [ -n "$ip" ] && ips="$ips $label $ip;"
  while IFS= read -r p; do
    check_file "$label" "$base" "$p" image/png
  done <<<"$paths"
  check_404 "$label" "$base"
done

check_redirect "Primary http" "${PRIMARY_BASE/https:/http:}/index.html" "$PRIMARY_BASE/"
check_redirect "Fallback http" "${FALLBACK_BASE/https:/http:}/index.html" "$FALLBACK_BASE/"
check_redirect "Primary github.io" "$PRIMARY_GITHUB_IO/index.html" "$PRIMARY_BASE/"

host=${PRIMARY_BASE#https://}
host=${host%%/*}
cert="not checked (openssl not found)"
if command -v openssl >/dev/null 2>&1; then
  cert=$(echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null |
    openssl x509 -noout -subject -issuer -enddate 2>/dev/null | tr '\n' ';' | sed 's/;$//')
  [ -n "$cert" ] || cert="could not read the certificate"
fi

if [ "${GITHUB_ACTIONS:-}" = true ]; then
  where="GitHub Actions runner ($RUNNER_OS), run $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
else
  where="local machine, DNS ${DOH_URL:-from the system resolver}"
fi

{
  echo "# Asset URL check"
  echo
  echo "- Run: $(date -u '+%Y-%m-%d %H:%M UTC'), $where"
  echo "- Files checked: commit $(git rev-parse --short HEAD), $count PNG files plus index.html, on each address"
  echo "- Primary: $PRIMARY_BASE"
  echo "- Fallback: $FALLBACK_BASE"
  echo "- Server IPs seen:${ips:- none}"
  echo "- Certificate for $host: $cert"
  echo "- Result: $passes passed, $fails failed"
  echo
  echo "| Result | Check | URL | Expected | Got |"
  echo "|---|---|---|---|---|"
  printf '%s\n' "${rows[@]}"
} >"$tmp/report.md"

if [ -n "$REPORT" ]; then cp "$tmp/report.md" "$REPORT"; fi
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$tmp/report.md" >>"$GITHUB_STEP_SUMMARY"; fi

sed -n '1,9p' "$tmp/report.md"
if [ "$fails" -gt 0 ]; then
  echo
  echo "Failed checks:"
  printf '%s\n' "${rows[@]}" | grep '^| FAIL'
  exit 1
fi
