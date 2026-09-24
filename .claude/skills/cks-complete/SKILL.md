---
name: cks-complete
description: Mark a CKS lab as done — update ROADMAP.md, data.json, and SESSION_PLAN.md based on lab performance.
disable-model-invocation: false
allowed-tools: Read, Write, Edit
---

# Goal

Update all progress tracking files after a CKS lab is completed. Takes lab ID, score, performance level, notes, and debuffs as input. Keeps ROADMAP.md, data.json, and SESSION_PLAN.md in sync so the webapp and the next agent session reflect the current state.

# Workflow

## 1. Gather completion context

The caller (agent or user) must provide:
- **Lab ID** — e.g. `LAB-03`
- **Score** — e.g. `4/4` or `3/4`
- **Performance** — one of: `clean` (no hints), `hints` (used hints), `struggled` (needed solution shown)
- **Notes** — one sentence summarizing what happened (mistakes, strong points)
- **New debuffs** — list of new weak points observed (can be empty)
- **Cured debuffs** — list of debuff names to remove (can be empty)

XP to award based on performance:
- `clean` → +50 XP
- `hints` → +40 XP
- `struggled` → +25 XP

Skill level increase based on performance:
- `clean` → +3 levels
- `hints` → +2 levels
- `struggled` → +1 level

## 2. Read current state

Read both files before making any changes:

```
<repo-root>/ROADMAP.md
<repo-root>/app-roadmap/data.json
<repo-root>/SESSION_PLAN.md
```

## 3. Update ROADMAP.md

- Find the lab row in the progress table and mark it `✅ Done — scored X/Y`
- Mark the next lab in sequence as `🔄 In Progress` if the user is moving on
- In the Character Sheet skill tree, increase the skill level for the completed lab
- Update `totalXP` and recalculate the XP bar percentage (`totalXP / 1600 * 100`)
- Add any new debuffs to the Debuffs section
- Remove any cured debuffs from the Debuffs section
- Update `last updated` date at the top to today's date

## 4. Update data.json

Mirror all ROADMAP.md changes into `data.json`:

- `meta.lastUpdated` → today's date (YYYY-MM-DD)
- `character.totalXP` → updated total
- `character.level` → recalculate: level = floor(totalXP / 100) capped at 16
- In `skills[]` — find the matching skill by name, set `status` to `"unlocked"`, update `level` and `notes`
- In `character.debuffs[]` — append new debuffs, remove cured ones by name
- In `labs[].items[]` — find the matching lab by id, set:
  - `status` → `"done"`
  - `score` → provided score
  - `notes` → provided notes

The webapp polls `data.json` every 3 seconds — no restart needed.

## 5. Update SESSION_PLAN.md

Find the todo item for the completed lab in `SESSION_PLAN.md` and mark it as checked:

Change:
```
- [ ] **LAB-XX** — ...
```
To:
```
- [x] **LAB-XX** — ...
```

## 6. Show a diff summary

Print a brief summary of every change made across all three files:

```
ROADMAP.md    LAB-03 → ✅ Done 4/4 | ServiceAccounts +2 levels | XP 160 → 200
data.json     lab status done | skill level 0→3 | totalXP 200 | debuff added
SESSION_PLAN  [x] LAB-03 checked off
```
