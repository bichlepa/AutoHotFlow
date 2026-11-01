# Send keystrokes

The action **Send keystrokes** sends keys and text to the active window, as if the user typed them.

> **Warning:** The keys go to the window that has the keyboard focus, whatever flow or window the user works in. Check that the right window is active before the flow sends keys.

## Settings

### Keys or text to send

The keys and the text to send. Special keys are written in braces, for example `{Enter}`, `{Tab}` or `{F5}`. The modifiers are `^` (Ctrl), `+` (Shift), `!` (Alt) and `#` (Win). The names are those of AutoHotkey v2, listed in the [key list](../../../../../../assets/help/en/Key_list.md).

**Raw mode**: the text is sent as it is. The characters `^ + ! # { }` are then sent as text and not as keys.

### Send mode

**Input mode**: the fastest and the most reliable method. It is the default.

**Event mode**: slower, but some applications accept only this method.

**Play mode**: can work in games and in applications that do not accept the other two.

## Remarks

Only the send mode is set for this action; the next action is not affected. The key names are those of AutoHotkey v2; the key names of the earlier AutoHotFlow version are not translated.
