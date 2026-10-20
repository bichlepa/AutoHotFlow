# WI-0095 Engine and storage: automatic saving and backups (E0065)

Size: M · Depends on: WI-0093 · Blocks: WI-0104

## Goal

A flow has no unsaved state. Every committed change is written shortly afterwards, Ctrl+S writes at once, and the backups cover editing sessions rather than single writes (E0065). Requirements: REQ-EDT-100, REQ-ROB-060, REQ-ROB-120 (the part "a crash loses nothing").

## Read first

`AGENTS.md`; `doc/DECISIONS.md` E0065, E0066; `doc/ARCHITECTURE.md` 4.2, 6.3; `doc/PROTOCOL.md` 4.2 (`cmd.flow.save`, flow lifecycle), 4.6 (`cmd.storage.flow.write`, `backup`); `src/engine/Engine.ahk` (`_CmdFlowSave`), `src/engine/vars/` (`VarWriter`, the pattern of the write-behind), `src/engine/FlowStateFile.ahk`; `src/storage/FlowFiles.ahk`.

## Tasks

1. **Docs first:** PROTOCOL 4.2 (the automatic saving, `cmd.flow.save` writes at once, the field `session` of `cmd.flow.patch`, `evt.flow.saved`) and 4.6 (the engine decides about `backup`). ARCHITECTURE 4.2 (the sentence "Saving is an explicit command" is replaced) and 6.3 (the flush at shutdown). MIGRATION (v1 saved by hand and at exit).
2. **Write-behind per flow:** a revision that is not saved yet is written 3 s after the last commit, and at the latest 10 s after the first unsaved commit. One write per flow is in flight; a commit during the write gives another write afterwards. Every write sends `evt.flow.saved {flowId, savedRev}`. A failed write gives `a0` and the storage notice (existing), and it is retried with a growing pause; the flow stays unsaved until a write succeeds.
3. **`cmd.flow.save`** writes now, answers after storage, and resets the timers.
4. **Shutdown:** `sys.shutdown` writes every unsaved flow before `sys.bye`, within the deadline, and logs what could not be written. `cmd.app.prepareExit` asks nothing.
5. **Backups:** storage makes a backup only when the engine asks for one. The engine asks at the first write of an editing session (the field `session` of `cmd.flow.patch`, one ID per editor start; a patch without it only follows the 10-minute rule) and then at most every 10 minutes per flow. A view patch (`view: true`) never asks. The writes of the manager (`cmd.flow.meta.update`) follow the 10-minute rule too. Ten backups are kept, as before.
6. **Delete:** a pending automatic write of a flow that is being deleted is dropped (a write after the delete would create the file again, E0066).
7. **Tests:** a commit is in the file after about 3 s (`scaled()`); patches every second give a write at least every 10 s; `cmd.flow.save` writes at once; a shutdown with an unsaved flow writes it; a killed engine leaves every edit older than 10 s in the file; a killed editor leaves its last edit in the file within 10 s; a session of 20 patches over 30 s gives one backup, a new session gives another; 10 minutes later there is another backup (with a clock that the test sets); a view patch gives no backup; a delete during a pending write.

## Acceptance criteria

- The tests of task 7 are green. PROTOCOL, ARCHITECTURE and MIGRATION are updated. REQ-EDT-100, REQ-ROB-060 and REQ-ROB-120 are updated.

## Not part of this

Restoring backups (REQ-MGR-110); the editor side of the session ID and of the view (WI-0096).
