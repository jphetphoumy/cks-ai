# How to Replicate This Learning System for Any Stack

This document explains how the CKS learning system works and how to rebuild it from scratch for any topic, certification, or skill.

---

## How This System Works

### The Core Architecture

This is a skill-orchestrated learning OS built on top of Claude Code. It has three layers:

```
┌────────────────────────────────────────────────┐
│  ORCHESTRATION LAYER                           │
│  /cks-next command → entry point               │
│  Reads state → selects next lab → delegates    │
└────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────┐
│  SKILL LAYER (7 Claude Code skills)            │
│  cks-lab → cks-validate → cks-complete         │
│  cks-exam (timed, no hints)                    │
│  cks-setup (idempotent env check)              │
│  create-skill (meta: builds more skills)       │
└────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────┐
│  STATE LAYER (3 synchronized files)            │
│  ROADMAP.md (human dashboard)                  │
│  data.json (machine API)                       │
│  SESSION_PLAN.md (schedule + agent context)    │
└────────────────────────────────────────────────┘
```

### What Makes It Effective

**1. Skills as composable agents**
Each skill is a single-responsibility agent with a clear input/output contract. `cks-lab` calls `cks-validate` calls `cks-complete`. This is agent chaining — each skill does one thing and passes state forward.

**2. The validation-as-code pattern**
`cks-validate` extracts the `## Validation` section from any lab file, generates a self-contained bash script, and runs it in a single SSH round-trip. The lab file IS the test spec — documentation and validation are the same artifact.

**3. Socratic method enforced structurally**
The `cks-lab` skill has a rule: present WHAT, not HOW. Hints are questions. Solutions require explicit student request after 2+ failures. Passive reading doesn't build muscle memory — struggling does.

**4. The 3-file state machine**
- `ROADMAP.md` — for humans reading the session
- `data.json` — for a webapp polling at 3s intervals
- `SESSION_PLAN.md` — for the *next agent* to pick up context without re-reading the whole conversation

`SESSION_PLAN.md` is the killer feature: every agent instance starts cold, but `SESSION_PLAN.md` gives it the student's current state, what's pending, and what problems occurred. This is **persistent agent context across sessions**.

**5. Debuff system as diagnostic feedback loop**
When a mistake pattern is observed (e.g., AND/OR YAML trap), a "debuff" is added to `ROADMAP.md` and `data.json`. Every future lab loads this debuff as a pre-warning. When the student demonstrates mastery, the debuff is removed. This is adaptive learning encoded into state.

**6. Exam fidelity through role isolation**
`cks-exam` strictly enforces exam conditions (no hints, timed, ABORT protection). It draws from `status: "done"` labs only. The separation between "learning mode" (`cks-lab`) and "test mode" (`cks-exam`) is hard-coded into skill behavior.

---

## The Bootstrap Seed: AGENTS.md

The entire system starts from a single file. A well-structured `AGENTS.md` causes an agent to self-bootstrap an entire learning system.

### Universal AGENTS.md Template

```markdown
# Learning Repository

## What to learn
Topic: [TOPIC]
Goal: [CERTIFICATION or SKILL LEVEL]
Deadline: [DATE or N days]

## Student context
Background: [what they already know]
Learning style: [hands-on / theory / mixed]
Environment: [local machine / VMs / cloud / browser / none]

## Bootstrap instructions (read this on first session)
If no labs/, ROADMAP.md, SESSION_PLAN.md, or .claude/skills/ exist:
1. Research the official curriculum for [TOPIC] from authoritative sources
2. Create PLAN.md with domain breakdown and weights
3. Generate labs/ with N lab files (see lab format below)
4. Create ROADMAP.md, data.json, SESSION_PLAN.md
5. Scaffold .claude/skills/ for this stack
6. Come back and report what was created

## Lab format
Every lab MUST have: Objective, Background, Tasks (Parts A–E),
## Validation (runnable commands), Exam Tips
```

That's the entire seed. Everything else grows from it.

---

## The Three-Phase Bootstrap Flow (First Session)

When an agent opens a fresh folder with only `AGENTS.md`:

```
Phase 1 — Research (WebSearch + WebFetch)
  Search: "[topic] official curriculum"
  Search: "[topic] certification exam domains weights"
  Search: "[topic] hands-on labs guide"
  → Extract domain names + percentage weights
  → Extract key tools, commands, concepts per domain
  → Build PLAN.md

Phase 2 — Lab generation (Write)
  For each domain topic:
    Create labs/LAB_NN_topic.md
    Structure: Objective → Background → Tasks → Validation → Tips
    Validation section = runnable commands that pass/fail

Phase 3 — Scaffold (Write + Edit)
  Create ROADMAP.md (pending status, XP=0)
  Create SESSION_PLAN.md (all labs unchecked, student context)
  Create data.json (empty character sheet)
  Create .claude/skills/ from templates
```

The agent does this autonomously in one session. You return to a complete system.

---

## The Ralph Wiggum Loop Applied to Learning

In agentic coding the Ralph loop is:

```
Agent plans → Agent executes → Observe output → Correct → Repeat
```

The student is passive. The AI does the work.

For **learning**, you invert the roles:

```
AI presents task (WHAT, not HOW)
  → Student attempts on real environment
  → AI validates (checks reality, not student's stated answer)
  → FAIL: AI gives Socratic hint (a question, not the answer)
    → Student attempts again
    → FAIL again: AI gives targeted hint #2
      → After 3 failures: AI asks "want to see solution?"
  → PASS: AI explains WHY it works (debrief)
  → Next task
```

The critical rule: **the AI never executes for the student**. The confusion phase (the "Wiggum" state) is where learning actually happens. If the student never fails, they never build the pattern recognition needed under pressure.

This maps directly to the `cks-lab` skill:

```
Step 4: Present task → WHAT to achieve, resource names, namespace
Step 5: User attempts → (AI waits)
Step 6: Validate against cluster
Step 7: If wrong → targeted hint (question form)
Step 8: After max 2–3 attempts → offer solution
Step 9: If right → explain why, debrief
Step 10: Next part
```

### Validation by Stack

The validation method changes by environment — the loop itself does not:

| Stack | Environment | Validation method |
|-------|-------------|-------------------|
| Kubernetes | Live cluster | `kubectl get` / SSH checks |
| AWS | Localstack or real account | AWS CLI / boto3 |
| Terraform | Local state | `terraform plan` output |
| SQL | Postgres container | query results |
| Music theory | None needed | AI evaluates answer |
| Language learning | None needed | AI evaluates translation + grammar |
| Medicine / USMLE | None needed | AI evaluates clinical reasoning |

For non-verifiable skills the AI acts as the validator itself, but still delays the answer: ask first, check student attempt, then confirm or correct.

---

## The Universal Lab Format

Every lab file must follow this structure exactly. The `## Validation` section is what the validate skill runs automatically.

```markdown
# LAB-NN — Topic Name

**Domain:** Category (weight%)

## Objective
One sentence.

## Background
Concept explanation (2-3 paragraphs).

## Tasks

### Part A — Environment setup (scaffolding only)
Steps to create the test environment.

### Part B — Core concept
Numbered steps. State WHAT to do, include commands.

### Part C — Edge case or attack scenario
...

### Part D — Fix / harden
...

### Part E — Exam scenario (from memory)
...

## Validation
```bash
# Self-contained commands. Each line = one check.
# Expected output is implicit (non-zero exit = fail)
command_that_should_succeed
command | grep expected_output
ssh remote "command" | grep expected
```

## Exam Tips
- Bullet points: things to memorize
- Key file paths
- Common mistakes
- Command syntax to know by heart
```

The `## Validation` section is the contract. It must be runnable bash that exits non-zero on failure. This is simultaneously documentation, test suite, and validation script.

---

## The 5 Core Skills (+ 2 Optional)

For any stack, you need exactly these 5 core skills:

| Skill | Purpose |
|-------|---------|
| `<stack>-bootstrap` | First-session scaffolding: research → labs → skills |
| `<stack>-lab` | Socratic tutor (Ralph Wiggum loop enforcer) |
| `<stack>-validate` | Reality checker: runs Validation section against environment |
| `<stack>-complete` | State writer: updates ROADMAP.md + data.json + SESSION_PLAN.md |
| `<stack>-next` | Orchestrator entry point: reads state → selects → delegates |

Plus 2 optional high-value skills:

| Skill | Purpose |
|-------|---------|
| `<stack>-exam` | Timed no-hint exam simulator |
| `<stack>-analyze` | Debuff detector: reviews session, proposes new debuffs automatically |

The `<stack>-analyze` skill closes the adaptive loop fully. It reviews the last lab session, identifies error patterns (typos, wrong flags, conceptual gaps), and proposes debuffs to `cks-complete` without manual annotation.

---

## The 3-File State Machine

These three files must stay synchronized. `cks-complete` updates all three atomically after every lab.

### ROADMAP.md (Human dashboard)

```markdown
# Learning Roadmap

## Labs
| # | Lab | Domain | Weight | Status |
| 1 | Topic A | Category | 15% | ⬜ Pending |

## Character Sheet
Total XP: 0 / 1600 | Level: 1
[░░░░░░░░░░░░░░░░░░░░] 0%

### Skill Tree
| Skill | Level | Notes |
| Topic A | 0/10 | Locked |

### Known Weaknesses (Debuffs)
(None)
```

### data.json (Machine API, polled by webapp)

```json
{
  "character": {
    "totalXP": 0,
    "maxXP": 1600,
    "level": 1,
    "debuffs": [],
    "examAttempts": []
  },
  "skills": [
    { "name": "Topic A", "level": 0, "maxLevel": 10, "status": "locked" }
  ],
  "labs": [
    {
      "day": 1,
      "items": [
        { "id": "LAB-01", "name": "Topic A", "status": "pending" }
      ]
    }
  ]
}
```

### SESSION_PLAN.md (Agent working memory)

This is the most important file for multi-session workflows. Every new agent instance reads this first to reconstruct context without re-reading the whole conversation history.

```markdown
# Session Plan

## Context for the next agent
- Student background: [summary]
- Current goal: [certification, deadline]
- Known weaknesses: [list]
- Cluster/environment state: [tools installed, versions]

## Current progress
- LAB-01 through LAB-03 complete
- LAB-04 in progress

## Todo
### Session 1
- [x] LAB-01 (done, 3/4, missed AND/OR trap)
- [ ] LAB-04
- [ ] LAB-05

## Instructions for running sessions
1. Load skill at start of each lab
2. Verify environment health
3. Surface active debuffs before each lab
4. Time-box ruthlessly
5. After each lab: update SESSION_PLAN + data.json
```

---

## Obsidian/Logseq as Agent Memory Layer

The flat `SESSION_PLAN.md` works but has limits: it grows linearly and is hard to query. Obsidian or Logseq can replace and extend it.

### Vault Structure

```
vault/
  _sessions/
    2026-02-26.md    ← daily note (structured frontmatter)
    2026-02-27.md
  _labs/
    LAB-01.md        ← linked note per lab (properties + notes)
    LAB-02.md
  _concepts/
    NetworkPolicy.md ← concept notes with backlinks to labs
    RBAC.md
  _debuffs/
    AND-OR-trap.md   ← each debuff is a note with context
  SESSION_PLAN.md    ← current state (still flat for AI reads)
  data.json          ← still the machine API
```

### Daily Note Format (Obsidian frontmatter)

```markdown
---
date: 2026-02-27
topic: CKS
labs_completed: [LAB-01, LAB-02, LAB-16]
labs_pending: [LAB-15, LAB-11, LAB-12]
active_debuffs: []
exam_date: 2026-02-28
xp: 470
level: 4
---

## Session
- Completed LAB-08 Audit Logging (6/6 clean)
- Struggled with volume mount order in kube-apiserver manifest

## Weak points identified
- [[AND-OR-trap]] manifested in LAB-01 again
```

### What the AI can do with this structure

```
Read _sessions/today.md
→ Get frontmatter: labs_completed, active_debuffs, exam_date
→ Follow [[AND-OR-trap]] link → read debuff context
→ Surface debuffs before next lab
→ Write to today's note after lab completion
→ Query backlinks: "what labs covered NetworkPolicy?"
```

### Spaced Repetition Integration

After each lab, the `<stack>-complete` skill can write flashcards to a review file:

```markdown
<!-- AUTO-GENERATED after LAB-01 -->
#flashcard
What policyTypes controls traffic INTO a pod?
?
Ingress
```

The Obsidian SR plugin schedules these for review. At session start, the agent reads the due list and runs a 5-minute review before the lab. This compounds retention across days.

---

## The Complete Bootstrap Sequence (Operational Steps)

```
1. mkdir my-learning-repo && cd my-learning-repo

2. Write AGENTS.md (the seed — 20 lines, see template above)

3. Open Claude Code in this folder
   → Agent reads AGENTS.md
   → Agent runs bootstrap:
     - WebSearch: curriculum research
     - Write: PLAN.md
     - Write: labs/LAB_01 through LAB_N
     - Write: ROADMAP.md, SESSION_PLAN.md, data.json
     - Write: .claude/skills/<stack>-lab/SKILL.md
     - Write: .claude/skills/<stack>-validate/SKILL.md
     - Write: .claude/skills/<stack>-complete/SKILL.md
     - Write: .claude/skills/<stack>-next/SKILL.md
     - Write: .claude/settings.local.json (permissions)
   → Session ends: "System bootstrapped. Type /next to begin."

4. Next session: /<stack>-next
   → Reads SESSION_PLAN.md
   → Finds first unchecked lab
   → Loads <stack>-lab
   → Ralph Wiggum loop begins

5. After each lab:
   → <stack>-validate (reality check)
   → <stack>-complete (state update)
   → SESSION_PLAN.md updated (agent memory for next session)
   → Obsidian daily note written (optional but powerful)

6. After N labs: /<stack>-exam
   → Timed session
   → Score → pass/fail
   → Weak areas fed back to SESSION_PLAN

7. Repeat until ready
```

---

## What Makes This Faster Than Traditional Learning

| Traditional | This system |
|-------------|-------------|
| Read docs passively | Attempt on real environment |
| Forget between sessions | SESSION_PLAN.md = perfect recall |
| No feedback loop | Ralph loop: attempt → fail → hint → pass |
| Practice when you feel like it | SESSION_PLAN enforces schedule |
| Don't know what you don't know | Debuff system tracks blind spots |
| Test at the end | Exam simulator throughout |
| One-way (teacher → student) | Bidirectional: AI guides, student executes |

The core mechanism: **the AI cannot learn for you, but it can build a system that forces you to learn efficiently**. The skills are not AI doing the work — they are AI orchestrating the conditions under which you do the work, with immediate feedback and no escape from the hard parts.

---

## Minimum Viable Version

If you want to start small, you need exactly:

```
.claude/
  skills/
    <stack>-lab/SKILL.md       ← Socratic tutor (most critical)
    <stack>-validate/SKILL.md  ← Validation runner
    <stack>-complete/SKILL.md  ← State writer
    <stack>-next/SKILL.md      ← Entry point
  settings.local.json
ROADMAP.md                     ← Human progress dashboard
SESSION_PLAN.md                ← Agent context / working memory
labs/
  LAB_01_topic.md              ← Labs with ## Validation sections
  LAB_02_topic.md
PLAN.md                        ← Cheatsheet + command reference
```

`data.json` and the Obsidian vault are enhancements. The loop runs without them.

The absolute requirement: **every lab file must have a `## Validation` section with runnable commands**. That section is simultaneously documentation, test suite, and validation script. Without it, the validate skill has nothing to run and the feedback loop breaks.
