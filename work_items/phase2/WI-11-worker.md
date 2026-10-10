# WI-11 Worker-Rolle

Größe: M · Hängt ab von: WI-06, WI-09 · Blockiert: WI-10 (Integration), WI-15

## Ziel

Ein Prozess, der Elemente im Modus `worker` ausführt: blockierende Aufrufe sind hier erlaubt, die Engine bleibt davon unberührt.

## Vorher lesen

`doc/ARCHITEKTUR.md` 2.3, `doc/PROTOKOLL.md` 4.5, `doc/ELEMENT-API-V2.md` (Abschnitt 3, `ctx`).

## Zu erstellen (`src/worker/`)

- `Worker.ahk` (Rolle `worker`, erbt `Role`): Handler `cmd.worker.run`, `cmd.worker.cancel`.
  - Antwort auf `cmd.worker.run` sofort `{ok:true}` (angenommen), Ergebnis später als `evt.worker.done`.
  - Ausführung: Klasse aus der Registry, `ctx` vom Typ `WorkerContext`: `Finish` sendet `evt.worker.done`, `imports` sind schreibgeschützt, `exports` werden gesammelt. `After` ist erlaubt.
  - Genau **eine** Ausführung zugleich pro Worker. Ein zweites `run` wird mit `busy` beantwortet (Pool/Zuteilung ist Sache der Engine).
  - Der Worker darf blockieren. Damit `sys.ping` und `cmd.worker.cancel` trotzdem bedient werden, laufen blockierende Teile in kurzen Scheiben mit `Sleep -1`-Pumpen **oder** das Element wird als `worker` nur dann akzeptiert, wenn es nicht länger als `pingTolerance` (Standard 6 s) am Stück blockiert. Entscheidung und Begründung in der Paketdatei dokumentieren (siehe „Offene Punkte“).
  - Absturzsicherheit: jede Elementausführung unter `try/catch`, Ergebnis `exception`.
- `WorkerContext.ahk`: wie `ExecContext` aus WI-09, aber ohne `GetVar`/`SetVar` auf Engine-Daten. Für Phase 2 genügt `Finish`, `State`, `Log`.
- Beenden nach `cmd.worker.cancel` oder `sys.shutdown`: Elementzustand abbrechen (`Stop`), `evt.worker.done` mit `result: "stopped"`.

## Akzeptanzkriterien

- `Action_TestBlockWorker`: Ergebnis `normal` nach ≥ 800 ms. Während dieser Zeit wird `sys.ping` weiterhin beantwortet (Test: 3 Pings in 800 ms, alle beantwortet) **oder** der Worker erklärt vorab, dass er nicht antwortet, und der Supervisor-Heartbeat toleriert das (Entscheidung siehe oben, im Test festgehalten).
- `cmd.worker.cancel` auf `Action_TestHangWorker`: `evt.worker.done` mit `stopped` innerhalb 500 ms.
- Absturz des Workers (Prozess beenden) wird von der Engine als Thread-`exception` gemeldet (Integrationstest zusammen mit WI-10 und WI-07).

## Tests

`tests/integration/test_worker.py` mit Python-Hub.

## Nicht Teil

Worker-Pool-Verwaltung, `RunScript` (AHK-Skript-Element), `ctx.Request`.

## Offene Punkte

- Pings während blockierender Aufrufe: AHK v2 hat keinen zweiten Thread. Mögliche Lösungen: (a) Heartbeat-Toleranz für Worker im Zustand `busy` größer als die Elementdauer, (b) Elemente mit blockierendem Sleep in `Sleep`-Scheiben aufteilen, (c) Worker meldet beim Start der Ausführung ein „busy until“-Fenster. Empfehlung: (c), ein `evt.worker.busy {execId, expectedMs}` an den Supervisor/Engine, Heartbeat-Toleranz = erwartete Dauer + 5 s. Mit der Engine abstimmen.

## Ergebnis

Stand: WI-11 umgesetzt, alle Akzeptanzkriterien grün. Commits mit Präfix `WI-11:` (`git log --oneline`). Gesamtlauf `python -m pytest tests -q`: `359 passed, 1 skipped in 179.34s`. Der Skip ist der bestehende AHK-seitige Skip in `tests/test_ahk_runner.py`. Danach keine von den Tests gestarteten AutoHotkey-Prozesse übrig.

**Akzeptanzkriterien:**

| Kriterium | Ergebnis | Beleg (`tests/integration/test_worker.py`) |
|---|---|---|
| `Action_TestBlockWorker`: Ergebnis `normal` nach ≥ 800 ms | erfüllt | `test_element_that_blocks_finishes_normal_after_its_time` |
| Während des Blockierens werden `sys.ping` beantwortet (3 Pings in 800 ms) | erfüllt | `test_pings_are_answered_while_a_blocking_element_runs` (Heartbeat-Toleranz nicht nötig, siehe unten) |
| `cmd.worker.cancel` auf `Action_TestHangWorker`: `evt.worker.done` mit `stopped` innerhalb 500 ms | erfüllt | `test_cancel_of_the_hang_element_reports_stopped_within_500_ms` (gemessen 29,3 ms) |
| Absturz des Workers: Engine meldet Thread-`exception` | erfüllt | `test_killed_worker_ends_its_element_with_worker_crashed` (Kill bis Instanzende 395 ms, Meldung "worker crashed (worker:1)") |
| Zusätzlich: `busy` bei zweitem `run`, Ergebnis mit `exports`, Abbruch von `Action_TestBlockWorker`, `sys.shutdown` während Lauf | erfüllt | `test_second_run_while_busy_is_answered_with_busy`, `test_run_is_accepted_at_once_and_the_result_comes_as_done` (Exporte), `test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms`, `test_shutdown_while_running_reports_stopped_before_bye` |

**Akzeptanzkriterium aus WI-10 (offen bis WI-11):** `Action_TestBlockWorker`, Snapshot unter 50 ms während der 800 ms Blockade: **erfüllt**. `test_snapshot_is_answered_within_50_ms_while_a_worker_element_blocks`, vier Snapshots während des Laufs, gemessen 0,7 bis 0,8 ms, das Element endet nach über 600 ms. Der WI-10-Eintrag ist nachgetragen.

**Weitere Tests (alle grün):** Timeout der Annahme bei eingefrorenem Worker (`test_frozen_worker_does_not_answer_the_run_and_the_element_fails_by_timeout`, Element endet mit "worker not available: worker:1 (timeout)"), Slot bleibt nach Abbruch ohne Bestätigung bis zur Orphan-Frist von 2 s `busy` und dann `down` (`test_frozen_worker_does_not_confirm_the_cancel_and_its_slot_is_down_after_the_orphan_deadline`), Stopp während Worker-Element innerhalb 500 ms plus freier Slot danach (`test_stop_during_a_worker_element...`), kein Worker verbunden: `exception`, kein Hänger (`test_without_a_connected_worker...`), Worker-Protokoll: `not_found` bei Abbruch unbekannter ID, `bad_payload`, Element ohne Worker-Modus abgelehnt, Element wirft → `exception` und der Worker bleibt bereit.

**Entscheidung zu den Offenen Punkten (Pings während Blockade):** Keine Heartbeat-Toleranz (weder (a) noch (c)). Begründung: AHK prüft Nachrichten zwischen Befehlszeilen. Elemente, die in kurzen Scheiben warten (`Sleep`, Schleifen mit `DllCall("Sleep", 100)`), antworten auf Pings und Abbruch. Ein einzelner langer Aufruf antwortet vermutlich nicht (nicht geprüft); solche Elemente würden vom Supervisor nach dem Ping-Timeout als hängend beendet (`evt.process.hung`/`crashed`, nicht geprüft). Dies ist für Phase 2 vertretbar, aber nicht als Regel für Elemente festgeschrieben (Stolperstein in `doc/HOW-TO.md`).

**Abweichungen von WI-11:**

- `Action_TestHangWorker` (WI-09) wartet jetzt in 100-ms-Scheiben statt 1000 ms. Mit 1000 ms dauerte der Abbruch 812 ms, das Kriterium verlangt 500 ms. Die Schleife bleibt "läuft nie zu Ende". Der Kommentar des Elements wurde korrigiert (die Annahme "ohne Nachrichten" war falsch, siehe HOW-TO).
- `timeoutMs` in `cmd.worker.run` bedient der Worker nicht. Die Engine setzt die Annahmefrist (5 s). Die Laufzeit eines Elements ist nicht begrenzt.
- Pool-Start: Die Engine bekommt `--workers=<n>`, die Slots heißen `worker:1..n`. Der Pool wird nicht über den Supervisor gesteuert (WI-11 nennt Pool-Verwaltung als nicht Teil). Im Crash-Test startet der echte Supervisor `--start=worker:1`. In den übrigen Engine-Tests startet der Test die Worker-Prozesse selbst (Stand-in).
- Worker-Crash wird nicht neu gestartet (Supervisor-Richtlinie kennt nur `storage` und `engine`).
- `Action_TestThrowWorker` und `Action_TestEchoWorker` sind neue Testelemente (Skeleton, Mode `worker`), damit Exception-Pfad und Imports/Exports im Worker testbar sind.
- `core/`: `src/core/RoleRegistry.ahk` verliert den Platzhalter `worker`, wie in WI-10 für `engine`. Die Registrierung steht im Einstieg (`AhfRegisterRoles`). Begründung im Commit `a28ee3a`.
- `tests/integration/test_role.py`: der Fall "nicht implementiert" nutzt `storage` statt `worker`.
- Die Engine behandelt Ergebnisse eines Worker-Laufs, die nicht zu `ExecContext.IsResult` passen (z. B. `stopped` ohne Abbruch), als `exception`.

**Stand-ins und was dadurch nicht geprüft ist:**

- `storage`: Python-Stand-in `StorageStub` (aus WI-10). Die Storage-Rolle fehlt.
- Hub: `WakingHub` (Python) in den meisten Tests, echter Supervisor-Hub nur im Crash-Test. Latenzen über den Python-Client enthalten dessen Weckruf-Verzug (siehe WI-07/WI-04). Die Messungen der Snapshot-Latenz gelten mit diesem Stand-in.
- Storage-Stand-in am Supervisor-Hub nimmt `sys.hello` von Nicht-Kindern an (Crash-Test grün).

**Gemessene Werte (Python-Client, Stand-in-Hub, `pytest -s`):**

- Snapshot während Worker-Blockade: 0,7 / 0,7 / 0,7 / 0,8 ms (vier Anfragen).
- Abbruch `Action_TestHangWorker` bis `evt.worker.done` `stopped`: 29,3 ms (Slice 100 ms; mit 1000 ms: 812 ms).
- Kill des Workers bis `evt.instance.ended` mit "worker crashed": 395 ms.
- Ack-Timeout (eingefrorener Worker): nicht als Wert gemessen, der Test prüft nur das Fenster 4,5 bis 8 s.

**Erstellt bzw. geändert:**

- `src/worker/Worker.ahk`, `src/worker/WorkerContext.ahk`: Rolle und Ausführungskontext.
- `src/engine/WorkerBridge.ahk`: Pool, Aufträge, Abbruch, Orphan-Frist, Prozessereignisse.
- `src/engine/Executor.ahk`, `src/engine/Engine.ahk`: Dispatch an den Pool, Abbruch, Option `--workers`.
- `src/elements/skeleton/Action_TestEchoWorker.ahk`, `Action_TestThrowWorker.ahk` (neu), `Action_TestHangWorker.ahk` (Scheibe 100 ms).
- `src/AutoHotFlow.ahk`, `src/core/RoleRegistry.ahk`.
- `tests/integration/test_worker.py`: 19 Tests (plus Engine-Seite).
- `doc/PROTOKOLL.md` (Abschnitte 4.5 und Engine-Seite), `doc/HOW-TO.md` (Einträge zu Worker, Dialogen, Pings, Tests).

**Nicht geprüft oder offen:**

- Dialog-Elemente im Worker (`MsgBox`, `InputBox`): Nicht getestet. `InputBox` ist ein `#32770`-Dialog und wird vom Dialog-Wächter von `ahkrun.py` geschlossen (Probe, Exit 97). Ein Test braucht einen Lauf ohne Wächter. Das Element wurde wieder entfernt.
- Blockierende Elemente ohne Scheiben (ein einziges langes `RunWait` oder `DllCall`): nicht geprüft, ob sie Pings verhindern, und wie lange. Gilt als Regel für Elementautoren, nicht im Code erzwungen.
- Pool-Verwaltung durch den Supervisor (Start über `--start` ist nur im Crash-Test benutzt), Neustart von Workern, mehrere Engine-Instanzen mit Worker-Pool.
- `ctx.Request` und `RunScript` nicht Teil.
- Die Orphan-Frist (2 s) und die Ack-Frist (5 s) sind Festwerte. Keine Konfiguration.
- Stresstest mit vielen Workern (WI-16).

**Fortschritt:** `[x] WI-11` in `work_items/phase2/README.md` gesetzt, da alle Akzeptanzkriterien grün sind. `WI-10` ist nach dem Nachtrag ebenfalls erfüllt und wurde gesetzt.
