# WI-16 Stresstest und Messung

Größe: M · Hängt ab von: WI-15 · Blockiert: WI-17

## Ziel

Zeigen, dass die Race-Condition-Klasse der Vorversion in der neuen Architektur nicht auftritt, und die Leistungsbudgets aus ARCHITEKTUR 9 messen.

## Vorher lesen

`doc/TESTSTRATEGIE.md` 3 (Stresstest), `doc/ARCHITEKTUR.md` 9.

## Zu erstellen (`tests/stress/`)

- `test_parallel_instances.py`: 200 parallele Instanzen des Skeleton-Flows (Ausführungsrichtlinie `parallel`). Alle enden, keine Zustände bleiben `running`, Zähler stimmen.
- `test_start_stop_storm.py`: 1000 Start/Stop-Wechsel eines Flows. Danach konsistent (keine Instanzen, `countRuns` null, kein Leck der Timer).
- `test_clients_churn.py`: 20 Python-Clients verbinden und trennen im Wechsel, während ein Flow läuft. Engine-Antwortlatenz bleibt im Budget.
- `test_soak.py` (`-m soak`): 10 Minuten Dauerlauf mit gemischten Operationen. Prozessanzahl, Handles und Speicher je Prozess am Anfang und Ende vergleichen (Wachstum unter 20 %).
- `tests/support/metrics.py`: Latenzverteilung (Median, p95, p99, max), Speicher/Handles via `psutil`.
- Bericht: `work_items/phase2/measurements.md` (Tabelle je Messung, Rechner und Datum). Die Datei wird von den Tests geschrieben oder vom Agenten manuell nach dem Lauf ergänzt.

## Akzeptanzkriterien

- Alle Tests außer `soak` laufen zehnmal hintereinander ohne Hänger.
- Latenz: Engine-Antwort auf `cmd.engine.snapshot` unter Last: Median unter 5 ms, p99 unter 50 ms. Weicht das ab, steht es mit Ursache im Bericht (kein stilles Lockern der Grenzen).
- Idle-CPU des Gesamtsystems ohne Flow unter 1 % (Messung über 30 s).

## Nicht Teil

Vergleichsmessung mit v1 (die Hänger sind dort nicht reproduzierbar, siehe TESTSTRATEGIE 3).
