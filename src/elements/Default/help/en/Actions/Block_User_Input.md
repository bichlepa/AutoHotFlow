# Block input

The action **Block input** disables or enables the user's ability to interact with the computer via keyboard and mouse.

> **Note:** This action might have no effect if UAC is enabled or AutoHotFlow has not been run as administrator.

## Settings

### New block state

If **Block user input** is selected, the user input will be blocked.

If **Unblock user input** is selected, a previously enabled block will be removed.

## Remarks

When BlockInput is in effect, user input is blocked but AutoHotkey can simulate keystrokes and mouse clicks. However, pressing `Ctrl+Alt+Del` will re-enable input due to a Windows API feature.
