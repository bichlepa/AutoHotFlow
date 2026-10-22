# Lock or unlock drive

The action **Lock or unlock drive** prevents a drive from being ejected (lock), or allows it again (unlock).

A drive that is locked by a flow stays locked when the flow ends, until a program or the next restart unlocks it. Most drives cannot be locked; a read-only drive ignores the lock.

## Settings

### Action

- **Lock drive**: the eject of the drive is prevented.
- **Unlock drive**: the eject of the drive is allowed again.

### Drive letter

A drive letter with its colon, for example `D:`. The letter alone (`D`) is accepted. An empty drive letter ends the element with an exception.
