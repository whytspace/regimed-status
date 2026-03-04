#!/usr/bin/env bash
set -euo pipefail

SITEMAP_URL="${SITEMAP_URL:?SITEMAP_URL environment variable is required}"
UPPTIMERC="${UPPTIMERC:-.upptimerc.yml}"
MANUAL_SITES="${MANUAL_SITES:-manual-sites.yml}"

ALL_URLS=""

fetch_urls() {
  local url="$1"
  local xml
  xml=$(curl -sSfL "$url")

  # Check if this is a sitemap index (grep is simpler and handles single-element edge cases)
  if echo "$xml" | grep -q '<sitemapindex'; then
    while IFS= read -r child; do
      [ -z "$child" ] && continue
      fetch_urls "$child"
    done < <(echo "$xml" | tr '<' '\n' | sed -n 's|^loc>\(.*\)|\1|p')
  else
    while IFS= read -r page_url; do
      [ -z "$page_url" ] && continue
      ALL_URLS="${ALL_URLS}${page_url}"$'\n'
    done < <(echo "$xml" | tr '<' '\n' | sed -n 's|^loc>\(.*\)|\1|p')
  fi
}

url_to_path() {
  local url="$1"
  local path
  path=$(echo "$url" | sed -E 's|https?://[^/]+||')
  echo "${path:-/}"
}

# Fetch all URLs from sitemap
echo "Fetching sitemap: $SITEMAP_URL"
fetch_urls "$SITEMAP_URL"

# Deduplicate and remove empty lines
URLS=$(echo "$ALL_URLS" | sort -u | sed '/^$/d')

URL_COUNT=0
[ -n "$URLS" ] && URL_COUNT=$(echo "$URLS" | wc -l | tr -d ' ')
echo "Found $URL_COUNT URLs"

# Build sites YAML: start with manual sites if present
SITES_YAML=""
if [ -f "$MANUAL_SITES" ]; then
  echo "Including manual sites from $MANUAL_SITES"
  SITES_YAML=$(cat "$MANUAL_SITES")
fi

# Append sitemap-derived sites (build YAML directly to avoid spawning yq per URL)
while IFS= read -r url; do
  [ -z "$url" ] && continue
  name=$(url_to_path "$url")
  SITES_YAML="${SITES_YAML}"$'\n'"- name: \"${name}\""$'\n'"  url: \"${url}\""
done <<< "$URLS"

# Write sites into .upptimerc.yml using load() so the value is parsed as YAML, not a string
TMP=$(mktemp)
echo "$SITES_YAML" > "$TMP"
SITES_FILE="$TMP" yq eval -i '.sites = load(strenv(SITES_FILE))' "$UPPTIMERC"
rm -f "$TMP"

echo "Updated $UPPTIMERC with $URL_COUNT sitemap URLs"
