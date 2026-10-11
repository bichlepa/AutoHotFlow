# WI-18 Testlaufzeit: parallele Ausführung

Größe: S · Hängt ab von: – · Blockiert: alle weiteren (spart Zeit)

## Ziel

Der Standardlauf `python -m pytest tests -q` dauert 346 s (2026-10-11, 431 Tests, seriell) und wächst mit jedem Paket. Ziel: deutlich kürzer durch parallele Ausführung, **ohne** neue sporadische Fehler.

## Hintergrund

- Die Tests sind für Parallelität vorbereitet (`doc/TESTSTRATEGIE.md` 1.4): `session_id` ist eine UUID (`tests/conftest.py`), jedes Datenverzeichnis ist eigen (`datadir`), Pipe-Namen enthalten die Sitzung.
- Risiken, die zu prüfen sind:
  - Zeitkritische Tests: Fault-Tests (Fristen 1 bis 8 s), Latenz- und Idle-CPU-Messungen, Speicherprüfungen (`num_handles`, RSS). Unter paralleler Last können Fristen reißen oder Messwerte verfälscht werden.
  - Gemeinsame Ressourcen: Dialog-Wächter schreibt nach `%TEMP%\ahf_dialogs\`, mögliche feste Namen (Suche nach `main`, festen Pipe- oder Mutex-Namen, festen Dateien in `%TEMP%`), Tests, die "alle AutoHotkey-Prozesse" zählen.
  - Prozessaufräumen (`procs`-Fixture) muss pro Worker-Prozess von pytest funktionieren.
- Es laufen fremde AutoHotkey-Prozesse des Projektinhabers. Nie nach Namen beenden (siehe `work_items/HANDOVER.md`).

## Aufgaben

1. Ausgangsmessung: `python -m pytest tests -q --durations=40` (Ausgabe in eine Datei, im Hintergrund). Die 40 langsamsten Tests notieren.
2. `pytest-xdist` in `tests/requirements.txt` aufnehmen und installieren.
3. Gemeinsame Ressourcen prüfen (Liste oben) und beheben, wo nötig (eindeutige Namen je Test, keine globalen Zählungen von Prozessen).
4. Zeitkritische Tests markieren und gruppieren, sodass sie nicht parallel zu Last laufen. Vorschlag: Marker `serial` plus `xdist_group` und `--dist loadgroup`, oder eine eigene Gruppe, die am Ende allein läuft. Messungen (`test_measurements.py`, Idle-CPU) dürfen nie parallel laufen. Stress und Soak bleiben wie bisher nur mit `-m`.
5. Die 10 langsamsten Tests ansehen: Wo ein festes Warten (`time.sleep`) durch Warten auf ein Ereignis mit Frist ersetzt werden kann, ersetzen. Fristen in Assertions nicht stillschweigend lockern; jede Änderung einer Frist im Commit begründen.
6. Den Aufruf festlegen (z. B. `python -m pytest tests -q -n auto --dist loadgroup`) und dokumentieren: `AGENTS.md` (Werkzeuge), `doc/TESTSTRATEGIE.md` Abschnitt 6, `work_items/HANDOVER.md`. Ob `-n` per `addopts` Standard wird, entscheidet das Paket (begründen; ein serieller Lauf muss weiter möglich sein, z. B. `-n 0`).
7. Stabilität: 5 parallele Gesamtläufe hintereinander, alle grün. Danach ein serieller Gesamtlauf grün. Nach jedem Lauf prüfen, dass keine von den Tests gestarteten AutoHotkey-Prozesse übrig sind (nur ansehen, `Get-CimInstance Win32_Process`).

## Akzeptanzkriterien

- Paralleler Standardlauf höchstens 40 % der seriellen Dauer auf diesem Rechner (Ziel unter 140 s), Zahl der Tests unverändert.
- 5 von 5 parallelen Läufen grün, 1 serieller Lauf grün.
- Keine übrig gebliebenen Testprozesse.
- Dokumentation angepasst.

## Nicht Teil

Neue Testfälle. Umbau der Stresstests.

## Hinweise

- `doc/HOW-TO.md` enthält Einträge zu Testprozessen, Ausgaben in Dateien und dem Dialog-Wächter. Neue Erkenntnisse zu xdist dort ergänzen.
- Die Anzahl der logischen CPUs ist 8. Mehr als 8 Worker bringen bei AHK-Prozessen wahrscheinlich nichts.
