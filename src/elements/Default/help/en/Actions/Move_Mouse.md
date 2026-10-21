# Move mouse

The action **Move mouse** simulates a mouse movement. The coordinates can be specified.

## Settings

### Mouse position

The mouse will be moved to the specified position.

### Method

There are different methods to simulate mouse events. If the mouse movement is not recognized by the application using the default method, you may try to change it.

**Input mode** has best performance and is the recommended one in most cases. It does not allow to set mouse movement speed.

**Event mode** has lower performance.

**Play mode** may require to disable the UAC to work. It may work better in games. It does not allow to set mouse movement speed.

**Input mode** can only be used in one AutoHotFlow instance. If you run multiple AutoHotFlow instances simultanously, the second instance will not be able to use it. Also other applications and AutoHotkey scripts may block the input mode. If **Input mode** is blocked, it will automatically fall back to **Event mode**.

### Mouse movement speed

The mouse movement speed can be changed here.

If **Input mode** or **Play mode** is selected, the mouse will always move instantly.

### Delay in ms

Specify the delay between each mouse action. It will be effective between every mouse click and between mouse movements.

If **Input mode** is selected, the delay will always be 0 and this option will have no effect.
