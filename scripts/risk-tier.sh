#!/usr/bin/env bash
# Compute the risk tier of a change from .github/risk-tiers.conf.
#
# Usage: risk-tier.sh [--map FILE] [--quiet] FILE...        tier of these paths
#        risk-tier.sh [--map FILE] [--quiet] --base REF     paths changed in REF...HEAD
#        git diff --name-only main | risk-tier.sh --stdin   paths from stdin
#
# Output: first line is the tier (low | medium | high); then the files that set it, one per
# line, indented. --quiet prints the tier only. An empty change is low.
set -euo pipefail

map=""; quiet=0; from_stdin=0; base=""; files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --map) map=$2; shift ;;
    --quiet) quiet=1 ;;
    --stdin) from_stdin=1 ;;
    --base) base=$2; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) files+=("$1") ;;
  esac
  shift
done

[ -n "$map" ] || map="$(git rev-parse --show-toplevel)/.github/risk-tiers.conf"
[ -f "$map" ] || { echo "risk map not found: $map" >&2; exit 1; }

[ -z "$base" ] || mapfile -t files < <(git diff --name-only "$base...HEAD")
[ "$from_stdin" -eq 0 ] || mapfile -t -O "${#files[@]}" files

rank() { case "$1" in low) echo 1 ;; medium) echo 2 ;; high) echo 3 ;; *) echo 0 ;; esac; }
names=("" low medium high)

tiers=(); pats=()
while read -r t p; do
  case "$t" in ''|'#'*) continue ;; esac
  [ "$(rank "$t")" -gt 0 ] || { echo "unknown tier '$t' in $map" >&2; exit 1; }
  [ -n "$p" ] || { echo "tier '$t' without a pattern in $map" >&2; exit 1; }
  tiers+=("$t"); pats+=("$p")
done <"$map"

top=1; ranks=()
for f in ${files[@]+"${files[@]}"}; do
  [ -n "$f" ] || continue
  r=0
  for i in "${!pats[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$f" == ${pats[$i]} ]]; then
      ri=$(rank "${tiers[$i]}"); [ "$ri" -le "$r" ] || r=$ri
    fi
  done
  [ "$r" -gt 0 ] || r=2            # unmatched paths count as medium
  ranks+=("$f"$'\t'"$r")
  [ "$r" -le "$top" ] || top=$r
done

echo "${names[$top]}"
[ "$quiet" -eq 1 ] && exit 0
for line in ${ranks[@]+"${ranks[@]}"}; do
  [ "${line##*$'\t'}" = "$top" ] && echo "  ${line%$'\t'*}"
done
exit 0
