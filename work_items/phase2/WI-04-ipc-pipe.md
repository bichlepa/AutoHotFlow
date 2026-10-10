# WI-04 Named Pipes, Rahmen, Weckruf

Größe: L (riskantestes Paket) · Hängt ab von: WI-01, WI-03 · Blockiert: WI-05

## Ziel

Eine robuste, **nie blockierende** Pipe-Schicht für AHK v2: Server (Hub-Seite) und Client, Längenpräfix-Rahmen, Weckruf per `PostMessage`, saubere Erkennung von Verbindungsabbruch.

## Vorher lesen

`doc/ARCHITEKTUR.md` 2.2, `doc/PROTOKOLL.md` Abschnitte 1 und 5, `work_items/spikes/pipe_server.ahk` und `client.py` (laufender Spike: überlappender Server, Python-Client, Weckruf: 0,3 ms Round-Trip).

Win32-Funktionen: `CreateNamedPipeW`, `ConnectNamedPipe`, `CreateFileW`, `ReadFile`, `WriteFile`, `GetOverlappedResult`, `CreateEventW`, `CancelIoEx`, `DisconnectNamedPipe`, `CloseHandle`, `PeekNamedPipe`, `PostMessageW`.

## Zu erstellen

Unter `src/core/ipc/`:

- `Frame.ahk`: `FrameWriter.Encode(text) -> Buffer` (`uint32` LE Länge + UTF-8), `FrameReader` (Eingabepuffer, `Feed(buf, n)`, `Next() -> String | ""`), Obergrenze 16 MiB (größere Rahmen: Verbindung schließen, `ProtocolError`).
- `PipeListener.ahk`: legt eine Serverinstanz an (`PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED`, Byte-Modus, `PIPE_REJECT_REMOTE_CLIENTS`, `nMaxInstances = PIPE_UNLIMITED_INSTANCES`), wartet überlappend auf einen Client. `Accept()` ist nicht blockierend: gibt `PipeConnection` zurück, sobald verbunden, sonst `""`, und legt danach sofort die nächste Instanz an.
- `PipeConnection.ahk`: gemeinsame Verbindung für beide Seiten.
  - `SendFrame(text)`: nicht blockierend. Schreibt über überlappendes `WriteFile`, eine Sendewarteschlange hält ausstehende Rahmen. Wächst die Warteschlange über `maxQueueBytes` (Standard 8 MiB) oder `maxQueueFrames` (1000), gibt `SendFrame` `false` zurück und setzt `OnClose(conn, "queue_overflow")`.
  - `Pump()`: arbeitet Lese- und Schreibabschluss ab (`GetOverlappedResult` mit `bWait = false`), ruft `OnFrame(conn, text)` pro vollständigem Rahmen und `OnClose(conn, reason)` genau einmal.
  - `static Connect(pipeName, timeoutMs)`: `CreateFileW` mit Wiederholung (`ERROR_PIPE_BUSY`, `ERROR_FILE_NOT_FOUND`) bis Timeout. Nicht blockierend im Sinne von: wartet höchstens `timeoutMs` und pumpt keine Nachrichten.
  - `PeerHwnd`: HWND des Gegenübers für den Weckruf, wird von der Nachrichtenschicht gesetzt.
  - Nach jedem `SendFrame`: `PostMessageW(PeerHwnd, 0x8001, 0, 0)`, wenn `PeerHwnd <> 0`.
  - `Close()`: idempotent, bricht offene I/O ab (`CancelIoEx`), schließt Handles und Events.
- `Wake.ahk`: Konstante `WM_AHF_WAKE := 0x8001`, `Wake.Register(handler)` über `OnMessage`, Fallback-Timer (250 ms) der `Pump()` aufruft. Beides gebündelt in `Wake.Install(pumpFn)`.

## Schnittstelle

Siehe `README.md` dieses Ordners („Gemeinsame Verträge“, `PipeListener`, `PipeConnection`). Zusätzlich:

```ahk
PipeConnection.OnFrame  := (conn, text) => ...
PipeConnection.OnClose  := (conn, reason) => ...    ; reason: "peer_closed" | "broken" | "queue_overflow" | "local"
PipeConnection.IsOpen   -> bool
PipeConnection.QueuedBytes -> Integer
```

## Akzeptanzkriterien

- Python-Client und AHK-Server (und umgekehrt, AHK-Client gegen Python-Server) tauschen 10.000 Rahmen unterschiedlicher Größe (1 Byte bis 1 MiB) ohne Verlust und in Reihenfolge.
- Schließt der Gegenüber abrupt (Prozess beendet), erhält die Verbindung innerhalb von 500 ms `OnClose`, kein Handle-Leck (Handle-Zahl vor/nach in einem Wiederholungstest stabil).
- Reißt die Gegenseite nicht ab, liest aber nicht (Python-Client liest nie), läuft `SendFrame` in `queue_overflow`, die Anwendung **blockiert nie**.
- Mit Weckruf: Round-Trip-Median unter 5 ms, 99 % unter 50 ms (Messung als Testausgabe, kein hartes Gate unter CI-Last).
- Teilweise gelesene Rahmen (Länge ankommend, Rest später) werden korrekt zusammengesetzt (Test mit absichtlich gestückeltem Schreiben aus Python).
- 100 Verbindungsaufbau/-abbau-Zyklen ohne Leck und ohne hängenden Prozess.

## Tests

`tests/ahk/frame.test.ahk` (reine Logik). `tests/integration/test_pipe.py` mit AHK-Hilfsskripten `tests/integration/helpers/pipe_echo_server.ahk`, `pipe_client.ahk`.

## Nicht Teil

JSON, Nachrichtentypen, Korrelations-IDs (WI-05).

## Hinweise

- `OVERLAPPED`-Struktur auf x64: `Internal`(8) `InternalHigh`(8) `Offset`(4) `OffsetHigh`(4) `hEvent`(8), `hEvent` bei Offset 24. Im Spike war dieser Offset die Fehlerquelle.
- `OVERLAPPED` und Datenpuffer müssen bis zum Abschluss der I/O gültig bleiben: als Mitglieder der Verbindung halten, nicht lokal.
- `A_LastError` direkt nach dem `DllCall` lesen. `ERROR_IO_PENDING` (997) ist der Normalfall.
- Pipe-Namen aus Konstanten bauen (siehe KONVENTIONEN 5).
- Ein `ERROR_BROKEN_PIPE` (109) beim Lesen ist ein normales Verbindungsende, kein Fehler im Programm.

## Ergebnis

Stand: WI-04 abgeschlossen, nicht committet. `python -m pytest tests -q`: `161 passed, 1 skipped` (der Skip ist ein bestehender Test), danach keine AutoHotkey-Prozesse übrig. Die 26 Pipe-Tests in `tests/integration/test_pipe.py` liefen in 8 Dateiläufen und 3 parallelen Dateiläufen grün.

Erstellt:

- `src/core/ipc/FrameWriter.ahk`, `FrameReader.ahk`, `Frame.ahk` (bindet beide ein, eine Klasse pro Datei), `PipeConnection.ahk`, `PipeListener.ahk`, `Wake.ahk`.
- `tests/ahk/frame.test.ahk` (18 Fälle), `tests/integration/test_pipe.py` (26 Tests), `tests/integration/helpers/pipe_echo_server.ahk`, `pipe_client.ahk`, `PipeTestKit.ahk`, `rawpipe.py`.
- `doc/HOW-TO.md` (neue Einträge), Verträge in `work_items/phase2/README.md` aktualisiert, Fortschritt WI-04 abgehakt.

Messwerte (Lauf mit `-s`, diese Maschine, keine CI-Last):

| Messung | Wert |
|---|---|
| Round-Trip Python → AHK-Server → Python, mit Weckruf, 1000 Läufe | Median 0,09 ms, p99 0,15 ms, max 5,4 ms |
| Round-Trip AHK-Client → AHK-Server → AHK-Client, mit Weckruf, 999 Läufe | Median 0,10 ms, p99 0,28 bis 0,46 ms, max 0,6 ms. Der erste Round-Trip (Annahme der neuen Verbindung ohne Weckruf) dauert bis ca. 210 ms und steht gesondert (`firstUs`). |
| Round-Trip AHK-Client → Python-Server → AHK-Client, 500 Läufe | Median 0,09 ms, p99 0,17 ms |
| Round-Trip ohne Weckruf (nur Fallback-Timer) | Median 250 ms |
| Durchsatz, 10.000 Rahmen je Richtung gleichzeitig (46 MB je Richtung) | ca. 43 MB/s je Richtung (AHK-Server), ca. 40 MB/s (AHK-Client); 1,1 s gesamt |
| Rahmen von genau 16 MiB (Echo) | ok, ca. 0,2 s |
| Abbruch eines Gegenübers, Erkennung | 42 bis 98 ms (3 Läufe Prozess beendet, 1 Lauf Handle geschlossen); durch den 250-ms-Fallback nach oben begrenzt |
| 100 Zyklen Verbindungsaufbau/-abbau gegen AHK-Server | 1,05 s, Handles 162 → 162 |
| 100 Zyklen eines AHK-Clients | Handles 160 → 160 |
| Nicht lesender Gegenüber, 100-KiB-Rahmen | `SendFrame` scheitert bei Rahmen 83 nach 14 ms, Grund `queue_overflow` |
| Nicht lesender Gegenüber, 10-Byte-Rahmen | scheitert bei Rahmen 5680 (Pipe-Puffer, dann 1000 in der Warteschlange) |

Akzeptanzkriterien und Beleg:

- 10.000 Rahmen 1 B bis 1 MiB, in Reihenfolge, beide Richtungen mit echter Gegenstelle: `test_ahk_server_python_client_exchanges_10000_frames` und `test_python_server_ahk_client_exchanges_10000_frames` (Größen 1 B bis 1.048.576 B, nicht ASCII in kleinen Rahmen, Größen um den 64-KiB-Lesepuffer, beide Seiten prüfen jeden Rahmen auf Inhalt und Reihenfolge).
- Abrupter Abbruch unter 500 ms, kein Handle-Leck: `test_abrupt_end_of_client_process_is_seen_within_500_ms` (3 Läufe, Prozess per `kill`, Zeit aus gemeinsamem QueryPerformanceCounter), `test_abrupt_end_of_server_side_is_seen_by_ahk_client_within_500_ms`, `test_100_connect_disconnect_cycles_*` (`psutil.num_handles`, Toleranz 2).
- Nicht lesender Gegenüber: `test_non_reading_peer_causes_queue_overflow_without_blocking`, `test_frame_count_limit_closes_with_queue_overflow`, `test_configured_queue_byte_limit_is_applied`. Der Server bedient danach einen neuen Client.
- Round-Trip-Messung: die drei `test_round_trip_*`. Hartes Gate nur Median unter 25 ms (belegt, dass der Weckruf wirkt; der Fallback allein liegt bei 250 ms), die Zielwerte 5 ms/50 ms stehen als Ausgabe.
- Gestückelte Rahmen: `test_fragmented_frames_are_reassembled` (Kopf 1+3 Byte, Schnitt in einem Mehrbyte-Zeichen, zwei Rahmen mit Schnitt im zweiten, Rahmen von 200.000 Bytes in ungeraden Teilen, Ende des einen und Anfang des nächsten in einem Schreibvorgang) plus `frame.test.ahk` (Byte für Byte).
- 100 Zyklen ohne Leck und ohne hängenden Prozess: beide Richtungen (siehe oben). Hängende Prozesse: die `procs`-Fixture prüft, dass nichts zurückbleibt.

Weitere geprüfte Fälle: ungültige Kopfzeile (zu groß, `0xFFFFFFFF`, Länge 0) schließt nur diese Verbindung mit `protocol_error`; geschriebene Daten bleiben nach sofortigem `Close()` lesbar; zweiter Listener auf demselben Namen wird abgelehnt (`FILE_FLAG_FIRST_PIPE_INSTANCE`); `Connect` ohne Server läuft in `AhfTimeoutError`; Annahme einer Verbindung ohne Weckruf über den Fallback-Timer (ca. 250 ms).

Abweichungen vom Paketentwurf (alle in `README.md` Verträge nachgetragen):

- `Frame.ahk` enthält nur `#Include` von `FrameWriter.ahk` und `FrameReader.ahk` (Konvention: eine Klasse pro Datei).
- Leere Rahmen (Länge 0) und `FrameWriter.Encode("")` sind `ProtocolError`. Dadurch bleibt `Next() -> ""` eindeutig "kein Rahmen".
- Neuer Schließgrund `protocol_error` (ungültiger Rahmenkopf, `Next` warf `ProtocolError`).
- Warteschlangengrenze: Überlauf, wenn der **Rückstand vor** dem neuen Rahmen `maxQueueBytes` erreicht oder `maxQueueFrames` Rahmen anstehen. Ein einzelner Rahmen bis 16 MiB ist immer sendbar, die Warteschlange ist durch `maxQueueBytes` plus einen Rahmen begrenzt. (Erste Fassung "Summe danach" lehnte einen 16-MiB-Rahmen ab, wenn noch ein kleiner stand.)
- `OnClose(conn, "queue_overflow")` und Schreibfehler aus `SendFrame` heraus werden mit `SetTimer(fn, -1)` unmittelbar nach dem aktuellen Aufruf gemeldet, nicht darin (kein Wiedereintritt in die Schleife des Aufrufers). `Pump()` und `Close()` rufen `OnClose` synchron. `Close()` meldet `"local"`.
- `Pump()` verarbeitet höchstens 64 Lesevorgänge (4 MiB) je Aufruf und plant den Rest per `SetTimer(-1)`, damit ein dauernd sendender Gegenüber die Nachrichtenschleife nicht aushungert. `Pump()` ist wiedereintrittssicher (zweiter Aufruf merkt nur "nochmal").
- Zusätzlich zu den geplanten Schnittstellen: `QueuedFrames`, `CloseReason`, `maxQueueBytes`/`maxQueueFrames` als Eigenschaften, `PipeConnection.FullName`, `Wake.Post`, `Wake.Hwnd`, `Wake.MaxThreads`. `PipeListener`: wirft `AhfError`, wenn der Name schon bedient wird.
- Pipe-Name: `PipeConnection.Connect` und `PipeListener` nehmen den Namen mit oder ohne `\.\pipe\`-Präfix (Präfix aus `Chr(92)` gebaut).
- Ausstehendes `WriteFile` wird zusätzlich über einen Folge-Timer (`SetTimer(-1)`) abgearbeitet, solange die Warteschlange nicht leer ist. Ohne ihn flösse eine große Warteschlange nur mit dem 250-ms-Fallback ab, weil ein Leser nach dem Lesen keinen Weckruf sendet (siehe HOW-TO).

Nicht geprüft / offen:

- `PROTOKOLL.md` Abschnitt 1 nennt die Annahme neuer Clients nicht: Ohne Weckruf des Clients an den Hub dauert sie bis 250 ms. WI-05/WI-07 sollten nach `Connect` einen Weckruf an die Hub-HWND senden (die HWND muss der Client vorher kennen, z. B. als Startparameter). Dokument nicht geändert (außerhalb des Auftrags).
- `OnMessage`-`MaxThreads` bleibt bei 1. In 12.000 Ping-Pong-Läufen (mit 1 und 4) wurde kein verlorener Weckruf beobachtet. Ein verlorener Weckruf würde ohnehin nur um bis 250 ms verzögern.
- Die Wiedereintrittswächter (`Critical` um das Setzen der Flags) sind durch die Tests nicht gezielt mit einer erzwungenen Unterbrechung belegt.
- Unter hoher Systemlast (CI) nicht gemessen; die 500-ms-Grenze hängt am 250-ms-Fallback und wäre dort die einzige Reserve.
- Unter AHK 32 Bit nicht geprüft (Offset von `hEvent` ist über `A_PtrSize` berechnet).
- Ein einmaliger, nicht reproduzierter Fehlschlag von `test_ahk_server_python_client_exchanges_10000_frames` in einer Gesamtsuite (siehe HOW-TO, Status vermutet).
- Die Zugriffsrechte der Pipe sind die Standard-DACL (gleicher Benutzer voll, andere nur lesend); ein eigenes Sicherheitsattribut ist nicht gesetzt.
