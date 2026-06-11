#!/usr/bin/env bash
# Pre-deploy guard for secondbrain.training.
#
# Root cause of incident SBT-2026-06-02-01: .assetsignore was a denylist, so
# `wrangler deploy` served the entire working directory (.git, vault copies,
# book drafts). This guard enforces the allowlist invariant and fails the
# deploy before anything ships if the deploy set is not strictly the site.
#
# Use ./deploy.sh (which runs this first). Never run `wrangler deploy` directly.
set -euo pipefail

cd "$(dirname "$0")"

fail() { printf 'PREDEPLOY GUARD FAILED: %b\n' "$*" >&2; exit 1; }

AI=".assetsignore"
[ -f "$AI" ] || fail "$AI is missing. Refusing to deploy without an allowlist."

# 1. Allowlist invariant: the first effective line of .assetsignore must be '*'
#    (deny everything, then re-include the site). If it is not, someone turned
#    it back into a denylist, which is exactly what caused the incident.
first="$(grep -vE '^[[:space:]]*(#|$)' "$AI" | head -1 | tr -d '[:space:]')"
[ "$first" = "*" ] || fail ".assetsignore must start with a deny-all '*'. Found '$first'. This looks like a denylist again."

# 2. VCS and tooling directories must be explicitly excluded.
grep -qE '^\.git/' "$AI"      || fail ".assetsignore must exclude .git/"
grep -qE '^\.wrangler/' "$AI" || fail ".assetsignore must exclude .wrangler/"

# 3. No manuscript / Office files anywhere in the deploy root.
docx="$(find . -type f \( -iname '*.docx' -o -iname '*.doc' -o -iname '*.pages' \) -not -path './.git/*' || true)"
[ -z "$docx" ] || fail "Office/manuscript files present in the deploy root:\n$docx"

# 4. Only known public-site entries may exist at the top level. Anything else
#    (a stray drafts folder, a vault copy, a runbook) fails the deploy.
ALLOWED=" index.html robots.txt sitemap.xml og.png favicon.svg _headers warmup setup personalize prompts about field-notes README.md wrangler.jsonc .gitignore .assetsignore .mcp.json .git .wrangler predeploy-check.sh deploy.sh "
while IFS= read -r entry; do
  name="$(basename "$entry")"
  case "$ALLOWED" in
    *" $name "*) : ;;
    *) fail "Unexpected top-level entry '$name'. Not part of the public site. Move it out of the deploy root, or add it to ALLOWED in this script on purpose." ;;
  esac
done < <(find . -mindepth 1 -maxdepth 1)

# 5. No stray markdown at the top level except README.md.
stray_md="$(find . -mindepth 1 -maxdepth 1 -type f -iname '*.md' ! -name 'README.md' || true)"
[ -z "$stray_md" ] || fail "Stray markdown at the top level:\n$stray_md"

echo "Pre-deploy guard passed: only the public site will be published."
