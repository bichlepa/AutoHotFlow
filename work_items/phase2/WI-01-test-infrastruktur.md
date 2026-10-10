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

## Ergebnis

Stand 2026-10-10. Umgesetzt wie beschrieben, mit den unten genannten Abweichungen.

**Testlauf** (`python -m pytest tests -q`, dreimal hintereinander identisch):

```
28 passed, 1 skipped in 6.90s
```

Der eine Skip ist der absichtlich übersprungene Fall in `tests/ahk/selfcheck.test.ahk`.

**Erstellt** (alle unter `tests/`):

- `requirements.txt`, `conftest.py`, `test_ahk_runner.py`
- `support/`: `ahk.py`, `procs.py`, `winpipe.py` (überlappte Pipes, Hilfsmodul), `ahfclient.py`, `pyhub.py` (Stand-in-Hub), `test_framing.py`, `test_client_hub.py`, `test_procs.py`
- `ahk/lib/Assert.ahk`, `ahk/selfcheck.test.ahk`

**Abweichungen vom Paket**

- `TestRun.Init()` ist zusätzlich nötig. Es liest den Ergebnispfad aus `A_Args[1]` und installiert den `OnError`-Handler. Ein Fehler außerhalb eines Falls beendet den Lauf mit einer `fatal`-Zeile und Exit-Code 2, ohne Fehlerdialog.
- `TestRun.Skip(name, reason)` ist zusätzlich vorhanden, damit der bewusste Skip-Fall ohne Umweg läuft.
- Die pytest-Items pro AHK-Fall entstehen beim Sammeln durch Lesen der Quelle (`TestRun.Case("…")`), nicht durch einen AHK-Lauf. Eine Datei läuft einmal pro Testlauf. Zusätzlich gibt es ein Datei-Item, das Exit-Code 0 und die Summary-Zeile verlangt.
- Die Python-Tests des Pakets liegen in `tests/support/` (innerhalb des Pfads), nicht in einem eigenen Ordner.
- `events(topic, timeout)`: `timeout` ist eine Leerlaufzeit (Ende, wenn so lange keine Nachricht kommt).
- Jeder Test hat ein Zeitlimit von 120 s (pytest-timeout, in `conftest.py` gesetzt, sofern kein eigenes Limit).

**Getestet**

- Rahmen und Envelope (Reihenfolge der Kopffelder, Typen bleiben erhalten, Obergrenze 16 MiB).
- Client gegen Stand-in-Hub: Handshake, Anfrage/Antwort über den Hub, `not_found`, Timeout ohne Hänger, `sys.ping`/`sys.pong`, Topic-Abo, Entfernen eines getrennten Peers.
- Prozessbaum-Beendigung, Suspend/Resume, Beenden beim Interpreter-Exit über den atexit-Hook (simuliert durch `KeyboardInterrupt` in einem Kindprozess).
- Hängendes AHK-Skript wird beim Timeout samt Prozess beendet, kein `AutoHotkey64.exe` bleibt übrig.
- Fehlschlagender AHK-Fall ist rot mit Meldung (manuell geprüft mit einer temporären Datei, danach gelöscht; zusätzlich automatisiert im Test `test_failing_and_erroring_cases_are_reported_red`).
- Fehlender Interpreter führt zu klaren Skips.
- `AHF_TEST_KEEP=1` behält das Datenverzeichnis.

**Nicht getestet**

- Ein echter Ctrl+C-Abbruch von pytest selbst. Abgedeckt ist nur der Interpreter-Exit-Pfad.
- `wake()` gegen ein echtes AHK-Fenster (kommt mit WI-04).
- Der synchrone Pipe-Fall (nur überlappte Variante verwendet).

**Offene Punkte**

- Der Fortschrittshaken WI-01 in `doc/ARCHITEKTUR.md` und `work_items/phase2/README.md` ist nicht gesetzt (außerhalb des Pakets, Auftraggeber).
- Der Stand-in-Hub ist nicht die Produktion. Für WI-04 und WI-05 gilt er nur als Gegenstelle.
