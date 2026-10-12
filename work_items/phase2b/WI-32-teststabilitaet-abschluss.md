# WI-32 Teststabilität und Abschluss des Fix-Blocks

Größe: M · Hängt ab von: WI-30, WI-31, WI-33 · Blockiert: Phase-3-Plan

## Ziel

Der parallele Standardlauf (`python -m pytest tests -q`, rund 2 Minuten) ist ein **verlässliches** Signal: rot heißt Fehler im Produkt oder im Test, nie Zufall. Heute ist er "meist grün", der serielle Lauf dauert rund 10 Minuten. In Phase 3 kommen viele Tests hinzu; ein wackelnder Lauf kostet dann jeden Agenten Zeit und verdeckt echte Fehler.

## Bekannte wackelnde Tests

| Test | Ursache | Quelle |
|---|---|---|
| `tests/integration/test_storage.py::test_engine_starts_with_the_real_storage_and_its_log_arrives` | Der Beobachter abonniert erst nach dem `sys.hello` der Engine und wartet auf `evt.engine.ready`. Ist die Engine schneller, ist das Ereignis schon weg (PROTOKOLL 5a), Fehlschlag nach 15 s. [gelesen] In den Fault-Tests wurde dasselbe Muster in WI-28 behoben (`Chain.wait_flows`, Zustand per Snapshot) | Review-Lauf 2026-10-12, parallel |
| `tests/ahk/storage_queue.test.ahk` "a budget runs many small operations in one go" | Unit-Test misst echte Zeit (Zeitbudget 10 ms); unter Last 159 statt 300 Operationen | Review-Lauf 2026-10-12, parallel |
| Fault- und Supervisor-Tests mit engen Zeitgrenzen (F-19), z. B. `test_role.py::test_shutdown_sends_bye_and_exits_0_within_one_second` (1,158 s bei Grenze 1,0 s) | Zeitbudget unter paralleler Last zu eng | WI-26, WI-22 |
| `clients_churn[smoke]`, `big_flows[smoke]` | zeitempfindlich unter Last | STATUS "Im Port offen" |
| `test_shutdown.py` `clean: false` (F-26) und `test_debug_role.py` Flows nicht geladen (F-31) | sollten nach WI-30 und WI-31 verschwunden sein | STATUS |

## Aufgaben

1. **Muster im ganzen Testbestand suchen und beheben** (nicht nur die Tabelle):
   - Warten auf ein Ereignis, das vor dem Abonnement gekommen sein kann → auf einen Zustand warten (Snapshot, `cmd.process.list`), wie in `Chain.wait_flows`.
   - Echte Zeit in Unit-Tests → Zeitquelle injizierbar machen (z. B. `WriteQueue` mit austauschbarer Uhr) oder die Aussage zeitunabhängig formulieren.
   - Absolute Zeitgrenzen im Standardlauf → Entweder die Aussage ohne enge Grenze prüfen (Reihenfolge, Ergebnis) und die strenge Zeitmessung in eine seriell laufende Gruppe (`xdist_group`, siehe WI-18) bzw. nach `-m stress` verschieben, oder die Grenze mit Begründung anpassen. Nie stillschweigend lockern; jede Änderung im Commit begründen.
2. **Abnahmeläufe**, jeder allein auf dem Rechner, Ergebnisse in `STATUS.md`:
   - 10 parallele Gesamtläufe hintereinander, alle grün. Jeder rote Test wird analysiert und behoben, oder als Fund mit Begründung festgehalten (dann zählt der Lauf nicht).
   - 1 serieller Gesamtlauf grün.
   - `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` grün.
   - `python -m pytest tests -m stress -q` grün.
3. **Abschluss des Fix-Blocks (Dokumente):**
   - `work_items/STATUS.md`: Entscheidungen E9 bis E15 (aus `README.md`, Nachtrag), Funde F-24, F-26, F-31, F-16 mit Ergebnis, neue Funde ab F-32. Beobachtungsliste ergänzen: leeres `--data=` schreibt nach `C:\Log` (E15), Fristen der Rollen nach Standby (WI-33), F-19 falls Reste bleiben.
   - `doc/MIGRATION.md`: Status von M-11, M-17, M-18 auf "bestätigt" (E13); E9 (Löschen ohne Frist) dort oder in `ARCHITEKTUR.md` 4.2 als bestätigt vermerken.
   - `work_items/HANDOVER.md` und `AGENTS.md` (aktueller Stand: Fix-Block abgeschlossen, als Nächstes der Phase-3-Plan mit dem Projektinhaber), offene Entscheidungen aktualisieren (beantwortet sind 1 bis 5 aus dem bisherigen HANDOVER; neu offen: E14 Manager schließen für Phase 3).
   - Fortschrittshaken in `README.md` (Fix-Block).
   - `.vscode/tasks.json` nach Regel 10 in `AGENTS.md` prüfen: Jede neue Option oder jedes neue Werkzeug aus WI-30 bis WI-33, das von Hand nützlich ist, hat einen Task.

## Akzeptanzkriterien

- 10 von 10 parallelen Gesamtläufen grün, serieller Lauf, Fault-Wiederholung und Stress grün.
- Keine Zeitgrenze wurde ohne Begründung gelockert.
- Dokumente wie oben, ein neuer Agent findet über `AGENTS.md` den Stand.

## Nicht Teil

Phase-3-Plan (WI-17 Schritte 6 und 7): den entwirft der Projektinhaber danach mit Claude.
