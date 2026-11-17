# ci

The checks every repo runs on its pull requests: a title and description in plain words naming one Linear issue, a
size reviewers can read, and commits that name their issue. ci checks its own pull requests with them
(`.github/workflows/pr.yml`). Ported from ThePearPoet143/foundation, where each was first built and proven (SUS-27,
SUS-28, SUS-29).

## Use it

A repo calls each check at one exact release:

```yaml
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, labeled, unlabeled]
jobs:
  text:
    if: github.event.pull_request.user.login != 'dependabot[bot]'
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: ThePearPoet143/ci/.github/actions/text-check@v0.2.0
        with:
          issue-prefix: HQ
  size:
    runs-on: ubuntu-24.04
    permissions:
      contents: read
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v7.0.1
        with:
          fetch-depth: 0
      - uses: ThePearPoet143/ci/.github/actions/size@v0.2.0
  branch:
    if: github.event.pull_request.user.login != 'dependabot[bot]'
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1
        with:
          fetch-depth: 0
      - uses: ThePearPoet143/ci/.github/actions/branch@v0.2.0
        with:
          issue-prefix: HQ
```

Dependabot's pull requests skip the text and branch checks: a bot writes no issue key, sections or model line.

## Releases

ci is released only by merging `dev` into `main`, in a pull request titled
`chore(release): v1.2.3, what it brings (HQ-123)`. Every call in this README and in ci's workflows names that one
version, and a test fails a pull request whose calls name two. The merge tags the release and writes its notes from the
pull request's "What and why", which lists the issues it releases.

Versions follow [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html): a check that fails more is a minor
version while ci is `0.x`.

## Tools

The checks run with exact tool versions, pinned in `.github/tools/tools.psd1`, so the same commit gets the same result
on any machine. Run what CI runs:

```
.github/Test-Ci.ps1
```

It stops with the install command when a pinned tool is missing; CI passes `-Install`.

## The rules

**Title:** `type(scope): what changed (KEY-123)`, at most 72 characters: plain words saying what's different, the
Linear issue key last. The types are Conventional Commits' `feat` and `fix`, plus `docs`, `chore`, `refactor`, `test`,
`ci`, `build`, `perf` and `style`, which `@commitlint/config-conventional` recommends
([Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)). A `!` after the type marks a breaking
change. Commits still start with the issue key (`HQ-1: …`), so Linear links each one.

**Description:**

| Type | Needs |
| ---- | ----- |
| every type | `## What and why`, at most 120 words |
| `fix` | `## Tests`, naming the Red step: the test that failed before the fix |
| `feat` | `## Proven`: where it was shown to work |

**Last line:** 🤖, then the model and its version, e.g. `🤖 Claude Opus 5.5`.

**Linear issues:** title at most 60 characters, body at most 80 words, with a "Done when". Check one before saving:

```
powershell -File .github\actions\text-check\Invoke-TextCheck.ps1 -IssueTitle '…' -IssueBody '…'
```

Words are counted as words and numbers; marks such as ✓ and — don't count.

## Size

The size check labels each PR by its effective changed lines, with Kubernetes'
thresholds (`kubernetes-sigs/prow`, `pkg/plugins/size/size.go`), the same T3 Code uses:

| Label | Changed lines | What it calls for |
| ----- | ------------- | ----------------- |
| `size:XS` | 0–9 | the text check |
| `size:S` | 10–29 | the text check |
| `size:M` | 30–99 | an AI review: the PR is labelled `review:ai` |
| `size:L` | 100–499 | an AI review, and the owner's |
| `size:XL` | 500–999 | fails: split it, or label it `size-exempt` and say why |
| `size:XXL` | 1,000+ | fails, as `size:XL` |

Lockfiles, generated and vendored files, and `changes/` aren't counted; nor are tests, unless a PR changes only tests.
A repo leaves out more with `size-extra-ignored`. The size check labels the PR, so the calling job grants
`pull-requests: write` and `issues: write`: a called workflow can't grant itself
more than its caller.

## Branches and commits

The branch and commit checks:

- **Target branch:** pull requests go into `dev`. One into `main` must be a release, from this repo's `dev`, not a
  fork's; a pull request into any other branch fails, so a throwaway proof targets `dev` and is closed unmerged.
- **Commits:** each one starts with its issue key in capitals (`HQ-1: …`), so Linear links it. GitHub's own "Merge
  pull request #n from …" commits pass; a merge you make yourself names its issue (`HQ-1: merge dev`). A release skips
  this check: its commits were checked on their way into `dev`.
- **A failed git command fails the check,** rather than reading as no commits or no changed lines.
- **Release:** one that names no issue (`HQ-123`) gets a warning, since Linear moves an issue only when a pull request
  names it.

## Writing PowerShell for both shells

The scripts run in Windows PowerShell 5.1 and PowerShell 7. A `.ps1` file with any character outside ASCII (🤖, ✓, —)
is saved as UTF-8 **with a BOM**: Windows PowerShell 5.1 reads a file without one as ANSI. And PowerShell treats the
typographic quotes ‘ ’ “ ” as quote marks, so write them as `’` and the like inside a string.

The analyzer also fails the traps that broke real runs (`.github/lint/Traps.ps1`), each with its fix:

| Rule | The trap |
| ---- | -------- |
| `JsonArrayInArray` | `@(… \| ConvertFrom-Json)` holds a JSON array as one item in 5.1; wrap the pipeline: `@((…))` |
| `JsonArrayMidPipeline` | `… \| ConvertFrom-Json \| …` passes the array on as one item in 5.1; end the pipeline: `@((…)) \| …` |
| `EmptyNativeArgument` | 5.1 drops an empty `''` argument to a program; pass `'""'` |
| `QuoteInNativeArgument` | 5.1 drops double quotes inside an argument to a program |
| `GhApiLeadingSlash` | Git Bash turns `gh api /repos/…` into a file path; write `repos/…` |
| `NativeStderrUnderStop` | under `$ErrorActionPreference = 'Stop'`, 5.1 stops on a program's redirected stderr |
| `GitWithoutInvokeGit` | a failed `git` reads as no output; call it through `Invoke-Git` |

A program is a name in `$NativeCommands` or ending in `.exe`; `cmd /c` keeps its own quotes. Stop is read from the
nearest `$ErrorActionPreference` setting before the command. Two traps stay with review, since a script's text can't
show them: a bare `--` passed to a function, and a one-item array that unwraps when splatted (type it `[string[]]`).

## Comments

A comment in ci's PowerShell and YAML is only a link to the source the code relies on (`# https://...`); what the
code does and why goes in this README, TESTING.md or the pull request. Comments go stale and nothing checks them, and
an agent copies one as a reason for a workaround (Lauren Tan, "All Code Is Slop", 8:20:
https://www.youtube.com/watch?v=O_zcc6Xl12g). A test fails any other comment (`.github/lint/Comments.ps1`), and
`Test-Ci.ps1` reads every link and fails one that doesn't load, printing what it read (outside state: it retries on
PowerShell 7, and it proves the page loads, not a `#anchor` on it). The test reads the files git tracks, and in YAML only
whole-line comments: a comment after a value isn't caught, and a `#` line inside a `run: |` block would be.

## Linear audit

Linear issues never pass through a pull request, so `.github/workflows/linear-audit.yml` checks them on its own: once a day
(13:17 UTC), on any pull request that changes it, and on demand, it reads every open issue in team HQ from Linear's API and runs the same
issue rules as the text check (title at most 60 characters, body at most 80 words not counting Agent notes, a "Done
when"). It prints the key of every issue it read (titles stay out: ci's logs are public), lists each problem by key, and fails if there is one, if it can't see the team, or if it read nothing. Closed issues (completed, canceled, duplicate) are skipped, and so is a pull request from a fork, which gets no key.
It doesn't change Linear. It needs the `LINEAR_API_KEY` secret; GitHub emails the person who last changed its schedule
when a scheduled run fails.
