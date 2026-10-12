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

## Ergebnis (Abschnitte 1 und 2)

Stand 2026-10-12, Agent für die Produktfehler. Abschnitte 3 bis 5 sind nicht Teil dieses Ergebnisses. Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**. Kein Haken gesetzt (setzt der Abnahmeagent). Keine Eskalation.

Commits: `6e5fc35` (F-41, `sys.shutdown` beim späten `sys.hello`), `7f460ba` (F-41 Aufgabe 3, geplanter Neustart beim Beenden gestrichen), `04192f9` (F-40, Hub antwortet mit `peer_gone`), `27d49cb` (F-40, Python-Hub der Tests ebenso), dazu der Abschluss-Commit (HOW-TO, diese Datei, `STATUS.md`).

### Abschnitt 1: F-41

**Status: abgeschlossen** (wartet auf die Abnahme).

- **Ursache belegt** [verifiziert]: Wie im Paket beschrieben. Nachgestellt mit einem echten Supervisor: `--start=storage,echo:slowhello3000` (die Testrolle `echo` verbindet sich erst 3 s nach dem Start, siehe unten), Beenden bei `storage` bereit und `echo` im Zustand `starting`, Frist 12 s. Log vorher: `exit requested`, danach `client 'echo:slowhello3000' connected`, dann nichts bis `deadline reached, terminating the remaining processes`, `terminating echo:slowhello3000`, `terminating storage`, `finished with exit code 5`. Genau das Muster aus der Abnahme (`worker:1` verband sich nach der Beendigungsanfrage, `storage` und `worker:1` hart beendet).
- **Korrektur** (Aufgabe 2): `Shutdown.OnHello(name)`, aufgerufen von `Supervisor._OnHello` nach `Children.OnHello`. In der Phase `shutdown` bekommt ein Kind beim `sys.hello` sofort `sys.shutdown` mit der Restfrist (`deadlineAt - now`, mindestens 1 ms), wenn seine Gruppe schon an der Reihe war oder gerade ist. Ein Kind einer späteren Gruppe wartet auf seine Gruppe (normale Reihenfolge). Ein Kind in **keiner** Gruppe (sein Prozess entstand gerade, als die Gruppen gebildet wurden, siehe Aufgabe 3) bekommt es sofort. In den Phasen `prepare` (die Gruppen entstehen später und enthalten es) und `kill` (`KillAlive` hat es schon beendet) passiert nichts, wie bisher. Logzeile `a1` "<name> connected during the shutdown, sys.shutdown sent (<n> ms left)". Keine Frist geändert. Ein spätes Kind verursacht keine Verzögerung über die Frist hinaus: es bekommt die Restfrist, und die harte Frist gilt unverändert.
- **Test rot, dann grün:**
  - `tests/fault/test_shutdown.py::test_a_child_that_says_hello_during_the_shutdown_gets_sys_shutdown_and_the_session_exits_clean`: vorher **Exit 5** an der Frist (Log oben), nachher **Exit 0 nach 3,09 s** (Verzögerung des Kindes 3 s, Frist 12 s), `echo` und `storage` mit `clean: true`. Grenze im Test: Verzögerung plus `CLEAN_EXIT_BUDGET_S` (über `scaled()`). Ist das Kind beim Beenden schon bereit (sehr langsame Maschine), überspringt sich der Test mit Begründung (`skip`), statt nichts zu prüfen.
  - AHK-Unit-Tests (`tests/ahk/supervisor_tick.test.ahk`): "a child of a group that had its turn gets sys.shutdown at its late hello" und "a child that is in no group ... gets sys.shutdown at its hello" vorher rot (`expected true but got 0`, `expected 1 but got 0`), nachher grün. Nur grün (Absicherung des bisherigen Verhaltens): "a child of a later group ... waits for the turn of its group", "a hello in the prepare phase or in the kill phase gets no sys.shutdown". Die Attrappe `FakeHub` kennt dafür nicht verbundene Namen (`offline`, `Send` liefert `false` wie der echte Hub).
- **Testhilfe:** Die Testrolle `echo` startet verzögert, wenn ihr Name `echo:slowhello<ms>` ist (`EchoRole.Start`, `_StartLate`). Keine neue Option im Produkt, der Supervisor gibt den Namen als `--flow=` ohnehin weiter. Kein VS-Code-Task nötig (kein neuer Aufruf, nur ein neuer Test in einer bestehenden Datei).
- **Aufgabe 3, weitere Wege, auf denen ein Kind nach `BeginShutdown` entsteht oder sich meldet** [gelesen, wo nicht anders gesagt]:
  1. **Geplanter Neustart** (Absturz von `storage` oder `engine` höchstens 300 ms vor dem Beginn des Beendens, `restartAt` schon gesetzt): `Children.Tick` startete den Prozess trotzdem, mitten im Beenden, in keiner Gruppe; er wäre erst an der Frist hart beendet worden (Exit 5). **Behoben** (`7f460ba`): `Children.BeginShutdown` streicht geplante Neustarts (Log `a1`). Rot, dann grün: Unit-Test "a restart that was planned before the shutdown does not start" (vorher `expected 0 but got 1` Starts) [verifiziert].
  2. `cmd.process.spawn` (`SpawnWorker`) und `cmd.app.command debug` (`_OpenDebug`) werfen `shutting_down`, sobald `shuttingDown` gesetzt ist. Rest: `_Launch` kann laut seinem Kommentar zwischen `CreateProcessW` und dem Speichern der Pid unterbrochen werden; der Datensatz gilt bis dahin als `gone`. Beginnt das Beenden genau in dieser Lücke, steht das Kind in keiner Gruppe. Abgedeckt durch den Zweig "in keiner Gruppe" (Unit-Test, siehe oben) [Lücke vermutet, nicht nachgestellt].
  3. Die Startliste (`--start`) wird in `Supervisor.Start` nach `hub.Start()` gestartet. Ein `cmd.app.exit` mitten in dieser Schleife (nur bei einer Unterbrechung des Threads denkbar) ergäbe Kinder in keiner Gruppe: ebenso abgedeckt [vermutet, nicht nachgestellt].
  4. Kinder, die in der Phase `prepare` entstehen (Worker auf Anfrage, Debug-Fenster, Neustart), stehen in den Gruppen, wenn sie beim Übergang zu `shutdown` leben; sie bekommen `sys.shutdown` beim `sys.hello` oder mit ihrer Gruppe.
  5. Wiederverbindung eines laufenden Kindes während des Beendens (Pipe gebrochen): bekommt beim neuen `sys.hello` `sys.shutdown`, wenn seine Gruppe an der Reihe war (das alte `sys.shutdown` kann mit der alten Verbindung verloren sein). Eine Rolle, die `sys.shutdown` schon hatte, verbindet sich nicht neu (`closing`) [gelesen, nicht getestet].
  6. Clients, die keine Kinder sind (Python-Testclients, die zweite Instanz mit `cmd.app.command`), bekommen `sys.shutdown` nur, wenn sie zu Beginn von Phase 2 verbunden sind; der Supervisor wartet nicht auf sie. Unverändert gelassen.
  7. Ein Kind, das sich nie meldet, hält seine Gruppe und alle späteren bis zur Frist auf (danach `KillAlive`); die Startfrist (`STARTUP_MS`, 10 s) ist länger als die Frist des Beendens (5 s). Siehe neuer Fund F-43.

### Abschnitt 2: F-40

**Status: abgeschlossen** (wartet auf die Abnahme). Die Vermutung des Pakets war richtig.

- **Aufgabe 1, Ursache belegt** [verifiziert]:
  - Der Test aus der Abnahme läuft nicht gegen den Supervisor, sondern gegen den Python-Hub `tests/support/pyhub.py`. Dort wie im echten `Hub` gilt: eine weitergeleitete Anfrage wird nirgends vermerkt. Im Test antwortet `DyingStorageStub` ab der 8. Leseanfrage mit `peer_gone`; der Test schließt den Stub, sobald die erste Absage da ist. Die Engine hat zwei Leseanfragen gleichzeitig offen (`LOAD_PARALLEL`). Liegt die zweite beim Schließen noch ungelesen in der Pipe des Stubs, antwortet niemand; `_ReadNext` ruft `_LoadInterrupted` erst, wenn auch diese Anfrage ein Ergebnis hat, also nach `READ_TIMEOUT_MS` (30 s). Der Test wartet nach dem Neustart des Stubs nur 15 s (`READY_TIMEOUT_S`) [gelesen].
  - Nachgestellt unter Last: der Originaltest 24-mal, je 8 gleichzeitig (eigene pytest-Prozesse, `-n 0`): **1 von 24 rot** mit derselben Meldung "no evt.engine.ready after storage came back" (Laufzeit 16,6 s). Der stderr der Engine war leer (ihre Logs gehen an den Stub), die offene Anfrage ist in diesem einen Lauf also nicht direkt gesehen [vermutet für diesen Lauf, Mechanismus verifiziert].
  - Deterministisch nachgestellt: neuer Stub `VanishingStorageStub` stirbt bei der 8. Leseanfrage, ohne sie zu beantworten. Die Engine wird **31,01 s** nach dem Tod bereit (Messung mit `AHF_TIMING_FACTOR=9`), also nach `READ_TIMEOUT_MS`.
  - Mit dem echten Supervisor: Client `a` fragt Client `b`, `b` geht ohne Antwort; ebenso eine eingefrorene Rolle `echo:a`, die dann getötet wird: in beiden Fällen **keine Antwort binnen 10 s** (eigene Frist der Anfrage).
- **Entscheidung (Aufgabe 2): der Hub merkt sich weitergeleitete Anfragen (Alternative des Pakets), nicht der `Peer`.**
  - Umsetzung (`src/supervisor/Hub.ahk`): `_NoteRouted` trägt nach jeder erfolgreichen Weiterleitung eines `cmd.*` die Kopffelder ein (Schlüssel Absender und `id`; Ziel, Typ, Ablauf = `timeoutMs` oder 30000, plus 1000 ms); ein zurücklaufendes `res.*` mit dieser `corr` **vom Ziel** löscht den Eintrag (beide Wege: Kopffelder und vollständiges Parsen). `_FailRouted` beim Ende der Verbindung des Ziels (`_OnClose`: Prozess tot, Pipe gebrochen, Überlauf der Warteschlange; `_Hello`: Wiederverbindung ersetzt die alte) antwortet jedem noch verbundenen Absender mit `peer_gone`. `_ForgetRoutedFrom` vergisst die Anfragen eines gegangenen Absenders. `Hub.Tick` vergisst abgelaufene Einträge (ohne Antwort, der Absender hat seine eigene), `Hub.Shift` verschiebt sie bei einem Stillstand (E12). Snapshot `hub`: neu `routedOpen`, `goneAnswers`.
  - **Kosten** des Hubs: je weitergeleitetem `cmd.*` ein Map-Eintrag, je `res.*` ein Nachschlagen; je Rahmen ein `SubStr` mehr; Speicher nur für offene Anfragen (höchstens 30 s plus 1 s). Kein Parsen der Nutzlast (Kopffelder liefert `ParseHead` schon). Gemessen nach der Änderung, seriell: `test_big_flows.py::test_hub_cost_of_a_large_frame_is_below_the_budget[smoke]` Mittel **2,07 ms**, Maximum 2,41 ms je 109-KB-Rahmen (Budget 5 ms; WI-24 hatte 1,7 ms gemessen, ein Vorher-Wert auf dieser Maschine heute fehlt, der Unterschied ist also nicht zuzuordnen).
  - **Nutzen gegenüber dem Vorschlag (Peer bricht bei `evt.process.crashed/exited` ab):** keine Änderung in `src/core/` und in keiner Rolle (sie verstehen `peer_gone` schon, die Engine zählt es seit WI-31 als "storage fehlt"); wirkt für **jeden** Client (auch ohne Abo von `process`, auch Clients, die keine Kinder sind) und auch, wenn die Pipe eines lebenden Prozesses bricht oder seine Warteschlange überläuft (dafür gibt es kein Prozessereignis); schneller (Ende der Verbindung statt Bewertung des Prozessendes, bis 0,7 s später); keine falsche Zuordnung bei einem Neustart (der Vorschlag hätte eine Anfrage an die **neue** `storage` abbrechen können, wenn das `crashed` der alten spät verarbeitet wird); erfüllt, was PROTOKOLL 5.5 und TESTSTRATEGIE ("Ausstehende Anfragen an ihn bekommen `peer_gone`") schon versprochen hatten.
  - **Verworfen:** der Vorschlag des Pakets (Peer, Topic `process` in `Role` für alle Rollen): mehr Verkehr an jede Rolle, Protokollwissen des Supervisors im `Peer` (core), Lücken wie oben. Ebenso verworfen: nur die Frist `READ_TIMEOUT_MS` der Engine senken (behandelt ein Symptom, jede andere Rolle bliebe betroffen).
  - **Folge, die Absender kennen müssen** (PROTOKOLL 2): `peer_gone` heißt "Ausgang unbekannt"; bei einer Wiederverbindung kann die echte Antwort noch danach kommen (wird als unbekannte `corr` verworfen), eine wiederholte schreibende Anfrage kann doppelt ausgeführt werden.
- **Test rot, dann grün:**
  - `tests/integration/test_supervisor.py::test_open_request_to_a_client_that_goes_away_is_answered_with_peer_gone_at_once`: vorher keine Antwort binnen 10 s, nachher `peer_gone` nach **0,154 s**; eine vorher gegebene Antwort bekommt keine zweite.
  - `tests/integration/test_supervisor.py::test_open_request_to_a_child_whose_process_dies_is_answered_with_peer_gone_at_once` (eingefrorene Rolle `echo:a`, dann getötet): vorher keine Antwort binnen 10 s, nachher **0,074 s** nach dem Töten. Grenze in beiden: `scaled(1.0)` s.
  - `tests/integration/test_engine.py::test_engine_resumes_loading_at_once_when_storage_dies_with_an_open_read` (Python-Hub): vorher bereit erst nach 31,0 s (Grenze `scaled(5.0)` s gerissen), nachher **1,04 s** (die Pause von 1 s nach einem Abbruch aus WI-31). Dafür antwortet `pyhub.py` jetzt wie der echte Hub (`27d49cb`).
  - Nur grün (neue Logik): AHK-Unit-Tests "a forwarded request is forgotten after its deadline, moves with a stand-still and ends only with the answer of its target", "when the target goes, each open request gets one peer_gone and an answered one none", "the requests of a sender that has gone are forgotten".
  - Originaltest unter Last nach der Änderung: **48 von 48 grün** (je 8 gleichzeitig), vorher 23 von 24.
- Doku im selben Commit (Regel 5): `doc/PROTOKOLL.md` 2 (neuer Absatz "Ziel geht vor der Antwort verloren"), 4.9 (Felder `routedOpen`, `goneAnswers`), 5 Punkt 5; `doc/ARCHITEKTUR.md` 6.2 (neue Zeile). `tests/support/snapshotschema.py` prüft die neuen Felder.

### Gelaufene Tests (alle parallel, `-n auto`, wenn nicht anders gesagt; Endstand nach allen vier Commits, sofern nicht anders gesagt)

- Nach F-41 (`6e5fc35`): `tests/fault/test_shutdown.py`, `tests/fault/test_worker_lifecycle.py`, `tests/integration/test_worker.py`, `test_worker_busy.py`, `test_worker_pool.py`, `test_supervisor.py`, `tests/test_architecture.py`, die Fälle von `supervisor_tick.test.ahk`: **123 passed**.
- Nach dem Neustart-Fix (`7f460ba`): `tests/fault/test_shutdown.py`, `test_process_crash.py`, `tests/integration/test_supervisor.py`, `tests/test_architecture.py`: **53 passed**; AHK-Unit-Tests `supervisor_tick`, `diag_report`, `children_output`: **57 passed**.
- Endstand: `tests/integration/test_engine.py`, `test_peer.py`, `test_pipe.py`, `test_supervisor.py`, `test_storage.py`, `test_role.py`, `tests/support`, `tests/fault/test_storage_abort.py`, `test_process_crash.py`, `test_snapshot.py`, `test_report.py`, `test_pipe_break.py`, `tests/test_architecture.py`, `tests/test_ahk_runner.py` (alle AHK-Unit-Tests): **645 passed, 1 skipped** (der bewusste Skip in `test_ahk_runner.py`), 70 s.
- Endstand: `python -m pytest tests -k "storage or restart"`: **86 passed**, 61 s.
- Endstand: `tests/fault` (alle Dateien), `tests/e2e`, `tests/integration/test_worker.py`, `test_worker_busy.py`, `test_worker_pool.py`, `test_entry.py`: **119 passed**, 67 s.
- Endstand: `tests/stress/test_measurements.py -k "start_to_ready and smoke"` (der Test, in dem F-41 auftrat): **1 passed**; `tests/stress/test_big_flows.py -k "hub_cost and smoke"` seriell: **1 passed** (2,07 ms).
- Lastproben (eigene pytest-Prozesse, je 8 gleichzeitig, `-n 0`): Originaltest von F-40 vorher 24 Läufe (1 rot), nachher 48 Läufe (0 rot).
- `python tools/arch_check.py`: 0 Verstöße.
- Nach den Läufen keine Testprozesse übrig (angesehen; nur `AutoHotkeyU32.exe` "Allgemeine Hilfe" des Projektinhabers).

### Nicht geprüft

- Gesamtlauf parallel und seriell, `-m stress`, `AHF_FAULT_REPEAT` (macht der Abnahmeagent, Abschnitt 5).
- F-41 mit einem echten warmen Worker (das Rennen der Abnahme) ist nicht gezielt nachgestellt, nur mit der verzögerten Testrolle; der Weg im Supervisor ist derselbe (`_OnHello`).
- Die Wiederverbindung eines Kindes während des Beendens und der Fall "Kind in keiner Gruppe" im echten Supervisor (nur Unit-Test).
- F-40: Die Wirkung auf den Worker-Pool, wenn ein Worker zwischen dem Empfang von `cmd.worker.run` und seiner Antwort stirbt: die Engine bekommt jetzt sofort `peer_gone` ("worker not available: worker:n (peer_gone)", der Slot wird entfernt und als abnormales Ende gezählt) statt zuerst `evt.process.crashed` ("worker crashed"). Ob das Ende dann doppelt gezählt wird (Antwort und Prozessereignis), ist nicht geprüft [gelesen nur ARCHITEKTUR 6.4, `WorkerBridge` nicht gelesen]. Ebenso `cmd.worker.cancel` an einen sterbenden Worker.
- F-40: Überlauf der Warteschlange und Wiederverbindung unter demselben Namen als Auslöser von `peer_gone`: gelesen, nicht getestet. Die Kosten des Hubs je Rahmen nur einmal seriell gemessen (siehe oben), nicht unter `-m stress`.

### Abweichungen

- Zusätzlich zu Aufgabe 2 von F-41 ein zweiter Fix aus Aufgabe 3 (geplanter Neustart), eigener Commit.
- F-40 ist nicht im `Peer` (`src/core/`) gelöst, sondern im Hub; damit war die im Paket genannte Datei `src/core/ipc/Peer.ahk` nicht nötig.
- Die Engine-Tests brauchen das neue Verhalten auch im Python-Hub (`tests/support/pyhub.py`), weil der Fehlschlag der Abnahme dort entstand.
- Doku über Regel 5 und 9 hinaus nur knapp: `doc/PROTOKOLL.md`, `doc/ARCHITEKTUR.md` 6.2 (eine Zeile) und drei HOW-TO-Einträge (Prozesse: F-41 und F-40, Tests: verzögerte Testrolle). **Für den Doku-Agenten (Abschnitt 4) offen:** `doc/ARCHITEKTUR.md` 6.3 (Kind meldet sich während des Beendens, gestrichener Neustart), `doc/TESTSTRATEGIE.md` (Zeile "Pipe wird vom Client abrupt geschlossen" ist jetzt umgesetzt; die neuen Tests).

### Neue Funde

- **F-43** (in `STATUS.md`): Ein Kind, das beim Erreichen seiner Gruppe noch startet, hält diese und alle späteren Gruppen auf, bis es `sys.hello` sagt. Braucht es länger als die Frist (z. B. ein Worker, der unter Last 5 s startet), wird `storage` an der Frist hart beendet, ohne `sys.shutdown` bekommen zu haben (dasselbe Symptom wie F-41, seltener). [gelesen, nicht nachgestellt]. Vorschlag: ein Kind, das beim Erreichen seiner Gruppe noch nie verbunden war, zählt nicht als Bedingung der Gruppe (es hat noch nichts gesendet, was `storage` schreiben müsste); es bekommt `sys.shutdown` beim `sys.hello` (schon so) und wird an der Frist beendet, falls es nie kommt. Entscheidung nötig, weil es die Reihenfolge der Ränge für diesen Fall lockert.

### Offene Punkte

- Änderungen außerhalb der im Paket genannten Hauptpfade: `doc/PROTOKOLL.md`, `doc/ARCHITEKTUR.md`, `doc/HOW-TO.md` (Abschnitt 4 gehört eigentlich dem Doku-Agenten; nur das nach Regel 5 und 9 Nötige). Keine Änderung in `src/core/` und `src/engine/`.
- Die Protokolländerung von F-40 (Hub antwortet mit `peer_gone`) betrifft alle Rollen als Absender; sie brauchen keine Änderung, sollten `peer_gone` aber als "Ausgang unbekannt" behandeln (PROTOKOLL 2). Bitte im Review bestätigen.
- Restverzögerung aus WI-31 unverändert: nach einem abgebrochenen Laden wartet die Engine 1 s, auch wenn `storage` schon wieder da ist.
