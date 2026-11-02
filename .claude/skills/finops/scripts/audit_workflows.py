#!/usr/bin/env python3
"""Static FinOps audit of GitHub Actions workflows. Advisory and read-only.

Usage: python3 -I audit_workflows.py .github/workflows/*.yml

It sees the YAML only: it cannot know which jobs are required checks or how often a
workflow really runs. Treat every line as a lead to check against run history.
"""
import re
import sys

import yaml

LLM_ACTIONS = ("claude-code-action", "claude-code-security-review")
CACHEABLE = ("actions/setup-node", "actions/setup-python", "actions/setup-java")


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def triggers(doc):
    on = doc.get("on", doc.get(True))  # PyYAML parses a bare `on` key as True
    if isinstance(on, str):
        return {on: None}
    if isinstance(on, list):
        return {k: None for k in on}
    return on or {}


def cron_more_than_daily(expr):
    parts = expr.split()
    if len(parts) != 5:
        return False
    minute, hour = parts[0], parts[1]
    return bool(re.search(r"[*,/]", hour)) or "," in minute and hour == "*"


def audit(path):
    findings = []

    def add(sev, job, msg, fix):
        findings.append((sev, path, job or "-", msg, fix))

    with open(path, encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    trig = triggers(doc)
    jobs = doc.get("jobs") or {}
    on_pr = "pull_request" in trig or "pull_request_target" in trig

    if "push" in trig and on_pr:
        push = trig.get("push") or {}
        if not push.get("branches"):
            add("HIGH", None, "runs on every push AND on pull_request, so each PR push runs twice",
                "limit `push` to `branches: [main]`")

    if on_pr and "concurrency" not in doc and not any("concurrency" in (j or {}) for j in jobs.values()):
        add("MED", None, "no `concurrency`: superseded PR runs keep burning minutes",
            "add `concurrency` with `cancel-in-progress: true` (not for deploy jobs)")

    for cron in [c.get("cron", "") for c in as_list(trig.get("schedule"))]:
        if cron_more_than_daily(cron):
            add("MED", None, f"schedule '{cron}' runs more than once a day",
                "reduce the frequency unless the data really changes that fast")

    for name, job in jobs.items():
        job = job or {}
        if "timeout-minutes" not in job:
            add("HIGH", name, "no `timeout-minutes` (default 360): a hung job bills up to 6 hours",
                "set a realistic limit")
        runs_on = str(job.get("runs-on", ""))
        if re.search(r"macos|windows", runs_on, re.I):
            add("MED", name, f"runs on '{runs_on}', billed at a higher rate than Linux",
                "use ubuntu-latest unless the code needs that OS")
        if re.search(r"large|xlarge|\d+-core", runs_on, re.I):
            add("MED", name, f"larger runner '{runs_on}' costs more per minute",
                "check that the speed-up pays for it")
        for step in job.get("steps") or []:
            uses = str(step.get("uses", ""))
            with_ = step.get("with") or {}
            if uses.startswith("actions/checkout") and str(with_.get("fetch-depth")) == "0":
                add("LOW", name, "checkout with `fetch-depth: 0` (full history)",
                    "use the default depth unless the job needs history")
            if uses.startswith(CACHEABLE) and "cache" not in with_:
                add("MED", name, f"{uses.split('@')[0]} without `cache`: dependencies reinstalled every run",
                    "enable the built-in cache")
            if uses.startswith("actions/upload-artifact") and "retention-days" not in with_:
                add("LOW", name, "artifact kept for the default 90 days",
                    "set a short `retention-days`")
            if any(a in uses for a in LLM_ACTIONS) and on_pr:
                types = (trig.get("pull_request") or {}).get("types") or ["opened", "synchronize", "reopened"]
                if "synchronize" in types:
                    add("INFO", name, f"{uses.split('@')[0]} runs on every push to a PR and bills API usage each time",
                        "consider `ready_for_review`/label triggers; keep it if this check is required")
    return findings


def main(paths):
    if not paths:
        print(__doc__)
        return 2
    rows = []
    for p in paths:
        try:
            rows += audit(p)
        except (OSError, yaml.YAMLError) as exc:
            rows.append(("ERROR", p, "-", f"cannot read: {exc}", ""))
    order = {"HIGH": 0, "MED": 1, "LOW": 2, "INFO": 3, "ERROR": 4}
    rows.sort(key=lambda r: order[r[0]])
    if not rows:
        print("No static findings. Check run history for real frequency and duration.")
        return 0
    for sev, path, job, msg, fix in rows:
        print(f"[{sev}] {path} job={job}: {msg}" + (f"\n       fix: {fix}" if fix else ""))
    print(f"\n{len(rows)} lead(s). Static only: confirm with `gh run list` before claiming savings.")
    return 1 if any(r[0] == "ERROR" for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
