# WI-30 Sauberes Beenden: keine letzte Nachricht geht verloren (F-26)

Größe: M · Hängt ab von: – · Blockiert: WI-33, WI-32

## Ziel

Was eine Rolle vor ihrem Ende sendet, kommt an: `sys.bye`, `evt.worker.done` "stopped", die letzten `evt.instance.ended`, die letzten Logzeilen, in Phase 3 die Variablen, die die Engine beim Beenden zum Storage schreibt (M-06). Der Supervisor bewertet ein Prozessende erst, wenn er alles gelesen hat, was das Kind geschrieben hat. Damit ist F-26 (`clean: false` bei sauberem Ende, rund 1 %) behoben.

## Funde aus dem Review (2026-10-12) [gelesen, Ursache vermutet, nicht nachgestellt]

**Ursache A, Seite der Rolle:** `Role._FinishShutdown` (`src/core/Role.ahk`) sendet `sys.bye` und ruft sofort `peer.Close()`, dann `ExitApp`. `PipeConnection.Close` → `_Teardown` ruft `CancelIoEx` (ein noch laufender Schreibvorgang wird abgebrochen) und verwirft die Warteschlange (`this._queue := []`, Kommentar "drops queued frames"). Konnte der Rahmen nicht sofort geschrieben werden (Puffer der Pipe voll, oder es warten schon Rahmen davor), geht das `bye` verloren und alles, was davor in der Warteschlange stand. Betroffen sind laut STATUS genau die gesprächigen Rollen (`manager`-Stub protokolliert jedes Ereignis, `storage` verteilt Logzeilen an das Topic `log`). Dasselbe Muster: `Worker.OnShutdown` sendet `evt.worker.done` "stopped" kurz vor dem `bye`; `Engine.OnShutdown` erzeugt mit `StopAll` viele Ereignisse; `Role._Exit` schließt ebenfalls sofort.

**Ursache B, Seite des Supervisors:** `Supervisor._Tick` ruft seit F-11 `hub.Pump()` vor `children.Tick`. Läuft in diesem Moment aber bereits eine `Pump` derselben Verbindung (der Tick-Timer hat einen Pump-Thread des Weckrufs unterbrochen), setzt die Sperre in `PipeConnection.Pump` nur `_pumpAgain` und kehrt sofort zurück. `Children._OnGone` bewertet dann `rec["bye"]`, bevor das `bye` gelesen ist. Der deterministische Test aus WI-22 (`tests/ahk/supervisor_tick.test.ahk`) deckt diesen Fall nicht ab.

Welche der beiden Ursachen F-26 in den Läufen erzeugt hat, ist offen. Beide werden behoben.

## Aufgaben

1. **Zuerst rot zeigen**, je Ursache ein Test:
   - A: Auf Ebene `PipeConnection` (AHK-Unit oder Integration mit einer Python-Gegenstelle aus `tests/integration/helpers/rawpipe.py`, die langsam oder erst später liest): Viele Rahmen senden, dann schließen; der letzte Rahmen muss ankommen. Heute geht er verloren.
   - B: Erweiterung von `tests/ahk/supervisor_tick.test.ahk` oder ein eigener Test: Prozessende wird bewertet, während eine Pump der Verbindung läuft (simuliert über den Zustand `_pumping`); `clean` muss stimmen.
2. **Leeren vor dem Schließen (Ursache A):** `PipeConnection` bekommt einen Abschluss, der keine neuen Rahmen mehr annimmt, die Warteschlange weiter über Timer schreibt und erst schließt, wenn sie leer ist oder eine Frist abgelaufen ist (z. B. `CloseWhenFlushed(timeoutMs, onDone)`). Nie blockierend (kein `FlushFileBuffers` auf der Pipe, das wartet ohne Frist auf den Leser).
3. **Rollen nutzen es:** `Role._FinishShutdown` sendet `bye`, schließt dann über den neuen Abschluss und ruft `ExitApp` im Rückruf (Frist: Rest der Shutdown-Frist, höchstens z. B. 1000 ms; Begründung im Code). Für `Role._Exit` prüfen, ob dasselbe sinnvoll ist (bei Hub-Verlust gibt es nichts zu leeren). `Storage._FinishShutdown` (eigene Variante) entsprechend.
4. **Supervisor bewertet erst nach dem letzten Byte (Ursache B):** Ein Prozessende wird erst ausgewertet, wenn die Verbindung des Kindes geschlossen ist (`onLinkLost`, das kommt erst nach dem Lesen bis zum Ende der Pipe), oder nach einer kurzen Nachfrist ab Prozessende (Vorschlag 500 ms), falls das Kind nie verbunden war oder die Verbindung nicht endet. Bis dahin bleibt der Zustand unverändert; die Zeit bis zur Meldung `evt.process.exited`/`crashed` wächst um höchstens die Nachfrist. Prüfen, dass die Fristen des Beendens (`Shutdown`) und der Neustart davon nicht verzögert werden, außer um diese Nachfrist.
5. Test aus WI-22/WI-18 (`test_shutdown.py`) **100-mal** wiederholen (`AHF_FAULT_REPEAT`), ohne `clean: false`. Zusätzlich ein Test: Engine mit vielen laufenden Instanzen beenden, jedes `evt.instance.ended` kommt beim Beobachter an; Worker mit laufendem Job beenden, `evt.worker.done` "stopped" kommt bei der Engine an.

## Akzeptanzkriterien

- Die Tests aus Aufgabe 1 waren rot und sind grün.
- 100 Wiederholungen von `test_shutdown.py` ohne `clean: false`; F-26 in `STATUS.md` geschlossen (mit Zahl).
- Gesamtlauf parallel und seriell grün (bekannte wackelnde Tests aus WI-32 ausgenommen, im Ergebnis benannt).

## Doku

`doc/ARCHITEKTUR.md` 6.3 (Beenden: Rolle leert vor dem Ende, Supervisor bewertet nach dem letzten Byte), `doc/PROTOKOLL.md` 4.1 (`sys.bye`, Zeitpunkt von `evt.process.exited`), `doc/HOW-TO.md` (Eintrag: "Close verwirft die Warteschlange", "Sperre gegen Wiedereintritt macht 'erst pumpen' wirkungslos").
