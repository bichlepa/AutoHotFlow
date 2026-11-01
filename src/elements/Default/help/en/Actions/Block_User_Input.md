# Block user input

The action **Block user input** stops the keyboard and the mouse of the user from having any effect. The action **Unblock user input** lets them work again.

> **Warning:** While the input is blocked, the user cannot use the computer. Unblock it in a later step of the flow. AutoHotFlow also unblocks the input when its worker process ends normally. If the process is killed (for example after a hang), AutoHotFlow does not release the input; this is not checked yet.

## Settings

### New block state

**Block user input**: the keyboard and the mouse of the user are blocked.

**Unblock user input**: the keyboard and the mouse of the user work again.
