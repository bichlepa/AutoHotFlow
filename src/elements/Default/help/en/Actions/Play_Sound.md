# Play sound

The action **Play sound** plays a system sound, or any sound file of a supported type.

## Settings

### Select sound

There is a selection of standard system sounds.

If **Sound file** is selected, specify the name and path of the file. The file path is assumed to be in the working directory if an absolute path isn't specified. If the file does not exist, the action ends with an exception.

### Wait until the sound has finished

Off (the default): the flow goes on at once while the sound plays.

On: the flow waits until the sound has finished.

## Remarks

Only one sound can be played at a time. If this action is executed while another sound is playing, the playback of the other sound stops and the new sound is played.

A sound that the flow does not wait for keeps playing after the action has ended. It stops when it has finished, when another sound is played, or when AutoHotFlow ends. A **Stop sound** action reaches only a sound that was started in the same background process of AutoHotFlow; a sound started by another action may keep playing.

The Preview buttons of the older version are not part of this element. To test a sound, run the flow.
