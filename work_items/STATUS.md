# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-11 (nach WI-20). Branch `v2-port`. Stand des Codes: Commit `4a2a6e4` (WI-19). Seit `604a4a9` haben WI-18 (Parallelität, Supervisor-Reihenfolge) und WI-19 (Architekturwächter) Code geändert, WI-20 ist reine Dokumentation.
Aktuelle Phase: **Phase 2b (Härtung vor Phase 3)**, Plan und Pakete in `work_items/phase2b/README.md`. Erledigt: WI-18, WI-19, WI-20. Phase 3 ist nicht begonnen und braucht die Freigabe des Projektinhabers.

Vorher: **Phase 2 (Walking Skeleton) technisch abgeschlossen, 15 von 17 Paketen fertig.** Offen: WI-13 nur wegen der manuellen GUI-Prüfung, WI-14 (optional) nicht gebaut. WI-17 ist bis Schritt 5 erledigt; der Phase-3-Plan (`work_items/phase3/README.md`) und die Fragenliste an den Projektinhaber (WI-17 Schritte 6 und 7) fehlen noch.

Detailliertes Handover: `work_items/HANDOVER.md`.

## Erledigt

- **Phase 0:** Bestandsaufnahme in `work_items/ANALYSE.md`, Lock-Audit in `work_items/analysis_v1/`.
- **Phase 1:** Architektur in `doc/` (ARCHITEKTUR, PROTOKOLL, ELEMENT-API-V2, TESTSTRATEGIE, KONVENTIONEN, MIGRATION, HOW-TO).
- **Spike:** Named Pipe + Weckruf in AHK v2 (`work_items/spikes/`).
- **Repo-Umbau:** v1 unverändert in `v1/`, Arbeitsdokumente in `work_items/`.
- **Werkzeuge:** `tools/ahkrun.py` und Dialog-Wächter (keine hängenden Läufe durch Fehlerdialoge).

### Phase-2-Pakete

| Paket | Stand | Wichtigste Commits |
|---|---|---|
| WI-01 Testinfrastruktur | fertig | `400728e` |
| Dialog-Wächter, `ahkrun.py` | fertig | `d502043`, `62fd573` |
| WI-02 JSON | fertig, Parsen 1,5 s (Ziel 1 s, kein hartes Gate) | `16a6539` |
| WI-03 Core-Basics | fertig | `410aa91` |
| WI-04 Pipe-Schicht | fertig | `5c997e1`, `e62ed65` |
| WI-05 Nachrichtenschicht | fertig | `7888b9c` |
| WI-06 Rollenbasis | fertig | `c34e57a`, F-05-Fix `f7a728e` |
| WI-07 Supervisor | fertig | `6bcb290`, `2bc8424` |
| WI-08 Engine-Kern | fertig | `888dd6d` |
| WI-09 Element-Basis | fertig | `d11afa1` |
| WI-10 Engine-Rolle | fertig | `5825344`, F-01 `111fde0` |
| WI-11 Worker | fertig | `a28ee3a`, `1086e2e` |
| WI-12 Storage | fertig | `be3d79f`, F-04 `1adb088` |
| WI-13 UI-Stub | **Automatisierte Abnahme erfüllt, GUI-Bedienung nicht geprüft (Klicks Start/Stop, Verschieben des Fensters)** | `9aa9537`, `d953843` |
| WI-14 Triggerhost | **nicht gebaut** (optional). Rolle `triggerhost` ist ein Platzhalter | – |
| WI-15 Fault-Injection | fertig, 20 Wiederholungen ohne Hänger | `fd0b927` bis `4042f45` |
| WI-16 Stress und Messung | fertig; Editor-Zielgrößen nicht messbar | `83dd463` bis `604a4a9` |
| WI-17 Abschluss | Schritte 1 bis 5 erledigt, 6 und 7 offen | siehe unten |

### Phase-2b-Pakete (`work_items/phase2b/README.md`)

| Paket | Stand | Commit |
|---|---|---|
| WI-18 Testlaufzeit: parallele Ausführung | fertig | `a6711c5` |
| WI-19 Architekturwächter | fertig | `4a2a6e4` |
| WI-20 Entscheidungen und Beobachtungsliste | fertig (dieser Stand) | Commit mit WI-20 im Betreff |
| WI-21 bis WI-29 | offen, in dieser Reihenfolge | – |

### Abnahme der Phase 2 (`work_items/phase2/README.md`)

| # | Kriterium | Stand | Beleg (Test) |
|---|---|---|---|
| 1 | Supervisor, Storage, Engine, UI-Stub starten, sprechen über den Hub, fahren sauber herunter (Quittungen, harte Frist) | erfüllt | `test_supervisor.py::test_required_roles_are_ready_within_3_seconds`, `::test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process`, `::test_frozen_child_at_exit_is_terminated_at_the_deadline`, `tests/fault/test_shutdown.py` |
| 2 | Hartcodierter Flow im v1-Format (Trigger → Action → Action) läuft in der Engine, jede Zustandsänderung kommt beim UI-Stub an | erfüllt | `test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_ui_stub.py::test_headless_stub_logs_every_skeleton_event_in_order` (Daten `tests/data/skeleton_flow.json`) |
| 3 | Absturz und Einfrieren je eines Prozesses sowie ein Timeout: nichts hängt, jedes Szenario endet binnen Frist mit gemeldetem Fehler | erfüllt | `tests/fault/test_process_crash.py`, `test_process_hang.py`, `test_timeouts.py`, `test_orphans.py`, `test_pipe_break.py`, `test_storage_abort.py`; 20 Wiederholungen (382 Tests, 2 rot wegen Testfehler/F-06, danach 80 von 80 grün) |
| 4 | Stresstest (viele parallele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden/trennen) ohne Hänger | erfüllt | `tests/stress/` (`test_parallel_instances.py`, `test_start_stop_storm.py`, `test_clients_churn.py`, `test_soak.py`); Messwerte in `work_items/phase2/measurements.md` |

Einschränkung zu 3: Der Absturzfall des Triggerhosts fehlt (nicht gebaut), UI-Abstürze sind nur für den Manager-Stub geprüft, nicht für einen Editor.

## Letzter Gesamtlauf

Seit WI-18 läuft der Standardlauf parallel (`pytest.ini`, `-n auto`). Letzter Lauf im WI-19-Abschluss (Code-Stand `4a2a6e4`): `python -m pytest tests -q` **458 passed, 1 skipped in 48,4 s** (WI-18: seriell 333 s, parallel 47 bis 50 s; Details in `work_items/phase2b/WI-18-testlaufzeit.md`).

Vorher, im WI-17-Abschluss (Code-Stand `604a4a9`): `python -m pytest tests -q`: **431 passed, 1 skipped, 11 deselected in 345,60 s**, Exit 0. Der Skip ist der bewusste Test in `tests/test_ahk_runner.py`; die 11 deselected sind die Stress- und Soak-Tests (laufen nur mit `-m stress` bzw. `-m soak`). Danach waren keine von den Tests gestarteten AutoHotkey-Prozesse übrig (nur angesehen). Der Prozess PID 29328 aus früheren Berichten existierte nicht mehr; es liefen noch `AutoHotkeyU32.exe` (Allgemeine Hilfe.ahk) und das v1-`AutoHotFlow.exe` des Projektinhabers.

Stress (`python -m pytest tests -m stress -q`, laut `WI-16-stress.md`, vor dem F-07-Fix): 9 passed, 1 failed (F-07). Nach dem Fix laut WI-16-Bericht der Churn-Test grün; ein vollständiger Stresslauf nach dem Fix ist in diesem Abschluss **nicht** wiederholt worden. Dauerlauf 600 s: ein Lauf grün (WI-16).

## Messwerte (Zusammenfassung, Details in `work_items/phase2/measurements.md`, ein Rechner, der nebenbei lief)

| Zielgröße (ARCHITEKTUR 9) | Ergebnis |
|---|---|
| Latenz `cmd.engine.snapshot`, Leerlauf / unter Last | Median 1,44 / 1,51 ms, p99 1,9 / 12,6 ms: erfüllt (Client weckt den Hub; ohne Weckruf 226 ms) |
| Idle-CPU ohne Flow | 0,23 % des Gesamtsystems (8 CPUs): erfüllt; als Summe in Prozent eines Kerns 1,8 %: **verfehlt**, Lesart des Ziels offen |
| Start bis `ready` | Median 0,30 s (Ziel 3 s): erfüllt |
| Speicher bei 5 offenen Editoren, Zustandsänderung bis Neuzeichnen | **nicht gemessen** (keine Editor-Rolle). Kette ohne Editor: 68,3 MB |

## Entscheidungen

Aus der Freigabe des Projektinhabers:
1. Mehrere Prozesse, ein Editor-Prozess pro Flow. Begründung in `doc/ARCHITEKTUR.md` 2.1.
2. Zeichnen im Editor-Prozess hinter `Renderer`-Schnittstelle, später trennbar. Risiko nicht gemessen, Messung in Phase 3.
3. Worker-Prozesse für blockierende und AHK-Skript-Elemente.
4. Zielversion AHK v2.
5. Alte Flows und Variablen müssen unverändert laden.
6. Eigener Branch `v2-port`, temporärer `v1/`-Ordner.
7. Chrome-Paket entfällt.
8. Tests mit pytest (e2e, Fault Injection, Stress) plus AHK-Unit-Tests.
9. Direkter Port, kein v1-Fix-Branch.

## Entscheidungen Phase 2b (2026-10-11, verbindlich)

Vollständiger Wortlaut mit Begründung in `work_items/phase2b/README.md`. Die Beschreibung steht je Entscheidung an genau einer Stelle in `doc/`, die übrigen Stellen verweisen darauf.

| # | Entscheidung | Beschrieben in | Wirkt in |
|---|---|---|---|
| E1 | Ändern während der Ausführung ist erlaubt. Die Engine nutzt die neueste committete Revision. Debugger-Anforderungen dürfen nicht verbaut werden | `doc/ARCHITEKTUR.md` 4.2 (Semantiktabelle), 4.3 (Ausblick Debugger) | WI-20, WI-21 |
| E2 | Ausführungsrichtlinie `wait` wird umgesetzt | `doc/MIGRATION.md` M-11 | WI-21 |
| E3 | Worker-Pool: Supervisor startet und beendet Worker auf Anfrage der Engine, Worker im Job ohne Ping-Prüfung, Fristen hält die Engine | `doc/ARCHITEKTUR.md` 2.3 | WI-27 |
| E4 | Nur 64 Bit, 32 Bit wird beim Start abgewiesen | `doc/ARCHITEKTUR.md` Kopf | WI-20, WI-22 |
| E5 | Idle-CPU-Ziel gilt für das Gesamtsystem, erfüllt (0,23 %) | `doc/ARCHITEKTUR.md` 9 | – |
| E6 | Triggerhost (WI-14) wird früh in Phase 3 gebaut, nicht in Phase 2b | `doc/ARCHITEKTUR.md` 8 | Phase 3 |
| E7 | Bewusst zurückgestellte Punkte stehen in der Beobachtungsliste (unten) | dieser Abschnitt | – |
| E8 | JSON-Wahrheitswerte als echte Booleans. Das Flow-Schreibformat bleibt in Phase 2b unverändert, Format-Wechsel erst in Phase 3 | `doc/ARCHITEKTUR.md` 7 | WI-26 |

## Beobachtungsliste (E7)

Punkte, die bewusst nicht in Phase 2b behoben werden. Je Punkt: was, warum zurückgestellt, woran man erkennt, dass er wichtig wird, was dann zu tun ist.

- **F-02, Pipe beim Start unter Last nicht nach 2 s verfügbar.** Im ersten Gesamtlauf der Phase 2 zwei Supervisor-Tests, Ursache vermutet (Last des Testrechners), nicht nachgewiesen. Seitdem nicht wieder berichtet; im WI-18-Endstand (5 parallele Gesamtläufe mit 8 Workern) kein Fall. *Warum zurückgestellt:* ohne Reproduktion keine belastbare Ursache. *Erkennen:* die Meldung „Pipe nicht verfügbar nach 2,0 s“ in einem Gesamtlauf, vor allem bei parallelen Läufen. *Tun:* Lauf wiederholen und das Supervisor-Log des Tests ansehen (Hilfe: `AHF_TEST_KEEP=1`, wie in WI-18 beschrieben), Ursache festhalten, dann Fix oder Entwarnung in dieser Datei.
- **`deadlineMs` von `sys.shutdown` wird nicht überall ausgewertet.** Verifiziert: `Storage.OnShutdown` nutzt die Frist (`src/storage/Storage.ahk:62`, Warteschlange leeren bis Frist minus Puffer). `Engine.OnShutdown` (`src/engine/Engine.ahk:76`) und `StubManager.OnShutdown` (`src/manager/StubManager.ahk:99`) werten sie nicht aus. Die harte Frist erzwingt der Supervisor (`test_frozen_child_at_exit_is_terminated_at_the_deadline`). *Warum zurückgestellt:* die harte Frist reicht heute. *Erkennen:* eine Rolle braucht für Aufräumarbeit mehr Zeit, als die Frist lässt, und der Supervisor beendet sie hart, z. B. die Engine beim Stoppen vieler Instanzen. *Tun:* in `Engine.OnShutdown` eine Teilfrist je Instanz (2 s, ARCHITEKTUR 6.3) aus `deadlineMs` ableiten.
- **`tests/support/pyhub.py` ohne Weckruf.** `PyHub` antwortet nur per Abfrage (Fallback-Timer, Latenz rund 250 ms). Verifiziert: Nur `tests/support/test_client_hub.py` nutzt `PyHub`, alle anderen Tests nutzen `WakingHub`. *Warum zurückgestellt:* reines Testwerkzeug. *Erkennen:* ein neuer zeitkritischer Test nutzt `PyHub` und scheitert an einer Frist. *Tun:* auf `WakingHub` umstellen oder dort den Weckruf nachrüsten (ARCHITEKTUR 2.2).
- **Idle-CPU optimieren.** Ziel erfüllt (E5, 0,23 % des Gesamtsystems). Möglich wäre, den Sicherheitstimer der Engine (`src/engine/Engine.ahk:33`, `SAFETY_MS = 100`) nur bei laufenden Instanzen aktiv zu lassen. *Warum zurückgestellt:* kein Muss nach E5. *Erkennen:* Idle-CPU über 1 % im Gesamtsystem bei einer Messung mit Editor in Phase 3. *Tun:* Timer nur bei laufenden Instanzen, dann mit der Messmethode aus WI-16 neu messen.
- **Manuelle GUI-Prüfung des Manager-Stubs.** Die Klicks (Start/Stop, Fensterverschieben) sind nicht geprüft. Der Stub ist Wegwerf-Code, die Abnahme der Phase 2 ist automatisiert erfüllt. *Warum zurückgestellt:* kein Blocker. *Erkennen:* der Stub wird für Vorführungen genutzt oder ein Fehler im Stub blockiert einen Test. *Tun:* Anleitung in `work_items/phase2/WI-13-ui-stub.md` durchgehen, Ergebnis hier und in WI-13 festhalten.
- **Sporadischer Dialog-Test `test_msgbox_is_captured_and_closed`.** Einmal Timeout in Phase 2 (Ursache ctypes-argtypes behoben). In WI-18 scheiterten zwei Dialog-Wächter-Tests unter Parallellast, Ursache vermutet: wiederverwendete Prozess-IDs im Wächter, behoben in `tools/ahf_dialogwatch.py` (nicht einzeln nachgestellt). *Erkennen:* ein Test endet mit Exit 0 statt 97 oder mit Timeout. *Tun:* Dialogbericht in `%TEMP%\ahf_dialogs\` ansehen (Dateiname enthält seit WI-18 die Test-PID), Ursache festhalten.
- **F-05 und F-07 (Änderungen in `src/core/` ohne Absprache).** F-05 (`f7a728e`, Orphan-Guard in `Role.Console`) und F-07 (`4f566bb`, Speicherleck in der Verbindung). Im Review am 2026-10-11 gelesen, ohne Befund. *Offen:* Bestätigung durch den Projektinhaber. *Erkennen:* ein Befund im Review oder ein Test, der Speicher oder stderr betrifft. *Tun:* Bestätigung einholen oder Befund beheben.
- **F-11, Reihenfolge in `Supervisor._Tick` (WI-18): geschlossen in WI-22.** Deterministischer Test `tests/ahk/supervisor_tick.test.ahk` (ungelesenes `sys.bye`, Prozess schon beendet): mit der alten Reihenfolge `clean` falsch, mit `hub.Pump()` vor `children.Tick` wahr. Dass dieser Fehler auch den einmaligen Ausfall in WI-18 verursachte, bleibt vermutet, ist nach 2 x 50 Wiederholungen von `test_shutdown` (kein falsches `clean`) aber sehr wahrscheinlich. Bei erneutem Auftreten von `clean=false` zuerst das Supervisor-Log lesen. Details: "Ergebnis" in `work_items/phase2b/WI-22-supervisor-robustheit.md`.

## Funde (Entscheidung je Fund; eine Datei `findings.md` wurde nie angelegt, die Funde stehen in den Paketdateien)

| Fund | Inhalt | Entscheidung | Beleg |
|---|---|---|---|
| F-01 | Engine sendete `evt.engine.restarted` nicht | behoben | `111fde0`, `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` |
| F-02 | Zwei Supervisor-Tests im ersten Gesamtlauf mit "Pipe nicht verfügbar nach 2,0 s" (Last, größerer Einstieg). Ursache vermutet | bewusst offen, beobachten (Beobachtungsliste, E7). In den dokumentierten späteren Gesamtläufen (427, 431 grün) und im WI-18-Endstand nicht berichtet | `WI-13-ui-stub.md` |
| F-03 | Test startete Flow vor dem Laden (eigener Testfehler) | behoben | `WI-13-ui-stub.md` |
| F-04 | Storage verlor Log-Zeilen, wenn ein anderer Prozess die Datei offen hatte | behoben | `1adb088`, `test_no_log_line_is_lost_while_other_processes_hold_the_files` |
| F-05 | Orphan-Guard beendete vom Supervisor gestartete Rollen nicht (`Console` warf) | behoben | `f7a728e`, `tests/fault/test_orphans.py` (20/20). Änderung in `src/core/` ohne Absprache, bitte prüfen |
| F-06 | `clean` in `evt.process.exited` einmal `false` bei sauberem Ende. Ursache: `_OnGone` vor dem Lesen von `sys.bye` | **behoben** (WI-18 Reihenfolge `Pump` vor `children.Tick`, WI-22 deterministischer Test: alte Reihenfolge `clean=false`, neue `true`; `test_shutdown` 2 x 50 Wiederholungen, `clean` nie falsch) | `WI-15-fault-injection.md`, `phase2b/WI-22-supervisor-robustheit.md` |
| F-07 | Speicherleck 83 KB je Verbindung (Referenzzyklus in `PipeConnection`) | behoben | `4f566bb`, `test_many_connects_keep_the_memory_of_the_supervisor_flat` |
| F-08 | Storage drainierte Log mit rund 30 Zeilen/s, Warteschlange unbegrenzt | behoben in WI-25 (1493 Zeilen/s über 10 s gemessen, Obergrenze 20000 Einträge oder 8 MiB, getrennte Warteschlangen) | `WI-25-storage-durchsatz.md` |
| F-09 | `seq` der Engine-Ereignisse vertauscht bei 200 Instanzen | behoben | `4906f7d` |
| F-10 | Trigger als Aktion ausgeführt (Race zwischen `Advance` und Dispatch-Timer) | behoben; ob `_Dispatch` und das Klonen in `Advance` dasselbe Muster haben, ist nicht geprüft | `887988b` |
| F-25 | Ein von einem anderen Prozess dauerhaft gehaltenes Logfile verliert nach 3 s das ganze Bündel (bis 500 Zeilen) dieser Datei, nicht nur eine Zeile | offen, niedrig (gezählt und im Log vermerkt, F-04 unverändert) | `WI-25-storage-durchsatz.md` |

## Bekannte Probleme

### Aus v1 (werden durch den Port gegenstandslos, nicht gefixt)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Verhaltensänderungen stehen in `doc/MIGRATION.md` (M-01 bis M-16).

### Im Port offen

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328 (`/restart /script …\src\AutoHotFlow.ahk`) wurde in früheren Berichten gemeldet; am 2026-10-11 nach dem Gesamtlauf nicht mehr vorhanden. Nie von den Tests gestartet oder beendet.
- **Fortschrittshaken** in `work_items/phase2/README.md`: im Abschluss gesetzt, WI-13 und WI-14 bewusst nicht (WI-17 erst nach Schritt 7).
- **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: einmal Timeout, Ursache (ctypes-argtypes) behoben, Status vermutet.
- **`core/RoleRegistry.ahk`** enthält zwei Klassen (`RoleRegistry`, `PlaceholderRole`), Verletzung "eine Klasse pro Datei".
- **Einstieg bindet Testrollen aus `tests/`** ein (`EchoRole` u. a., nur mit `--test-roles` registriert). Abhängigkeit `src/` → `tests/`, vor einem Release auflösen.
- **`deadlineMs`** von `sys.shutdown`: Nur der Storage wertet den Wert aus, Engine und Manager-Stub nicht (siehe Beobachtungsliste). Die Frist erzwingt der Supervisor durch hartes Beenden (`test_frozen_child_at_exit_is_terminated_at_the_deadline`).
- **`tests/support/pyhub.py`** sendet keinen Weckruf (Tests nutzen `WakingHub`, siehe Beobachtungsliste).
- **Storage:** Temp-Dateien (`*.ahf-<pid>.tmp`) nach hartem Kill werden nicht aufgeräumt (nicht geprüft). Pfad "neue Datei" beim Abbruch mitten im Schreiben nie beobachtet.
- **Richtlinie `wait`** ist in der Engine noch nicht umgesetzt (`busy`). M-11 ist bestätigt (E2), Umsetzung in WI-21.
- **Semantik bei Änderungen während der Ausführung:** Engine hält die Definition noch beim Start fest (`Executor._NewRun`). Umsetzung in WI-21 (E1, ARCHITEKTUR 4.2). Abweichungen von v1: M-17, M-18.
- **Löschen eines laufenden Flows:** In v1 wartet `DeleteFlow` höchstens 10 s, danach Abbruch ohne Löschen. Das Verhalten in v2 ist nicht festgelegt (offen, vor Phase 3 entscheiden).
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. M-13 legt fest: ignorieren und mit `f1`-Log melden.
- **Test-Laufzeit:** Der Standardlauf ist seit WI-18 parallel (rund 48 s statt 337 s seriell). Er wächst mit jedem Paket, Grenze und Messung in WI-18.

### Nicht geprüft

Timing unter Systemlast, AHK 32 Bit, Screenshots bei gesperrtem Desktop, Editor-Zeichnen (Phase 3), GUI-Bedienung des Stubs, Dauerlauf mit Verbindungswechseln (`AHF_SOAK_CHURN=1`) nach dem F-07-Fix, Worker-Pool unter Last, Triggerhost (nicht gebaut), AHK-Client (Editor) als Gegenstelle der Latenzmessung.

## Nächste Schritte

1. Phase 2b in der Reihenfolge aus `work_items/phase2b/README.md`: WI-21 (Engine-Korrektheit, nach E1 und E2) als Nächstes, dann WI-22 bis WI-29.
2. Phase 3 braucht die Freigabe des Projektinhabers. Der Phase-3-Plan (`work_items/phase3/README.md`) und die Fragenliste (WI-17 Schritte 6 und 7) sind noch offen.
3. Beobachtungsliste (oben) bei jedem Gesamtlauf im Blick behalten, besonders F-02 und F-11.
4. Projektinhaber: GUI des Stubs einmal von Hand prüfen (Anleitung in `WI-13-ui-stub.md`), danach WI-13 abhaken.
5. `work_items/` und `v1/` erst nach der Portierung entfernen (Entscheidung des Projektinhabers, nicht jetzt).
