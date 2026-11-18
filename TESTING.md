# Testing

How ci's own checks are tested. Each rule here is one this suite follows today; a rule enters with the tests that keep
it.

- **Red first.** A new check or a fix starts with a test that fails for the right reason, then the code that makes it
  pass. The pull request names the red test under `## Verification`.
- **Both shells.** The scripts run in Windows PowerShell 5.1 and PowerShell 7, so CI runs every test in both
  (`.github/workflows/check.yml`), and PSScriptAnalyzer on every script. Run them before you push with the same
  command and tool versions: `.github/Test-Ci.ps1`.
- **One test file per check, beside it.** `.github/actions/<check>/<Check>.Tests.ps1` tests the check's functions with
  samples shaped like real input (titles, descriptions, `git diff --numstat`, commit subjects).
- **Test at one layer:** the functions are tested once, not again through
  the script that calls them. The script is proven by the check running on a real pull request.
- **A check is proven on pull requests:** one it should pass and one it should fail, before it ships.
