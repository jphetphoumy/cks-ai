---
name: cks-exam
description: CKS exam simulator — draws tasks from completed labs, runs a timed 30-minute session, validates results on the cluster, scores and debriefs without showing solutions.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Goal

Simulate a real CKS exam session. Draw tasks exclusively from labs the user has already completed (status: "done" in data.json), run a timed 30-minute session with no hints, validate all tasks against the live cluster at the end, and produce a scored debrief. Update data.json with the attempt record. If the user types `ABORT` at any point, end immediately with partial results and skip the data.json update.

---

# Workflow

## 1. Read data.json and identify completed labs

Read `<repo-root>/app-roadmap/data.json`.

Collect every lab item where `status == "done"` across all days. Build a list of eligible lab IDs (e.g. `["LAB-01", "LAB-02", "LAB-03"]`).

If fewer than 2 completed labs exist, tell the user there is not enough completed material to run a meaningful exam session and stop.

## 2. Read all completed lab files

For each eligible lab ID, map it to its file path using this naming convention:

```
LAB-01  →  labs/LAB_01_network_policies.md
LAB-02  →  labs/LAB_02_rbac.md
LAB-03  →  labs/LAB_03_service_accounts.md
LAB-04  →  labs/LAB_04_pod_security_standards.md
LAB-05  →  labs/LAB_05_secrets_etcd_encryption.md
LAB-06  →  labs/LAB_06_apparmor.md
LAB-07  →  labs/LAB_07_seccomp.md
LAB-08  →  labs/LAB_08_audit_logging.md
LAB-09  →  labs/LAB_09_falco.md
LAB-10  →  labs/LAB_10_trivy_image_scanning.md
LAB-11  →  labs/LAB_11_cis_benchmark.md
LAB-12  →  labs/LAB_12_ingress_tls.md
LAB-13  →  labs/LAB_13_image_signing_cosign.md
LAB-14  →  labs/LAB_14_static_analysis.md
LAB-15  →  labs/LAB_15_immutable_containers.md
LAB-16  →  labs/LAB_16_api_server_hardening.md
```

Read each lab file. Parse all Parts that are **not Part A** (Part A is setup scaffolding — not a task to test). Extract for each task Part:
- The **Part label** (e.g. `Part B`, `Part C`)
- The **task description** — WHAT must be achieved (resource names, namespaces, requirements), stripped of commands and YAML
- The **validation checks** — the commands from the `## Validation` section that correspond to this lab

## 3. Build the task set

From all eligible task Parts (across all completed labs), randomly select **5 to 6 tasks**. Aim for variety: prefer drawing from different labs rather than multiple parts of the same lab if possible.

Internally note for each selected task:
- Task number (1–N)
- Lab ID (e.g. `LAB-02`)
- Part label (e.g. `Part C`)
- Task description (what to do — no commands, no YAML, no hints)
- Lab file path (for later validation)

## 4. Clean up the cluster before starting

Before beginning the exam, run cleanup to ensure a neutral cluster state. For each selected lab, run its lab's namespace and resource cleanup:

```bash
ssh $SSH_USER@$MASTER_IP 'sudo bash -s' <<'EOF'
# Clean namespaces from completed labs to ensure a fresh state
for ns in shop rbac-test sa-test pod-security secret-test apparmor-test seccomp-test audit-test falco-test trivy-test ingress-test cosign-test static-test immutable-test; do
  kubectl delete namespace $ns --ignore-not-found --wait=false 2>/dev/null || true
done
kubectl delete pod attacker --ignore-not-found 2>/dev/null || true
echo "Cleanup complete"
EOF
```

Tell the user the cluster has been reset to a clean state for the exam.

## 5. Present the exam brief

Show:

```
╔══════════════════════════════════════════════════════╗
║             CKS EXAM SIMULATOR                       ║
╠══════════════════════════════════════════════════════╣
║  Tasks      : <N>                                    ║
║  Time limit : 30 minutes                             ║
║  Pass grade : 66% or more tasks passing              ║
╠══════════════════════════════════════════════════════╣
║  RULES                                               ║
║  • No hints will be given during the exam            ║
║  • No solutions will be shown                        ║
║  • Validation runs only at the end                   ║
║  • Type  next  to move to the next task              ║
║  • Type  done  when you have finished all tasks      ║
║  • Type  ABORT to end the exam immediately           ║
╚══════════════════════════════════════════════════════╝
```

Use AskUserQuestion: "Type `start` when you are ready to begin, or `ABORT` to cancel."

If the user types `ABORT`: stop here. Show "Exam aborted. No results recorded." and exit.

Note the start timestamp internally (record as a string like "HH:MM:SS" using the current time context, or note "Timer started" — the exact elapsed time will be estimated from the conversation turns if precise timing is unavailable).

## 6. Present tasks one by one

Print the start marker:

```
=== EXAM STARTED ===
```

For each task in order (1 to N), present:

```
────────────────────────────────────────
Task <N> of <TOTAL>   [<LAB-ID> — <Part label>]
────────────────────────────────────────
<Task description — WHAT to achieve, resource names, namespaces, exact names the validation will check>
────────────────────────────────────────
```

**Critical rules for task presentation:**
- Show WHAT needs to be done (the goal, resource names, namespaces, constraints)
- NEVER show HOW (no kubectl commands, no YAML snippets, no hints, no references to the lab)
- Always include exact names, namespaces, and identifiers the user must use (because validation will check these exact values)
- Do not say which lab this came from

After presenting the task, wait for the user to respond. Accept:
- Any response that isn't `next`, `done`, or `ABORT` → assume they are still working; acknowledge briefly ("Working on it — type `next` when done with this task.")
- `next` → move to the next task
- `done` → skip remaining tasks and proceed to validation
- `ABORT` → end immediately (see step 8 — ABORT path)

Check for `ABORT` after every user input throughout the session.

Repeat for all tasks or until the user types `done`.

When all tasks are presented (or user typed `done`): print "=== ALL TASKS SUBMITTED ===" and proceed to validation.

## 7. Validate all tasks on the cluster

For each lab represented in the selected tasks, generate a combined validation script. Follow the same pattern as the `cks-validate` skill:

1. Read the `## Validation` section of each relevant lab file
2. Generate a single combined bash script `/tmp/cks-exam-validate.sh` locally using this template:

```bash
#!/usr/bin/env bash
# CKS Exam Simulator — Validation Run
# Auto-generated

set -uo pipefail

PASS=0
FAIL=0
declare -A TASK_RESULTS

check() {
  local task_id="$1"
  local desc="$2"
  local cmd="$3"
  local expect="${4:-}"

  if output=$(eval "$cmd" 2>&1); then
    if [[ -z "$expect" ]] || echo "$output" | grep -q "$expect"; then
      echo "  PASS  [$task_id] $desc"
      TASK_RESULTS[$task_id]="${TASK_RESULTS[$task_id]:-PASS}"
      ((PASS++))
    else
      echo "  FAIL  [$task_id] $desc"
      echo "        expected: $expect"
      echo "        got:      $output"
      TASK_RESULTS[$task_id]="FAIL"
      ((FAIL++))
    fi
  else
    echo "  FAIL  [$task_id] $desc"
    echo "        error: $output"
    TASK_RESULTS[$task_id]="FAIL"
    ((FAIL++))
  fi
}

echo ""
echo "=== CKS EXAM VALIDATION ==="
echo ""

# --- checks per task ---
<GENERATED_CHECKS_PER_TASK>

echo ""
echo "Results: $PASS passed, $FAIL failed"
```

Substitute `<GENERATED_CHECKS_PER_TASK>` with the relevant `check` calls for each task's lab validation section, prefixed with `# Task <N> — <LAB-ID> Part <X>`.

3. Copy and run on master:

```bash
scp /tmp/cks-exam-validate.sh $SSH_USER@$MASTER_IP:/tmp/
ssh $SSH_USER@$MASTER_IP 'sudo bash /tmp/cks-exam-validate.sh'
```

4. Clean up scripts:

```bash
rm /tmp/cks-exam-validate.sh
ssh $SSH_USER@$MASTER_IP 'rm -f /tmp/cks-exam-validate.sh'
```

## 8. Present final results

Based on validation output, determine per-task pass/fail. A task **passes** if ALL its validation checks pass.

Estimate elapsed time from context (note approximate minutes elapsed since "=== EXAM STARTED ===").

Print the score table:

```
╔══════════════════════════════════════════════════════════════════════╗
║  CKS EXAM RESULTS                                                    ║
╠═══╦══════════════════════════════════════════════════╦══════════╣
║ # ║ Task                                             ║ Result   ║
╠═══╬══════════════════════════════════════════════════╬══════════╣
║ 1 ║ <short task description>                         ║  PASS ✓  ║
║ 2 ║ <short task description>                         ║  FAIL ✗  ║
...
╠═══╩══════════════════════════════════════════════════╩══════════╣
║  Score : <X>/<N> tasks passed                                        ║
║  Grade : PASS  ✓  (≥66%)   OR   FAIL  ✗  (<66%)                     ║
║  Time  : ~<M> minutes                                                ║
╚══════════════════════════════════════════════════════════════════════╝
```

Grade threshold: PASS if (tasks_passed / total_tasks) >= 0.66.

## 9. Debrief failed tasks

For each **failed** task, show:

```
── Task <N> FAILED — <LAB-ID> Part <X> ──
What was checked: <list the validation check descriptions that failed>
What was missing: <describe the gap — e.g. "The NetworkPolicy was missing the policyTypes field" — based on the check output. Do NOT show the correct YAML or command.>
```

Show gaps only — never show the solution, correct YAML, or exact commands. The user should return to the lab for that.

## 10. ABORT path

If the user types `ABORT` at any point during steps 5–7:

1. Stop immediately
2. Show: "=== EXAM ABORTED ==="
3. Display partial results for any tasks that were already validated (if validation had started), or just "No tasks validated."
4. Do NOT update data.json
5. Exit the skill

## 11. Update data.json with the exam attempt

Read `<repo-root>/app-roadmap/data.json`.

Add an `examAttempts` array to `character` if it doesn't exist. Append a new entry:

```json
{
  "date": "<YYYY-MM-DD>",
  "tasksTotal": <N>,
  "tasksPassed": <X>,
  "score": "<X>/<N>",
  "grade": "PASS" or "FAIL",
  "failedTaskIds": ["LAB-01-PartB", "LAB-02-PartC"],
  "durationMinutes": <estimated_minutes>
}
```

Write the updated data.json back.

Confirm to the user: "Exam attempt recorded in data.json."

## 12. Closing message

Print:

```
=== EXAM SESSION COMPLETE ===
```

If PASS: "Well done — you cleared the simulation. Keep drilling the failed tasks before the real exam."
If FAIL: "Not there yet — focus on the failed tasks. Run the relevant labs again before re-attempting."

Suggest the next action based on results:
- If any tasks failed: name the specific lab(s) to revisit (e.g. "Revisit LAB-01 to reinforce NetworkPolicy syntax.")
- If all passed: suggest running the exam simulator again after completing more labs, or move to the next pending lab.
