# WI-31 Engine wartet auf `storage` und setzt abgebrochenes Laden fort (F-31, F-24)

Größe: S · Hängt ab von: – · Blockiert: WI-32

## Ziel

Die Engine lädt ihre Flows immer, egal wie lange `storage` zum Start braucht, und auch, wenn `storage` während des Ladens neu startet. Kein unnötiges `evt.storage.error` beim normalen Start.

## Funde aus dem Review (2026-10-12)

- **Die Engine gibt nach ~2,5 s für immer auf [gelesen]:** `Engine._LoadFlows` fragt `cmd.storage.flows.list`. Ist `storage` noch nicht verbunden, antwortet der Hub `not_found`, die Engine wiederholt `LOAD_TRIES` (5) mal im Abstand von `LOAD_RETRY_MS` (500 ms) und loggt dann "flow list not loaded after 5 tries, engine stays not ready" (`_RetryLoad`). Danach lädt sie nie wieder.
- **F-24 [beobachtet in WI-24]:** Die Engine meldet sich beim Start oft vor `storage`; der erste `flows.list` endet mit `not_found`, dazu ein `evt.storage.error`.
- **F-31 [vermutet, passt]:** Im langen seriellen Gesamtlauf (Last auf dem Rechner) waren die Flows einmal je Lauf nach 20 s nicht geladen. Das passt zu einem Start von `storage`, der länger als ~2,5 s dauert. Beim nächsten Auftreten im Log nach der Zeile oben suchen.
- **Folge im Produkt:** Ein langsamer Start nach der Windows-Anmeldung (Virenscanner, viele Autostarts) kann AutoHotFlow ohne Flows hochfahren lassen.
- **Abgebrochenes Laden [gelesen]:** Seit WI-24 meldet die Engine nach einem `timeout`/`peer_gone` alle übrigen Dateien sofort als Fehler (`storageDown`). Startet `storage` danach neu, werden die fehlenden Flows nie mehr geladen.

## Aufgaben

1. **Zuerst rot zeigen:** Integrationstest, in dem `storage` 5 s nach der Engine startet: heute wird die Engine nie bereit. Zweiter Test: `storage` wird während des Ladens von 20 großen Flows (`tests/data/bigflows/`) beendet und neu gestartet: heute fehlen danach Flows.
2. **Auf `storage` warten:** Die Engine abonniert das Topic `process` immer (heute nur mit Worker-Pool) und beginnt das Laden, sobald `storage` bereit ist: `evt.process.ready` mit Name `storage`, oder beim eigenen Start über `cmd.process.list` (erst abonnieren, dann fragen, PROTOKOLL 5a). Ohne feste Obergrenze der Versuche; solange `storage` fehlt, kein `evt.storage.error` (F-24), höchstens eine `a1`-Logzeile je Zeitraum.
3. **Laden fortsetzen:** Bricht das Laden durch `timeout`/`peer_gone` ab, wartet die Engine wieder auf `storage` und lädt nur die noch fehlenden Dateien (die Liste neu holen, schon geladene Flows bleiben). `evt.engine.ready` erst, wenn jede Datei der Liste ein Ergebnis hat (geladen oder echter Datei- oder Parse-Fehler).
4. Die Staffelung aus WI-24 (`LOAD_PARALLEL`) bleibt.
5. Umschauen: Gibt es andere Stellen, die beim Start auf eine Rolle warten und mit fester Versuchszahl aufgeben (Stub, Debug-Rolle, `DiagReport`, Supervisor-Log)? Im Ergebnis auflisten, offensichtliche gleich mitbeheben.

## Akzeptanzkriterien

- Beide Tests aus Aufgabe 1 rot, dann grün.
- Normaler Start: kein `evt.storage.error` mehr (Test, der das prüft; den Filter für F-24 in den bestehenden Tests entfernen).
- F-24 in `STATUS.md` geschlossen, F-31 mit dem Ergebnis aktualisiert (geschlossen, wenn in WI-32 kein Fall mehr auftritt).

## Doku

`doc/ARCHITEKTUR.md` 6.1 (Start: die Engine wartet auf `storage`), `doc/PROTOKOLL.md` 4.3 (`evt.storage.error` nur für echte Fehler), `doc/HOW-TO.md` bei Bedarf.
