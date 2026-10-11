# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-11. Branch `v2-port`. Stand des Codes: Commit `604a4a9` (letzte Code-Änderung `4f566bb`, F-07); danach nur Dokumentation (WI-17).
Aktuelle Phase: **Phase 2 (Walking Skeleton) technisch abgeschlossen, 15 von 17 Paketen fertig.** Offen: WI-13 nur wegen der manuellen GUI-Prüfung, WI-14 (optional) nicht gebaut. WI-17 ist bis Schritt 5 erledigt; der Phase-3-Plan (`work_items/phase3/README.md`) und die Fragenliste an den Projektinhaber (WI-17 Schritte 6 und 7) fehlen noch.

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

### Abnahme der Phase 2 (`work_items/phase2/README.md`)

| # | Kriterium | Stand | Beleg (Test) |
|---|---|---|---|
| 1 | Supervisor, Storage, Engine, UI-Stub starten, sprechen über den Hub, fahren sauber herunter (Quittungen, harte Frist) | erfüllt | `test_supervisor.py::test_required_roles_are_ready_within_3_seconds`, `::test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process`, `::test_frozen_child_at_exit_is_terminated_at_the_deadline`, `tests/fault/test_shutdown.py` |
| 2 | Hartcodierter Flow im v1-Format (Trigger → Action → Action) läuft in der Engine, jede Zustandsänderung kommt beim UI-Stub an | erfüllt | `test_engine.py::test_start_emits_the_documented_event_order`, `tests/e2e/test_ui_stub.py::test_headless_stub_logs_every_skeleton_event_in_order` (Daten `tests/data/skeleton_flow.json`) |
| 3 | Absturz und Einfrieren je eines Prozesses sowie ein Timeout: nichts hängt, jedes Szenario endet binnen Frist mit gemeldetem Fehler | erfüllt | `tests/fault/test_process_crash.py`, `test_process_hang.py`, `test_timeouts.py`, `test_orphans.py`, `test_pipe_break.py`, `test_storage_abort.py`; 20 Wiederholungen (382 Tests, 2 rot wegen Testfehler/F-06, danach 80 von 80 grün) |
| 4 | Stresstest (viele parallele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden/trennen) ohne Hänger | erfüllt | `tests/stress/` (`test_parallel_instances.py`, `test_start_stop_storm.py`, `test_clients_churn.py`, `test_soak.py`); Messwerte in `work_items/phase2/measurements.md` |

Einschränkung zu 3: Der Absturzfall des Triggerhosts fehlt (nicht gebaut), UI-Abstürze sind nur für den Manager-Stub geprüft, nicht für einen Editor.

## Letzter Gesamtlauf

`python -m pytest tests -q` am 2026-10-11 im WI-17-Abschluss (Code-Stand `604a4a9`): **431 passed, 1 skipped, 11 deselected in 345,60 s**, Exit 0. Der Skip ist der bewusste Test in `tests/test_ahk_runner.py`; die 11 deselected sind die Stress- und Soak-Tests (laufen nur mit `-m stress` bzw. `-m soak`). Danach waren keine von den Tests gestarteten AutoHotkey-Prozesse übrig (nur angesehen). Der Prozess PID 29328 aus früheren Berichten existierte nicht mehr; es liefen noch `AutoHotkeyU32.exe` (Allgemeine Hilfe.ahk) und das v1-`AutoHotFlow.exe` des Projektinhabers.

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

## Funde (Entscheidung je Fund; eine Datei `findings.md` wurde nie angelegt, die Funde stehen in den Paketdateien)

| Fund | Inhalt | Entscheidung | Beleg |
|---|---|---|---|
| F-01 | Engine sendete `evt.engine.restarted` nicht | behoben | `111fde0`, `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` |
| F-02 | Zwei Supervisor-Tests im ersten Gesamtlauf mit "Pipe nicht verfügbar nach 2,0 s" (Last, größerer Einstieg). Ursache vermutet | bewusst offen, beobachten. In den dokumentierten späteren Gesamtläufen (427, 431 grün) nicht berichtet | `WI-13-ui-stub.md` |
| F-03 | Test startete Flow vor dem Laden (eigener Testfehler) | behoben | `WI-13-ui-stub.md` |
| F-04 | Storage verlor Log-Zeilen, wenn ein anderer Prozess die Datei offen hatte | behoben | `1adb088`, `test_no_log_line_is_lost_while_other_processes_hold_the_files` |
| F-05 | Orphan-Guard beendete vom Supervisor gestartete Rollen nicht (`Console` warf) | behoben | `f7a728e`, `tests/fault/test_orphans.py` (20/20). Änderung in `src/core/` ohne Absprache, bitte prüfen |
| F-06 | `clean` in `evt.process.exited` einmal `false` bei sauberem Ende. Ursache vermutet (`_OnGone` vor dem Lesen von `sys.bye`) | **Phase 3** (Meldung unzuverlässig, Exit-Code und Fristen stimmten) | `WI-15-fault-injection.md` |
| F-07 | Speicherleck 83 KB je Verbindung (Referenzzyklus in `PipeConnection`) | behoben | `4f566bb`, `test_many_connects_keep_the_memory_of_the_supervisor_flat` |
| F-08 | Storage drainiert Log mit rund 30 Zeilen/s, Warteschlange unbegrenzt | **Phase 3** (Obergrenze und Durchsatz festlegen, bevor der echte Manager und Editor Logs erzeugen) | `WI-16-stress.md` |
| F-09 | `seq` der Engine-Ereignisse vertauscht bei 200 Instanzen | behoben | `4906f7d` |
| F-10 | Trigger als Aktion ausgeführt (Race zwischen `Advance` und Dispatch-Timer) | behoben; ob `_Dispatch` und das Klonen in `Advance` dasselbe Muster haben, ist nicht geprüft | `887988b` |

## Bekannte Probleme

### Aus v1 (werden durch den Port gegenstandslos, nicht gefixt)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Verhaltensänderungen stehen in `doc/MIGRATION.md` (M-01 bis M-16).

### Im Port offen

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328 (`/restart /script …\src\AutoHotFlow.ahk`) wurde in früheren Berichten gemeldet; am 2026-10-11 nach dem Gesamtlauf nicht mehr vorhanden. Nie von den Tests gestartet oder beendet.
- **Fortschrittshaken** in `work_items/phase2/README.md`: im Abschluss gesetzt, WI-13 und WI-14 bewusst nicht (WI-17 erst nach Schritt 7).
- **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: einmal Timeout, Ursache (ctypes-argtypes) behoben, Status vermutet.
- **`core/RoleRegistry.ahk`** enthält zwei Klassen (`RoleRegistry`, `PlaceholderRole`), Verletzung "eine Klasse pro Datei".
- **Einstieg bindet Testrollen aus `tests/`** ein (`EchoRole` u. a., nur mit `--test-roles` registriert). Abhängigkeit `src/` → `tests/`, vor einem Release auflösen.
- **`deadlineMs`** von `sys.shutdown`: Die Rollen werten den Wert nicht aus (`Engine.OnShutdown` stoppt nur alle Instanzen). Die Frist erzwingt der Supervisor durch hartes Beenden (`test_frozen_child_at_exit_is_terminated_at_the_deadline`). Ob eine Rolle selbst eine Frist braucht, ist offen.
- **`tests/support/pyhub.py`** sendet keinen Weckruf (Tests nutzen `WakingHub`).
- **Storage:** Temp-Dateien (`*.ahf-<pid>.tmp`) nach hartem Kill werden nicht aufgeräumt (nicht geprüft). Pfad "neue Datei" beim Abbruch mitten im Schreiben nie beobachtet.
- **Richtlinie `wait`** ist in der Engine nicht umgesetzt (`busy`), M-11 vom Projektinhaber nicht ausdrücklich bestätigt.
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. M-13 legt fest: ignorieren und mit `f1`-Log melden.
- **Test-Laufzeit** des Standardlaufs über 5 Minuten (WI-16: 342 s), wächst mit jedem Paket.

### Nicht geprüft

Timing unter Systemlast, AHK 32 Bit, Screenshots bei gesperrtem Desktop, Editor-Zeichnen (Phase 3), GUI-Bedienung des Stubs, Dauerlauf mit Verbindungswechseln (`AHF_SOAK_CHURN=1`) nach dem F-07-Fix, Worker-Pool unter Last, Triggerhost (nicht gebaut), AHK-Client (Editor) als Gegenstelle der Latenzmessung.

## Nächste Schritte

1. WI-17 Schritte 6 und 7: Phase-3-Plan `work_items/phase3/README.md` und gebündelte Fragen an den Projektinhaber (in diesem Lauf bewusst nicht begonnen).
2. Projektinhaber: GUI des Stubs einmal von Hand prüfen (Anleitung in `WI-13-ui-stub.md`), danach WI-13 abhaken.
3. Projektinhaber: Entscheidung zu WI-14 (Triggerhost) und zum Zeitpunkt der Editor-Rolle (siehe Vorschläge im Abschlussbericht).
4. `work_items/` und `v1/` erst nach der Portierung entfernen (Entscheidung des Projektinhabers, nicht jetzt).
