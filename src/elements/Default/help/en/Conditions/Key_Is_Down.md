# Key is down

The condition **Key is down** is **yes** while the key is held down, otherwise **no**.

## Settings

### Key name

The name of the key, in the key names of AutoHotkey v2 (for example `a`, `Space`, `F6`, `LButton` for the left mouse button; the list is in the [key list](../../../../../../assets/help/en/Key_list.md)).

### Which key state

**Logical**: the state that the system and the active window see. It is the normal choice.

**Physical**: the state of the key on the keyboard. It differs from the logical state when a key is sent by a flow.

## Remarks

The condition reads the keys of the user. A key name that AutoHotkey does not know ends the flow with an error.
