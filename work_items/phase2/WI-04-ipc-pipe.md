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
