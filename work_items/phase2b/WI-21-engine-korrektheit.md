# WI-21 Engine: Loop-Stack, Wiedereintritt, neueste Revision, `wait`

Größe: M · Hängt ab von: WI-20 (Semantik E1) · Blockiert: –

## Ziel

Vier Korrekturen in der Engine, bevor echte Loops, Patches und Ausführungsrichtlinien in Phase 3 darauf aufbauen.

## 1. Loop mit mehreren `tail`- oder `exception`-Verbindungen [verifiziert]

**Fund:** `Scheduler.Advance` (`src/engine/core/Scheduler.ahk`) ruft `thread.Loops.Pop()` innerhalb der Schleife über alle passenden Verbindungen auf, also einmal **je Verbindung** auf demselben Thread. Hat ein Loop zwei `tail`-Verbindungen und den Stack der Tiefe 1, wirft der zweite `Pop` `AhfError("LoopStack.Pop: loop stack is empty")`. Ergebnis (mit einem Wegwerfskript nachgewiesen): Der Thread steht `ready` auf dem ersten Ziel, der zweite Zweig wird nie angelegt. In der Engine läuft die Ausnahme durch `_OnFinish` in den Aufrufer; das Ergebnis ist ein verlorener Zweig plus eine irreführende Logzeile.

Herkunft: v1 macht dasselbe (`Execution Task.ahk`, Zeilen 119 bis 126: `LoopVariable_RestoreFromStack` je passender Verbindung), setzt bei leerem Stack aber still `""` (M-14 macht das in v2 zum Fehler).

**Korrektur:** Den Stack einmal vor der Schleife über die Verbindungen herunternehmen (wenn der Loop verlassen wird), danach klonen.

**Zweite Abweichung von v1 (dokumentieren):** v1 legt beim Eintritt in einen Loop den Stack immer auf den **Ursprungs**-Thread (`LoopVariable_AddToStack(OneInstanceID, OneThreadID)`, Zeilen 142 bis 145), auch wenn der Klon in den Loop läuft. v2 legt ihn korrekt auf den Ziel-Thread. Das ist eine stille Fehlerbehebung: Eintrag in `doc/MIGRATION.md` (nächste freie M-Nummer).

**Tests** (`tests/ahk/engine_scheduler.test.ahk`): Loop mit zwei `tail`-Verbindungen (beide Threads `ready`, Stack beider Threads hat die Tiefe vor dem Eintritt, Loop-Variablen wiederhergestellt), dasselbe mit `exception`, Verzweigung beim Eintritt in einen Loop (nur der Ziel-Thread bekommt den Push).

## 2. Doppelte Ausführung durch Wiedereintritt in `Executor.Tick` [gelesen, nicht reproduziert]

**Fund:** `Engine` ruft `Executor.Tick` über zwei verschiedene Timer-Funktionen auf (`_tickFn` für `Kick`, `_safetyFn` alle 100 ms, `src/engine/Engine.ahk`). AHK lässt einen Timer nicht sich selbst unterbrechen, wohl aber einen anderen Timer-Thread, sobald dieser länger als ~15 ms läuft (`doc/HOW-TO.md`, F-09/F-10). `Executor.Tick` prüft `thread.State != "ready"` und ruft danach `_Dispatch`. `_Dispatch` wertet die Rückgabe von `thread.Dispatch()` **nicht** aus. Unterbricht ein zweiter Tick zwischen Prüfung und Dispatch und startet denselben Thread, startet der erste Tick das Element ein zweites Mal (der fehlgeschlagene Übergang wird nur als `a0` geloggt).

**Korrektur:** `_Dispatch` bricht ab, wenn `thread.Dispatch()` false liefert. Zusätzlich `Tick` gegen Wiedereintritt sperren (Flag plus "noch einmal laufen", wie `PipeConnection.Pump`), oder beide Timer auf eine Funktion zurückführen. Danach die übrigen Timer und Handler der Engine auf dasselbe Muster prüfen (Prüfen und Ändern in getrennten Zeilen, dazwischen unterbrechbar) und das Ergebnis im "Ergebnis"-Abschnitt auflisten.

**Tests:** Unit-Test, der `Tick` aus einem laufenden Element heraus erneut aufruft (Element, dessen `Run` den Tick auslöst): jedes Element läuft genau einmal. Stresstest `test_parallel_instances` unverändert grün.

## 3. Neueste Revision bei jedem Schritt (E1) [gelesen]

**Fund:** `Executor.StartFlow` legt die Definition beim Start in `run["flow"]` ab (`Executor._NewRun`). Alle Schritte (`_Dispatch`, `Scheduler.Advance`, Parameter, Klasse) lesen diese Kopie. Nach E1 muss jeder Schritt die neueste committete Revision lesen.

**Korrektur:** Der Lauf merkt sich nur die `flowId`. Jeder Schritt holt die aktuelle Definition aus der `FlowTable` (über den Besitzer `Engine`). Die Fälle der Semantiktabelle aus WI-20 umsetzen (gelöschtes nächstes Element, gelöschter Flow). Die Parameter eines laufenden Elements bleiben die vom Start (sie liegen schon in `run["active"]`).

**Tests:** Da die Patch-Operationen erst in Phase 3 kommen, auf Unit-Ebene: einen `FlowRecord` zwischen zwei Schritten durch eine neue Definition ersetzen und prüfen, dass der nächste Schritt die neue Verbindung nimmt, und dass ein gelöschtes nächstes Element zu `exception` führt. Falls `Executor` dafür einen Test-Besitzer braucht (Attrappe für `Emit`, `Kick`, `flows`, `workers`), ihn in `tests/ahk/` anlegen.

## 4. Ausführungsrichtlinie `wait` (E2, M-11) [gelesen]

**Heute:** `Executor.StartFlow` antwortet bei `wait` mit `busy` ("not supported in WI-10").

**v1-Semantik** (Kommentar in `src/engine/core/ExecutionPolicy.ahk`): Bei `wait` wird eine neue Instanz angelegt, aber nur die erste laufende Instanz eines Flows läuft weiter; die übrigen warten, bis sie endet. In v1 war das unerreichbar (M-11), die Absicht ist aber klar.

**Vorschlag für v2** (im Paket festlegen und dokumentieren):
- Neuer Instanzzustand `waiting` in der Tabelle `doc/ARCHITEKTUR.md` 5.1 und in `Instance.Transitions`: `new → waiting`, `waiting → running`, `waiting → ended` (Stopp).
- `cmd.flow.start` antwortet `{instanceId, waiting: true}`. Ereignis beim Einreihen z. B. `evt.instance.queued`, `evt.instance.started` erst beim Übergang nach `running`.
- Reihenfolge FIFO je Flow. `cmd.flow.stop` beendet laufende **und** wartende Instanzen (Grund wie heute). `executing` ist wahr, solange eine Instanz läuft, stoppt oder wartet.
- Die Richtlinie wird bei der Entscheidung gelesen (wie heute über `ExecutionPolicy.Decide`).
- Keine Obergrenze der Warteschlange in 2b (v1 hatte keine); als Beobachtungspunkt notieren.

**Tests:** Unit (`ExecutionPolicy`, `Instance` mit `waiting`), Integration (`tests/integration/test_engine.py`): drei Starts mit `wait` laufen nacheinander, Ereignisreihenfolge geprüft, Stopp beendet auch die wartenden.

**Doku:** `doc/PROTOKOLL.md` 4.2 und 4.3, `doc/ARCHITEKTUR.md` 5.1, `doc/MIGRATION.md` M-11 (Status umgesetzt).

## 5. Kleinigkeit: veralteter `active`-Eintrag bei Worker-Fehler [gelesen]

`WorkerBridge.Run` kann einen Job synchron beenden (Fehler beim Senden, `_Finish` im `catch`) und trotzdem die `execId` zurückgeben. `Executor._DispatchWorker` trägt den Job danach in `run["active"]` ein, obwohl der Thread schon weitergelaufen ist. Harmlos, aber unsauber: `Run` gibt bei sofortigem Fehler `""` zurück oder der Aufrufer prüft, ob der Job noch existiert. Wird WI-27 ohnehin umgebaut, kann das dort erledigt werden (im Ergebnis vermerken).

## Akzeptanzkriterien

- Alle Tests oben grün, Gesamtlauf grün, Stresstests (`-m stress`) grün.
- `doc/ARCHITEKTUR.md` 5.1 und 5.2, `doc/PROTOKOLL.md`, `doc/MIGRATION.md` angepasst.
