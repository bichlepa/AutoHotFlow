# WI-33 Worker enden mit der Engine (E10), Fristen nach Stillstand (F-16, E12)

Größe: S · Hängt ab von: WI-30 (gleiche Dateien im Supervisor) · Blockiert: WI-32

## 1. Worker enden mit der Engine (E10)

**Heute [gelesen, WI-27]:** Endet die Engine, bleiben ihre Worker leben, bis eine neue Engine sie beim Start (`WorkerBridge.Start`, `cmd.process.list`) beenden lässt. Bleibt die Engine dauerhaft weg (Neustartgrenze erreicht), bleiben Worker mit offenen Dialogen bis zum Ende der Sitzung stehen; ihr Ergebnis nimmt niemand mehr an.

**Entscheidung E10:** Endet der Engine-Prozess (unerwartet oder geplant, außerhalb des Beendens der Sitzung), beendet der Supervisor sofort alle lebenden `worker:*` (Grund z. B. "engine gone", Meldung als `evt.process.exited` mit `reason`, kein Absturz, zählt nicht für Exit-Code 5). Beim Beenden der Sitzung bleibt die Reihenfolge der Ränge unverändert.

**Aufgaben:** Umsetzen in `src/supervisor/` (an der Stelle, an der das Ende der Engine erkannt wird). `WorkerBridge.Start` in der neuen Engine bleibt als zweite Sicherung.

**Tests:** Engine hart beenden, während ein Worker einen hängenden Job hat (`Action_TestHangWorker`): Worker ist binnen 1 s weg; die neue Engine baut den Pool auf, ein neuer Job läuft. Engine bis zur Neustartgrenze beenden: keine Worker bleiben übrig.

## 2. Fristen nach einem Stillstand des Supervisors (F-16, E12)

**Heute [gelesen, WI-22]:** Nur der Heartbeat erkennt einen Stillstand des Supervisors (Lücke zwischen zwei Ticks größer als `PING_EVERY_MS`, z. B. Standby oder langer Rückstau) und setzt seine Zeitstempel zurück. Andere Fristen laufen nach der Wanduhr weiter und können nach dem Aufwachen sofort ablaufen:
- `Shutdown.deadlineAt` (hartes Beenden der Kinder),
- `Hub.Request` (über `SetTimer`, z. B. `cmd.app.prepareExit` mit 10 Minuten),
- Frist für `sys.hello` neuer Verbindungen (`Hub.Tick`) und die Startfrist der Kinder (`Children.STARTUP_MS`),
- weitere, die das Paket findet (`DiagReport`, Warten auf `storage`, ...).

**Aufgaben:**
1. Die Stillstandserkennung an **eine** Stelle legen (Tick des Supervisors) und alle Fristinhaber benachrichtigen. Jede Frist wird um die Dauer des Stillstands verlängert (Restzeit bleibt erhalten), statt sofort abzulaufen.
2. Für Fristen über `SetTimer` (`Hub.Request`): Restzeit merken und den Timer neu setzen, oder auf eine Fristliste umstellen, die der Tick prüft. Im Paket entscheiden und begründen.
3. Alle Fristinhaber im Ergebnis auflisten (gefunden, angepasst oder bewusst nicht).

**Tests:** Supervisor 8 s einfrieren (`psutil`), während eine Anfrage `cmd.app.prepareExit` mit verkürzter Frist (`--prepare-limit`, z. B. 5 s) offen ist: Nach dem Fortsetzen läuft sie nicht sofort ab, sondern bekommt ihre Restzeit. Dasselbe für eine neue Verbindung ohne `sys.hello`.

**Hinweis für die Rollen (nicht Teil):** Auch die Fristen der Rollen (`Peer.Request` über `SetTimer`) laufen nach einem Standby alle auf einmal ab. Das ist hinnehmbar (Antwort `timeout`, der Aufrufer wiederholt). Als Beobachtungspunkt in `STATUS.md` aufnehmen.

## Akzeptanzkriterien

- Tests aus 1 und 2 grün, Gesamtlauf grün.
- F-16 in `STATUS.md` geschlossen, E10 umgesetzt.

## Doku

`doc/ARCHITEKTUR.md` 6.2 (Stillstand), 6.4 (Worker-Pool: Ende mit der Engine), `doc/PROTOKOLL.md` 4.1a (`evt.process.exited` mit `reason` "engine gone").
