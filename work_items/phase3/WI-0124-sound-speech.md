# WI-0124 Sound and speech

Size: M · Depends on: WI-0117 · Blocks: WI-0134, WI-0135

## Goal

The sound, volume and speech elements of v1 exist in v2, through `SystemOps` (E0103), so the tests make no noise. Requirements: REQ-ELM-380.

## Classes

| Class | Mode | Note |
|---|---|---|
| `Action_Play_Sound` | worker | a file or a system sound (v1 `systemSound`, e.g. `tada.wav`); wait or not |
| `Action_Stop_Sound` | worker | stops a sound of `Action_Play_Sound`: check how it reaches a sound that another worker plays (a sound of a worker that has ended) |
| `Action_Beep` | worker | |
| `Action_Get_Volume` | worker | `SoundGetVolume`, `SoundGetMute`, the devices of v1 |
| `Action_Set_Volume` | worker | |
| `Action_Speech_output` | worker | SAPI (COM), voice, speed, volume, wait or not; the voices of the machine for the drop-down |

## Read first

The common part of the element packages (README S0008); `doc/MIGRATION.md` M-0077 (the speech output that the S0003 test copy removed); AutoHotkey docs: `SoundPlay`, `SoundBeep`, `SoundGetVolume`, `SoundSetVolume`, `ComObject`.

## Tasks

The common tasks (README S0008) for every class, and:

1. **Asynchronous sound:** a sound or a speech that does not wait outlives the job. Decide where it plays (the worker keeps it until it ends and is then free; or one long-lived process) and how `Action_Stop_Sound` reaches it; write the decision into the class header and ELEMENT-API-V2.
2. **The adapted copy of "Trigger test"** (M-0077) gets its speech output back if the test provider makes it silent; otherwise M-0077 stays and says why.
3. **gui test** (owner) for one real sound and one real speech output.

## Acceptance criteria

Those of every element package (README S0008).

## Not part of this

Recording sound, more speech engines than SAPI.
