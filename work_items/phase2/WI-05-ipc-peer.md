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

## Ergebnis

Stand: WI-05 abgeschlossen, **nicht committet**. `python -m pytest tests -q`: `299 passed, 1 skipped in 62.21s`. Danach keine AutoHotkey-Prozesse übrig.

Erstellt:

- `src/core/ipc/Message.ahk`, `Dispatcher.ahk`, `Peer.ahk`
- `tests/ahk/message.test.ahk` (19 Fälle), `tests/ahk/dispatcher.test.ahk` (15 Fälle)
- `tests/integration/test_peer.py` (10 Tests), `tests/integration/helpers/peer_probe.ahk`
- Geändert: `doc/PROTOKOLL.md` (Abschnitte 1, 2, 5), `doc/HOW-TO.md` (7 Einträge), `work_items/phase2/README.md` (Vertrag `Message`/`Dispatcher`/`Peer`, Fortschritt WI-05 abgehakt).

Akzeptanzkriterien und Beleg:

- Feste Kopf-Reihenfolge, `ReadTo` ohne vollständiges Parsen: `message.test.ahk` (Serialize-Fälle, ReadTo-Fälle).
- Request mit Antwort, Callback einmal mit passender `corr`: `test_request_answers_and_event_between_two_ahk_peers` (`corr` == gesendete `id`).
- Ohne Antwort: Callback einmal mit `timeout` nach 304,1 ms (Soll 300 ms, ±50): `test_timeout_calls_back_once_and_late_answer_is_dropped`.
- Antwort nach Timeout: kein zweiter Callback, Zähler `lateReplies == 1`: selber Test.
- Zwei Peers über den Python-Hub: Anfrage, Ereignis, `unknown_type`, Handler-Exception → `busy`, `bad_payload` für unlesbaren Payload: `test_request_answers...`, `test_python_gets_answers_for_...`.
- Hub bricht ab: Wiederverbindung, Abos neu gesendet, `OnReady` wieder: `test_reconnect_after_hub_restart_resubscribes...`. `OnClosed` (`hub_unreachable`) nach 10,25 s: `test_hub_gone_for_longer_than_the_budget...`.
- Offene Anfrage bei Verbindungsverlust: `peer_gone` sofort: `test_pending_request_fails_with_peer_gone...`.
- 10.000 Anfragen ohne wachsende Handles: `test_10000_sequential_requests...`.

Messwerte (10.000 sequentielle Anfragen, `-s`-Lauf):

- 9,87 s gesamt, 0,99 ms je Anfrage, 0 Fehlantworten.
- Handles 163 → 163 → 163.
- `PendingCount` am Ende 0. Die Zahl aktiver Timer ist nicht direkt messbar, nur indirekt über Pending.

Stabilität: `tests/integration/test_peer.py` fünfmal hintereinander grün, je `10 passed` (25 s je Lauf).

Ready-Zeit mit `hubHwnd`-Weckruf: 1,1 bis 1,2 ms nach Start. Weckruf am Hub-Fenster nach `sys.hello`: 0,02 ms nach Abfrage (`test_hello_wakes_the_hub_window...`).

Abweichungen vom Paket:

- `Peer.__New(name, hubPipe, options := "")`, `Send(to, msgType, payload := "")`: Default statt `Map()`, da der Default ein Objekt ist. Parameter heißen `msgType` (Name `type` würde `Type()` verdecken). Im Vertrag nachgetragen.
- `options` als Map oder Objekt akzeptiert.
- Zusätzlich: `Peer.Close()`, `PendingCount`, Zähler `lateReplies`, `badFrames`, `droppedSends`, `closeReason`, `lastCloseReason`, `hubSession`.
- `Wake.Install` wird vom Peer selbst aufgerufen. Pro Prozess nur ein Peer.
- Schließen (`Close`) meldet `OnClosed` ebenfalls, nicht nur nach Ablauf der Frist.
- Ein `sys.welcome` mit `error` oder `ok:false` gilt als `denied`. Der Peer beendet die Verbindung, `OnClosed` folgt.
- Bei unlesbarem Frame mit lesbaren `from`/`id`/`type` und `cmd.` antwortet der Peer mit `bad_payload`. Das steht in PROTOKOLL Abschnitt 2.
- Wahrheitswerte gehen als `1`/`0` auf die Leitung (Json-Vertrag WI-02). Empfänger prüfen truthy. Dokumentiert in PROTOKOLL Abschnitt 2 und HOW-TO.

Nicht geprüft oder offen:

- `tests/support/pyhub.py` postet selbst keinen Weckruf. Die Tests nutzen die Unterklasse `WakingHub` in `test_peer.py`. Eine Änderung an `pyhub.py` (außerhalb meiner Pfade) wäre sauberer. Vorschlag für Phase 2 / WI-07.
- Der Wert 250 ms ohne Weckruf stammt aus der WI-04-Messung, für den Peer-Pfad nicht separat gemessen.
- `with WakingHub(...).start()` ruft `start()` vermutlich doppelt (`PyHub.__enter__`). Aus dem Code gelesen, nicht ausgeführt (HOW-TO, Status vermutet).
- Der Fall "alte Verbindung meldet nach dem Wechsel" ist nicht gezielt getestet.
- Die Bytes einer Antwort mit `1` statt `true` wurden nicht ausgegeben. Das ist aus dem Code von `Json.Emit` gelesen.
- Ein Bool-Typ im Json-Baustein wäre die saubere Lösung, ist aber ein Vertragswechsel für WI-02.
