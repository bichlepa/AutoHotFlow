# Architektur AutoHotFlow v2

Status: Entwurf, freigegeben als Grundlage für Phase 2 (Walking Skeleton), in Phase 2b ergänzt (WI-20, Entscheidungen E1 bis E8 in `work_items/phase2b/README.md`). Stand 2026-10-11.
Zielplattform: AutoHotkey v2, **nur 64 Bit** (E4, 2026-10-11). 32 Bit wird nicht unterstützt und beim Start abgewiesen (Umsetzung in WI-22). Begründung: Strukturen und DllCalls werden nur für 64 Bit getestet. Stock Interpreter, keine AHK_H-Erweiterungen.
Verwandte Dokumente: [PROTOKOLL.md](PROTOKOLL.md), [ELEMENT-API-V2.md](ELEMENT-API-V2.md), [TESTSTRATEGIE.md](TESTSTRATEGIE.md), [KONVENTIONEN.md](KONVENTIONEN.md), [MIGRATION.md](MIGRATION.md).

Kennzeichnung: **[M]** = gemessen oder im Spike bestätigt, **[V1]** = im v1-Code verifiziert, **[A]** = Annahme, die in Phase 2 geprüft wird.

---

## 1. Ziele

1. Deadlocks und Race Conditions können **konstruktiv nicht mehr entstehen**: kein geteilter Speicher, kein globales Lock, jedes Datum hat genau einen schreibenden Besitzer.
2. Kein blockierender Aufruf im Nachrichtenpfad. Datei-I/O und Dialoge laufen nie in der Engine.
3. Ein hängender oder abstürzender Prozess reißt keinen anderen mit. Das System erkennt ihn und reagiert definiert.
4. Alte Flows (`.json`) und Variablen (`.ahfvd`/`.ahfvar`) laden unverändert.
5. Das Elementformat der 114 Actions plus Conditions, Loops und Trigger lässt sich weitgehend mechanisch portieren.

Nicht-Ziele: neue Features, neues Flow-Dateiformat, Plugin-Sandbox gegen böswilligen Elementcode.

---

## 2. Entscheidungen

| # | Entscheidung | Begründung |
|---|---|---|
| D1 | **Mehrere Prozesse, keine Threads.** | AHK v2 hat keine Threads im selben Prozess. Pseudo-Threads sind kooperativ: eine blockierende Operation hält alles an. Echte Parallelität gibt es nur über Prozesse. |
| D2 | **Ein Editor-Prozess pro geöffnetem Flow.** | Mehrere Editoren sind gleichzeitig offen, auch nicht fokussierte müssen laufend aktualisiert werden. Ein Prozess pro Editor entkoppelt Zeichnen, Eingabe und Abstürze. Kosten **[M]**: ~30 ms Start, ~14 MB RSS, 0 % CPU im Leerlauf je Prozess. Das ist vernachlässigbar. |
| D3 | **Manager (Flow-Liste, Einstellungen, Import/Export) ist ein eigener Prozess.** | Wie der Editor: Dialoge und Baumansicht dürfen die Engine nie anhalten. |
| D4 | **Zeichnen läuft im Editor-Prozess, hinter einer schmalen `Renderer`-Schnittstelle.** | Siehe 2.1. Dadurch ist es später ohne Umbau des Editors in einen eigenen Prozess abtrennbar. |
| D5 | **IPC: Named Pipes (Byte-Modus, overlapped) für Daten, `PostMessage` nur als Weckruf.** | Siehe 2.2. `WM_COPYDATA` verworfen. |
| D6 | **Sterntopologie: der Supervisor ist der Hub.** Alle Prozesse verbinden sich mit ihm, er routet. | Hält Verbindungen auch bei Engine-Neustart stabil, einzige Stelle für Prozessüberwachung. Der Supervisor enthält keine Fachlogik und blockiert nie. |
| D7 | **Ein `storage`-Prozess besitzt alle Dateien** (Flows, Variablen, Einstellungen, Logs). | I/O nie im kritischen Pfad. Ein Schreiber pro Datei verhindert Dateikonflikte zwischen Prozessen. In v1 war das nur über das globale Lock gelöst, das dafür gehalten werden musste. |
| D8 | **Ein `triggerhost`-Prozess hält OS-Hooks, Hotkeys und Trigger-Timer.** | Low-Level-Hooks müssen schnell antworten, sonst entfernt Windows sie. Das darf nicht von Engine-Last abhängen. Trigger-Arten können später auf mehrere Hosts verteilt werden. |
| D9 | **Elemente laufen hybrid: `inline` in der Engine oder `worker` in einem eigenen Prozess.** | Siehe 2.3. Blockierende, riskante oder UI-zeigende Elemente laufen in Workern. Das entspricht dem v1-Muster „eigener Thread für AHK-Code“. |
| D10 | **Editor hält einen Entwurf, die Engine besitzt die committete Definition.** Änderungen laufen als Patches mit Revisionsnummer. | Siehe 4.2. Ein Editor pro Flow, daher keine Mehrschreiber-Konflikte. |
| D11 | **Flow-Dateiformat bleibt unverändert** (JSON, `ElementIDCounter` etc.). | Anforderung 4. Siehe 7. |
| D12 | **Ein Einstieg, Rollen per Parameter**: `AutoHotFlow.ahk --role=<name>`. | Ein kompiliertes Artefakt statt vieler. Der Supervisor startet sich selbst mit anderer Rolle. |
| D13 | **Tests mit pytest als e2e-Treiber plus kleine AHK-Unit-Tests.** | Siehe [TESTSTRATEGIE.md](TESTSTRATEGIE.md). |

### 2.1 Zeichnen im Editor-Prozess (D4)

Ausgangslage: v1 hatte einen zentralen Draw-Thread, der alle Flows zeichnete und dabei um dasselbe Lock konkurrierte. Das war eine Ursache der schlechten Performanz.

In v2 zeichnet jeder Editor-Prozess nur seinen eigenen Flow, mit eigenem Prozess und ohne geteilte Locks. Mehrere Editoren zeichnen damit parallel auf verschiedenen CPU-Kernen. Der verbleibende Nachteil: Ein langer Zeichenvorgang blockiert die Eingabe **desselben** Editors. Das mildern wir durch:

- Zeichnen nur bei Änderung (Dirty-Flag), Zusammenfassen mehrerer Änderungen auf einen Frame, Obergrenze ca. 30 Bilder/s.
- Der `Renderer` bekommt einen **unveränderlichen Szenen-Schnappschuss** (`Scene`: Elemente, Verbindungen, Ansicht, Zustände) und ein Ziel (HWND oder Bitmap). Er liest keinen Editor-Zustand direkt.

Trennbarkeit: Ersetzt man den Aufruf `Renderer.Draw(scene, target)` durch eine Nachricht `cmd.render.draw {scene}` an einen `render`-Prozess, der in ein gemeinsam genutztes Bitmap (File Mapping) rendert, ändert sich nur der Editor-Adapter. Der Renderer-Code bleibt gleich.

Kriterium für die Abtrennung **[A]**: Wenn ein Frame bei einem realistischen großen Flow (z. B. 300 Elemente) im Mittel über 16 ms liegt oder die Eingabe spürbar stockt, wird der Render-Prozess gebaut. Die Messung ist Teil von Phase 3 (Editor).

### 2.2 IPC (D5)

Verglichen: Named Pipes und `WM_COPYDATA`.

| Kriterium | Named Pipe | WM_COPYDATA |
|---|---|---|
| Richtung / Trennung | bidirektional, pro Verbindung getrennt | pro Richtung ein Fenster-Handle nötig |
| Blockieren | Schreiben in overlapped-Modus mit Timeout, Aufrufer bleibt handlungsfähig | `SendMessage` blockiert, bis der Empfänger die Nachricht verarbeitet hat. Ein hängender Empfänger hängt den Sender (genau der Deadlock, den wir vermeiden wollen). `PostMessage` ist nicht möglich, weil der Datenzeiger gültig bleiben muss. |
| Absturzerkennung | Gegenseite weg → `ERROR_BROKEN_PIPE` | nur über Fenster-Handle-Prüfung |
| Größe | frei (Rahmen mit Längenpräfix) | begrenzt durch Speicher, UIPI-Probleme bei erhöhten Prozessen |
| Aufwand | höher (DllCall, OVERLAPPED) | gering |

**Entscheidung:** Named Pipes. Der Aufwand wurde in einem Spike geprüft **[M]**:

- Ein AHK-v2-Prozess betreibt per `DllCall` einen overlapped Pipe-Server. Ein Python-Prozess verbindet sich mit `open(r"\\.\pipe\name", "r+b", buffering=0)`. Damit sind pytest-basierte e2e-Tests ohne Zusatzbibliothek möglich.
- Reines Polling (Timer 250 ms) ergibt Round-Trips um 250 ms. Mit `PostMessage` als Weckruf nach dem Schreiben sinkt die Round-Trip-Zeit auf **~0,3 ms** (Median).
- Der Spike liegt in `work_items/spikes/` (`pipe_server.ahk`, `client.py`).

Konsequenzen:

- Nach jedem Schreiben sendet der Sender `PostMessage(peerHwnd, WM_AHF_WAKE)`. Der Empfänger liest bei Weckruf **und** zusätzlich per Fallback-Timer (250 ms), damit ein verlorener Weckruf nichts blockiert.
- Die HWNDs werden im Handshake (`sys.hello`/`sys.welcome`) ausgetauscht.
- Pipes sind `PIPE_REJECT_REMOTE_CLIENTS`, der Name enthält eine Session-ID.

### 2.3 Elementausführung: inline oder worker (D9)

AHK v2 hat kein `await`. Ein Element, das `RunWait`, `WinWait`, einen Download oder einen Dialog nutzt, würde die Engine anhalten.

| Modus | Läuft in | Für | Regel |
|---|---|---|---|
| `inline` | Engine | schnelle, nicht blockierende Elemente (Variablen, Strings, Zahlen, Listen, Timer über `SetTimer`) | darf **nie** blockieren. Langes läuft über `ctx.After(ms, fn)` oder wird in Teile zerlegt. |
| `worker` | eigener Prozess aus einem Pool | blockierende, riskante oder UI-zeigende Elemente: Dialoge (`MsgBox`, `InputBox`, `FileSelect`), `RunWait`, Netzwerk, COM, DllCall, AHK-Skript | bekommt **ausgewertete Parameter** und eine explizite Importliste, liefert Ergebnis plus Exportvariablen zurück |
| `trigger` | triggerhost | alle Trigger | siehe [ELEMENT-API-V2.md](ELEMENT-API-V2.md) |

Das erfüllt die Vorgabe „keine UI-Dialoge aus der Engine“: Dialog-Elemente laufen im Worker. Die Engine „bittet die UI per Nachricht“. Der Worker ist der UI-Prozess dafür.

Eine falsch eingestufte Inline-Aktion fällt nicht still auf: Der Engine-Watchdog (6.2) meldet, wenn ein Elementaufruf länger als 250 ms im Engine-Prozess läuft, mit Klasse und Flow.

**Entscheidung E3 (2026-10-11):** Der Supervisor startet und beendet Worker-Prozesse auf Anfrage der Engine (elastischer Pool). Ein Worker, der einen Job bearbeitet, ist von der Ping-Prüfung ausgenommen. Fristen für Jobs hält die Engine. Details in WI-27.

---

## 3. Prozesse

| Rolle (`--role`) | Anzahl | Aufgabe | Besitzt | Tut niemals |
|---|---:|---|---|---|
| `supervisor` | 1 | Start, Überwachung, Neustart, Shutdown, Hub/Router, Tray-Symbol | Prozessliste, Session-ID | Fachlogik, Datei-I/O, Dialoge |
| `storage` | 1 | Dateizugriff, Log-Senke, Einstellungsdatei | alle Dateien unter dem Datenverzeichnis | Fachentscheidungen, Dialoge |
| `engine` | 1 | Flow-Definitionen (committed), Instanzen, Threads, Variablen, Ausführung inline-Elemente, Trigger-Soll-Zustand | Laufzeitzustand | blockieren, Dateien anfassen, Dialoge zeigen |
| `triggerhost` | 1 (später n) | Trigger scharf schalten, Ereignisse melden | OS-Handles der Trigger (Hotkeys, Hooks, Timer) | Flows ausführen |
| `manager` | 0..1 | Flow-Liste, Kategorien, Einstellungen, Import/Export, Log-Anzeige | Fensterzustand | Flows ausführen |
| `editor:<flowId>` | 0..n | Bearbeiten und Anzeigen eines Flows, Zeichnen | Entwurf des Flows, Undo/Redo, Ansicht (Zoom/Offset), Auswahl | Laufzeitzustand ändern |
| `worker:<n>` | 0..m (Pool) | blockierende/UI-Elemente ausführen | nur kurzlebige Kopie der Aufgabe | Zustand halten |

Der Supervisor ist der kleinste und einfachste Prozess. Er ist ein Hub, weil ein Neustart der Engine dann keine Verbindung der Clients zerstört. Fällt der Supervisor selbst aus, beenden sich alle Kinder nach kurzer Frist (Orphan-Guard, siehe 6.3).

---

## 4. Datenbesitz

**Ein Besitzer pro Datum.** Alle anderen bekommen Kopien oder Ereignisse, nie Referenzen.

| Datum | Besitzer (einziger Schreiber) | Kopien / Konsumenten |
|---|---|---|
| Flow-Definition (committed, mit `rev`) | engine | editor (Entwurf), manager (Metadaten für Liste) |
| Flow-Entwurf, Undo/Redo, Auswahl, Zoom, Offset | `editor:<flowId>` | – |
| Instanzen, Threads, Element-Ausführungsstatus | engine | UI per Ereignis (`evt.element.state`) |
| Variablen `instance`/`thread`/`loop` | engine | – (Worker bekommt Kopie der importierten) |
| Variablen `global`/`static` (Arbeitskopie) | engine | – |
| Variablen-Dateien auf Platte | storage | – (write-behind aus der Engine) |
| Flow-Dateien, Backups | storage | – |
| Einstellungen (Laufzeit) | engine | alle als read-only Kopie per `evt.settings.changed` |
| Einstellungen (Datei) | storage | – |
| Trigger-Handles (Hotkey, Hook) | triggerhost | engine kennt nur den Soll-Zustand |
| Prozessliste, Neustartzähler | supervisor | – |
| Sprachtexte | jede Rolle lädt `language/*.ini` selbst, read-only | – |

### 4.1 Zustandsänderungen sind Ereignisse

UIs rendern, was die Engine meldet. Ein Editor markiert ein Element nicht selbst als „running“, er empfängt `evt.element.state`. Ein neu verbundener oder neu gestarteter Client holt den Ist-Zustand per `cmd.engine.snapshot` (Resync), danach folgen Ereignisse mit steigender `seq`.

### 4.2 Bearbeitungsmodell (D10, E1)

- v1 verhält sich so **[V1]**: Der Editor ändert den „current state“ des Flows direkt im geteilten Speicher, die Ausführung liest bei jedem Schritt aus dem aktuellen Zustand. Änderungen während der Ausführung wirken sich also auf folgende Schritte aus.
- **Entscheidung E1 (2026-10-11): Ändern während der Ausführung ist erlaubt** (beobachtbares v1-Verhalten). Die Engine nutzt bei jedem Schritt die **neueste committete Revision** eines Flows. Umgesetzt in WI-21: Ein Lauf (`Executor._NewRun`) merkt sich nur die `flowId`. Jeder Schritt (Start eines Elements, Wahl der nächsten Verbindung) holt die Definition über `Executor._DefOf` aus der `FlowTable` der Engine. Eine neue Revision (`FlowRecord.Commit`) gilt damit beim nächsten Schritt aller laufenden Instanzen. Klasse und Parameter eines laufenden Elements stehen in `run["active"]` und bleiben die vom Start.
- v2 behält dieses beobachtbare Verhalten, aber ohne geteilten Speicher: Der Editor schickt nach jeder abgeschlossenen Benutzeraktion (Mausloslassen, Dialog OK) einen **Patch** `cmd.flow.patch {flowId, baseRev, ops}`. Die Engine wendet ihn atomar an, erhöht `rev` und antwortet mit der neuen `rev`. Die Engine liest bei jedem Schritt die neueste committete Revision. Jede Revision ist ein unveränderlicher Schnappschuss, es gibt keine halb geschriebenen Zustände.
- Bei `baseRev`-Konflikt (z. B. Manager hat umbenannt) lehnt die Engine ab und sendet den aktuellen Stand. Der Editor führt neu zusammen.
- Nur-Ansicht-Änderungen (Zoom, Offset) gehören dem Editor und werden mit „Speichern“ als `flowSettings` mitgeschrieben.
- Speichern ist ein expliziter Befehl: `cmd.flow.save`. Die Engine übergibt den Schnappschuss an `storage`, `storage` schreibt atomar (Temp-Datei + Umbenennen) und meldet `evt.flow.saved`.

**Semantik bei Änderungen während der Ausführung (Zielzustand nach WI-21).** Abgeglichen mit v1 (`v1/Source_Execution/Execution Task/Execution Task.ahk`, Zeilen aus dem Code gelesen, nicht ausgeführt). Abweichungen von v1 stehen in [MIGRATION.md](MIGRATION.md) (M-17, M-18).

| Fall | Verhalten in v2 | Verhalten in v1 |
|---|---|---|
| Laufendes Element (`running`), dessen Parameter oder Klasse geändert werden | läuft mit Klasse und Parametern zu Ende, mit denen es gestartet wurde; `Element_stop` mit denselben Werten | Parameter werden beim Start kopiert (`:72`) und aus der Kopie ausgeführt und gestoppt (`:246`, `:211`). Die Klasse für `Element_stop` kommt aber aus dem aktuellen Zustand (`:198`), siehe M-18 |
| Thread wartet (`ready`, v1 `starting`), Element wird geändert | startet mit den Werten, die im Moment des Starts gelten | liest Klasse und Parameter beim Start aus dem aktuellen Zustand (`:67`, `:72`) |
| Nächste Verbindung nach dem Ende eines Elements | aus der neuesten Revision | `:110`, `:115`, `:138` lesen den aktuellen Zustand |
| Thread wartet (`ready`), nächstes Element wurde gelöscht | endet mit Ergebnis `exception`, Meldung „element was removed“, `f1`-Log. Kein Dialog aus der Engine. Abweichung, siehe M-17 | `:67` liefert ein leeres Element, `:71` setzt den Thread auf `running`, `:88`–`:94` findet keine Funktion und ruft `MsgBox` auf, innerhalb der kritischen Sektion. Es wird keine Aufgabe eingereiht, der Thread bleibt dauerhaft `running` (vermutet, dass der Zugriff auf eine Eigenschaft des leeren Werts keinen Fehler wirft, nicht ausgeführt) |
| Laufendes Element wird gelöscht | läuft zu Ende. Danach findet es keine Verbindung, der Thread endet. Die Meldung nennt Element-ID und den Namen aus dem Start (M-18) | `:110` liefert kein Element, `:153`–`:166` beenden den Thread. Der Name im `f0`-Log bleibt leer (`:161`, vermutet) |
| Flow wird gelöscht | alle Instanzen werden gestoppt (Grund `flow.deleted`, `Executor.FlowDeleted`). Der Stopp wartet auf keine Quittung (`Executor._StopRun`), das Löschen kann also nicht an einer Frist scheitern. Verschwindet ein Flow aus der Tabelle, ohne dass `FlowDeleted` lief, stoppt der nächste Schritt der Instanz sie mit demselben Grund | `DeleteFlow` stoppt alle Instanzen (`Manage Flows.ahk:190`, `Instances and Threads.ahk:165`–`:188`), wartet höchstens 10 s, sonst bricht es ab und löscht nicht (`Manage Flows.ahk:192`–`:206`). Einen Grund gibt es in v1 nicht. Das Verhalten bei Fristablauf in v2 ist offen (siehe `work_items/STATUS.md`) |

### 4.3 Ausblick: Debugger (E1)

Der Debugger wird in Phase 2b **nicht** gebaut. Die folgenden Anforderungen dürfen spätere Entwürfe aber nicht verbauen:

- Ein **Ausführungstor** im Dispatcher der Engine: Vor jedem Element kann die Ausführung je Instanz oder Flow angehalten werden (Pause, Breakpoint an einem Element, Einzelschritt, künstliche Verzögerung nach jedem Element, z. B. 3 s). Pausieren wirkt an Elementgrenzen; ein laufendes Element (vor allem im Worker) läuft zu Ende.
- Während einer Pause können Clients alle Variablen einer Instanz lesen und ändern (Nachrichten an die Engine, die Engine besitzt die Variablen, Abschnitt 4).
- Bearbeiten während der Pause wirkt beim nächsten Schritt (folgt aus E1 und der Tabelle in 4.2).
- Die Ereignisse dafür (z. B. `evt.instance.paused`) und Befehle (`cmd.debug.*`) entwirft Phase 3 oder später.

---

## 5. Zustandsautomaten

Ungültige Übergänge werden **nicht** ausgeführt, sondern mit `a0`-Log abgewiesen. Die Tabellen sind normativ.

### 5.1 Instanz (`instance`)

| Von | Ereignis | Nach | Aktion |
|---|---|---|---|
| (neu) | `flow.start` oder Trigger akzeptiert (nach Ausführungsrichtlinie) | `running` | Thread für Trigger-Element anlegen |
| (neu) | Richtlinie `skip` und Flow läuft | (abgewiesen) | Callback „skipped“ |
| (neu) | Richtlinie `wait` und Flow läuft (E2, M-11) | `waiting` | in die Warteschlange des Flows einreihen (FIFO), `evt.instance.queued`, Antwort `waiting: true` |
| `waiting` | keine gestartete Instanz des Flows mehr (die vorige ist `ended`) und die Instanz ist die erste der Warteschlange | `running` | Thread für Trigger-Element anlegen, `evt.instance.started`. Fehlt der Flow oder der Trigger inzwischen, endet die Instanz ohne `started` (Grund `flow.deleted` bzw. `trigger removed`) |
| `waiting` | `flow.stop` / Flow gelöscht | `ended` | aus der Warteschlange entfernen, `evt.instance.ended`. Die Instanz hat keinen Thread |
| `running` | letzter Thread entfernt | `ended` | Instanz entfernen, `flow.executing` neu berechnen |
| `running` | `flow.stop` / Richtlinie `stop` / `x_InstanceStop` | `stopping` | alle Threads `stopping`. Wartende Instanzen des Flows werden vorher beendet |
| `stopping` | alle Threads entfernt | `ended` | Callback „stopped“ |
| `stopping` | Frist (2 s) ohne Quittung | `ended` | Worker hart beenden, loggen |
| `ended` | beliebig | – | ignorieren (loggen) |

### 5.2 Thread (`thread`, Zustände wie v1: starting, running, finished, stopping **[V1]**)

| Von | Ereignis | Nach | Aktion |
|---|---|---|---|
| `ready` (v1 `starting`) | Dispatcher wählt Thread | `running` | Element starten (inline oder Worker) |
| `running` | `ctx.Finish(result, msg)` | `finished` | Ergebnis speichern, Zähler und Zustand des Elements aktualisieren |
| `finished` | passende Verbindung gefunden | `ready` | nächstes Element setzen, bei mehr als einer Verbindung Thread klonen |
| `finished` | keine passende Verbindung | `removed` | bei Ergebnis `exception`: unbehandelt loggen und melden |
| `running` | Stopp der Instanz | `stopping` | `Element_stop` aufrufen oder Worker abbrechen |
| `stopping` | Stopp-Quittung oder Frist | `removed` | – |
| `ready` | Stopp der Instanz | `removed` | – |
| `finished`/`stopping`/`removed` | verspätetes `Finish` | (keine) | ignorieren, `f2`-Log (entspricht v1) |

Die Auswahl der nächsten Verbindung folgt exakt v1: Verbindungstyp gleich Ergebnis, bei Schleifen zusätzlich `fromPart` **[V1]**. Loop-Variablen werden beim Eintritt auf einen Stack gelegt und beim Verlassen (`tail`/`exception`) wiederhergestellt **[V1]**.

### 5.3 Prozess (durch den Supervisor überwacht)

`starting` → (`sys.hello`) → `ready` → (`sys.shutdown`) → `stopping` → `exited`. Abweichungen: `hung` (Ping-Timeout), `crashed` (Prozess weg oder Pipe gebrochen). Siehe 6.2.

---

## 6. Ablauf, Fehler, Beenden

### 6.1 Start

1. Einstieg `AutoHotFlow.ahk` (Rolle `supervisor`). Ein benannter Mutex stellt Einzelinstanz sicher. Ist schon eine Instanz da, leitet der Aufruf Kommandozeilenbefehle (v1: `AHFCommand`) per Pipe an sie weiter und endet.
2. Supervisor erstellt die Hub-Pipe und startet `storage`. `storage` meldet `sys.hello`, lädt Einstellungen und Verzeichnisindex.
3. Supervisor startet `engine`. Die Engine holt Einstellungen und alle Flow-Dateien über `storage` (Antworten, nie blockierend), lädt sie in den Speicher und meldet `evt.engine.ready`.
4. Supervisor startet `triggerhost`. Die Engine schickt `cmd.trigger.arm` für die Trigger aktiver Flows. Fehler pro Trigger werden zurückgemeldet, sie verhindern den Start nicht.
5. Supervisor startet `manager` (außer `--background`). Das Tray-Symbol hängt am Supervisor.
6. Jeder Schritt hat ein Timeout (Standard 10 s). Scheitert ein Pflichtprozess, meldet der Supervisor das über Tray-Hinweis und Log und beendet die Session sauber.

### 6.2 Fehlerbehandlung

| Szenario | Erkennung | Reaktion |
|---|---|---|
| Kindprozess stürzt ab | Prozess-Handle signalisiert oder Pipe gebrochen | Supervisor loggt, startet nach Richtlinie neu (max. 3 Versuche in 60 s), meldet `evt.process.crashed` |
| Engine stürzt ab | wie oben | Neustart. Laufende Instanzen sind verloren (Dokumentation in [MIGRATION.md](MIGRATION.md)). Clients erhalten `evt.engine.restarted {epoch}` und synchronisieren sich neu. Triggerhost wird neu armiert. |
| Prozess hängt | kein `sys.pong` auf 3 aufeinanderfolgende Pings (je 2 s) | Supervisor sendet `sys.shutdown`, nach 2 s `TerminateProcess`, dann wie Absturz. Hängt ein Editor, ist nur sein Fenster betroffen. |
| Anfrage ohne Antwort | Timeout der Korrelations-ID | Aufrufer erhält `res` mit `error.code = "timeout"`, nie ein endloses Warten |
| Pipe bricht | `ERROR_BROKEN_PIPE`/`NO_DATA` | Client versucht Wiederaufbau (Backoff 100 ms bis 2 s, max. 10 s), danach Rolle beendet sich |
| Worker bricht ab | Prozess weg | Engine meldet dem Thread `exception` mit Text „worker crashed“ |
| Element blockiert die Engine | Watchdog: Elementaufruf > 250 ms (Warnung), > 5 s (Fehler `f0`) | Hinweis auf Klasse und Flow, die Einstufung `inline` ist zu korrigieren |
| Elementcode wirft | `try/catch` um jeden Aufruf | Thread-Ergebnis `exception` mit Meldung (wie v1 `finishExecutionOfElement(..., "Exception", msg)`) |
| Ungültiger Zustandsübergang | Zustandsautomat | abgewiesen, `a0`-Log mit Kontext |
| Datei nicht schreibbar | `storage` meldet Fehler | `evt.storage.error`, Engine behält Arbeitskopie, UI zeigt Hinweis. Nie ein Dialog aus der Engine. |
| Unbekannte Nachricht | Dispatcher | `res` mit `error.code = "unknown_type"`, geloggt |

### 6.3 Beenden

Zwei Phasen, damit Benutzerentscheidungen nicht in harte Timeouts laufen:

1. **Prepare (abbrechbar, keine harte Frist):** Supervisor sendet `cmd.app.prepareExit` an Editoren und Manager. Ein Editor mit ungespeicherten Änderungen fragt den Benutzer. Der Benutzer kann abbrechen, dann endet der Vorgang, nichts wurde gestoppt.
2. **Shutdown (harte Frist, Standard 5 s gesamt):** Supervisor sendet `sys.shutdown {deadlineMs}`. Reihenfolge der Quittungen: Editoren/Manager, Engine (stoppt Instanzen mit je 2 s, schreibt Variablen zu `storage`), Triggerhost (deaktiviert alle Trigger), Worker, zuletzt `storage` (Queue leeren). Jeder Prozess quittiert mit `sys.bye` und beendet sich selbst.
3. Nach der Frist beendet der Supervisor übrige Prozesse hart. Das ist ungefährlich, weil es kein geteiltes Lock gibt und `storage` atomar schreibt (Temp-Datei + `MoveFileEx`).
4. **Orphan-Guard:** Jede Rolle prüft alle 2 s, ob der Supervisor noch lebt (Pipe). Sonst beendet sie sich nach 3 s. Beim Systemende (`WM_QUERYENDSESSION`) startet der Supervisor Schritt 2 sofort.

Der v1-Mechanismus `criticalSectionCounter` und die 4-Sekunden-`exit`-Notbremse entfallen.

---

## 7. Kompatibilität mit v1-Dateien

Geprüft an den 23 Flows in `v1/AppData/Saved Flows` und `Save.ahk` **[V1]**:

- Flow-Datei: JSON, UTF-8 ohne BOM, Einrückung 2. Wurzelschlüssel: `name`, `category` (als **Name**, nicht ID), `ElementIDCounter`, `flowSettings`, `allElements`, `allConnections`.
- Elemente haben `ID`, `type`, `class`, `x`, `y`, `name`, `StandardName`, `pars` (nur die von der Klasse deklarierten Parameter), `package`, `packageVersion`, optional `HeightOfVerticalBar` (Loop), `DefaultTrigger` (`trigger_manual`), `enabled` (Trigger).
- Verbindungen haben `ID`, `from`, `to`, `type`, `ConnectionType`, optional `fromPart`/`toPart`.
- **Werte sind gemischt als JSON-String und JSON-Zahl gespeichert.** In den 23 Beispieldateien stehen 17.453 Strings und 703 Zahlen (z. B. `"ElementIDCounter": "5"` und `"zoomFactor": "0.700000"` als Strings, `"DelimiterComma": 1` und `"x": 7` als Zahlen). `true`, `false` und `null` kommen nicht vor. v2 muss den Typ je Wert erhalten (AHK v2 unterscheidet `String`, `Integer`, `Float`, das macht das möglich). Round-Trip-Tests vergleichen geparste Struktur und Typen.
- Ein Schlüssel `CompabilityVersion` kommt in den vorhandenen Dateien nicht vor. Nach `Compatibility.ahk` ist ein fehlender Wert gleich „älteste Version“ (v1-Hooks sind leer). Die Hook-Struktur (`package`-spezifische Funktion) bleibt erhalten.
- Variablen: globale unter `<Datenverzeichnis>/Variables/<name>.ahfvd`, statische unter `<Datenverzeichnis>/Variables/<FlowID>/<name>.ahfvd` (z. B. `Flow 1010290492`). `.ahfvd` enthält JSON-Metadaten `{name, type}`, `.ahfvar` den Inhalt (bei `type=object` JSON).
- Export/Import `.ahf` ist ein ZIP (7z). Bleibt erhalten.
- Das Backup-Verhalten (bis 10 Dateien, `backup/`-Unterordner) bleibt.

Unbekanntes in Dateien (Schlüssel, die v2 nicht kennt) wird beim Laden **beibehalten und beim Speichern zurückgeschrieben**, damit ein Wechsel zwischen v1 und v2 nichts verliert.

**Entscheidung E8 (2026-10-11):** Wahrheitswerte gehen in v2 als echte JSON-Booleans auf die Leitung (WI-26). Das Flow-Dateiformat darf in v2 künftig vom v1-Format abweichen. Pflicht bleibt, dass alte Flows und Variablen laden. In Phase 2b ändert sich das **Schreibformat der Flows nicht**. Ein neues Schreibformat ist eine eigene Entscheidung in Phase 3, mit Versionskennung in der Datei. Bis dahin schreibt v2 das v1-Format. Ein Flow in einem neuen Format ist für v1 nicht mehr lesbar.

---

## 8. Ordnerstruktur

```
AutoHotFlow/
├─ AGENTS.md                # Kurzumriss für Agenten (Stand der Arbeit)
├─ README.md
├─ doc/                     # dauerhafte Dokumentation (dieses Verzeichnis)
├─ work_items/              # temporär: Pläne, Analysen, Spikes (nach der Portierung löschen)
├─ v1/                      # temporär: unveränderter v1-Stand als Referenz (am Ende löschen)
├─ src/
│  ├─ AutoHotFlow.ahk       # Einstieg, Rollen-Dispatch
│  ├─ core/                 # prozessübergreifende Bausteine, keine GUI
│  │  ├─ Json.ahk  Ids.ahk  Errors.ahk  Log.ahk  Args.ahk
│  │  └─ ipc/               # Pipe, Frame, Wake, Message, Dispatcher, Peer
│  ├─ supervisor/  engine/  storage/  triggerhost/  worker/
│  ├─ ui_common/            # Lang(), GUI-Helfer
│  ├─ manager/  editor/     # editor/render/ = Renderer-Schnittstelle (D4)
│  └─ elements/
│     ├─ base/              # AhfElement, Registry, Context
│     └─ default/{actions,conditions,loops,triggers}/
├─ assets/                  # Icons, language/*.ini, help (aus v1 übernommen, sobald gebraucht)
├─ tests/                   # siehe TESTSTRATEGIE.md
└─ tools/                   # Konverter, Übersetzungswerkzeuge, Audit-Skripte
```

**Ist-Stand am Ende von Phase 2 (WI-17, verglichen mit dem Dateibaum, verifiziert):** Die Struktur oben ist weiter das Ziel. Abweichungen und Lücken:

- **Entscheidung E6 (2026-10-11):** Der Triggerhost (WI-14) wird früh in Phase 3 mit den echten Triggern gebaut, nicht in Phase 2b.
- Vorhanden: `src/AutoHotFlow.ahk`, `core/` (zusätzlich `Role.ahk`, `RoleRegistry.ahk`, `Time.ahk`; `ipc/` zusätzlich `Deferred.ahk`, `PipeConnection.ahk`, `PipeListener.ahk`, `FrameReader.ahk`, `FrameWriter.ahk`), `supervisor/`, `engine/` (mit `core/` für Zustandsautomaten, Flowmodell, Scheduler), `storage/`, `worker/`, `manager/` (nur `StubManager.ahk` und `StubGui.ahk`), `elements/base/`.
- **Nicht vorhanden (Phase 3 oder später):** `triggerhost/` (WI-14 optional, nicht gebaut; die Rolle ist in `RoleRegistry.ahk` ein Platzhalter), `editor/` (Platzhalter-Rolle), `ui_common/`, `assets/`, `elements/default/{actions,conditions,loops,triggers}/`. Statt `elements/default/` gibt es `elements/skeleton/` mit acht Demo- und Testelementen (`Trigger_Manual`, `Action_Sleep`, `Action_Do_nothing`, `Action_Test*`).
- `tools/` enthält bisher nur `ahkrun.py` und `ahf_dialogwatch.py` (Laufwächter), keine Konverter.
- **Bewusste Abweichung von der Einbindregel unten:** Der Einstieg `src/AutoHotFlow.ahk` bindet die Testrollen aus `tests/integration/helpers/` ein (`EchoRole`, `CrasherRole`, `HangerRole`, `SlowShutdownRole`). Sie sind nur mit `--test-roles` registriert (PROTOKOLL 4.1b). Das ist eine Abhängigkeit von `src/` auf `tests/`; vor einem Release auflösen (Phase 3: eigener Testeinstieg oder bedingtes Einbinden).
- `core/RoleRegistry.ahk` enthält zwei Klassen (`RoleRegistry`, `PlaceholderRole`), entgegen der Konvention "eine Klasse pro Datei" (`KONVENTIONEN.md`). Offen.
- `manager` wird im Einstieg registriert, nicht in `core/RoleRegistry.ahk` (wie `engine`, `storage`, `worker`), damit `core/` keine Rollenordner einbindet.

Regel: Ein Ordner unter `src/` ist ein Prozess-Rollen- oder Bibliotheks-Modul. `core/` darf nichts aus Rollenordnern einbinden. Rollenordner binden nur `core/`, `ui_common/` (nur UI-Rollen) und `elements/` ein, nie einander.

---

## 9. Leistungsbudgets (Ziele, in Phase 2 gemessen)

- Nachrichtenlatenz lokal (Engine ↔ Client über Hub): Median unter 5 ms, 99 % unter 50 ms.
- Engine-Zustandsänderung bis Editor-Neuzeichnen: unter 50 ms bei nicht blockiertem Editor.
- Idle-CPU des Gesamtsystems ohne laufende Flows: unter 1 %.
- Speicher: unter 100 MB insgesamt bei 5 offenen Editoren.

**Entscheidung E5 (2026-10-11):** Das Ziel für die Idle-CPU gilt für das **Gesamtsystem**. Gemessen 0,23 % (8 CPUs, WI-16), erfüllt. Die Lesart „Summe in Prozent eines Kerns“ (1,8 %) ist damit nicht mehr das Maßstab. Eine Optimierung ist kein Muss und steht als Beobachtungspunkt in `work_items/STATUS.md`.

---

## 10. Risiken und offene Punkte

| # | Risiko / offener Punkt | Gegenmaßnahme |
|---|---|---|
| R1 | Overlapped Named Pipes in AHK v2 sind fehleranfällig (OVERLAPPED-Struktur, Handle-Lebensdauer). | In Phase 2 als getestete Bibliothek `core/ipc` mit Python-Gegenstelle, Fault-Injection-Tests. Spike liegt vor. |
| R2 | Zeichnen im Editor-Prozess könnte bei sehr großen Flows ruckeln. | `Renderer`-Schnittstelle, Messung in Phase 3, Trennkriterium in 2.1. |
| R3 | Alle Elementklassen in jeder Rolle einzubinden kostet Parse-Zeit und Speicher (v1: 29.000 Zeilen). | Messen. Falls zu groß: Metadaten und Laufzeitcode je Rolle in getrennte Dateien. |
| R4 | Elemente mit Callback-Bedarf an die Engine (`GetVariable` im Worker) brauchen Request/Response ohne `await`. | Callback-API `ctx.Request(...)` mit Timeout. Worker dürfen blockierend warten (eigener Prozess), die Engine nie. |
| R5 | Ausführungsrichtlinien (`default`, `parallel`, `skip`, `wait`, `stop`): genaue Semantik muss aus `newInstance` und `executionTask` übernommen werden. | Charakterisierungstests gegen v1 vor dem Port (Phase 3). |
| R6 | Verhaltensabweichung: Engine-Absturz verliert laufende Instanzen. | In [MIGRATION.md](MIGRATION.md) dokumentiert. v1 hatte denselben Effekt beim Absturz des Gesamtprozesses. |
| R7 | Installer/Kompilierung (Ahk2Exe v2, ein Artefakt mit Rollenparameter). | Spätere Phase, Einstieg ist dafür bereits vorbereitet (D12). |
