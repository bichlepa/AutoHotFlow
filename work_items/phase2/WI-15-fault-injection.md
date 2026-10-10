# WI-15 Fault-Injection-Tests

Größe: M · Hängt ab von: WI-07, WI-10, WI-11, WI-12, WI-13 · Blockiert: WI-16

## Ziel

Die Zusage der Architektur in Tests fassen: Absturz, Hänger, Timeout, Pipe-Bruch führen nie zu einem hängenden Gesamtsystem. Jedes Szenario läuft mehrfach (Wiederholung deckt Zufallsfehler auf).

## Vorher lesen

`doc/TESTSTRATEGIE.md` 3 (Tabelle), `doc/ARCHITEKTUR.md` 6.2, 6.3.

## Zu erstellen (`tests/fault/`)

Pro Zeile der Tabelle in TESTSTRATEGIE 3 ein Test, jeweils mit **voller Kette** (Supervisor, Storage, Engine, Headless-UI-Stub, bei Bedarf Worker):

| Datei | Szenarien |
|---|---|
| `test_process_crash.py` | UI, Worker, Engine, Storage, Triggerhost werden hart beendet. Erwartung: `evt.process.crashed`, Neustart nach Richtlinie, restliche Rollen laufen, laufende Anfragen enden mit `peer_gone`/`timeout`. |
| `test_process_hang.py` | UI, Engine, Storage werden eingefroren (`psutil.Process.suspend()`). Erwartung: als `hung` erkannt, beendet, behandelt wie Absturz, Gesamtsystem reagiert weiter. |
| `test_timeouts.py` | Anfragen an eine eingefrorene Rolle: Aufrufer erhält `timeout` genau einmal, späte Antwort wird verworfen. |
| `test_pipe_break.py` | Client schließt abrupt, Client liest nie (Queue-Überlauf), Hub-Pipe wird beendet. Erwartung: Aufräumen, kein Handle-Leck, kein Hänger. |
| `test_shutdown.py` | Beenden mit gesunden Rollen (unter 2 s), mit einem eingefrorenen Prozess (unter Frist + 1 s), mit `cancel` von der UI in Phase 1, zweimal hintereinander. |
| `test_orphans.py` | Supervisor wird hart beendet. Alle Kinder verschwinden innerhalb von Orphan-Frist + 2 s. |

## Akzeptanzkriterien

- Jedes Szenario läuft 20-mal hintereinander ohne ein einziges Hängen oder Zeitüberschreiten (Zeitlimit pro Szenario 30 s, `pytest-timeout`).
- Nach jedem Test bleibt kein Prozess übrig (Fixture prüft per `psutil`, schlägt den Test sonst fehl).
- Ergebnisprotokoll: Dauer pro Szenario (Median, Maximum) wird in `work_items/phase2/measurements.md` festgehalten (durch WI-16 zusammengeführt).

## Hinweise

- Fehler **im System** (Test findet einen Hänger): nicht den Test lockern. Ein Fund wird als Eintrag in `work_items/phase2/findings.md` dokumentiert (Szenario, Reproduktion, Logs) und dem zuständigen Paket zurückgegeben.
- Eingefrorene Prozesse nach dem Test mit `resume()` oder `kill()` beenden, sonst bleiben sie hängen.
