---
name: ticket
description: Create a GitHub issue in this repository without starting work on it. Use when asked to "create a ticket", "file an issue" or "capture this as an issue"
argument-hint: <what the ticket is about>
---

# Create a Ticket

File a GitHub issue that captures a problem, then stop. Creating a ticket is not starting work on it: running it is a separate step, `/work <N>` or an Orca workspace started from the issue URL.

The argument `$ARGUMENTS` is what the ticket is about. If it is empty, ask what the ticket should capture.

## Step 1: Sharpen It (optional)

If the request is thin, brainstorm before writing: ask one question at a time about the problem, why it matters, and the scope or the design agreed so far. Skip this step when the user declines it or the request already says enough.

## Step 2: Draft

Write a short title and a body in this shape:

```markdown
## Problem

<what is wrong or missing, and why it matters>

## What we want

<the outcome, in the user's terms>

## Scope

<in and out of scope; only when agreed>

## Design

<the agreed design; only when there is one>
```

Show the user the title and body and file it once they approve. When they said to just file it, file it without showing it first.

## Step 3: File

Write the body to a file in the scratchpad directory and run:

```bash
gh issue create -R "$(bin/repo)" --assignee @me --title "<title>" --body-file <file>
```

The issue is assigned to you, its creator; `/work` reassigns it to whoever starts it.

## Step 4: Stop

Once it is filed, print the issue URL and stop. Creating the ticket is the whole task: no branch, no OpenSpec change, no breakdown comment, no `/work`, no code. To work on it later, the user runs `/work <N>` or starts an Orca workspace from the issue URL.
