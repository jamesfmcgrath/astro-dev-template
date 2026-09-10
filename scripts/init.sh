#!/usr/bin/env bash
# One-time template initialiser. Run from the repo root immediately after
# creating a repo from this template:  ./scripts/init.sh
# Takes its answers from flags, from prompts, or from both; records them in
# template.answers; substitutes {{TOKENS}} across every file that holds one;
# then removes itself, TEMPLATE.md, the regression suite and template-docs/.
# Portable across macOS (BSD) and Linux (GNU). Touches no network.
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m"
info()  { echo -e "${BOLD}> $*${RESET}"; }
ok()    { echo -e "${GREEN}OK $*${RESET}"; }
warn()  { echo -e "${YELLOW}!! $*${RESET}"; }
die()   { echo -e "${RED}!! $*${RESET}" >&2; exit 1; }

ANSWERS_FILE="template.answers"

usage() {
  cat <<'EOF'
Usage: ./scripts/init.sh [options]

Any value not given as a flag is prompted for. With --defaults, or with a full
flag set, the script runs without touching a tty.

  --site NAME            Site machine name, kebab-case (for example acme-site)
  --site-label LABEL     Human-readable site name (default: title-cased name)
  --client TEXT          Client / context line
  --skill-fork OWNER     GitHub owner hosting the agent-resources fork
  --flavour FLAVOUR      minimal | blog | starlight
  --deploy-target TARGET static | ssr
  --defaults             Accept every default without prompting
  -h, --help             Show this help

Flags take --flag VALUE or --flag=VALUE. Use --flag=VALUE to supply an
explicitly empty value.

Derived from --flavour and --deploy-target, never prompted:
  ASTRO_TEMPLATE   the create-astro template name (minimal | blog | starlight)
  ADAPTER          empty for static, @astrojs/node for ssr
EOF
}

SITE_NAME="";     SET_SITE_NAME=0
SITE_LABEL="";    SET_SITE_LABEL=0
CLIENT="";        SET_CLIENT=0
SKILL_FORK="";    SET_SKILL_FORK=0
FLAVOUR="";       SET_FLAVOUR=0
DEPLOY_TARGET=""; SET_DEPLOY_TARGET=0
DEFAULTS=0

require_value() { # require_value <flag> <remaining argc> <next arg>
  local flag="$1" argc="$2" value="${3-}"
  [ "$argc" -ge 2 ] || die "$flag requires a value (use $flag=VALUE for an empty one)."
  case "$value" in
    --*) die "$flag requires a value, got $value. Use $flag=VALUE for a value starting with --." ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --site=*)           SITE_NAME="${1#*=}";     SET_SITE_NAME=1 ;;
    --site)             require_value "$1" "$#" "${2-}"; SITE_NAME="$2";     SET_SITE_NAME=1;     shift ;;
    --site-label=*)     SITE_LABEL="${1#*=}";    SET_SITE_LABEL=1 ;;
    --site-label)       require_value "$1" "$#" "${2-}"; SITE_LABEL="$2";    SET_SITE_LABEL=1;    shift ;;
    --client=*)         CLIENT="${1#*=}";        SET_CLIENT=1 ;;
    --client)           require_value "$1" "$#" "${2-}"; CLIENT="$2";        SET_CLIENT=1;        shift ;;
    --skill-fork=*)     SKILL_FORK="${1#*=}";    SET_SKILL_FORK=1 ;;
    --skill-fork)       require_value "$1" "$#" "${2-}"; SKILL_FORK="$2";    SET_SKILL_FORK=1;    shift ;;
    --flavour=*)        FLAVOUR="${1#*=}";       SET_FLAVOUR=1 ;;
    --flavour)          require_value "$1" "$#" "${2-}"; FLAVOUR="$2";       SET_FLAVOUR=1;       shift ;;
    --deploy-target=*)  DEPLOY_TARGET="${1#*=}"; SET_DEPLOY_TARGET=1 ;;
    --deploy-target)    require_value "$1" "$#" "${2-}"; DEPLOY_TARGET="$2"; SET_DEPLOY_TARGET=1; shift ;;
    --defaults)         DEFAULTS=1 ;;
    -h|--help)          usage; exit 0 ;;
    *)                  usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

if ! grep -q "{{SITE_LABEL}}" AGENTS.md 2>/dev/null; then
  warn "Already initialised (no {{SITE_LABEL}} token in AGENTS.md). Aborting."
  exit 1
fi

ask() { # ask <prompt> <default> -> echoes answer
  local prompt="$1" def="${2:-}" ans
  if [ "$DEFAULTS" = "1" ]; then echo "$def"; return 0; fi
  if [ -n "$def" ]; then read -r -p "$prompt [$def]: " ans; echo "${ans:-$def}"
  else read -r -p "$prompt: " ans; echo "$ans"; fi
}

# BSD tr (macOS) rejects a multi-char set like tr '-_' '  ' as an illegal
# option because it starts with '-'; awk alone avoids tr entirely and its
# toupper/substr are POSIX, so this stays portable across BSD and GNU.
titlecase() {
  printf '%s' "$1" | awk '{
    gsub(/[-_]+/, " ")
    for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2)
    print
  }'
}

SITE_NAME_RULE="Site machine names must start with a lowercase letter and may contain only lowercase letters, digits and hyphens (for example acme-site). This becomes the npm package name, so underscores and capitals are not valid."

valid_site_name() { # valid_site_name <value> -> 0 when usable
  local ans="$1"
  [ -n "$ans" ] || return 1
  case "$ans" in [a-z]*) ;; *) return 1 ;; esac
  [ -z "$(printf '%s' "$ans" | tr -d 'a-z0-9-')" ]
}

ask_site_name() { # ask_site_name <prompt> <default> -> echoes a valid name
  local prompt="$1" def="$2" ans
  while true; do
    ans="$(ask "$prompt" "$def")"
    if valid_site_name "$ans"; then echo "$ans"; return 0; fi
    warn "$SITE_NAME_RULE" >&2
  done
}

require_flag_value() { # require_flag_value <value> <flag>
  [ -n "$1" ] || die "$2 must not be empty."
}

# Validate flag values before the first prompt, so a typo fails immediately
# rather than after a run of questions.
if [ "$SET_SITE_NAME" = "1" ]; then
  valid_site_name "$SITE_NAME" || die "--site: $SITE_NAME_RULE"
fi
[ "$SET_SITE_LABEL" = "1" ] && require_flag_value "$SITE_LABEL" "--site-label"
[ "$SET_CLIENT" = "1" ]     && require_flag_value "$CLIENT" "--client"
[ "$SET_SKILL_FORK" = "1" ] && require_flag_value "$SKILL_FORK" "--skill-fork"
if [ "$SET_FLAVOUR" = "1" ]; then
  case "$FLAVOUR" in
    minimal|blog|starlight) ;;
    *) die "--flavour must be minimal, blog or starlight (got '$FLAVOUR')." ;;
  esac
fi
if [ "$SET_DEPLOY_TARGET" = "1" ]; then
  case "$DEPLOY_TARGET" in
    static|ssr) ;;
    *) die "--deploy-target must be static or ssr (got '$DEPLOY_TARGET')." ;;
  esac
fi

echo ""; info "Initialise this template"; echo ""

if [ "$SET_SITE_NAME" != "1" ]; then
  SITE_NAME="$(ask_site_name 'Site machine name (kebab-case)' 'my-site')"
fi
if [ "$SET_SITE_LABEL" != "1" ]; then
  SITE_LABEL="$(ask 'Site label' "$(titlecase "$SITE_NAME")")"
fi
if [ "$SET_CLIENT" != "1" ]; then
  CLIENT="$(ask 'Client / context' 'an internal project')"
fi
if [ "$SET_SKILL_FORK" != "1" ]; then
  SKILL_FORK="$(ask 'agent-resources fork owner (hosts the astro skills)' 'jamesfmcgrath')"
fi

echo ""
if [ "$SET_FLAVOUR" != "1" ]; then
  # Anything unrecognised at the prompt falls back to minimal, matching the
  # permissive prompt behaviour of the flags-validated path above.
  FLAVOUR="$(ask 'Astro flavour: minimal, blog or starlight' 'minimal')"
  case "$FLAVOUR" in
    minimal|blog|starlight) ;;
    *) warn "Unrecognised flavour '$FLAVOUR'; using minimal."; FLAVOUR="minimal" ;;
  esac
fi
if [ "$SET_DEPLOY_TARGET" != "1" ]; then
  DEPLOY_TARGET="$(ask 'Deploy target: static or ssr' 'static')"
  case "$DEPLOY_TARGET" in
    static|ssr) ;;
    *) warn "Unrecognised deploy target '$DEPLOY_TARGET'; using static."; DEPLOY_TARGET="static" ;;
  esac
fi

# Derived tokens.
#
# ASTRO_TEMPLATE is the value passed to create-astro's --template flag. The map
# is currently the identity: verified against create-astro 5.2.4, which offers
# basics, blog, starlight and minimal, resolving minimal and blog to
# github:withastro/astro/examples/<name> and special-casing starlight to
# github:withastro/starlight/examples/basics. Keep this indirection: if a
# flavour ever needs a different upstream name, this is the only place to
# change it.
case "$FLAVOUR" in
  blog)      ASTRO_TEMPLATE="blog" ;;
  starlight) ASTRO_TEMPLATE="starlight" ;;
  *)         ASTRO_TEMPLATE="minimal" ;;
esac

# ADAPTER is passed to "astro add" by setup.sh. Empty means a fully static
# build with no adapter. @astrojs/node is the default server runtime and is
# swappable: replace it with @astrojs/cloudflare or @astrojs/vercel in
# template.answers and in the ADAPTER line of scripts/setup.sh, then re-run
# "make add I=<adapter>". All three are official Astro adapters.
case "$DEPLOY_TARGET" in
  ssr) ADAPTER="@astrojs/node" ;;
  *)   ADAPTER="" ;;
esac

# scan-urls.json: the shared page list axe-core and the Playwright visual
# regression test both read (see CONVENTIONS.md, "Browser checks"). Set from
# FLAVOUR so the default list matches pages the flavour actually builds: the
# front page always, plus one real content page for blog and starlight, taken
# from the create-astro / starlight example content each flavour scaffolds.
# Edit the file later as real content replaces the example pages.
case "$FLAVOUR" in
  blog)      SCAN_URLS='[
  "/",
  "/blog/first-post/"
]' ;;
  starlight) SCAN_URLS='[
  "/",
  "/guides/example/"
]' ;;
  *)         SCAN_URLS='[
  "/"
]' ;;
esac
printf '%s\n' "$SCAN_URLS" > scan-urls.json

# Record the resolved answers before substituting, so the run is auditable and
# can be reproduced with the matching flags. Each prompted key maps to the flag
# of the same name (SITE_NAME to --site, and so on); the last two are derived.
{
  echo "# Answers used by scripts/init.sh on $(date -u '+%Y-%m-%d'). Not a shell script:"
  echo "# a record of the run, one KEY=value per line, values unquoted."
  echo "SITE_NAME=$SITE_NAME"
  echo "SITE_LABEL=$SITE_LABEL"
  echo "CLIENT=$CLIENT"
  echo "SKILL_FORK=$SKILL_FORK"
  echo "FLAVOUR=$FLAVOUR"
  echo "DEPLOY_TARGET=$DEPLOY_TARGET"
  echo "ASTRO_TEMPLATE=$ASTRO_TEMPLATE"
  echo "ADAPTER=$ADAPTER"
} > "$ANSWERS_FILE"

# Paths never substituted into: this script (rewriting it while bash is still
# reading it corrupts the run), the suite that documents tokens as test
# fixtures, and the answers file just written.
SKIP_PATHS=(./scripts/init.sh ./scripts/test-template.sh "./$ANSWERS_FILE")

discover_token_files() { # -> one path per line, relative to the repo root
  # template-docs/ holds maintainer history that quotes tokens verbatim, and
  # CONVENTIONS.md documents the token grammar itself. node_modules/ and dist/
  # only exist once setup.sh has run, and dependency code is never ours to
  # rewrite.
  grep -rlE '\{\{[A-Z_]+\}\}' . \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist \
    --exclude-dir=.astro --exclude-dir=template-docs \
    --exclude=CONVENTIONS.md \
    2>/dev/null || true
}

FILES=()
while IFS= read -r found; do
  [ -n "$found" ] || continue
  skip=0
  for skip_path in "${SKIP_PATHS[@]}"; do
    if [ "$found" = "$skip_path" ]; then skip=1; break; fi
  done
  if [ "$skip" = "1" ]; then continue; fi
  FILES+=("$found")
done <<EOF
$(discover_token_files)
EOF

[ "${#FILES[@]}" -gt 0 ] || die "No files with {{TOKENS}} found. Run this from the repo root."

echo ""; info "Applying to ${#FILES[@]} files..."

# & and | are special in a sed replacement (or are the delimiter), so a client
# name like "Bath & North East Somerset" has to be escaped.
sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

SED_ARGS=()
sub() { # sub <token> <value>
  SED_ARGS+=(-e "s|{{$1}}|$(sed_escape "$2")|g")
}
sub SITE_NAME      "$SITE_NAME"
sub SITE_LABEL     "$SITE_LABEL"
sub CLIENT         "$CLIENT"
sub SKILL_FORK     "$SKILL_FORK"
sub FLAVOUR        "$FLAVOUR"
sub DEPLOY_TARGET  "$DEPLOY_TARGET"
sub ASTRO_TEMPLATE "$ASTRO_TEMPLATE"
sub ADAPTER        "$ADAPTER"

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  tmp="$(mktemp)"
  # Write back into the original file so its permissions (e.g. +x) are kept.
  sed "${SED_ARGS[@]}" "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
done

rm -f TEMPLATE.md scripts/test-template.sh
rm -rf template-docs
chmod +x scripts/setup.sh 2>/dev/null || true

ok "Tokens applied ($SITE_NAME, $FLAVOUR, $DEPLOY_TARGET)."
ok "Answers recorded in $ANSWERS_FILE; commit it alongside the substituted files."
info "Removing initialiser (scripts/init.sh)..."
rm -f scripts/init.sh
ok "Done. Next: ./scripts/setup.sh"
echo ""
if [ "$DEPLOY_TARGET" = "static" ]; then
  warn "Static build, no adapter. To go server-rendered later: make add I=node"
else
  warn "Server-rendered via $ADAPTER. Swap for Cloudflare or Vercel with: make add I=cloudflare (or I=vercel)."
  warn "Use the short adapter name; the scoped package name installs without configuring astro.config."
fi
warn "Review the git diff, then commit: git add -A && git commit -m 'Initialise from template'"
