# Messwerte Phase 2 (WI-16)

Messung mit `python -m pytest tests -m stress` (die Tests schreiben bei gesetztem `AHF_MEASURE_OUT=<datei>` je Messung eine JSON-Zeile und geben sie als `MEASURE ...` aus). Werte: Anzahl der Läufe, Median, Maximum.

**Rechner und Last:** Windows 11 Pro (10.0.26300), 8 logische CPUs, Python 3.13, AutoHotkey v2 (`AutoHotkey64.exe`). Der Rechner des Projektinhabers lief nebenbei weiter (VS Code, v1-AutoHotFlow, weitere AHK-Skripte); es gab keine gezielte Entlastung, die Werte gelten für einen normal genutzten Arbeitsrechner. Datum: 2026-10-11. Die Python-Clients wecken den Hub nach jedem Schreiben wie die AHK-Rollen (`tests/stress/stresskit.py`, `StressClient`).

**Wiederholung:** Alle Tests ausser den Dauertests liefen zehnmal hintereinander (`-k "not memory and not backlog"`). Die Zahlen unten sind, wenn nicht anders angegeben, der Median und das Maximum über diese 10 Läufe (bei Latenzen: Median der Mediane, Maximum der Maxima).

## Zielgrössen aus ARCHITEKTUR 9

| Zielgrösse | Ziel | Gemessen | Urteil |
|---|---|---|---|
| Nachrichtenlatenz (`cmd.engine.snapshot`), Leerlauf, 10 Läufe zu je 2000 Anfragen | Median < 5 ms, p99 < 50 ms | Median 1,44 ms (max über Läufe 1,47), p99 1,91 ms (max 4,91), grösster Einzelwert 28,5 ms | erfüllt |
| Nachrichtenlatenz unter Last (Instanzen starten alle 5 ms), 10 Läufe zu je 3000 Anfragen | Median < 5 ms, p99 < 50 ms | Median 1,51 ms (max 1,52), p95 9,9 ms, p99 12,6 ms (max 13,0), grösster Einzelwert 36,6 ms | erfüllt |
| Idle-CPU des Gesamtsystems ohne Flow, 30 s | < 1 % | 5 Läufe: 0,23 % des Gesamtsystems (8 CPUs; Maximum 0,25 %), entspricht 1,8 % eines Kerns (Maximum 2,0 %) | erfüllt für "Gesamtsystem", verfehlt wenn man die Summe in Prozent eines Kerns liest (Abschnitt Idle-CPU) |
| Speicher bei 5 offenen Editoren | < 100 MB | **nicht gemessen**: es gibt keine Editor-Rolle. Gemessen wurde die Kette ohne Editor (Supervisor, Storage, Engine, Manager-Stub): 68,3 MB Summe RSS | nicht gemessen |
| Engine-Zustandsänderung bis Editor-Neuzeichnen | < 50 ms | **nicht gemessen** (kein Editor, kein Neuzeichnen) | nicht gemessen |
| Start bis `ready` (Supervisor-Start bis alle Rollen bereit und Flows geladen), 100 Starts (10 Läufe zu je 10 Starts) | < 3 s | 0,30 s Median (Maximum 0,34 s); alle Rollen bereit nach 0,21 s (Maximum 0,24 s) | erfüllt |

Hinweis zur Latenz: Ein Python-Client, der den Hub nicht weckt, erreicht ihn nur über den Fallback-Timer (250 ms). Gemessen (10 Läufe zu je 100 Anfragen): Median 226 ms, p99 264 ms, Maximum 274 ms. Das ist kein Fehler der Architektur, sondern die dokumentierte Folge fehlender Weckrufe (PROTOKOLL 1, HOW-TO). Es gilt für jeden Client ohne Fenster. Die Latenzen oben messen den Weg Client → Hub → Engine → Hub → Client; der Weckruf des Clients an den Hub wurde dabei vom Python-Client nachgebildet (`PostMessage` an das Skriptfenster des Supervisors), die Weckrufe zwischen Hub und Engine sind die der AHK-Prozesse. **Nicht gemessen:** ein AHK-Client (Editor) als Gegenstelle.

## Stresstests

| Fall | Umfang | Ergebnis |
|---|---|---|
| Parallele Instanzen | 50 und 200 Instanzen (Richtlinie `parallel`), Starts hintereinander ohne Warten auf die Antworten | alle Starts beantwortet (Fehlerquote 0), alle Instanzen enden mit `finished`, gleichzeitig lebten alle (Spitze 50 bzw. 200), 6 Elementereignisse je Instanz, `countRuns` am Ende 0, `seq` lückenlos. 200 Instanzen: Starts in 0,87 s (Median, Maximum 0,93 s) beantwortet, alle beendet nach 6,84 s (Median, Maximum 6,90 s; Sleep 6 s). Dabei fand der Test zwei Fehler in der Engine (F-09 `seq` vertauscht, F-10 Trigger als Aktion ausgeführt, beide behoben, siehe `WI-16-stress.md`). Nach den Korrekturen 60 von 60 Läufen ohne Ausfall |
| Start/Stop-Folge | 1000 Zyklen (jeder dritte mit zwei Instanzen, 1334 Instanzen), 10 Läufe | je Lauf 10,5 s (max 10,9 s); Start-Antwort Median 2,7 ms, p99 17,5 ms; Stop-Antwort Median 2,5 ms, p99 15,8 ms; jede Instanz hat genau ein `started` und ein `ended` (`flow.stop`), `seq` lückenlos (8830 Ereignisse), Zähler 0, Engine-Handles 159 → 159 und RSS 17,1 MB → 17,1 MB |
| Clients verbinden und trennen | 20 Clients mal 8 Runden = 160 Verbindungswechsel, während ein Flow läuft, 10 Läufe | Fehler 0, alle Pids unverändert, keine Neustarts; Handles Supervisor 186 → 186, Engine 159 → 159; Snapshot-Latenz während der Wechsel Median 2,05 ms, p99 9,5 ms (Maximum über Läufe 15,3 ms); Verbindungsaufbau Median 5,1 ms, p99 103 ms (Maximum 145 ms, Hub nimmt neue Clients auf seinem 250-ms-Takt an) |
| Speicher des Supervisors nach 400 Verbindungen | 400 Verbindungswechsel nach 100 zur Erwärmung | **rot (F-07)**: Handles flach (183 → 183), aber RSS 25,2 → 57,8 MB, rund 83 KB je Verbindung. Mit der Korrektur in `PipeConnection` (siehe F-07) 17,47 → 17,49 MB nach 800 Verbindungen |
| Dauerlauf (`-m soak`) | 600 s, rund 20 Ereignisse/s, ohne Verbindungswechsel | grün: Fehler 0, Pids unverändert, Prozesse 5 → 5, Handles flach (Supervisor 195, Rollen 159), RSS Supervisor 17,88 → 17,86 MB, Engine 17,07 → 17,10, Manager 17,06 → 17,09, Storage 17,14 → 17,21 MB; Snapshot-Latenz im letzten Teil Median 2,5 ms, p99 11,2 ms, Maximum 59,6 ms. 1 Lauf (zuvor 90 s: gleiche Werte) |
| Ereignisflut | 20 s mit rund 290 Ereignissen/s (725 Instanzen) | Engine-Snapshot-Latenz während der Flut Median 1,6 ms, p95 29 ms, p99 40 ms, Maximum 59 ms (Budget gehalten); **Storage fällt zurück (F-08)**: RSS 17,1 → 56,1 MB am Ende der Flut, das Log schrieb noch 207 s nach der Flut, danach RSS 17,4 MB |

## Idle-CPU

5 Läufe zu je 30 s Leerlauf der Kette (Supervisor, Storage, Engine, Manager-Stub, `--headless`) nach 5 s Beruhigung. Die Tabelle zeigt einen Lauf des Gesamtlaufs `-m stress` (Summe dort 1,93 %), die Summenzeilen darunter sind der Median über die 5 Läufe, gemessen als Differenz der CPU-Zeit (`psutil cpu_times`) durch die Wandzeit.

| Prozess | CPU in % eines Kerns | RSS |
|---|---|---|
| supervisor | 0,37 | 17,3 MB |
| engine | 0,42 | 17,0 MB |
| storage | 0,57 | 17,0 MB |
| manager (Stub) | 0,57 | 17,0 MB |
| Summe der vier Rollen | 1,82 (Median, Maximum 2,03) | 68,3 MB (Maximum 68,5) |
| Summe, bezogen auf alle 8 logischen CPUs | **0,23 %** (Median, Maximum 0,25 %) | |
| `ahkrun.py`-Wächter (Python, nur Testwerkzeug, nicht Teil des Produkts) | 5,3 | |

Ein früherer Entwicklungslauf ergab 2,5 % eines Kerns (Supervisor 1,15 %), also 0,31 % des Gesamtsystems; die Werte schwanken je nach Last des Rechners. Das Ziel "unter 1 %" gilt hier für das Gesamtsystem (alle CPUs, wie im Task-Manager). Liest man es als "Summe der Prozesse in Prozent eines Kerns", ist es mit 1,6 bis 2,5 % **verfehlt**. Ursache sind die Takte im Leerlauf (Fallback-Timer 250 ms in jedem Prozess, Tick des Supervisors, Pings). Ob die engere Lesart gemeint ist, ist offen.

## Dauer der Tests

Ein Durchlauf aller Stresstests ausser Dauertest und Ereignisflut: rund 107 s (10 Läufe: 105 bis 109 s). Ereignisflut: rund 235 s. Idle-CPU: 37 s.
