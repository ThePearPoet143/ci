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
      - uses: ThePearPoet143/ci/.github/actions/text-check@v0.3.0
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
      - uses: ThePearPoet143/ci/.github/actions/size@v0.3.0
  branch:
    if: github.event.pull_request.user.login != 'dependabot[bot]'
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1
        with:
          fetch-depth: 0
      - uses: ThePearPoet143/ci/.github/actions/branch@v0.3.0
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
powershell -File .github/ruleset/Set-Ruleset.ps1 -Repo ThePearPoet143/ci
```

Run it again after changing `ruleset.json`. Two effects to know: a release into `main` over 500 changed lines now needs
the `size-exempt` label to merge (until releases skip the size check), and an approval is dismissed when anything is
pushed to the PR, or merged into its base, after it, so approve last. Nobody can merge a PR the owner opened, since
authors can't approve their own; agents open the PRs. Every pull request's `ruleset` check reads the rules GitHub enforces on
`dev` and `main` and fails if one is missing.
