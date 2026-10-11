# WI-27 Worker-Pool-Lebenszyklus

Größe: L · Hängt ab von: WI-22, WI-23 · Blockiert: Port der Worker-Elemente in Phase 3 (Dialoge, Downloads, AHK-Skripte, RunWait)

## Ziel

Der Worker-Pool funktioniert im Produkt ohne Eingriffe: Worker werden bei Bedarf gestartet, nach Absturz ersetzt, nach einem Abbruch oder einer Fristüberschreitung beendet, und ein lange blockierender Worker wird nicht als hängend erschossen. Entscheidung E3: **Der Supervisor startet und beendet Worker auf Anfrage der Engine; ein Worker im Job ist von der Ping-Prüfung ausgenommen; die Engine hält die Fristen.**

## Funde [gelesen]

1. **Niemand startet Worker.** Die Engine nimmt `--workers=n` (`Engine._PoolSize`), aber der Supervisor gibt die Option nicht weiter (`Supervisor._RoleOpts`) und startet keine `worker:n`. Nur die Tests starten Worker selbst (`tests/integration/test_worker.py`). Im Produkt endet jedes Worker-Element mit "worker not available".
2. **Kein Ersatz nach Absturz.** `WorkerBridge` setzt den Slot auf `down`; nur `evt.process.ready` macht ihn wieder `idle`, und der Supervisor startet Worker nicht neu (`Children.AUTO_RESTART` nur `storage`, `engine`). Ein Slot, der einmal `down` ist, bleibt es.
3. **Abbruch ohne Wirkung bei blockierenden Workern.** `WorkerBridge.Cancel` setzt den Slot nach `ORPHAN_MS` (2 s) auf `down`, der Prozess (z. B. mit offener `MsgBox`) läuft weiter. `doc/ARCHITEKTUR.md` 5.1 verlangt "Frist 2 s ohne Quittung → Worker hart beenden"; die Engine darf aber keine Prozesse beenden.
4. **Neustart der Engine:** Laufende Worker-Jobs der alten Engine sind verwaist. Die neue Engine hält die Slots für `idle`, `cmd.worker.run` trifft auf `busy`, der Slot wird `down`, das späte `evt.worker.done` des alten Jobs wird verworfen. Der Pool bleibt geschädigt.
5. **Heartbeat erschießt blockierende Worker.** Ein Worker, der länger als 6 s am Stück blockiert (Download, synchroner COM-Aufruf, langer `DllCall`), beantwortet keine Pings und wird beendet ("worker crashed"). `MsgBox`, `InputBox` und `RunWait` pumpen Nachrichten und sind unkritisch (`doc/HOW-TO.md`, Worker-Abschnitte). Entscheidung in WI-11 war "keine Toleranz"; E3 ändert das.

## Entwurf (im Paket ausarbeiten, zuerst in `doc/ARCHITEKTUR.md` und `doc/PROTOKOLL.md`, dann Code)

- **Neue Befehle an den Supervisor**, nur für den Absender `engine` und nur für Namen `worker:*` erlaubt (sonst `denied`):
  - `cmd.process.spawn {role: "worker"}` → `{ok, name}` (der Supervisor vergibt die Nummer).
  - `cmd.process.kill {name, reason}` → `{ok}` (TerminateProcess, Meldung wie heute über `evt.process.*`).
- **Busy-Meldung des Workers:** Der Worker meldet dem Supervisor Beginn und Ende eines Jobs (z. B. `sys.busy {busy}`), der Heartbeat prüft Pongs eines beschäftigten Workers nicht. Alternativ meldet die Engine es dem Supervisor; im Paket entscheiden und begründen. Ein beschäftigter Worker, dessen Prozess stirbt, wird weiter über den Prozess-Handle erkannt.
- **Pool-Regeln in der Engine** (`WorkerBridge`): Obergrenze N (Option, Standard z. B. 4, später Einstellung), Zahl warmer Worker W (Standard 1). Alle beschäftigt und weniger als N vorhanden → neuen anfordern; der Thread wartet `ready` wie heute. Überzählige freie Worker enden nach einer Leerlaufzeit (z. B. 60 s).
- **Abbruch:** `cmd.worker.cancel`; kommt binnen `ORPHAN_MS` kein `evt.worker.done`, fordert die Engine `cmd.process.kill` an und bei Bedarf Ersatz.
- **Jobfrist:** optional je Element (`timeoutMs`), sonst keine (v1 hatte keine). Ablauf → wie Abbruch, Ergebnis `exception` "worker timeout".
- **Engine-Neustart:** Die neue Engine fragt `cmd.process.list` und beendet alle vorhandenen `worker:*` (Waisen der alten Epoche), dann baut sie den Pool neu auf. Einfacher und sicherer als Übernehmen.
- **Absturz eines Workers:** Slot entfernen, laufendes Element `exception` "worker crashed" (wie heute), Ersatz bei Bedarf. Neustartstürme begrenzen (z. B. höchstens 5 Starts in 60 s, dann `exception` "worker not available" und `a0`-Log).
- **Beenden:** unverändert (Worker Rang 3). Ein beschäftigter Worker meldet `stopped` vor `sys.bye` (wie heute).

## Tests (`tests/integration/test_worker.py`, `tests/fault/`)

- Produktstart ohne Testoptionen: ein Worker-Element läuft (Pool startet bei Bedarf), Zeit bis zum Start des ersten Jobs gemessen (Ziel unter 300 ms kalt).
- `Action_TestBlockWorker` blockiert länger als 6 s am Stück: kein `hung`, Element endet normal.
- Abbruch eines hängenden Workers (`Action_TestHangWorker`): Prozess nach Frist beendet, Ersatz verfügbar, nächster Job läuft.
- Worker-Absturz während eines Jobs: `exception`, Ersatz, nächster Job läuft.
- Engine-Neustart während eines Worker-Jobs: keine Waisen danach (Prozessliste), neuer Job läuft.
- Mehr Jobs als N: die überzähligen warten und laufen nacheinander, Obergrenze nie überschritten.
- `cmd.process.spawn`/`kill` von einem anderen Absender als `engine`: `denied`.
- Leerlauf: überzählige Worker enden nach der Leerlaufzeit (Zeit im Test per Option verkürzen).

## Doku

`doc/ARCHITEKTUR.md` 2.3, 3, 5.1 (Frist und hartes Beenden), 6.2; `doc/PROTOKOLL.md` 4.1 (neue Befehle, Rechte), 4.5 (Umsetzung WorkerBridge neu); `doc/HOW-TO.md`. Den Abschnitt "Entscheidung für WI-11: keine Heartbeat-Toleranz" im Kopf von `src/worker/Worker.ahk` anpassen.
