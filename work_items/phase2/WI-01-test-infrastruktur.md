# WI-01 Test- und Laufinfrastruktur

Größe: M · Hängt ab von: – · Blockiert: alle Pakete mit Tests

## Ziel

Alle späteren Pakete können Tests schreiben, ohne sich um Prozessstart, Aufräumen und Protokoll-Client zu kümmern.

## Vorher lesen

`doc/TESTSTRATEGIE.md` (vollständig), `doc/PROTOKOLL.md` Abschnitte 1 und 2, `work_items/spikes/pipe_server.ahk` und `client.py` (funktionierender Spike für Pipe + Weckruf).

## Zu erstellen

- `tests/requirements.txt`: `pytest`, `pytest-timeout`, `psutil`.
- `tests/conftest.py`: Fixtures
  - `ahk_exe` (Umgebungsvariable `AHF_AHK2_EXE`, sonst `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`; Test überspringt mit klarer Meldung, wenn nicht vorhanden),
  - `datadir` (temporäres Verzeichnis, mit `AHF_TEST_KEEP=1` behalten),
  - `session_id` (eindeutig),
  - `procs` (Prozessverfolgung, beendet am Ende alle gestarteten Prozesse samt Kindern),
  - `run_ahk(script, *args, timeout)` (Skript ausführen, Exit-Code und Ausgabedatei zurückgeben).
- `tests/support/ahk.py`: Interpreter-Suche. `procs.py`: Start/Kill/Suspend/Resume, Baumbeendigung (`psutil`). `ahfclient.py`: Python-Client für das Protokoll (siehe unten).
- `tests/ahk/lib/Assert.ahk`: Funktionen `Assert.Equal(a, b, msg)`, `Assert.True(v, msg)`, `Assert.Throws(fn, errorClass := "")`, `TestRun.Case(name, fn)` und `TestRun.Finish()`. Ergebnis wird als JSON-Zeilen in die Datei geschrieben, deren Pfad als erstes Argument kommt. Exit-Code 0 nur, wenn alle Fälle grün sind.
- `tests/test_ahk_runner.py`: sammelt `tests/ahk/*.test.ahk`, startet jede Datei, wertet die JSON-Zeilen aus und erzeugt pro Fall ein pytest-Ergebnis.
- Ein Beispieltest `tests/ahk/selfcheck.test.ahk`, der die Assert-Bibliothek prüft (grüner und absichtlich übersprungener Fall).

## `ahfclient.py`

- `AhfClient(pipe_name, name)`: verbindet sich (Wiederholung bis Timeout), sendet `sys.hello` mit seiner `pid` und `hwnd = 0` (Python hat kein Fenster, Weckruf an Python ist nicht nötig), liest `sys.welcome`.
- `send(to, type, payload=None, corr=None) -> id`; `request(to, type, payload, timeout=5)` wartet auf `res` mit `corr`; `events(topic=None, timeout)` Generator; `wake(peer_hwnd)` über `ctypes.windll.user32.PostMessageW(hwnd, 0x8001, 0, 0)`.
- Rahmen: `uint32` little endian + UTF-8-JSON (siehe PROTOKOLL 1).
- Hinweis: Der Hub existiert noch nicht. Für eigene Tests des Clients ein kleiner Python-Hub in `tests/support/pyhub.py` (nimmt Verbindung an, antwortet `sys.welcome`, kann Nachrichten routen). Er dient später auch als Gegenstelle für Rollentests ohne Supervisor.

## Akzeptanzkriterien

- `pytest tests -q` läuft auf einem sauberen Checkout (nach `pip install -r tests/requirements.txt`) durch.
- Nach einem Testlauf, auch nach Abbruch mit Ctrl+C und nach einem Timeout, bleibt kein `AutoHotkey64.exe` übrig, das der Test gestartet hat.
- `Assert`-Bibliothek: ein fehlschlagender Fall führt zu einem roten pytest-Ergebnis mit der Meldung.

## Nicht Teil

AHK-Rollencode, echte Protokolltests (kommen mit WI-04/05).

## Hinweise

- Pipe-Namen nicht als `\\.\pipe\...`-Literal in Shell-Heredocs schreiben, siehe KONVENTIONEN 5. In Python `r"\\.\pipe\\" + name` oder `"\\\\.\\pipe\\" + name`.
- Windows: Prozesse mit `creationflags=subprocess.CREATE_NO_WINDOW` starten, damit keine Konsolenfenster aufblitzen.
