# Click

The action **Click** clicks a mouse button, holds it down, releases it or turns the mouse wheel. It clicks at the current position of the mouse, or it moves the mouse to the given coordinates first.

## Settings

### Which button

The button to click: left, right, middle, the wheel (up, down, left or right), or the fourth and fifth button (back and forward).

### Click count

How often the button is clicked. For the wheel, the number of notches. **0** only moves the mouse (with **Move mouse before clicking**).

### Event

**Click (Down and up)**: the button is pressed and released.

**Hold down**: the button is pressed and stays down until a **Release only** action.

**Release only**: the button is released.

### Mouse position

**Move mouse before clicking**: the mouse is moved to the coordinates before the click.

**Coordinates (x,y)**: the position. **Get coordinates** opens the mouse tracker: move the mouse to the place, and press OK.

**Relative to screen**, **Relative to active window position**, **Relative to active window client position**: the reference point of the coordinates.

**Relative to current mouse position**: the coordinates are an offset from the current position of the mouse.

### Method

**Input mode** is the fastest and the most reliable method. **Event mode** is slower and obeys the delay below. **Play mode** can work in games and in applications that do not accept the other two.

### Mouse movement speed

How fast the mouse moves to the coordinates before the click: 0 is the fastest, 100 the slowest. The speed is set for this click only, and it has an effect only in **Event mode**.

### Delay in ms

The delay between the parts of the click in **Event mode** and **Play mode**.

## Remarks

The click acts on the whole desktop: the window under the mouse receives it, whatever flow or window is active. Use **Move mouse** and **Click** only where the user expects it.
