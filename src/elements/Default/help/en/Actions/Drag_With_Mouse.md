# Drag with mouse

The action **Drag with mouse** moves the mouse to the start position, holds the button down, moves the mouse to the end position and releases the button.

## Settings

### Which button

The button to hold: left, right, middle, the fourth or the fifth button.

### Mouse position

**Relative to screen**, **Relative to active window position**, **Relative to active window client position**: the reference point of both positions.

**Relative to current mouse position**: the start position is an offset from the current position of the mouse, and the end position is an offset from the start position.

### Start coordinates (x,y)

The position where the drag starts. **Get coordinates** opens the mouse tracker.

### End coordinates (x,y)

The position where the drag ends. **Get coordinates** opens the mouse tracker.

### Method

**Input mode** is the fastest and the most reliable method. **Event mode** and **Play mode** obey the delay below.

### Mouse movement speed

How fast the mouse moves while the button is held: 0 is the fastest, 100 the slowest. The speed has an effect in **Event mode** only.

### Delay in ms

The delay between the steps of the drag in **Event mode** and **Play mode**.
