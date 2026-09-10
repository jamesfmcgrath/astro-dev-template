#!/usr/bin/env bash
# Regression suite for the bare template. Exercises scripts/init.sh across the
# supported flavour/deploy-target combinations in a throwaway copy, then
# asserts the tokeniser and file invariants.
# No network, no package manager, no create-astro: the live spin-up remains a
# manual verification step (see template-docs/memory.md).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; RESET="\033[0m"

TOTAL_PASS=0
TOTAL_FAIL=0

pass() { TOTAL_PASS=$((TOTAL_PASS + 1)); echo -e "  ${GREEN}OK${RESET}   $*"; }
fail() { TOTAL_FAIL=$((TOTAL_FAIL + 1)); echo -e "  ${RED}FAIL${RESET} $*"; }

# One entry per combination under test:
#   flavour|deploy target|expected ASTRO_TEMPLATE|expected ADAPTER
# The three flavours are covered on static, plus one on ssr, because the
# adapter axis is derived independently of the template axis. Add a line here
# when a new flavour or deploy target lands; this is the only place a new
# combination registers its expected derived values.
COMBOS=(
  "minimal|static|minimal|"
  "blog|static|blog|"
  "starlight|static|starlight|"
  "minimal|ssr|minimal|@astrojs/node"
)

SITE_NAME="regress-site"
SITE_LABEL="Regress Site"
# The ampersand is deliberate: real client names contain one, and & is special
# in a sed replacement, so this also proves init.sh escapes its values.
CLIENT="Regress & District Ltd"
SKILL_FORK="regressowner"

# The scratch file one combo injects before running init.sh, to prove the
# substitution list is discovered rather than hand-maintained.
INJECTED_FILE="scratch-token-check.md"

# Files that document the {{UPPER_SNAKE}} token convention as literal text
# rather than being files init.sh substitutes into. CONVENTIONS.md survives
# into the created project, so its literal example is a permanent, deliberate
# exception. template-docs/ is removed by init.sh and never reaches this check.
TOKEN_DOC_EXCEPTIONS=("CONVENTIONS.md")

# Files that hold no {{TOKENS}} and so must survive init.sh byte for byte.
VERBATIM_FILES=(.editorconfig .vscode/extensions.json CHANGELOG.md \
  eslint.config.mjs .prettierrc.json vitest.config.ts cspell.json \
  scripts/a11y-scan.mjs playwright.config.mjs tests/vrt/vrt.spec.mjs \
  scripts/browser-check.sh)

yaml_parse() {
  local f="$1"
  if command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -e "YAML.load_file(ARGV[0])" "$f" >/dev/null 2>&1
  elif python3 -c "import yaml" >/dev/null 2>&1; then
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" >/dev/null 2>&1
  else
    echo "  no YAML parser (ruby or python3+PyYAML) available" >&2
    return 1
  fi
}

json_parse() {
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$1" >/dev/null 2>&1
}

# Paths init.sh removes as part of a normal run. Prose here (TEMPLATE.md,
# template-docs/, this suite's own source) quotes the ${{ }} rule rather than
# holding real workflow expressions, and its removal is already asserted in
# assert_common; excluded so it does not pollute the tokenisation invariant
# below with an expected deletion.
GA_EXPR_EXCLUDES=("./scripts/init.sh" "./TEMPLATE.md" "./scripts/test-template.sh" "./template-docs")

# extract_ga_expressions <dir> -> sorted "relpath<TAB>expression" lines, one
# per GitHub Actions ${{ ... }} match. The baseline is derived from whatever
# the staged copy currently contains rather than a hardcoded count, so a
# legitimate CI edit that adds or removes an expression never breaks the
# suite; the invariant is that tokenisation must not alter or destroy any
# expression that was there before init.sh ran.
extract_ga_expressions() {
  local dir="$1" f p skip
  (cd "$dir" && grep -rlE '\$\{\{[^}]*\}\}' . --exclude-dir=.git 2>/dev/null) | while IFS= read -r f; do
    skip=0
    for p in "${GA_EXPR_EXCLUDES[@]}"; do
      case "$f" in
        "$p" | "$p"/*) skip=1; break ;;
      esac
    done
    [ "$skip" = "1" ] && continue
    grep -oE '\$\{\{[^}]*\}\}' "$dir/$f" | while IFS= read -r expr; do
      printf '%s\t%s\n' "${f#./}" "$expr"
    done
  done | sort
}

# Feed init.sh's prompts in order. A blank line accepts the offered default.
# Prompt order: site name, site label, client, skill fork, flavour, deploy
# target. Used by the one combo that covers the interactive path; every other
# combo goes through init_flags below.
init_input() { # init_input <flavour> <deploy_target>
  printf '%s\n' "$SITE_NAME"
  printf '\n\n\n'
  printf '%s\n%s\n' "$1" "$2"
}

# The non-interactive form: one flag per prompt, one line per argument so the
# caller can read it back into an array.
init_flags() { # init_flags <flavour> <deploy_target>
  printf '%s\n' --site "$SITE_NAME" --site-label "$SITE_LABEL" \
    --client "$CLIENT" --skill-fork "$SKILL_FORK" \
    --flavour "$1" --deploy-target "$2"
}

# .superpowers/ is a session's own SDD scratch workspace (ledger, briefs,
# reports). It is never part of the template and must not leak into a staged
# copy, where init.sh would substitute tokens into it and the leftover-token
# scan would read it.
stage_copy() { # stage_copy <dest>
  rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
    --exclude='.astro' --exclude='.claude/settings.local.json' \
    --exclude='.superpowers' \
    "$REPO_ROOT"/ "$1"/ >/dev/null
}

assert_no_leftover_tokens() { # assert_no_leftover_tokens <dir> <label>
  local dir="$1" label="$2" ex leftover
  local exclude_args=()
  for ex in "${TOKEN_DOC_EXCEPTIONS[@]}"; do exclude_args+=(--exclude="$ex"); done
  leftover="$(grep -rlE '\{\{[A-Z_]+\}\}' "$dir" --exclude-dir=.git "${exclude_args[@]}" 2>/dev/null || true)"
  if [ -z "$leftover" ]; then
    pass "$label: no {{UPPER_SNAKE}} tokens remain outside ${TOKEN_DOC_EXCEPTIONS[*]}"
  else
    fail "$label: leftover tokens in: $(echo "$leftover" | tr '\n' ' ')"
  fi
}

# Shared per-run assertions: the invariants that must hold after init.sh no
# matter which combination was answered.
assert_common() { # assert_common <dir> <label>
  local dir="$1" label="$2" f

  if [ ! -e "$dir/scripts/init.sh" ]; then pass "$label: scripts/init.sh removed itself"; else fail "$label: scripts/init.sh still present"; fi
  if [ ! -e "$dir/TEMPLATE.md" ]; then pass "$label: TEMPLATE.md removed"; else fail "$label: TEMPLATE.md still present"; fi
  if [ ! -e "$dir/scripts/test-template.sh" ]; then pass "$label: scripts/test-template.sh removed"; else fail "$label: scripts/test-template.sh still present"; fi
  if [ ! -e "$dir/template-docs" ]; then pass "$label: template-docs/ removed"; else fail "$label: template-docs/ still present"; fi

  # Maintainer-only material a client project must not inherit. Both already
  # live under template-docs/, so the blanket removal above covers them; these
  # assert that explicitly rather than relying only on the coarser check.
  if [ ! -e "$dir/template-docs/plans" ]; then pass "$label: template-docs/plans/ removed"; else fail "$label: template-docs/plans/ still present"; fi
  if [ ! -e "$dir/template-docs/PROMPTS.md" ]; then pass "$label: template-docs/PROMPTS.md removed"; else fail "$label: template-docs/PROMPTS.md still present"; fi

  # CONVENTIONS.md documents the scripts a created project still has, so it is
  # deliberately kept.
  if [ -f "$dir/CONVENTIONS.md" ]; then pass "$label: CONVENTIONS.md kept"; else fail "$label: CONVENTIONS.md was removed"; fi

  assert_no_leftover_tokens "$dir" "$label"

  if bash -n "$dir/scripts/setup.sh" 2>/dev/null; then pass "$label: scripts/setup.sh bash -n"; else fail "$label: scripts/setup.sh bash -n failed"; fi
  if [ -x "$dir/scripts/setup.sh" ]; then pass "$label: scripts/setup.sh still executable"; else fail "$label: scripts/setup.sh not executable"; fi

  for target in help dev build preview check lint lint-fix format format-check test spell clean a11y vrt vrt-update; do
    if (cd "$dir" && make -n "$target") >/dev/null 2>&1; then
      pass "$label: make -n $target parses"
    else
      fail "$label: make -n $target failed"
    fi
  done
  if (cd "$dir" && make -n add I=react) >/dev/null 2>&1; then
    pass "$label: make -n add I=react parses"
  else
    fail "$label: make -n add I=react failed"
  fi

  if json_parse "$dir/.vscode/extensions.json"; then
    pass "$label: .vscode/extensions.json is valid JSON"
  else
    fail "$label: .vscode/extensions.json is not valid JSON"
  fi
  if json_parse "$dir/.prettierrc.json"; then
    pass "$label: .prettierrc.json is valid JSON"
  else
    fail "$label: .prettierrc.json is not valid JSON"
  fi
  if json_parse "$dir/cspell.json"; then
    pass "$label: cspell.json is valid JSON"
  else
    fail "$label: cspell.json is not valid JSON"
  fi
  if json_parse "$dir/scan-urls.json"; then
    pass "$label: scan-urls.json is valid JSON"
  else
    fail "$label: scan-urls.json is not valid JSON"
  fi
  if yaml_parse "$dir/.github/workflows/ci.yml"; then
    pass "$label: ci.yml is valid YAML"
  else
    fail "$label: ci.yml is not valid YAML"
  fi

  for f in "${VERBATIM_FILES[@]}"; do
    if diff -q "$REPO_ROOT/$f" "$dir/$f" >/dev/null 2>&1; then
      pass "$label: $f survives init.sh verbatim"
    else
      fail "$label: $f changed or missing after init.sh"
    fi
  done
}

assert_file_contains() { # assert_file_contains <file> <literal> <message>
  if grep -qF "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

# The answers file records what init.sh resolved: prompted and derived alike.
assert_answers() { # assert_answers <dir> <label> <flavour> <deploy> <astro_template> <adapter> <mode>
  local dir="$1" label="$2" flavour="$3" deploy="$4" astro_template="$5"
  local adapter="$6" mode="$7" expected
  if [ -f "$dir/template.answers" ]; then
    pass "$label: template.answers written and kept"
  else
    fail "$label: template.answers missing"
    return
  fi
  local expectations=(
    "SITE_NAME=$SITE_NAME"
    "FLAVOUR=$flavour"
    "DEPLOY_TARGET=$deploy"
    "ASTRO_TEMPLATE=$astro_template"
    "ADAPTER=$adapter"
  )
  # The interactive combo accepts the offered defaults for these three, so only
  # a flag run can assert the supplied values.
  if [ "$mode" != "interactive" ]; then
    expectations+=("SITE_LABEL=$SITE_LABEL" "CLIENT=$CLIENT" "SKILL_FORK=$SKILL_FORK")
  fi
  for expected in "${expectations[@]}"; do
    if grep -qxF "$expected" "$dir/template.answers"; then
      pass "$label: template.answers records $expected"
    else
      fail "$label: template.answers missing $expected"
    fi
  done
}

# The substituted values, including the derived ones, must actually reach the
# files that use them.
assert_substitutions() { # assert_substitutions <dir> <label> <flavour> <deploy> <astro_template> <adapter> <mode>
  local dir="$1" label="$2" flavour="$3" deploy="$4" astro_template="$5"
  local adapter="$6" mode="$7"

  assert_file_contains "$dir/scripts/setup.sh" "ASTRO_TEMPLATE=\"$astro_template\"" \
    "$label: setup.sh carries the derived ASTRO_TEMPLATE ($astro_template)"
  assert_file_contains "$dir/scripts/setup.sh" "ADAPTER=\"$adapter\"" \
    "$label: setup.sh carries the derived ADAPTER (${adapter:-empty})"
  assert_file_contains "$dir/scripts/setup.sh" "SITE_NAME=\"$SITE_NAME\"" \
    "$label: setup.sh carries SITE_NAME"
  assert_file_contains "$dir/Makefile" "SITE_NAME = $SITE_NAME" \
    "$label: Makefile carries SITE_NAME"
  assert_file_contains "$dir/Makefile" "FLAVOUR = $flavour" \
    "$label: Makefile carries FLAVOUR"
  assert_file_contains "$dir/Makefile" "DEPLOY_TARGET = $deploy" \
    "$label: Makefile carries DEPLOY_TARGET"
  assert_file_contains "$dir/AGENTS.md" "\`$SITE_NAME\`" \
    "$label: AGENTS.md carries SITE_NAME"

  if [ "$mode" != "interactive" ]; then
    assert_file_contains "$dir/AGENTS.md" "$CLIENT" "$label: AGENTS.md carries --client"
    assert_file_contains "$dir/README.md" "$CLIENT" "$label: README.md carries --client"
    assert_file_contains "$dir/AGENTS.md" "$SITE_LABEL" "$label: AGENTS.md carries --site-label"
    assert_file_contains "$dir/README.md" "# $SITE_LABEL" "$label: README.md heading carries --site-label"
    assert_file_contains "$dir/scripts/setup.sh" "SKILL_FORK=\"$SKILL_FORK\"" \
      "$label: setup.sh carries --skill-fork"
    assert_file_contains "$dir/agr.toml" "default_owner = \"$SKILL_FORK\"" \
      "$label: agr.toml carries --skill-fork"
  fi
}

# scan-urls.json's content depends only on FLAVOUR, set directly by init.sh
# rather than substituted, so it gets its own comparison instead of living in
# assert_substitutions.
assert_scan_urls() { # assert_scan_urls <dir> <label> <flavour>
  local dir="$1" label="$2" flavour="$3" expected
  case "$flavour" in
    blog)      expected='["/", "/blog/first-post/"]' ;;
    starlight) expected='["/", "/guides/example/"]' ;;
    *)         expected='["/"]' ;;
  esac
  if python3 -c "
import json, sys
expected = json.loads(sys.argv[1])
actual = json.load(open(sys.argv[2]))
sys.exit(0 if actual == expected else 1)
" "$expected" "$dir/scan-urls.json" 2>/dev/null; then
    pass "$label: scan-urls.json matches $flavour defaults"
  else
    fail "$label: scan-urls.json does not match $flavour defaults (got: $(cat "$dir/scan-urls.json" 2>/dev/null | tr '\n' ' '))"
  fi
}

run_combo() { # run_combo <flavour> <deploy> <astro_template> <adapter> [mode] [inject]
  local flavour="$1" deploy="$2" astro_template="$3" adapter="$4"
  local mode="${5:-flags}" inject="${6:-}"
  local label="$flavour/$deploy${mode:+ ($mode)}"

  echo ""
  echo -e "${BOLD}== $label ==${RESET}"

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-template.XXXXXX")"
  stage_copy "$tmp_dir"

  local ga_before ga_after
  ga_before="$(extract_ga_expressions "$tmp_dir")"

  # A file that did not exist when the template was written must still be
  # substituted: the file list is discovered, not hand-maintained.
  if [ "$inject" = "1" ]; then
    printf 'Injected before init.sh, for %s\n' '{{CLIENT}}' > "$tmp_dir/$INJECTED_FILE"
  fi

  local init_log="$tmp_dir/.init-output.log"
  if [ "$mode" = "interactive" ]; then
    if (cd "$tmp_dir" && init_input "$flavour" "$deploy" | ./scripts/init.sh) >"$init_log" 2>&1; then
      pass "$label: init.sh exits 0"
    else
      fail "$label: init.sh exited nonzero (see $init_log)"
    fi
  else
    local flags=() arg
    while IFS= read -r arg; do flags+=("$arg"); done < <(init_flags "$flavour" "$deploy")
    # stdin closed: a flag run that still reaches a prompt fails here.
    if (cd "$tmp_dir" && ./scripts/init.sh "${flags[@]}" </dev/null) >"$init_log" 2>&1; then
      pass "$label: init.sh exits 0 with no tty interaction"
    else
      fail "$label: init.sh exited nonzero (see $init_log)"
    fi
  fi

  assert_common "$tmp_dir" "$label"
  assert_answers "$tmp_dir" "$label" "$flavour" "$deploy" "$astro_template" "$adapter" "$mode"
  assert_substitutions "$tmp_dir" "$label" "$flavour" "$deploy" "$astro_template" "$adapter" "$mode"
  assert_scan_urls "$tmp_dir" "$label" "$flavour"

  if [ "$inject" = "1" ]; then
    if grep -qF "$CLIENT" "$tmp_dir/$INJECTED_FILE" 2>/dev/null; then
      pass "$label: newly added $INJECTED_FILE was discovered and substituted"
    else
      fail "$label: newly added $INJECTED_FILE was not substituted"
    fi
  fi

  # GitHub Actions ${{ ... }} expressions must survive untouched: the exact
  # set (not just a count) must match before and after init.sh ran.
  ga_after="$(extract_ga_expressions "$tmp_dir")"
  if [ "$ga_before" = "$ga_after" ]; then
    pass "$label: \${{ }} expressions unchanged across init.sh"
  else
    fail "$label: \${{ }} expressions changed across init.sh"
    diff <(printf '%s\n' "$ga_before") <(printf '%s\n' "$ga_after") | sed 's/^/      /'
  fi

  # A second run must refuse rather than half-apply anything.
  if [ -e "$tmp_dir/scripts/init.sh" ]; then
    fail "$label: cannot test the re-run guard, init.sh still present"
  else
    pass "$label: re-run is impossible, init.sh removed itself"
  fi

  rm -rf "$tmp_dir"
}

echo -e "${BOLD}Template regression suite${RESET}"
echo "Repo: $REPO_ROOT"

# Guard: the bare template must still hold its tokens, or every assertion below
# is meaningless.
if grep -q '{{SITE_LABEL}}' AGENTS.md 2>/dev/null; then
  pass "bare template still holds its tokens"
else
  fail "bare template has no {{SITE_LABEL}} token in AGENTS.md; has init.sh already run here?"
fi

echo ""
echo -e "${BOLD}== browser-check scripts: syntax ==${RESET}"
NODE_CHECK_FILES=(scripts/a11y-scan.mjs playwright.config.mjs tests/vrt/vrt.spec.mjs)
for f in "${NODE_CHECK_FILES[@]}"; do
  if command -v node >/dev/null 2>&1 && node --check "$f" 2>/dev/null; then
    pass "node --check $f"
  elif ! command -v node >/dev/null 2>&1; then
    echo "  no node available, skipping node --check $f" >&2
  else
    fail "node --check $f"
  fi
done
if bash -n scripts/browser-check.sh; then
  pass "bash -n scripts/browser-check.sh"
else
  fail "bash -n scripts/browser-check.sh"
fi
if [ -x scripts/browser-check.sh ]; then
  pass "scripts/browser-check.sh is executable"
else
  fail "scripts/browser-check.sh is not executable"
fi

# Every combination through the flag path. The first also injects a file to
# prove dynamic discovery.
first=1
for combo in "${COMBOS[@]}"; do
  IFS='|' read -r flavour deploy astro_template adapter <<< "$combo"
  if [ "$first" = "1" ]; then
    run_combo "$flavour" "$deploy" "$astro_template" "$adapter" flags 1
    first=0
  else
    run_combo "$flavour" "$deploy" "$astro_template" "$adapter" flags ""
  fi
done

# One combination through the prompt path, so the interactive fallback stays
# covered.
run_combo "blog" "static" "blog" "" interactive ""

# titlecase()/SITE_LABEL: BSD tr rejected tr '-_' '  ' as an illegal option
# (starts with '-'), so titlecase() silently produced nothing and SITE_LABEL
# came out empty on any run that did not pass --site-label explicitly. None of
# the COMBOS above exercise this path, since they all pass --site-label, so
# this section drives it directly.
echo ""
echo -e "${BOLD}== titlecase / SITE_LABEL ==${RESET}"

# Unit-level: exercise the function itself with input a real --site value
# never reaches (site names cannot hold an underscore, see valid_site_name),
# so the hyphen-and-underscore case can only be proven directly.
titlecase_src="$(sed -n '/^titlecase() {/,/^}/p' scripts/init.sh)"
eval "$titlecase_src"
tc_result="$(titlecase 'foo-bar_baz')"
if [ "$tc_result" = "Foo Bar Baz" ]; then
  pass "titlecase: hyphen and underscore both split and capitalised (foo-bar_baz -> $tc_result)"
else
  fail "titlecase: foo-bar_baz -> '$tc_result', expected 'Foo Bar Baz'"
fi

# --defaults: no flags at all, so SITE_LABEL must derive from titlecase() of
# the default site name.
defaults_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-template.XXXXXX")"
stage_copy "$defaults_dir"
if (cd "$defaults_dir" && ./scripts/init.sh --defaults </dev/null) >/dev/null 2>&1; then
  pass "titlecase: --defaults run exits 0"
else
  fail "titlecase: --defaults run exited nonzero"
fi
if grep -qxF 'SITE_LABEL=My Site' "$defaults_dir/template.answers" 2>/dev/null; then
  pass "titlecase: --defaults derives a non-empty SITE_LABEL (My Site)"
else
  fail "titlecase: --defaults produced an unexpected or empty SITE_LABEL ($(grep '^SITE_LABEL=' "$defaults_dir/template.answers" 2>/dev/null))"
fi
rm -rf "$defaults_dir"

# --site only: every other prompt falls through to ask()'s own default,
# including SITE_LABEL, which is exactly the path the bug broke.
site_only_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-template.XXXXXX")"
stage_copy "$site_only_dir"
if (cd "$site_only_dir" && ./scripts/init.sh --site acme-site </dev/null) >/dev/null 2>&1; then
  pass "titlecase: --site-only run exits 0 with no tty interaction"
else
  fail "titlecase: --site-only run exited nonzero"
fi
if grep -qxF 'SITE_LABEL=Acme Site' "$site_only_dir/template.answers" 2>/dev/null; then
  pass "titlecase: --site acme-site derives a non-empty SITE_LABEL (Acme Site)"
else
  fail "titlecase: --site acme-site produced an unexpected or empty SITE_LABEL ($(grep '^SITE_LABEL=' "$site_only_dir/template.answers" 2>/dev/null))"
fi
rm -rf "$site_only_dir"

# Flag validation: a bad value must fail before any prompt, and a repeat run
# must refuse.
echo ""
echo -e "${BOLD}== flag validation ==${RESET}"
validate_dir="$(mktemp -d "${TMPDIR:-/tmp}/test-template.XXXXXX")"
stage_copy "$validate_dir"
for bad in "--flavour=nonsense" "--deploy-target=nonsense" "--site=Bad_Name" "--client=" "--nope"; do
  if (cd "$validate_dir" && ./scripts/init.sh "$bad" </dev/null) >/dev/null 2>&1; then
    fail "flag validation: $bad was accepted"
  else
    pass "flag validation: $bad rejected"
  fi
done
if [ -f "$validate_dir/scripts/init.sh" ]; then
  pass "flag validation: a rejected run leaves init.sh in place"
else
  fail "flag validation: a rejected run removed init.sh"
fi
if [ ! -f "$validate_dir/template.answers" ]; then
  pass "flag validation: a rejected run writes no template.answers"
else
  fail "flag validation: a rejected run wrote template.answers"
fi
# --help must exit 0 and change nothing.
if (cd "$validate_dir" && ./scripts/init.sh --help </dev/null) >/dev/null 2>&1; then
  pass "flag validation: --help exits 0"
else
  fail "flag validation: --help did not exit 0"
fi
# The re-run guard: initialise, then try again.
(cd "$validate_dir" && ./scripts/init.sh --site "$SITE_NAME" --site-label "$SITE_LABEL" \
  --client "$CLIENT" --skill-fork "$SKILL_FORK" --flavour minimal --deploy-target static </dev/null) >/dev/null 2>&1
cp "$REPO_ROOT/scripts/init.sh" "$validate_dir/scripts/init.sh"
if (cd "$validate_dir" && ./scripts/init.sh --defaults </dev/null) >/dev/null 2>&1; then
  fail "re-run guard: init.sh ran a second time on an initialised repo"
else
  pass "re-run guard: init.sh refuses to run on an initialised repo"
fi
rm -rf "$validate_dir"

echo ""
echo -e "${BOLD}== summary ==${RESET}"
echo -e "  ${GREEN}pass: $TOTAL_PASS${RESET}"
if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo -e "  ${RED}fail: $TOTAL_FAIL${RESET}"
  exit 1
fi
echo "  fail: 0"
echo ""
echo "Tokeniser invariants hold. The create-astro spin-up is out of scope for"
echo "this suite; its live verification status is in template-docs/memory.md."
