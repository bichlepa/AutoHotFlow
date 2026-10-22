# Speech output

The action **Speech output** uses an installed text to speech voice to read some text.

## Settings

### Text to speak

Text that should be spoken.

### Wait options

**Wait until previous speech output has finished:** if selected, the flow waits until the speech of the background process of AutoHotFlow has finished before this text is spoken. Otherwise the current speech of that process is interrupted and this text is spoken at once.

**Wait until this speech output finishes:** if selected, the flow waits until this text has been spoken. Otherwise the flow goes on while the text is spoken.

### Speech engine

This list contains all voices installed on your computer. Select one of them. An empty entry uses the default voice of the system.

### Volume

Specify the volume from 0 to 100 %.

A volume of 100 % means that it will be spoken with the current sound volume.

### Speed

Specify the speed of the speech, a whole number from -10 (slowest) to 10 (fastest). 0 is the normal speed.

### Pitch

Specify the pitch of the speech, a whole number from -10 (lowest) to 10 (highest). 0 is the normal pitch.

## Remarks

A voice that is not installed ends the action with an exception.

The speech of another flow or action that runs in another background process is neither waited for nor interrupted.
