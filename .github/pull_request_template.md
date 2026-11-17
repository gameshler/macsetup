## Summary

One or two sentences on what this changes for someone setting up a Mac.

## Technical architecture

The structural change and the design decisions behind it. Name the tab, the
settings module, the shared library, or the menu behavior that changed.

## Blast radius and risk assessment

What could break on a machine that runs this. Flag **HIGH RISK** when the
change touches `core/main.sh`, `core/tabs/common-script.sh`,
`core/tabs/settings-lib.sh`, `start.sh`, `sudo` usage, or anything that deletes
files.

Most changes are not undone by running the script again with a different
value. Say so when that applies.

## Automated validation

List the exact commands that passed.

- [ ] `shellcheck -S warning -e SC1090,SC1091` passed on every changed script
- [ ] `shfmt -d -i 4 .` reports no diff
- [ ] `bats test/` passed, when `settings-lib.sh`, `common-script.sh`,
      `optimize-settings.sh`, or a module in `core/settings/` changed
- [ ] `typos` passed
- [ ] Pull-request CI passed on the latest commit
- [ ] No credential, license key, serial, or `.env` file is staged

## Manual testing

CI checks spelling, formatting and shell syntax only. It cannot tell whether a
preference key is the one macOS reads. Describe what was run, and on what.

- [ ] Run on a real Mac, not only in CI
- [ ] Every changed preference read back with `defaults read` as the logged-in
      user, and confirmed in System Settings
- [ ] Every changed install path run twice; the second run detects what the
      first installed and skips it
- [ ] macOS version and hardware recorded below
- [ ] Screenshots or terminal output attached for anything the user sees

Environment:

## Rollback plan

One sentence on reverting safely, including how to undo a preference or an
install that reverting the code does not undo.

## Review

- [ ] Independent review is complete
- [ ] Actionable review threads are resolved

## Limitations and follow-up

Skipped validation, untested tabs, accepted exceptions, and follow-up work.
Write "None" when there are none.
