# WI-34 Funde aus der Abnahme des Fix-Blocks (F-37 bis F-42)

Größe: M · Hängt ab von: WI-30 bis WI-33 · Blockiert: Abschluss des Fix-Blocks (Haken "Abnahme" in `README.md`)

## Ziel

Die Abnahme von WI-32 (`work_items/STATUS.md`, Abschnitt "Abnahmelauf Fix-Block") war nicht grün: parallel 5 von 10 Läufen, im Fault-Lauf ein roter Test. Die roten Tests sind die Funde F-37 bis F-42. Dieses Paket klärt jeden Fund: **Produktfehler beheben, mit einem Test, der vorher rot ist**, oder Testfehler beheben, oder begründet zurückstellen. Danach wird die Abnahme wiederholt.

Einordnung aus dem Review (2026-10-12): Mindestens einer der Funde ist ein echter Produktfehler (F-41), ein weiterer möglicherweise (F-40). Die übrigen sind sehr wahrscheinlich Testprobleme. Die Produktfehler kommen zuerst.

## 1. F-41: Kind, das sich während des Beendens meldet, bekommt nie `sys.shutdown` (Produktfehler) [gelesen, nicht nachgestellt]

**Beobachtet:** `test_measurements.py::test_start_to_ready_time[smoke]` endete mit Exit 5. Log: "deadline reached, terminating the remaining processes", `storage` und `worker:1` wurden hart beendet; `worker:1` verband sich erst nach der Beendigungsanfrage.

**Ursache im Code:**
- `Shutdown._SendGroup` (`src/supervisor/Shutdown.ahk`) schickt `sys.shutdown` an die Kinder einer Gruppe **einmal**, wenn die Gruppe an der Reihe ist. `Children.SendShutdown` gibt false zurück, wenn das Kind noch nicht verbunden ist; das wird nicht vermerkt und nie wiederholt.
- `Supervisor._OnHello` → `Children.OnHello` setzt das Kind auf `ready`, sendet aber während des Beendens nichts.
- `Children.GroupDone` wartet auf `sys.bye` oder das Prozessende. Beides kommt nie. Die Gruppe von `storage` (Rang 4) kommt nie an die Reihe, nach der Frist werden beide hart beendet, Exit 5.

**Warum wichtig:** Das tritt auf, wenn der Benutzer kurz nach dem Start beendet, während der warme Worker, ein Editor oder das Debug-Fenster noch hochfährt. Das Beenden dauert dann die volle Frist, und `storage` wird hart beendet. In Phase 3 heißt das: Was in der Warteschlange von `storage` steht (Variablen, Logzeilen), wird nicht geschrieben.

**Aufgaben:**
1. Test, der vorher rot ist: Beenden auslösen, während ein Kind (z. B. ein Worker oder die Testrolle `echo` mit verzögertem Start, falls nötig neue Testoption) noch nicht verbunden ist; Erwartung: Exit 0, alle Kinder `clean`, Dauer deutlich unter der Frist.
2. Korrektur: Ein Kind, das `sys.hello` sagt, während das Beenden läuft (Phase `shutdown`), bekommt sofort `sys.shutdown` mit der Restfrist, wenn seine Gruppe schon an der Reihe war oder ist. Für Kinder einer späteren Gruppe gilt die normale Reihenfolge. Ein Kind, das sich erst in der Phase `kill` meldet, wird wie bisher behandelt.
3. Prüfen, ob es weitere Wege gibt, auf denen ein Kind nach `BeginShutdown` entsteht oder sich meldet (Neustart ist gesperrt, `SpawnWorker` wirft `shutting_down`; das Debug-Fenster über `--command=debug`?). Im Ergebnis auflisten.

## 2. F-40: Anfragen an einen gestorbenen Prozess warten ihre volle Frist ab (möglicherweise Produktfehler) [vermutet]

**Beobachtet:** `test_engine.py::test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files` bekam nach dem Neustart des Storage-Stubs kein `evt.engine.ready` (1 von 10 parallelen Läufen, im langsamsten Lauf).

**Vermutete Ursache:** Der Hub merkt sich Anfragen zwischen zwei Clients nicht (auf dem schnellen Weg aus WI-24 parst er sie nicht einmal). Stirbt `storage`, bekommen die offenen `cmd.storage.flow.read` der Engine keine Antwort und laufen bis zu ihrer eigenen Frist (`Engine.READ_TIMEOUT_MS`, 30 s). Erst dann erkennt die Engine den Abbruch und setzt das Laden fort. Ob das im Test die Ursache war, ist nicht geprüft (in der Meldung steht der stderr der Engine nicht ausgewertet).

**Allgemeines Muster:** Jede Anfrage an einen Prozess, der abstürzt, wartet ihre volle Frist ab. In Phase 3 betrifft das z. B. einen Editor, der die Engine fragt, während sie abstürzt.

**Aufgaben:**
1. Den Fehlschlag nachstellen oder die Ursache anders belegen (Testlauf mit `AHF_TEST_KEEP=1`, Log der Engine). Ergebnis im Ergebnis-Abschnitt.
2. Ist die Vermutung richtig: Test, der vorher rot ist (Ziel stirbt mit offener Anfrage, die Antwort `peer_gone` kommt binnen 1 s statt nach der Frist). Korrektur nach Wahl des Pakets, begründet:
   - Vorschlag: Der `Peer` bricht offene Anfragen an ein Ziel sofort mit `peer_gone` ab, wenn `evt.process.crashed` oder `evt.process.exited` für dieses Ziel eintrifft. Dafür muss die Rolle das Topic `process` abonniert haben (die Engine tut das seit WI-31); ob das für alle Rollen in `Role` gehört, im Paket entscheiden.
   - Alternative: Der Hub merkt sich weitergeleitete `cmd.*` mit Absender (nur Kopffelder, das liefert `ParseHead` schon) und antwortet beim Verlust des Ziels selbst mit `peer_gone`. Kosten und Nutzen gegenüber dem Vorschlag abwägen.
3. Ist die Vermutung falsch: eigentliche Ursache finden und beheben, oder begründet zurückstellen.

## 3. Testkorrekturen (sehr wahrscheinlich Testprobleme) [vermutet]

Jeweils zuerst die Ursache belegen (Meldung, Log), dann korrigieren. Keine Grenze stillschweigend lockern.

| Fund | Test | Vermutung aus dem Review | Richtung |
|---|---|---|---|
| F-37 | `test_worker.py::test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms` | Nur 0,1 s zwischen `cmd.worker.run` und `cmd.worker.cancel`; unter Last ist der Auftrag noch nicht angenommen, `cancel` endet mit `not_found` | Auf den Zustand "läuft" warten (z. B. `sys.busy` des Workers oder Snapshot), nicht auf eine feste Zeit. Die Antwort `ans` in der Fehlermeldung ausgeben |
| F-38 | `test_debug_role.py::test_refresh_stores_the_snapshot_of_every_role_and_the_supervisor` | Der Test wartet nur, bis `worker:1` in der Prozessliste steht (irgendein Zustand). `DebugView.RefreshSnapshots` fragt aber nur Prozesse im Zustand `ready`. Ist `worker:1` noch `starting`, sind es 5 statt 6 [gelesen] | Test wartet auf `ready`. Zusätzlich die Produktfrage beantworten: Soll der Refresh Prozesse, die nicht `ready` sind, als "nicht bereit" anzeigen statt sie wegzulassen? Vorschlag ja (das Fenster soll gerade solche Zustände zeigen); dann den Test darauf ausrichten |
| F-39 | `test_big_flows.py::test_hub_cost_of_a_large_frame_is_below_the_budget[smoke]` | Feste Grenze 5,0 ms im Standardlauf, nicht über `scaled()`; gemessen 5,07 ms | Smoke-Variante über `scaled()`, die strenge Grenze bleibt unter `-m stress` |
| F-42 | `test_diagnose.py::test_the_handles_of_the_supervisor_stay_flat_over_50_restarts` | Feste 15-s-Wartezeit (`wait_restarted_ready(..., timeout=15)`), nicht über `scaled()` | Über `scaled()`. Vorher das Supervisor-Log aus der Meldung auswerten: War es nur Last oder ein verzögerter Neustart? |

Danach den ganzen Testbestand einmal nach festen Wartezeiten und Grenzen durchsuchen, die nicht über `scaled()` laufen, aber Produktversprechen sind (Suche nach `timeout=` mit Zahl, festen `assert ... < ` mit Zeiten). Treffer anpassen oder im Ergebnis begründen.

## 4. Doku und Regeln

- `doc/TESTSTRATEGIE.md`: Regel ergänzen: Der parallele Lauf erkennt wegen `scaled()` keine Verschlechterung der Latenz mehr. **Der serielle Lauf und `-m stress` laufen mindestens am Ende jedes Pakets, das Zeitverhalten ändert, und am Ende jedes Blocks** (sie sind die strenge Referenz). Kein automatisches Wiederholen roter Tests (z. B. `pytest-rerunfailures`): Ein wackelnder Test kann einen echten Fehler zeigen (F-26 war einer).
- Die Bestätigungen E16 (`Peer.CloseWhenFlushed`) und E17 (`scaled()` mit Faktor 3 bleibt) stehen in `README.md` (Nachtrag WI-34); in `STATUS.md` (Abschnitt Entscheidungen) übernehmen.
- `doc/ARCHITEKTUR.md` 6.3 (Kind meldet sich während des Beendens), ggf. `doc/PROTOKOLL.md` (Abbruch offener Anfragen bei Prozessende), `doc/HOW-TO.md`.
- `.vscode/tasks.json` nach Regel 10 in `AGENTS.md`.

## 5. Abnahme wiederholen

Wie in WI-32, Aufgabe 2, jeder Lauf allein auf dem Rechner, Ergebnisse in `STATUS.md` (neuer Abschnitt, der alte bleibt):
- 10 parallele Gesamtläufe hintereinander, alle grün. Jeder rote Test wird eingeordnet (neuer Fund ab **F-43**) und, wenn möglich, im Paket behoben; dann zählt die Serie neu. Nach drei Runden mit neuen Funden anhalten und dem Projektinhaber berichten, statt weiterzumachen.
- 1 serieller Gesamtlauf grün.
- `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` grün.
- `python -m pytest tests -m stress -q` grün.
- Laufzeiten festhalten (parallel, seriell) und mit WI-18 (parallel 48 s) und dem Abnahmelauf (rund 110 s) vergleichen. Wächst die Laufzeit weiter, die zehn langsamsten Tests nennen.

## Akzeptanzkriterien

- F-41 behoben, Test vorher rot und danach grün.
- F-40 geklärt: behoben mit rotem Test oder mit Beleg begründet zurückgestellt.
- F-37, F-38, F-39, F-42 behoben oder begründet zurückgestellt.
- Abnahme aus Abschnitt 5 grün. Dann den Haken "WI-32 Abnahmeläufe" und "WI-34" in `README.md` setzen, Fix-Block als abgeschlossen melden (`STATUS.md`, `HANDOVER.md`, `AGENTS.md`).
