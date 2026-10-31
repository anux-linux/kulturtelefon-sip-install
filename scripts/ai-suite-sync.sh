#!/usr/bin/env bash
# Keep this repository's copy of the ai-suite harness identical to one ai-suite commit.
#
# Usage:
#   scripts/ai-suite-sync.sh --check                  verify the copy against .claude/ai-suite.lock
#   scripts/ai-suite-sync.sh --update <ai-suite dir>  copy the harness from a clean checkout of
#                                                     ai-suite and rewrite the lock
#   scripts/ai-suite-sync.sh --compare <repo dir>...  say whether the lock files of these
#                                                     repositories equal ours
#   scripts/ai-suite-sync.sh -h | --help              print this text
#
# Exit status: 0 success, 1 a difference was found, 2 a usage or environment error.
# Needs bash, git, coreutils and tar. No network. Identical in all four Kulturtelefon
# repositories and listed in the lock: change it in all four.
set -euo pipefail

# Copied from ai-suite. A directory belongs to ai-suite as a whole: never add a file to it here.
MANAGED=(.claude/agents .claude/commands .claude/hooks .claude/skills .claude/settings.json
         .github/workflows/claude-review.yml scripts/linear-git-status.sh scripts/risk-tier.sh
         scripts/setup-branch-protection.sh scripts/validate.sh templates/plan.md)
# Not from ai-suite, but the same in all four Kulturtelefon repositories.
OWN=(scripts/ai-suite-sync.sh .github/workflows/ai-suite.yml)
LOCK=.claude/ai-suite.lock

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
caller=$PWD

usage() {
  local line
  while IFS= read -r line; do
    case $line in
      '#!'*) ;;
      '#'*) line=${line#\#}; printf '%s\n' "${line# }" ;;
      *) break ;;
    esac
  done <"$self"
}

die() { echo "ai-suite-sync: $*" >&2; exit 2; }

command -v git >/dev/null || die "git not found"
command -v sha256sum >/dev/null || die "sha256sum not found"
command -v tar >/dev/null || die "tar not found"
root=$(git -C "$(dirname "$self")" rev-parse --show-toplevel 2>/dev/null) || die "$self is not inside a git work tree"

# A directory argument is relative to where the script was called from.
abs() { (cd "$caller" && cd -- "$1" 2>/dev/null && pwd) || die "no such directory: $1"; }

cd "$root"

# Every path the lock must list, sorted bytewise: the files under MANAGED that git tracks or
# would show as untracked, plus OWN. An index entry whose file is gone from the work tree is not
# a file here (right after --update, before the deletions are staged).
expected_files() {
  local f
  {
    git ls-files --cached --others --exclude-standard -- "${MANAGED[@]}" | while IFS= read -r f; do
      if [ -e "$f" ]; then printf '%s\n' "$f"; fi
    done
    printf '%s\n' "${OWN[@]}"
  } | LC_ALL=C sort -u
}

check() {
  local problems=0 line1 line mode sha path have
  local re='^(100644|100755) ([0-9a-f]{64})  (.+)$'
  local -a listed=()

  if [ ! -f "$LOCK" ]; then
    echo "missing: $LOCK" >&2
    return 1
  fi
  line1=$(head -n 1 "$LOCK")
  if [[ ! $line1 =~ ^ai-suite\ [0-9a-f]{40}$ ]]; then
    echo "lock: line 1 of $LOCK is not 'ai-suite <40 hex digits>'" >&2
    problems=$((problems + 1))
  fi

  while IFS= read -r line; do
    if [[ ! $line =~ $re ]]; then
      echo "lock: malformed line in $LOCK: $line" >&2
      problems=$((problems + 1))
      continue
    fi
    mode=${BASH_REMATCH[1]}
    sha=${BASH_REMATCH[2]}
    path=${BASH_REMATCH[3]}
    listed+=("$path")
    if [ ! -f "$path" ]; then
      echo "missing: $path" >&2
      problems=$((problems + 1))
      continue
    fi
    have=$(sha256sum -- "$path")
    if [ "${have%% *}" != "$sha" ]; then
      echo "edited: $path" >&2
      problems=$((problems + 1))
    fi
    if [ -x "$path" ]; then
      if [ "$mode" != 100755 ]; then
        echo "mode: $path is executable, the lock says $mode" >&2
        problems=$((problems + 1))
      fi
    elif [ "$mode" != 100644 ]; then
      echo "mode: $path is not executable, the lock says $mode" >&2
      problems=$((problems + 1))
    fi
  done < <(tail -n +2 "$LOCK")

  local listed_sorted actual
  listed_sorted=$(if [ "${#listed[@]}" -gt 0 ]; then printf '%s\n' "${listed[@]}" | LC_ALL=C sort; fi)
  actual=$(expected_files)
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    echo "extra: $path" >&2
    problems=$((problems + 1))
  done < <(LC_ALL=C comm -13 <(printf '%s\n' "$listed_sorted") <(printf '%s\n' "$actual"))
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    # A file that is not on disk was reported above.
    if [ -e "$path" ]; then
      echo "missing: $path (listed in the lock, but git does not track it)" >&2
      problems=$((problems + 1))
    fi
  done < <(LC_ALL=C comm -23 <(printf '%s\n' "$listed_sorted") <(printf '%s\n' "$actual"))

  if [ "$problems" -ne 0 ]; then
    echo "FAIL: $problems problem(s) against $LOCK" >&2
    return 1
  fi
  echo "OK: ai-suite ${line1#ai-suite } copy matches $LOCK"
}

update() {
  local src ref p meta path mode tmp
  local -a paths=()
  src=$(abs "$1")
  ref=$(git -C "$src" rev-parse --verify HEAD 2>/dev/null) || die "$src is not a git work tree"
  git -C "$src" cat-file -e HEAD:.claude/agents/planner.md 2>/dev/null \
    || die "$src is not an ai-suite checkout (no .claude/agents/planner.md at HEAD)"
  [ -z "$(git -C "$src" status --porcelain)" ] \
    || die "$src has uncommitted changes; check out a clean commit"
  for p in "${OWN[@]}"; do
    [ -f "$p" ] || die "missing $p; copy it from another Kulturtelefon repository first"
  done
  for p in "${MANAGED[@]}"; do
    [ -n "$(git -C "$src" ls-tree --name-only HEAD -- "$p")" ] \
      || die "ai-suite ${ref} has no $p; this script's MANAGED list needs a change in all four repositories"
  done
  while IFS=$'\t' read -r meta path; do
    mode=${meta%% *}
    case $mode in
      100644 | 100755) paths+=("$path") ;;
      *) die "ai-suite ${ref} has $path with mode $mode; only 100644 and 100755 are supported" ;;
    esac
  done < <(git -C "$src" ls-tree -r HEAD -- "${MANAGED[@]}")

  # Replace, not merge: a file that ai-suite deleted must disappear here too.
  for p in "${MANAGED[@]}"; do rm -rf -- "$p"; done
  git -C "$src" archive --format=tar HEAD -- "${MANAGED[@]}" | tar -xf - -C "$root"

  tmp="$LOCK.tmp"
  {
    echo "ai-suite $ref"
    while IFS= read -r path; do
      if [ -x "$path" ]; then mode=100755; else mode=100644; fi
      # The mode of a copied file is the one ai-suite has; tar kept it.
      sha=$(sha256sum -- "$path")
      printf '%s %s  %s\n' "$mode" "${sha%% *}" "$path"
    done < <({ printf '%s\n' "${paths[@]}"; printf '%s\n' "${OWN[@]}"; } | LC_ALL=C sort -u)
  } >"$tmp"
  mv -- "$tmp" "$LOCK"
  echo "Copied ai-suite $ref"
}

compare() {
  local fail=0 d dir ours theirs
  ours=$(sha256sum <"$LOCK")
  for d in "$@"; do
    dir=$(abs "$d")
    if [ ! -f "$dir/$LOCK" ]; then
      echo "$dir: no $LOCK"
      fail=1
      continue
    fi
    theirs=$(sha256sum <"$dir/$LOCK")
    if [ "$theirs" = "$ours" ]; then
      echo "same: $dir"
    else
      echo "DIFFERENT: $dir"
      fail=1
    fi
  done
  return "$fail"
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  --check) [ $# -eq 1 ] || { usage >&2; exit 2; }; check ;;
  --update) [ $# -eq 2 ] || { usage >&2; exit 2; }; update "$2" ;;
  --compare) [ $# -ge 2 ] || { usage >&2; exit 2; }; shift; compare "$@" ;;
  -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
