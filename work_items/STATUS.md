# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-10. Branch `v2-port`, letzter Commit `befe8cc`. Arbeitsbaum sauber.
Aktuelle Phase: **Phase 2 (Walking Skeleton), 7 von 17 Paketen fertig.** Nächstes Paket WI-07 (Supervisor) wartet auf Freigabe des Projektinhabers.

Detailliertes Handover: `work_items/HANDOVER.md`.

## Erledigt

- **Phase 0:** Bestandsaufnahme in `work_items/ANALYSE.md`, Lock-Audit in `work_items/analysis_v1/`.
- **Phase 1:** Architektur in `doc/` (ARCHITEKTUR, PROTOKOLL, ELEMENT-API-V2, TESTSTRATEGIE, KONVENTIONEN, MIGRATION, HOW-TO).
- **Spike:** Named Pipe + Weckruf in AHK v2 (`work_items/spikes/`).
- **Repo-Umbau:** v1 unverändert in `v1/`, Arbeitsdokumente in `work_items/`.
- **Werkzeuge:** `tools/ahkrun.py` und Dialog-Wächter (keine hängenden Läufe mehr durch Fehlerdialoge).

### Phase-2-Pakete

| Paket | Commit | Stand |
|---|---|---|
| WI-01 Testinfrastruktur | `400728e` | fertig |
| Dialog-Wächter, `ahkrun.py` | `d502043`, `62fd573` | fertig |
| WI-03 Core-Basics | `410aa91` | fertig |
| WI-02 JSON | `16a6539` | fertig, Parsen 1,5 s (Ziel 1 s, kein hartes Gate) |
| WI-04 Pipe-Schicht | `5c997e1`, `e62ed65` | fertig, Race bei 16-MiB-Rahmen behoben |
| WI-08 Engine-Kern | `888dd6d` | fertig |
| WI-09 Element-Basis | `d11afa1` | fertig |
| WI-05 Nachrichtenschicht | `7888b9c` | fertig, 299 grün |
| WI-06 Rollenbasis | `c34e57a` | fertig, 308 grün |

### Offen in Phase 2

WI-07 Supervisor (nicht begonnen), WI-10 Engine-Rolle, WI-11 Worker, WI-12 Storage, WI-13 UI-Stub, WI-14 Triggerhost (optional), WI-15 Fault-Injection, WI-16 Stresstest, WI-17 Abschluss.

## Letzter Gesamtlauf

`python -m pytest tests -q`: **308 passed, 1 skipped** (Stand nach WI-06, Laufzeit rund 71 s). Der Skip ist ein bewusster Test in `test_ahk_runner.py`.

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

## Bekannte Probleme

### Aus v1 (werden durch den Port gegenstandslos, nicht gefixt)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Kurz: Dialoge, Datei-I/O und Element-Code unter Lock, `throw` ohne Lock-Freigabe, `x_enabled` statt `x_finish` in 6 Elementen, unquotiertes `callback`, undefinierte `instance`, `currentlyLoadingFlow` ohne Reset, nicht lauffähige Testsuite. Verhaltensänderungen stehen in `doc/MIGRATION.md` (M-01 bis M-14).

### Im Port offen

- **Fremder Prozess:** `AutoHotkey64.exe` PID 29328 (`/restart /script …\src\AutoHotFlow.ahk`), Elternprozess existiert nicht. Nicht von den Tests gestartet, nicht beendet. Vom Projektinhaber prüfen.
- **Fortschrittshaken** in `work_items/phase2/README.md` fehlen für WI-03 und WI-06.
- **Doppelte Überschrift** „Prozesse, Pipes, Nachrichten“ in `doc/HOW-TO.md`.
- **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: einmal Timeout, Ursache (ctypes-argtypes) behoben, Status vermutet.
- **RoleRegistry.ahk** enthält zwei Klassen, Verletzung „eine Klasse pro Datei“.
- **EchoRole.ahk** ist im Produkteinstieg eingebunden, vor WI-17 entscheiden.
- **`deadlineMs`** von `sys.shutdown` wird noch nicht erzwungen (WI-10).
- **`tests/support/pyhub.py`** sendet keinen Weckruf (Tests nutzen `WakingHub`), Vorschlag für WI-07.
- **Storage (WI-12):** CRLF-Entscheidung (v1-Dateien CRLF, Ausgabe bisher LF), Backup-Verhalten laut M-07 neu umsetzen.
- **Richtlinie `stop` (WI-08):** Frist 2 s laut Architektur, v1 ohne Frist. Umsetzung in WI-10.
- **Dangling-Verbindungen:** 154 von 1039 in den Beispielflows. Ob das Laden warnen soll, ist offen.
- **Test-Laufzeit** über 70 s, wächst mit jedem Paket.

### Nicht geprüft

Timing unter Systemlast, AHK 32 Bit, Screenshots bei gesperrtem Desktop, Editor-Zeichnen (Phase 3).

## Nächste Schritte

1. Freigabe des Projektinhabers für WI-07 (Supervisor) abwarten.
2. Danach WI-10 bis WI-17, jeweils ein Paket, ein Commit, `doc/HOW-TO.md` am Ende der Phase mit committen.
3. `work_items/` und `v1/` nach der Portierung entfernen (Entscheidung des Projektinhabers).
