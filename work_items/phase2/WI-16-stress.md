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

## Ergebnis

Stand: umgesetzt in `tests/stress/` (`stresskit.py` mit Fixture `stress_chain`, `test_parallel_instances.py`, `test_start_stop_storm.py`, `test_clients_churn.py`, `test_measurements.py`, `test_log_backlog.py`, `test_soak.py`) und `tests/support/metrics.py`. Alle Tests laufen gegen die echte Kette (Supervisor, Storage, Engine, Manager-Stub über `tools/ahkrun.py`). Aufruf: `python -m pytest tests -m stress -q` (voller Umfang), `AHF_SOAK_SECONDS=600 python -m pytest tests -m soak -q` (Dauerlauf). Der Standardlauf enthält nur die Smoke-Varianten (`tests/conftest.py` wirft Tests mit den Markern `stress` und `soak` aus der Auswahl, wenn `-m` sie nicht nennt). Messwerte stehen in `work_items/phase2/measurements.md`, Rechner und Last dort.

**Gesamtlauf:** Standard `python -m pytest tests -q`: **431 passed, 1 skipped, 11 deselected in 342 s** (vorher 427 passed in 318 s; neu sind 4 Smoke-Tests, rund +24 s). Stress `python -m pytest tests -m stress -q`: **9 passed, 1 failed in 388 s** (rot: `test_many_connects_keep_the_memory_of_the_supervisor_flat`, F-07). Wiederholung (Abnahme 1): alle Stresstests ausser Dauerlauf, Ereignisflut und Speichertest liefen **10-mal hintereinander** (je 7 Tests, 105 bis 109 s je Durchlauf): 69 von 70 Testläufen grün, **kein Hänger**, ein Ausfall (F-10, danach behoben, 60 von 60 grün). Idle-CPU wurde 5-mal gemessen (der Filter `-k "not memory"` hatte sie in den 10 Läufen ausgeschlossen), die Ereignisflut 2-mal (Gesamtlauf und Einzellauf).

### Pflichtfälle

| Pflichtfall | Test | Ergebnis | Stand |
|---|---|---|---|
| Parallele Instanzen (WI: 200; Auftrag: 20 bis 50) | `test_parallel_instances.py` (10, 50, 200) | 200 Instanzen: alle Starts beantwortet (Fehlerquote 0), alle enden mit `finished` nach 6,8 s (Sleep 6 s), Spitze 200 gleichzeitig, `countRuns` 0, `seq` lückenlos. 60 von 60 Läufen grün nach den Korrekturen F-09/F-10 | erfüllt |
| Schnelle Start/Stop-Folgen (WI: 1000, Auftrag: 500) | `test_start_stop_storm.py` (30, 1000) | 1000 Zyklen mit 1334 Instanzen in 10,5 s (10 Läufe, max 10,9 s): jede Instanz genau ein `started`/`ended`, `seq` lückenlos über 8830 Ereignisse, Zähler 0, Engine-Handles 159 → 159, RSS 17,1 → 17,1 MB, Engine nicht neu gestartet | erfüllt |
| Clients verbinden und trennen (WI: 20 Clients; Auftrag: 100 Wechsel) | `test_clients_churn.py` (3x2, 20x8) | 160 Wechsel durch 20 Clients, Fehler 0, Pids unverändert, Handles Supervisor 186 → 186 und Engine 159 → 159, Snapshot-Latenz währenddessen Median 2,05 ms, p99 9,5 ms | erfüllt für Handles und Pids |
| Keine Leaks beim Verbinden (Speicher) | `test_many_connects_keep_the_memory_of_the_supervisor_flat` | **rot**: RSS des Supervisors 25,2 → 57,8 MB nach 400 Verbindungen (rund 83 KB je Verbindung), Handles flach | **verfehlt (F-07, offen)** |
| Dauerlauf (WI: 10 min, `-m soak`) | `test_soak.py` | 600 s, rund 20 Ereignisse/s (1165 Bursts, 196 Start/Stop, 9816 Snapshots, 299 Umschaltungen): Fehler 0, Pids unverändert, Prozesse 5 → 5, Handles flach (Supervisor 195, Rollen 159), RSS Supervisor 17,88 → 17,86 MB, Engine 17,07 → 17,10, Manager 17,06 → 17,09, Storage 17,14 → 17,21 MB; Snapshot-Latenz im letzten Teil Median 2,5 ms, p99 11,2 ms (max 59,6 ms) | erfüllt (1 Lauf, ohne Verbindungswechsel wegen F-07 und mit begrenzter Rate wegen F-08) |
| Messungen ARCHITEKTUR 9 | `test_measurements.py` | siehe `measurements.md` | siehe Tabelle unten |

### Zielgrössen (ARCHITEKTUR 9)

| Zielgrösse | Ziel | Gemessen (Läufe) | Urteil |
|---|---|---|---|
| Latenz `cmd.engine.snapshot`, Leerlauf | Median < 5 ms, p99 < 50 ms | 10 Läufe zu 2000: Median 1,44 ms, p99 1,9 ms (max 4,9 ms), grösster Wert 28,5 ms | erfüllt |
| Latenz unter Last (alle 5 ms eine neue Instanz) | Median < 5 ms, p99 < 50 ms | 10 Läufe zu 3000: Median 1,51 ms, p99 12,6 ms (max 13,0 ms), grösster Wert 36,6 ms | erfüllt |
| Latenz während Ereignisflut (290 Ereignisse/s) | wie oben | Median 1,6 ms, p99 40 ms (2 Läufe) | erfüllt (knapp unter 50 ms) |
| Idle-CPU ohne Flow, 30 s | < 1 % | 5 Läufe: 0,23 % des Gesamtsystems (8 CPUs, max 0,25 %); als Summe in Prozent eines Kerns 1,8 % (max 2,0 %) | erfüllt für das Gesamtsystem, **verfehlt** bei der Lesart "Prozent eines Kerns". Die Lesart ist nicht festgelegt, siehe `measurements.md` |
| Speicher bei 5 offenen Editoren | < 100 MB | **nicht gemessen**, es gibt keine Editor-Rolle. Kette ohne Editor: 68,3 MB Summe RSS (Supervisor, Storage, Engine, Manager-Stub) | nicht gemessen |
| Engine-Zustandsänderung bis Neuzeichnen | < 50 ms | **nicht gemessen** (kein Editor) | nicht gemessen |
| Start bis `ready` | < 3 s | 100 Starts (10 Läufe zu 10): Median 0,30 s, max 0,34 s (alle Rollen bereit 0,21 s, Flows geladen 0,30 s) | erfüllt |

Einschränkungen der Latenzmessung: Der Python-Client weckt den Hub nach jedem Schreiben wie eine AHK-Rolle (`PostMessage`). Ohne Weckruf misst derselbe Test 226 ms Median und 274 ms Maximum (der 250-ms-Takt des Hubs); ein Client ohne Fenster kann das Budget deshalb nicht einhalten. Eine AHK-Gegenstelle (Editor) wurde nicht gemessen.

### Funde

**F-09 `seq` der Engine-Ereignisse kam vertauscht an (behoben, `src/engine/Engine.ahk`).** Bei 200 parallelen Instanzen kamen Ereignisse in falscher Reihenfolge an (`seq` 253 nach 271), mit dem echten Supervisor und mit dem Python-Hub, also im Engine-Prozess. `Engine.Emit` vergab `seq` und sendete getrennt; ein Thread, den ein Timer nach 15 ms unterbrach, sendete sein Ereignis nach den Ereignissen des unterbrechenden Threads. Folge: der Stub hätte das ältere Ereignis als "schon gesehen" verworfen. Fix: `Emit` unter `Critical`. Vorher 2 von 2 Läufen mit Lücken, danach 3 von 3 (Python-Hub) und über 100 Läufe der 200-Instanz-Tests in Ordnung. Commit 4906f7d.

**F-10 Instanz endete mit `exception` "element Trigger_Manual cannot be an action (mode trigger)" (behoben, `src/engine/Executor.ahk`).** Ausfall in 2 von 53 Läufen mit 200 parallelen Instanzen (einmal im Wiederholungslauf, einmal in einer Schleife). `Scheduler.Advance` setzt den Thread auf `ready` und danach auf das nächste Element; der Dispatch-Timer unterbrach dazwischen und führte den Trigger als Aktion aus. Fix: `Executor._Advance` unter `Critical`. Danach 60 von 60 Läufen des 50/200-Instanz-Tests ohne Ausfall (Beleg, kein Beweis: die Ausfallrate lag bei rund 4 %). Ob andere Stellen dasselbe Muster haben (`_Dispatch`, Klonen in `Advance`), ist nicht geprüft. Commit 887988b.

**F-07 Speicherleck im Supervisor: rund 83 KB je Client-Verbindung (offen, `src/core/ipc/PipeConnection.ahk`).** `__New` speichert `ObjBindMethod(this, "Pump")` und `ObjBindMethod(this, "_NotifyClose")` in Feldern des Objekts. Das ist ein Referenzzyklus; AHK zählt Verweise, das geschlossene Objekt (mit 64-KiB-Lesepuffer und Rahmenpuffer) wird nie freigegeben. `num_handles` bleibt flach, deshalb fällt das nur bei Speichermessung auf. Ursache belegt durch Probelauf: Mit `this._pollFn := ""` und `this._notifyFn := ""` am Ende von `_NotifyClose` blieb der RSS bei 17,47 → 17,49 MB nach 800 Verbindungen (ohne: +16 MB je 200), und alle 133 Tests von `tests/integration` und `tests/e2e` liefen grün. Die Änderung liegt in `src/core/` und wurde **nicht übernommen** (nur nach Absprache). Der Test bleibt rot, bis die Korrektur im Code ist. Ob dasselbe Leck die Rollen (Peer-Verbindung) bei Wiederverbindung trifft, ist nicht geprüft. Der Dauerlauf läuft deshalb ohne Verbindungswechsel (`AHF_SOAK_CHURN=1` schaltet sie zu).

**F-08 Storage drainiert das Log mit rund 30 Zeilen je Sekunde, die Warteschlange ist unbegrenzt (offen, `src/storage/WriteQueue.ahk`).** Der Manager-Stub schreibt jedes Engine-Ereignis ins Log. Bei rund 290 Ereignissen/s (20 s) wuchs der Storage von 17 auf 56 MB; das Log schrieb noch 207 s nach der Flut, danach war der RSS wieder 17,4 MB (kein Leck, ein Rückstau). Die Engine blieb im Latenzbudget. Der echte Manager wird nicht jedes Ereignis protokollieren, die Engine selbst loggt aber auch über den Storage; die Obergrenze und der Durchsatz sind offen. Ursache vermutet (`RunOne` je Timer, Timer-Auflösung), nicht einzeln nachgemessen. Der Dauerlauf hält deshalb rund 20 Ereignisse/s.

### Nicht geprüft / offen

- Dauerlauf über 10 Minuten: erfolgt, ein Lauf; der Dauerlauf mit Verbindungswechseln (`AHF_SOAK_CHURN=1`) wurde nicht gefahren, er würde an F-07 scheitern.
- Speicher bei 5 offenen Editoren und Neuzeichnen-Zeit: kein Editor vorhanden.
- AHK-Client als Gegenstelle der Latenzmessung; Triggerhost (WI-14) nicht gebaut, nicht in den Läufen.
- Worker-Elemente (Pool) wurden nicht unter Last gesetzt.
- F-06 (WI-15, `clean` in `evt.process.exited`) trat in den Läufen nicht auf, wurde hier aber nicht gezielt geprüft.
- Alle Werte von einem Rechner, der nebenbei lief (siehe `measurements.md`).
- `src/core/` unverändert (F-07 wartet auf Absprache). `src/engine/` an zwei Stellen geändert (F-09, F-10).
