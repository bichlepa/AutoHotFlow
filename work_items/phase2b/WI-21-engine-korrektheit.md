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

## Ergebnis

Status: Punkte 1 bis 5 abgeschlossen (2026-10-11). Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**. Keine Eskalation.

Commits: `9e84422` (Punkt 1), `26cada9` (Punkte 2 und 5), `58c17d9` (Punkt 3), `a06623f` (Punkt 4); Dokumentation und HOW-TO im Abschlusscommit. Läufe: `python -m pytest tests -q` (parallel) 486 passed, 1 skipped in 47,7 s; `python -m pytest tests -m stress -q` 10 passed in 376 s (`test_parallel_instances` unverändert); `tools/arch_check.py` 0 Verstöße. Je Commit lief ein Gesamtlauf (Punkt 1: 463 passed; Punkte 2 und 5: 466 passed, die damals noch nicht umgesetzten Testdateien waren ausgelagert, ein Verstoß der Architekturprüfung im ersten Lauf wurde danach behoben; Punkt 3: 475 passed; Punkt 4: 486 passed). Nach den Läufen waren keine Testprozesse übrig (nur ein fremder `AutoHotkeyU32.exe`, gestartet 17:23, nicht von den Tests, nicht angefasst).

### Punkt 1: Loop-Stack [verifiziert, rot dann grün]

- Fund bestätigt, dazu ein zweiter Fehler: Der Klon für die zweite Verbindung entstand **nach** dem Push des ersten Zweigs und erbte ihn (Tiefe 1 statt 0). Test `Advance: branching into a loop pushes only the loop thread (loop connection first)` war rot.
- Korrektur in `Scheduler.Advance`: einmal `Pop` vor dem Klonen, alle Klone vor jeder Änderung, danach Element und Push je Ziel.
- Tests (`tests/ahk/engine_scheduler.test.ahk`, vor der Korrektur 4 von 5 rot): zwei `tail`-Verbindungen, zwei `exception`-Verbindungen, Verlassen eines Loops innerhalb eines äußeren Loops, Verzweigung in einen Loop (Loop-Verbindung zuerst, Loop-Verbindung zuletzt; der zweite Fall war schon grün und bleibt als Regression).
- v1-Abweichung als **M-19** in `doc/MIGRATION.md`.

### Punkt 2: Wiedereintritt [jetzt mit Test belegt, vorher nur gelesen]

- Test `Tick: a tick that interrupts before the dispatch does not start an element twice` (Haken in `FakeWorkers.Usable`, das zwischen Prüfung und Start liegt): vor der Korrektur **2 statt 1** Start, danach 1.
- Korrektur: `_Dispatch` bricht ab, wenn `thread.Dispatch()` false liefert. `Executor.Tick` ist gegen Wiedereintritt gesperrt (Flag plus "nochmal" in `Critical`, Freigabe auch bei Ausnahme). Beide Timer bleiben, rufen aber dieselbe gesperrte Funktion.
- Test-Besitzer: `tests/ahk/helpers/EngineOwner.ahk` (Attrappe für `Emit`, `Kick`, `flows`, `workers`), gemeinsame Bausteine in `tests/ahk/helpers/ExecutorKit.ahk`.
- **Prüfung der übrigen Timer und Handler** (gelesen, Muster "Prüfen und Ändern in getrennten Zeilen"):
  - Behoben: `ThreadState.TryTransition`, `ThreadState.Finish`, `Instance.TryTransition` (Prüfen und Setzen in `Critical`, Meldung danach); `Executor._EndRun` (`Has` dann `Delete`: konnte `evt.instance.ended` doppelt senden); `Executor._DispatchWorker` (Eintrag, `Run` und `execId` als ein Schritt).
  - `Engine._Tick`, `Engine.Emit`, `Executor._Advance`: schon geschützt oder fangen Fehler.
  - Nicht behoben, siehe F-13 und F-14: `_OnFinish` (`Has` dann `Delete` auf `run["active"]`), `_ElementStarted`/`_ElementStopped` (Zähler lesen und schreiben in getrennten Zeilen), `WorkerBridge.OnDone`/`_Finish`/`_OnRunAnswer` (`Get` dann `Delete`), `ExecContext.Finish` (`finished` prüfen, dann setzen), `Ids.Next` (Zähler erhöhen, dann erneut lesen). Alle gelesen, **nicht reproduziert**. Die letzten beiden liegen außerhalb von `src/engine/`.

### Punkt 3: neueste Revision [verifiziert]

- `Executor._NewRun` hält nur noch `flowId` (und `triggerId`). `Executor._DefOf(run)` liest bei jedem Schritt `owner.flows.Get(flowId).Def`: Dispatch (Klasse, Parameter), Wahl der Verbindung (`_Advance`), Worker-Prüfung in `Tick`. `FlowRecord.Commit(def)` setzt Definition und erhöht `Rev` (Phase 3 ruft es beim Patch auf); `FlowTable.Remove` für gelöschte Flows.
- Semantik, umgesetzt und getestet (`tests/ahk/engine_revision.test.ahk`, 5 von 6 Fällen vor der Korrektur rot): nächste Verbindung aus der neuesten Revision; Thread `ready`, Element gelöscht: Ergebnis `exception`, Meldung "element was removed", `f1`-Log "element 'x' was removed before it could start"; Thread `ready`, Klasse geändert: startet mit der neuen Klasse; laufendes Element gelöscht: läuft zu Ende, Thread endet; laufendes Element behält Parameter für `Stop` (war schon grün, Regression); `Executor.FlowDeleted(flowId)` stoppt mit Grund `flow.deleted`; Flow aus der Tabelle verschwunden: der nächste Schritt stoppt die Instanz mit demselben Grund.
- **Fristablauf beim Löschen (offener Punkt aus WI-20):** In v2 wartet `_StopRun` auf keine Quittung und gibt Threads sofort frei. Eine Frist, nach der das Löschen abbricht (v1: 10 s), gibt es daher nicht; das Löschen kann nicht scheitern. Festgehalten in `doc/ARCHITEKTUR.md` 4.2. Bekommt der Stopp in WI-27 eine Quittung mit Frist, ist Fristablauf hartes Ende (`Instance.Expire`, 5.1), danach wird gelöscht. Das ist meine Entscheidung im Rahmen des Pakets, bitte bestätigen.
- Der Engine fehlt noch ein Befehl zum Löschen eines Flows (Phase 3): `FlowDeleted` und `FlowTable.Remove` sind vorbereitet, aber die Engine ruft sie nicht auf.

### Punkt 4: `wait` [verifiziert]

- Instanzzustand `waiting` (`new → waiting`, `waiting → running`, `waiting → ended`), `Instance.Wait()`; `Stop` einer wartenden Instanz endet sofort. `cmd.flow.start` antwortet `{instanceId, waiting: true}` (Feld nur bei Wartenden), Ereignis `evt.instance.queued {flowId, instanceId, position}`, `evt.instance.started` erst beim Übergang nach `running`.
- **Reihenfolge (offener Punkt aus WI-20):** FIFO je Flow nach Startzeit (Array je Flow), nicht nach der Reihenfolge der Instanzliste wie in v1 (die in v2 eine nach Schlüsseln sortierte Map wäre). Nachrücken, wenn keine gestartete Instanz des Flows mehr existiert (auch bei vorher parallel gestarteten Instanzen). Das Nachrücken läuft in `Tick`, nicht im Aufruf, der die vorige Instanz beendet: keine Verschachtelung bei langen Warteschlangen, serialisiert durch die Sperre aus Punkt 2.
- Stopp (`cmd.flow.stop`, `StopAll`) beendet zuerst die wartenden, dann die laufenden; so rückt beim Stopp nichts nach. `executing` ist wahr, solange eine Instanz läuft, stoppt oder wartet. Eine nachrückende Instanz liest Flow und Trigger aus der neuesten Revision; fehlt der Trigger oder der Flow, endet sie ohne `started` (Grund `trigger removed` bzw. `flow.deleted`, `f1`-Log).
- Tests: `tests/ahk/engine_wait.test.ahk` (6 Fälle), `engine_states.test.ahk` (Tabelle 5.1 mit `waiting`, 3 neue Fälle), `tests/integration/test_engine.py`: `test_wait_policy_queues_the_starts_and_runs_them_one_after_the_other`, `test_wait_policy_stop_ends_the_running_and_the_waiting_instances` (ersetzen den Test, der `busy` erwartete). Vorher alle rot (Methoden fehlten bzw. `busy`).
- Doku: `doc/PROTOKOLL.md` 4.2 und 4.3, `doc/ARCHITEKTUR.md` 5.1, `doc/MIGRATION.md` M-11 (umgesetzt).
- Keine Obergrenze der Warteschlange (Beobachtungspunkt, in `STATUS.md` zu führen, WI-29).

### Punkt 5: veralteter `active`-Eintrag [verifiziert]

Hier erledigt (nicht in WI-27): Der Eintrag wird vor `workers.Run` angelegt, `_OnFinish` entfernt ihn bei sofortigem Ende, `execId` wird nur eingetragen, wenn der Eintrag noch der eigene ist. Test `Worker: a job that ends at once leaves no active entry` (vorher 2 statt 1 Einträge).

### Nicht geprüft

- Das Verhalten in der **laufenden Engine** (Prozess) mit echter Unterbrechung der Timer: Der Doppelstart ist nur mit dem Haken in der Attrappe nachgewiesen, nicht in einem echten Lauf beobachtet.
- `soak` nicht gelaufen. Ein serieller Gesamtlauf (ohne `-n`) ist nicht gelaufen: Die Vorgabe "einmal seriell bei Zeitänderung" ist nicht erfüllt. Das Paket ändert das Zeitverhalten nur durch Sperren, aber das ist nicht gemessen.
- `cmd.flow.toggle` mit Richtlinie `wait` (stoppt bei laufendem Flow wie bisher, auch die Wartenden) ist nicht gesondert getestet.

### Abweichungen vom Plan

- `Instance.TryTransition`, `ThreadState.TryTransition` und `ThreadState.Finish` laufen in `Critical` (Punkt 2, über den Wortlaut hinaus, aber Teil der geforderten Prüfung der übrigen Handler).
- Punkt 5 schon hier erledigt.
- Die Tests liegen in eigenen Dateien (`engine_executor`, `engine_revision`, `engine_wait`), damit jeder Punkt mit grünem Gesamtlauf committet werden konnte.

### Neue Funde (nächste freie Nummer laut `STATUS.md`: F-12)

- **F-12 [gelesen]** `Scheduler.Advance` ruft `Pop` vor dem Übergang `finished → ready`. Bei leerem Stack (M-14) wirft es; der Thread bleibt `finished`, die Ausnahme läuft durch `_Advance` und `_OnFinish` zum Aufrufer (in `ElementRunner.Run` führt das zu einem zweiten `Finish`, das als `a0` ignoriert wird). M-14 verspricht "Thread endet mit `exception`", das ist so nicht umgesetzt. Offen: `Advance` fängt den Fehler und beendet den Thread mit `exception`.
- **F-13 [gelesen]** Weitere Prüfen-dann-Ändern-Stellen ohne Schutz (siehe Punkt 2): `Executor._OnFinish`/`_StopRun` (`Has`, dann `Delete` auf `run["active"]` wirft bei Gleichzeitigkeit), `_ElementStarted`/`_ElementStopped` (Zähler), `WorkerBridge` (`Get`, dann `Delete`). Nur bei einer Unterbrechung nach über 15 ms Laufzeit, nicht reproduziert.
- **F-14 [gelesen, `src/core/` und `src/elements/`, nicht geändert]** `Ids.Next` erhöht den Zähler und liest ihn eine Zeile später erneut; eine Unterbrechung dazwischen kann dieselbe ID zweimal vergeben (Nachrichten-, Instanz-, Thread-IDs). Ebenso `ExecContext.Finish`: `finished` prüfen und setzen sind getrennte Zeilen.
- **F-15 [beobachtet]** Für ein gelöschtes Element sendet die Engine im `exception`-Pfad `evt.element.state` (`running`, dann `exception`), obwohl es das Element nicht mehr gibt. Clients müssen unbekannte Element-IDs ignorieren. Bewusst so gelassen (gleicher Pfad wie bei unbekannter Klasse).

### Offene Punkte

- Löschen eines Flows: Befehl fehlt (Phase 3); Entscheidung zu Fristablauf siehe Punkt 3 (Bestätigung durch den Projektinhaber).
- F-12 bis F-14 entscheiden; WI-29 überträgt sie in `STATUS.md`.
- Serieller Gesamtlauf nach dem nächsten Paket, das Zeitverhalten ändert (WI-22).
