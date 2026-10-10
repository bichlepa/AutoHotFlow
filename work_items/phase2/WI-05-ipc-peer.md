# WI-05 Nachrichtenschicht (Message, Dispatcher, Peer)

Größe: M · Hängt ab von: WI-02, WI-03, WI-04 · Blockiert: WI-06 und alle Rollen

## Ziel

Aus Rahmen werden typisierte Nachrichten mit Korrelation und Timeouts. Jede Rolle redet nur noch über `Peer`.

## Vorher lesen

`doc/PROTOKOLL.md` (vollständig), `doc/KONVENTIONEN.md` Abschnitt 4.

## Zu erstellen

Unter `src/core/ipc/`:

- `Message.ahk`: Klasse `Message` (`to`, `from`, `id`, `type`, `corr`, `timeoutMs`, `payload`). `Message.Serialize()` schreibt die Kopffelder **in fester Reihenfolge** `to, from, id, type, corr, timeoutMs, payload` (nicht die Map-Sortierung, siehe PROTOKOLL 2). `Message.Parse(text)` validiert Pflichtfelder (`ProtocolError` mit Code `bad_payload` bei Fehlern). `Message.ReadTo(text)` gibt `to` ohne vollständiges Parsen zurück (für den Hub, aus den ersten Bytes).
- `Dispatcher.ahk`: Registrierung von Handlern nach Typ oder Typpräfix (`On("cmd.flow.", fn)`; der längste passende Präfix gewinnt). Aufruf unter `try/catch`: Exception wird zu `res` mit `{ok:false, error:{code,message}}`. Antworten auf unbekannte Typen mit `unknown_type`.
- `Peer.ahk`: wie in `README.md` („Gemeinsame Verträge“). Zusätzlich:
  - `Request(...)`: Timer pro Anfrage. Bei Fristablauf wird der Callback **genau einmal** mit synthetischer `res` (`ok:false`, `error.code = "timeout"`) aufgerufen, eine verspätete echte Antwort wird verworfen.
  - Pro Anfrage Zählung offener Anfragen, Obergrenze (z. B. 1000) mit klarer Fehlermeldung.
  - `Connect()`: `sys.hello` mit `{name, pid, hwnd, protocol: 1}` senden, `sys.welcome` abwarten (mit Timeout, über Callback), danach Status `ready` und `OnReady`.
  - Wiederverbindung nach PROTOKOLL 5 (Backoff 100 ms → 2 s, gesamt 10 s), danach `OnClosed`.
  - Ping-Beantwortung: `sys.ping` → `sys.pong` automatisch.
  - Topic-Abos werden gemerkt und bei Wiederverbindung neu abonniert.

## Akzeptanzkriterien

- `Message.Serialize` erzeugt Kopffelder in fester Reihenfolge, `ReadTo` funktioniert auf diesem Format ohne vollständigen Parser.
- `Request` mit Antwort: Callback einmal, mit passender `corr`. Ohne Antwort: Callback einmal mit `timeout` nach Frist (±50 ms). Antwort nach Timeout: kein zweiter Callback.
- Zwei Peers über einen Python-Hub (aus WI-01): Anfrage, Ereignis, `unknown_type`-Antwort, Handler-Exception → Fehlerantwort.
- Hub bricht ab: Peer versucht Wiederverbindung, stellt Abos wieder her, ruft `OnClosed` nach Ablauf der Frist.
- 10.000 Anfragen nacheinander ohne wachsende Timer-/Handle-Zahl.

## Tests

`tests/ahk/message.test.ahk`, `tests/ahk/dispatcher.test.ahk`, `tests/integration/test_peer.py` mit Hilfsskript `tests/integration/helpers/peer_probe.ahk`.

## Nicht Teil

Routing (Supervisor, WI-07), Rollenlebenszyklus (WI-06).

## Hinweise

- Ein `SetTimer` pro Anfrage ist einfach, aber teuer bei sehr vielen. Ein Timer mit sortierter Fälligkeitsliste ist erlaubt, solange die Genauigkeit ±50 ms bleibt.
- Handler laufen im Nachrichtenpfad: **kein** Blockieren, Dateizugriff oder Warten.
