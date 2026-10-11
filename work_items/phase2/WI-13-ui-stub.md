# WI-13 UI-Stub

Größe: M · Hängt ab von: WI-06 · Blockiert: WI-15

## Ziel

Ein minimaler UI-Prozess, der beweist, dass eine echte GUI-Rolle mit Engine und Hub zusammenarbeitet: verbinden, Zustand empfangen, Befehle senden, Resync nach Engine-Neustart. Zugleich ein Testwerkzeug (Headless-Modus).

## Vorher lesen

`doc/ARCHITEKTUR.md` 4.1, 6.2, `doc/PROTOKOLL.md` 3, 4.3, 5.

## Zu erstellen (`src/manager/StubManager.ahk`, `src/manager/StubGui.ahk`)

- Rolle `manager` im Stub-Modus (`--ui=stub`):
  - Verbindet sich, abonniert `engine`, `flow:*` (explizit je Flow aus dem Snapshot), `process`, ruft `cmd.engine.snapshot` auf.
  - **GUI (v2 `Gui`)**: Tabelle der Flows (`ListView`), Tabelle der Elementzustände des gewählten Flows, Schaltflächen „Start“, „Stop“, „Beenden“, Statuszeile (Verbindung, `epoch`, `seq`, letzte Latenz).
  - **Headless** (`--headless`): keine GUI, schreibt jedes empfangene Ereignis als JSON-Zeile in `<data>/ui_events.log`, nimmt Befehle über Datei- oder Nachrichtenschnittstelle an (`cmd.test.command`, nur im Stub). Wird von den Tests genutzt.
  - Resync: bei `evt.engine.restarted`, `seq`-Lücke oder Wiederverbindung `cmd.engine.snapshot`.
  - Nur UI-Zustand halten, keine Wahrheit über die Ausführung.
- Beenden: `cmd.app.prepareExit` immer mit `cancel:false` beantworten, `sys.shutdown` → GUI schließen, `sys.bye`.

## Akzeptanzkriterien

- Headless-Stub mit laufender Engine: Ereignisse aus dem Skeleton-Flow stehen vollständig und in Reihenfolge in `ui_events.log`.
- Nach `kill` der Engine und Neustart: `ui_events.log` enthält `evt.engine.restarted` und einen neuen Snapshot, ohne dass der Stub neu gestartet wurde.
- GUI-Modus: manuell prüfbar (Start/Stop-Klick ändert die Elementtabelle, Fenster bleibt bedienbar, während eine Instanz läuft). Im Paket als Testanleitung beschreiben, nicht automatisiert.
- Der Stub blockiert nie auf Anfragen (alle Aufrufe mit Callback).

## Tests

`tests/e2e/test_ui_stub.py` (Headless).

## Nicht Teil

Echte Manager-/Editor-Oberfläche, Zeichnen, Einstellungen.

## Hinweise

- GUI-Zustandsänderungen gehören in den GUI-Thread des Stubs (derselbe Prozess): Ereignisse puffern und per Timer in kleinen Batches rendern (z. B. 20 Hz), damit eine Ereignisflut die Oberfläche nicht lähmt.

## Ergebnis

Stand: Umgesetzt in `src/manager/StubManager.ahk`, `src/manager/StubGui.ahk`, Test `tests/e2e/test_ui_stub.py`. Gesamtlauf `python -m pytest tests -q`: `401 passed, 1 skipped in 174.34s`, Exit 0 (letzter Lauf). Der Skip ist der bestehende AHK-seitige Skip in `tests/test_ahk_runner.py`. Vor dem letzten Lauf war der Gesamtlauf zweimal rot (siehe F-03 und F-04), beide Male im Stub-Test; einzelne Läufe der Stub-Tests unter Parallellast wurden bis 6 von 6 grün. WI-13 ist **nicht** abgehakt: Akzeptanzkriterium 2 ist nur teilweise erfüllt (siehe Tabelle) und die GUI-Bedienung ist nicht geprüft.

**Umgesetzt**
- Rolle `manager` mit `--ui=stub` (ohne `--ui` Exit 3). Registrierung im Einstieg, nicht in `core/` (siehe Abweichungen).
- Abonnements `engine`, `process`, `log`, nach dem Snapshot `flow:<id>` je Flow. Snapshot `cmd.engine.snapshot` nach Ereignis (Liste, `epoch`, Lücke in `seq`, veraltete Antwort wird wiederholt).
- `--headless`: keine Oberfläche, Befehlsschnittstelle `cmd.test.command` (nur Flow-Befehle und Snapshot, Antwort über `Deferred`).
- GUI (`StubGui`): ListView Flows, ListView Elemente des gewählten Flows, Schaltflächen Start, Stop, Beenden, Statuszeile (Verbindung, `epoch`, `seq`, Ereignisse, Resync, letzte Befehlslatenz). Nicht modal, kein MsgBox. Zeichnen per Timer, 20 Hz, nur bei Änderung.
- `cmd.app.prepareExit` wird mit `{ok, cancel}` beantwortet, `cancel` 1 mit `--stub-cancel-exit`.
- `sys.shutdown`: Fenster schließen, `sys.bye`, Exit 0.

**Akzeptanzkriterien**

| Kriterium | Ergebnis | Beleg |
|---|---|---|
| Headless: Skeleton-Ereignisse vollständig und in Reihenfolge im Log | erfüllt (Abweichung: Ablage in `Log/Log_manager.txt`, siehe unten) | `test_headless_stub_logs_every_skeleton_event_in_order`, 10 Ereignisse, Reihenfolge identisch mit Beobachter, Latenz Befehl bis Eingang im Stub 2 bis 4 ms für die ersten Ereignisse, 223 bis 226 ms nach dem 200-ms-Sleep-Element |
| Engine-Kill und Neustart: Log enthält `evt.engine.restarted` und neuen Snapshot, Stub nicht neu gestartet erfüllt: neuer Snapshot mit neuer `epoch`, `evt.process.restarted` (engine) und `evt.engine.restarted` mit der neuen `epoch` (F-01 behoben, Commit 111fde0) | `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` (Stub-PID unverändert, `restarts` 0) |
| GUI manuell prüfbar | **offen**: Smoke-Lauf erfüllt (Fenster öffnet, Supervisor antwortet, kein Dialog, `cmd.app.exit` gibt Exit 0). Klicks Start/Stop und Bedienbarkeit nicht geprüft | Smoke-Lauf (Skript im Scratchpad, nicht versioniert), Anleitung unten |
| Stub blockiert nie auf Anfragen | erfüllt | `test_stub_answers_at_once_while_the_engine_is_missing`: Antwort auf Befehl ohne Engine (`not_found`) und `sys.ping` je unter 2 s |

Zusätzlich: `test_cancelled_exit_is_answered_and_nothing_stops` (Abbruch durch Stub, Engine und Storage laufen weiter), `test_exit_without_cancel_ends_the_stub_cleanly` (Exit 0, `stub.shutdown`).

**Abweichungen (begründet)**
- `ui_events.log` entfällt. Der Stub schreibt keine Datei (Auftrag: nur über `storage`). Ereignisse laufen als `evt.log.append` (Quelle `manager`) nach `Log/Log_manager.txt`, Zeilen `ui-event {json}`. Eigene Zeilen des Stubs: `stub.*`.
- Die Registrierung von `manager` steht im Einstieg. `src/core/RoleRegistry.ahk` verliert die Platzhalter-Zeile `manager` (wie `engine` und `storage` in früheren Paketen). Ohne diese Änderung wirft die Registrierung im Einstieg einen Doppelfehler. Das ist eine Änderung in `core/`, ohne vorherige Absprache, im Commit begründet.
- Der Supervisor gibt `--ui`, `--headless` und `--stub-cancel-exit` an alle Rollen weiter (`src/supervisor/Supervisor.ahk`, `Children.ahk`). Das ist eine Erweiterung von WI-07, damit der Start über den Supervisor mit `--ui=stub` möglich ist.
- (erledigt, F-01) Die Engine sendet `evt.engine.restarted` jetzt selbst.

**Gemessen**
- Ankunftszeit (Befehl im Stub bis Ereignis im Stub, Wandzeit): erster Lauf 2 bis 4 ms für `evt.instance.started` und die ersten Elementzustände, 223 bis 226 ms für die Ereignisse nach dem 200-ms-Sleep. Lauf 2 ähnlich (4 bis 16 ms, dann 224 bis 227 ms). Gemessen mit `GetSystemTimePreciseAsFileTime`. Die Python-Seite ist nicht enthalten.

**Funde (zum Zusammenspiel, Entscheidung offen)**
- F-01 (**behoben**, Commit 111fde0 `WI-10: engine announces its restart ...`): Die Engine sendete `evt.engine.restarted` nicht. Ursache (verifiziert): Der Code dafür fehlte, und ein neuer Engine-Prozess kann Start und Neustart nicht unterscheiden. Behebung: Der Supervisor hängt bei einem automatischen Neustart `--restarted=<n>` an, die Engine sendet das Ereignis (sie besitzt die `epoch`) nach dem Laden der Flows vor `evt.engine.ready`. Test: `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` (Assertion auf das Ereignis und die neue `epoch`; ohne die Engine-Änderung rot). Der Stub folgt weiter zusätzlich den Signalen `evt.process.restarted`, `evt.engine.ready` und neuer `epoch`. Die Datei `work_items/phase2/findings.md` wurde nicht angelegt (Schreibregel für Berichtsdateien), die Funde stehen hier.
- F-02: Im ersten Gesamtlauf schlugen zwei Supervisor-Tests mit "Pipe nicht verfügbar nach 2,0 s" fehl (`test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process`, `test_slow_child_is_waited_for_and_not_terminated`). Einzeln bestanden beide in 3,5 s. Vermutung: Last durch parallel laufende Tests und der größere Einstieg (mehr Klassen zu laden). Nicht geprüft, ob das Parsen des Einstiegs den Start messbar verlängert.
- F-03 (eigener Fehler im Test, behoben): Der Test startete den Flow, bevor die Engine die Flow-Datei geladen hatte. `sys.hello` kommt vor dem Laden, das Ereignis `evt.engine.ready` danach. Behoben: Fixture wartet auf den Flow im Snapshot, Start prüft die Antwort der Engine.
- F-04 (**behoben**, Commit 1adb088 `WI-12: retry log writes ...`, siehe `WI-12-storage.md` und `doc/HOW-TO.md`; Tests `test_no_log_line_is_lost_while_other_processes_hold_the_files`, `test_a_log_line_that_cannot_be_written_is_reported_in_the_own_log`; Ursache verifiziert: `FileAppend` öffnet ohne Freigabe und scheitert mit Fehler 32, sobald ein anderer Prozess die Datei offen hat; die Fehlernummer 6 ließ sich nicht erneut erzeugen). Ursprünglicher Fund: Storage verliert Log-Zeilen, wenn ein anderer Prozess die Datei gleichzeitig offen hat. Beleg: `Log.txt` im Testverzeichnis enthält `storage unexpected OSError: (6) Das Handle ist ungültig. (line 45, Return)`, und die Zeile der zugehörigen Anfrage fehlt. Auslöser im Test: Python las `Log_manager.txt` während des Laufs. Der Test liest die Datei daher jetzt nur noch nach dem Ende des Supervisors und beobachtet während des Laufs das Topic `log` (Storage leitet erst nach dem Schreiben weiter). Im Betrieb kann ein Editor oder Virenscanner denselben Fehler auslösen. Vorschlag: Schreibversuch mit kurzer Wiederholung bei gesperrter Datei in `LogSink.Append`, und `_RotateIfBig` ebenso. Umgesetzt wie vorgeschlagen, mit Wiederholung per Timer in der Schreibwarteschlange.
- Korrigierte Hypothese: Zuerst wurde vermutet, dass das Senden aus dem Frame-Handler (Logzeile je Ereignis) Ereignisse verliert (Wiedereintritt im Peer). Das Umstellen auf eine Warteschlange mit Timer hat den Verlust nicht behoben, die Ursache war F-04. Die Warteschlange bleibt als Vorsicht, nicht als belegte Maßnahme.

**Testanleitung GUI (manuell, nicht automatisiert)**
1. `python tools/ahkrun.py --timeout 300 src/AutoHotFlow.ahk --session=gui1 --data=<leerer Ordner> --start=storage,engine,manager --ui=stub` in einem zweiten Terminal, nicht mit `--headless`. Vorher `Flows\skeleton.json` in den Datenordner kopieren (`tests/data/skeleton_flow.json`).
2. Fenster prüfen: Liste zeigt `skeleton`, Statuszeile zeigt Verbindung `ready`, `epoch` und `seq`.
3. `skeleton` anklicken, dann Start: die Elementliste zeigt Zustände `running` und `finished` für drei Elemente, Statuszeile zeigt eine Befehlslatenz.
4. Während eines Laufs das Fenster verschieben und Start mehrfach klicken: das Fenster bleibt bedienbar.
5. Beenden: Der Prozess endet mit Exit 0.
6. Kein Dialog (Fenster `#32770`) erscheint. Der Dialogwächter würde ihn unter `%TEMP%\ahf_dialogs\` ablegen.

**Nicht geprüft / offen**
- GUI-Klicks (Schritte 3 bis 4 oben) und Darstellung der Umlaute (Beschriftungen bewusst ASCII).
- Engine-Neustart während laufender Instanz: Die Instanzen sind verloren (MIGRATION), nicht getestet.
- (erledigt) Abnahme 2 ist mit F-01 erfüllt.
