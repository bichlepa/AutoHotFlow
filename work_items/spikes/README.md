# Spike: Named Pipe + Weckruf (AHK v2)

Ergebnis (2026-10-10, Entwicklungsrechner, AutoHotkey 2.0.x):

- AHK v2 betreibt per DllCall einen overlapped Pipe-Server. Python verbindet sich mit `open(pipe, "r+b", buffering=0)`.
- Nur Polling (Timer 250 ms): Round-Trip Median ~256 ms.
- Mit `PostMessage`-Weckruf nach dem Schreiben: Round-Trip Median ~0,3 ms, max ~0,5 ms.
- Prozesskosten AHK v2 (8 Instanzen): Start ~30 ms, ~14 MB RSS, 0 % CPU im Leerlauf.

Fehlerquellen, die der Spike gezeigt hat:

- `OVERLAPPED.hEvent` liegt auf x64 bei Offset 24 (2 * A_PtrSize + 8), nicht 16.
- `#SingleInstance` ist in v2 standardmäßig "Force"-artig: mehrere Prozesse desselben Skripts brauchen `#SingleInstance Off`.
- Backslashes in Pipe-Namen können beim Schreiben über Shell-Heredocs verloren gehen (`\.\pipe` wird zu `\.\pipe`). Namen aus `/` zusammensetzen (`StrReplace`).

Dateien: `pipe_server.ahk` (Server, Echo), `client.py` (Messung). Der Spike ist Referenz, kein Produktionscode.
