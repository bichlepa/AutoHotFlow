# Empty recycle bin

The action **Empty recycle bin** empties the recycle bin of all drives, or of one drive. The files are removed for good. Be careful: the files cannot be restored afterwards.

## Settings

### Which drive

- **All drives**: the recycle bins of all drives are emptied.
- **Specified drive**: only the recycle bin of the drive that is chosen below is emptied.

### Drive letter

The drive, for example `C:`. It is needed only for **Specified drive**; an empty drive ends the element with an exception.

## Behavior

If the recycle bin cannot be emptied, the element ends with an exception.

## Examples

Empty the recycle bin of drive D.

| Parameter | Value |
| --- | --- |
| Which drive | Specified drive |
| Drive letter | `D:` |
