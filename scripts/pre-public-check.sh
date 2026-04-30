#!/usr/bin/env bash
# Pre-public safety check for Cast.
#
# Runs the full pre-flip-public checklist from the plan:
#   - secret/token patterns in git history (all branches)
#   - gitleaks scan if installed
#   - suspicious files in the working tree
#   - .gitignore sanity
#   - pull_request_target usage in workflows
#   - commit author/email audit
#   - branch hygiene info
#
# Exit code: 0 = pass (possibly with warnings), 1 = findings to address.

set -u

# Move to repo root so paths are stable regardless of where the script is run.
cd "$(dirname "$0")/.."

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

FINDINGS=0
WARNINGS=0

section() { printf "\n${BOLD}${BLUE}== %s ==${NC}\n" "$1"; }
pass()    { printf "${GREEN}PASS${NC} %s\n" "$1"; }
fail()    { printf "${RED}${BOLD}FAIL${NC} %s\n" "$1"; FINDINGS=$((FINDINGS + 1)); }
warn()    { printf "${YELLOW}WARN${NC} %s\n" "$1"; WARNINGS=$((WARNINGS + 1)); }

#---------------------------------------------------------------------
section "1. Secret/token patterns in git history (all branches)"
#---------------------------------------------------------------------
# Patterns: OpenAI keys, GitHub tokens (PAT/server/oauth/user/refresh/installation),
# AWS keys, hardcoded password/secret JSON-style values, bearer tokens.
SECRET_HITS=$(git log --all -p 2>/dev/null \
    | grep -inE 'sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{30,}|gho_[a-zA-Z0-9]{30,}|ghu_[a-zA-Z0-9]{30,}|ghs_[a-zA-Z0-9]{30,}|github_pat_[a-zA-Z0-9_]{30,}|aws_secret_access_key|aws_access_key_id|"password"[[:space:]]*[:=]|"secret"[[:space:]]*[:=]|bearer[[:space:]]+[a-zA-Z0-9_.-]{20,}' \
    | head -50 || true)
if [ -n "$SECRET_HITS" ]; then
    HIT_COUNT=$(printf '%s\n' "$SECRET_HITS" | grep -c . || echo 0)
    fail "Found $HIT_COUNT lines matching secret patterns (first 10 below):"
    printf '%s\n' "$SECRET_HITS" | head -10 | sed 's/^/    /'
    printf "    ${YELLOW}(May be false positives in CHANGELOG/comments. Review each line.)${NC}\n"
else
    pass "No secret patterns found in git history."
fi

#---------------------------------------------------------------------
section "2. gitleaks scan"
#---------------------------------------------------------------------
if command -v gitleaks >/dev/null 2>&1; then
    LEAKS_OUT=$(gitleaks detect --source . --no-banner --redact -v 2>&1 || true)
    printf '%s\n' "$LEAKS_OUT" | tail -n 5
    if printf '%s' "$LEAKS_OUT" | grep -qE 'leaks found: 0|no leaks found'; then
        pass "gitleaks found no leaks."
    else
        COUNT=$(printf '%s' "$LEAKS_OUT" | grep -oE 'leaks found: [0-9]+' | grep -oE '[0-9]+' | head -1)
        if [ -n "${COUNT:-}" ] && [ "$COUNT" != "0" ]; then
            fail "gitleaks found $COUNT leaks (see output above)."
        else
            warn "gitleaks output unclear — review manually."
        fi
    fi
else
    warn "gitleaks not installed. Install with: brew install gitleaks"
fi

#---------------------------------------------------------------------
section "3. Suspicious files in working tree"
#---------------------------------------------------------------------
SUSPICIOUS=$(find . \
    -path ./.git -prune -o \
    -path ./Sources/CMLXStructured/xgrammar -prune -o \
    -path ./.build -prune -o \
    -type f \( \
        -name '.env' -o -name '.env.*' -o \
        -name '*.p12' -o -name '*.pem' -o -name '*.key' -o \
        -name 'id_rsa*' -o -name '.netrc' -o \
        -name '*.mobileprovision' -o -name 'GoogleService-Info.plist' \
    \) -print 2>/dev/null)
if [ -n "$SUSPICIOUS" ]; then
    fail "Suspicious files present in working tree:"
    echo "$SUSPICIOUS" | sed 's/^/    /'
else
    pass "No suspicious files (.env, *.p12, *.pem, etc.) in working tree."
fi

#---------------------------------------------------------------------
section "4. .gitignore sanity"
#---------------------------------------------------------------------
if [ ! -f .gitignore ]; then
    warn "No .gitignore file at repo root."
else
    if grep -qE '^\.claude/?$|settings\.local\.json' .gitignore; then
        pass ".claude/ (or settings.local.json) is gitignored."
    else
        warn ".claude/ is not in .gitignore. Add it before flipping public."
    fi

    if grep -qE '^\.env($|/|\.|\*)' .gitignore; then
        pass ".env files are gitignored."
    else
        warn ".env files may not be gitignored. Recommended: add '.env' and '.env.*'."
    fi
fi

#---------------------------------------------------------------------
section "5. pull_request_target usage (fork PR security)"
#---------------------------------------------------------------------
PRT_FILES=$(grep -lr 'pull_request_target' .github/workflows/ 2>/dev/null || true)
if [ -n "$PRT_FILES" ]; then
    warn "pull_request_target used in:"
    echo "$PRT_FILES" | sed 's/^/    /'
    echo "    Verify these don't run untrusted fork code with secret access."
else
    pass "No pull_request_target usage (safe default)."
fi

#---------------------------------------------------------------------
section "6. Commit author/email audit"
#---------------------------------------------------------------------
echo "Unique authors in history (confirm these emails are okay to be public):"
git log --all --pretty=format:'  %an <%ae>' | sort -u

#---------------------------------------------------------------------
section "7. Branch hygiene"
#---------------------------------------------------------------------
echo "Branches with last commit date (decide: keep, merge, or delete before public flip):"
git for-each-ref \
    --format='  %(committerdate:short)  %(refname:short)  (%(authorname))' \
    refs/remotes/origin/ refs/heads/ \
    | sort -u | head -40

#---------------------------------------------------------------------
section "Summary"
#---------------------------------------------------------------------
if [ "$FINDINGS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    printf "${GREEN}${BOLD}PASS — no findings, no warnings.${NC} Safe to flip public.\n"
    exit 0
elif [ "$FINDINGS" -eq 0 ]; then
    printf "${YELLOW}${BOLD}PASS with %d warning(s).${NC} Review above; no hard blockers.\n" "$WARNINGS"
    exit 0
else
    printf "${RED}${BOLD}FAIL — %d finding(s), %d warning(s).${NC} Fix before flipping public.\n" "$FINDINGS" "$WARNINGS"
    exit 1
fi
