# Click

The action **Click** simulates a click with any mouse button. The coordinates can be specified.

## Settings

### Which button

Specify the button to click.

### Click count

The number of times to click the mouse. To simulate a double click, set this value to 2.

### Event

If Click is selected, each click will consist of a "down" event followed by an "up" event.

The mouse can be kept down or released by selection of one of the other options.

### Mouse position

If **Move mouse before clicking** is checked, the mouse will be moved to the specified position.

Since this field is an expression, it is possible to do some calculation here. Such as defining an offset after searching for an image using action Search image. For example: ImagePosX + 10.

You can use the wizard to get the coordinates.

### Method

There are different methods to simulate mouse events. If the mouse click is not recognized by the application using the default method, you may try to change it.

**Input mode** has best performance and is the recommended one in most cases. It does not allow to set mouse movement speed.

**Event mode** has lower performance.

**Play mode** may require to disable the UAC to work. It may work better in games. It does not allow to set mouse movement speed.

**Input mode** can only be used in one AutoHotFlow instance. If you run multiple AutoHotFlow instances simultanously, the second instance will not be able to use it. Also other applications and AutoHotkey scripts may block the input mode. If **Input mode** is blocked, it will automatically fall back to **Event mode**.

### Mouse movement speed

If **Move mouse before clicking** is selected, the mouse movement speed can be changed here.

If **Input mode** or **Play mode** is selected, the mouse will always move instantly.

### Delay in ms

Specify the delay between each mouse action. It will be effective between every mouse click and between mouse movements.

If **Input mode** is selected, the delay will always be 0 and this option will have no effect.
