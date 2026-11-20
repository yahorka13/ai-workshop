---
name: crm-backlog
description: File the CRM backlog, small CRM issues labelled crm with after dependencies, into this repository without starting work on them. Use when asked to "file the CRM backlog", "create the crm issues" or run /crm-backlog
argument-hint: "[--dry-run]"
---

# File the CRM Backlog

File the workshop's CRM backlog into this repository, then stop. The issues are fixed files in `issues/` next to this skill, in the `/ticket` shape, each small enough for one OpenSpec change. `bin/crm-backlog` files them in order, labels each `crm` (creating the label when it is missing), writes each dependency as an `after: #<number>` line, and skips any issue whose title already exists, so running it again is safe. It refuses a template repository: the backlog belongs in a copy of the template.

## Step 1: Preview (optional)

When the argument is `--dry-run`, or the user asks what would be filed, run:

```bash
bin/crm-backlog --dry-run
```

It only reads: it prints `would file <title>` with the titles each issue depends on, or `exists #<number> <title>`. Show the output and stop.

## Step 2: File

```bash
bin/crm-backlog
```

It prints `filed #<number> <title>` or `exists #<number> <title>` for each issue. When it fails partway, show the error and run it again once the cause is fixed: what was filed is skipped.

## Step 3: Stop

Print what was filed and stop. Filing the backlog is not starting work on it: no branch, no OpenSpec change, no `/work`. To build an issue, the user runs `/work <N>` or starts an Orca workspace from its URL.
