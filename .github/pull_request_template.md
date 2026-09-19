## Summary

One or two sentences on what this changes for someone setting up a Mac.

## Technical architecture

Summarize the structural change and the important design decisions. Name the
tab, the shared library, or the menu behavior that changed.

## Blast radius and risk assessment

What could break on a machine that runs this. Flag **HIGH RISK** when the
change touches `core/main.sh`, `core/tabs/common-script.sh`,
`core/tabs/settings-lib.sh`, `start.sh`, `sudo` usage, or anything that
deletes files.

Most changes here are not reverted by re-running the script with a different
value. Say so when that applies.

## Automated validation

List the exact commands that passed.

- [ ] `shellcheck -S warning -e SC1090,SC1091` passed on every changed script
- [ ] `shfmt -d -i 4 .` reports no diff
- [ ] `bats test/` passed, when `core/tabs/settings-lib.sh` changed
- [ ] `typos` passed
- [ ] Pull-request CI passed on the latest commit
- [ ] No credential, license key, serial, or `.env` file is staged

## Manual testing

CI checks spelling and shell syntax only. It cannot tell whether a preference
key is the one macOS actually reads. Describe what was run and on what.

- [ ] Run on a real Mac, not only in CI
- [ ] Every changed preference read back with `defaults read` as the logged-in
      user, and confirmed against the System Settings UI
- [ ] Any install path run twice: the second run detects what the first
      installed and skips it
- [ ] macOS version and hardware recorded below
- [ ] Screenshots or terminal output attached for anything the user sees

Environment:

## Rollback plan

One sentence on reverting safely. Include how to undo a preference or an
install that a revert of the code does not undo.

## Review

- [ ] Independent review is complete
- [ ] Actionable review threads are resolved

## Limitations and follow-up

Document skipped validation, untested tabs, accepted exceptions, and follow-up
work. Use "None" when there are no known items.
