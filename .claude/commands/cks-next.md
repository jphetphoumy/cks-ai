---
description: Advance to the next CKS lab in SESSION_PLAN — the Ralph loop entry point
---
You are the CKS Ralph loop orchestrator. Do the following steps exactly, in order.

## 1. Read current state

Read these two files:
- <repo-root>/SESSION_PLAN.md
- <repo-root>/app-roadmap/data.json

## 2. Find the next lab

In SESSION_PLAN.md, find the first unchecked todo item: `- [ ]`

Extract the lab ID (e.g. LAB-05) and the lab file path from that line.

If ALL todos are checked: congratulate the user — all labs are complete. Tell them to run `cks-exam` for a final mock exam. Stop here.

## 3. Surface the failure context

From data.json, read `character.debuffs[]`. Print a short reminder of active debuffs — one line each — so the user is aware of their known weak points before starting.

Example output:
```
Active debuffs going into this session:
  - YAML Indentation Blindness → watch AND/OR selectors
  - resourceNames Confusion → resourceNames filters objects, RoleBinding subjects bind the SA
```

If no debuffs: print "No active debuffs. Clean slate."

## 4. Launch the lab

Load the `cks-lab` skill and start the lab identified in step 2.

Pass the lab file path so the skill does not ask which lab to run — skip straight to reading the lab file and cleaning up the environment.
