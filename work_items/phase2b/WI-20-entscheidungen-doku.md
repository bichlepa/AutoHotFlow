# WI-20 Entscheidungen und Beobachtungsliste dokumentieren

Größe: S · Hängt ab von: – · Blockiert: WI-21 (Semantik von E1)

## Ziel

Die Entscheidungen E1 bis E8 (`README.md` dieses Ordners) stehen dauerhaft in `doc/`, damit spätere Pakete und Phase 3 sich darauf beziehen. Die bewusst zurückgestellten Punkte werden als Beobachtungsliste festgehalten. Reine Dokumentation, kein Code.

## Aufgaben

### 1. `doc/ARCHITEKTUR.md`

- **Zielplattform** (Kopf): nur AutoHotkey v2 **64 Bit** (E4). Begründung kurz: Strukturen und DllCalls werden nur für 64 Bit getestet.
- **4.2 Bearbeitungsmodell** (E1): Klarstellen, dass die Engine bei jedem Schritt die **neueste** committete Revision nutzt. Heute hält der Code die Definition beim Start der Instanz fest (`Executor._NewRun`, Feld `flow`); das ändert WI-21. Die Semantik für Änderungen während der Ausführung festlegen und als Tabelle aufschreiben. Vorschlag (vorher in v1 nachsehen, wie sich v1 verhält, und Abweichungen in `MIGRATION.md` eintragen):

  | Fall | Verhalten |
  |---|---|
  | Laufendes Element, dessen Parameter geändert werden | läuft mit den Parametern zu Ende, mit denen es gestartet wurde |
  | Nächste Verbindung nach dem Ende eines Elements | aus der neuesten Revision |
  | Thread, dessen nächstes Element gelöscht wurde (Zustand `ready`) | endet mit Ergebnis `exception`, Meldung "element was removed", `f1`-Log |
  | Laufendes Element wird gelöscht | läuft zu Ende, danach findet es keine Verbindung (Thread endet) |
  | Flow wird gelöscht | alle Instanzen werden gestoppt (Grund `flow.deleted`) |

  v1-Verweis: `v1/Source_Execution/Execution Task/Execution Task.ahk` liest Elemente und Verbindungen bei jedem Schritt aus dem "current state" (`_getElementFromState`, `_getConnectionFromState`).
- **Neuer Abschnitt "Ausblick: Debugger"** (E1): Anforderungen, die spätere Entwürfe nicht verbauen dürfen:
  - Ein **Ausführungstor** im Dispatcher der Engine: Vor jedem Element kann die Ausführung je Instanz oder Flow angehalten werden (Pause, Breakpoint an einem Element, Einzelschritt, künstliche Verzögerung nach jedem Element). Pausieren wirkt an Elementgrenzen; ein laufendes Element (vor allem im Worker) läuft zu Ende.
  - Während einer Pause können Clients alle Variablen einer Instanz lesen und ändern (Nachrichten an die Engine, die Engine besitzt die Variablen, ARCHITEKTUR 4).
  - Bearbeiten während der Pause wirkt beim nächsten Schritt (folgt aus E1).
  - Die Ereignisse dafür (z. B. `evt.instance.paused`) und Befehle (`cmd.debug.*`) entwirft Phase 3 oder später.
- **2.3 / 3 Worker:** Grundsatz E3 kurz nennen (Supervisor startet und beendet Worker auf Anfrage der Engine), Details folgen in WI-27.
- **7 Kompatibilität / D11** (E8): v2 muss alle v1-Flows und Variablen laden. Ein eigenes v2-Schreibformat ist künftig erlaubt (Entscheidung in Phase 3, mit Versionskennung in der Datei). Bis dahin schreibt v2 das v1-Format. Hinweis: Ein in einem neuen Format gespeicherter Flow ist für v1 nicht mehr lesbar.
- **8 Ist-Stand:** Triggerhost kommt früh in Phase 3 (E6).
- **9 Leistungsbudgets:** Idle-CPU gilt für das Gesamtsystem (E5), gemessen 0,23 %.

### 2. `doc/MIGRATION.md`

- M-11 (`wait`): Status "vom Projektinhaber bestätigt (2026-10-11), Umsetzung WI-21".
- Abweichungen aus der Semantik von E1 (falls v1 anders reagiert) als neue Einträge.

### 3. `work_items/STATUS.md`

- Abschnitt "Entscheidungen": E1 bis E8 ergänzen (mit Datum).
- Neuer Abschnitt **"Beobachtungsliste"** (E7). Je Punkt: Inhalt, warum zurückgestellt, woran man erkennt, dass er wichtig wird, was dann zu tun ist:
  - **F-02** Pipe beim Start unter Last nicht nach 2 s verfügbar: seit den ersten Läufen nicht wieder aufgetreten, vermutlich Last des Testrechners. Wieder ansehen, wenn er in parallelen Läufen (WI-18) auftritt.
  - **`deadlineMs` von `sys.shutdown`** wird von den Rollen nicht ausgewertet: Der Supervisor erzwingt die Frist hart. Erst nötig, wenn eine Rolle ihre Aufräumarbeit an die Frist anpassen muss.
  - **`tests/support/pyhub.py` ohne Weckruf:** reines Testwerkzeug, Tests nutzen `WakingHub`.
  - **Idle-CPU optimieren:** Möglich wäre, den Sicherheitstimer der Engine (100 ms) nur bei laufenden Instanzen aktiv zu lassen. Kein Muss (E5).
  - **Manuelle GUI-Prüfung des Manager-Stubs:** Wegwerf-Code, Anleitung in `work_items/phase2/WI-13-ui-stub.md`. Kein Blocker.
  - **Sporadischer Dialog-Test** `test_msgbox_is_captured_and_closed`: beobachten.
  - **F-05 und F-07** (Änderungen in `src/core/` ohne Absprache): im Review am 2026-10-11 gelesen, ohne Befund. Bestätigung durch den Projektinhaber offen.
- "Nächste Schritte" auf Phase 2b umstellen.

### 4. `AGENTS.md` und `work_items/HANDOVER.md`

- `AGENTS.md`: Werkzeuge "nur 64 Bit", Hinweis auf `work_items/phase2b/README.md` im aktuellen Stand (falls noch nicht vorhanden).

## Akzeptanzkriterien

- Jede Entscheidung E1 bis E8 ist an genau einer Stelle in `doc/` (oder `STATUS.md` für E7) beschrieben, die anderen Stellen verweisen darauf.
- Die Semantiktabelle zu E1 ist vollständig und mit v1 abgeglichen (Abweichungen in `MIGRATION.md`).
- Keine Codeänderung.

## Ergebnis

Status: abgeschlossen (2026-10-11). Kennzeichnung: **verifiziert** = gelesen oder getestet, **vermutet**, **nicht geprüft**. Keine Codeänderung, kein Gesamtlauf (Auftrag: reine Dokumentation; `python -m pytest tests/test_architecture.py -q`: 27 passed).

### Erledigt

- **`doc/ARCHITEKTUR.md`:** Kopf mit E4 (nur 64 Bit) und Stand 2026-10-11. E3 in 2.3 (Verweis WI-27). 4.2 mit E1 (Ist-Stand `Executor._NewRun` verifiziert, `src/engine/Executor.ahk:84` und `:323`), Semantiktabelle (7 Fälle, v2 und v1 je mit Zeilenbeleg), neuer Abschnitt 4.3 „Ausblick: Debugger“ (E1). E8 in 7, E6 in 8, E5 in 9.
- **`doc/MIGRATION.md`:** M-11 Status auf „vom Projektinhaber bestätigt (2026-10-11, E2), Umsetzung WI-21“. Neu: M-17 (wartender Thread, Element gelöscht: v1 MsgBox und Hänger) und M-18 (Klasse und Name während der Ausführung).
- **`work_items/STATUS.md`:** Kopf auf Phase 2b, Abschnitt „Phase-2b-Pakete“, Abschnitt „Entscheidungen Phase 2b“ mit E1 bis E8 und Ort der Beschreibung je Entscheidung, Abschnitt „Beobachtungsliste (E7)“ mit allen Punkten aus Abschnitt 3 und F-11 (Verweis WI-22), „Letzter Gesamtlauf“ auf WI-19 (458 passed, 48,4 s), Bekannte Probleme korrigiert (siehe unten), „Nächste Schritte“ auf Phase 2b umgestellt.
- **`AGENTS.md`:** Zeile AHK v2 um „Nur 64 Bit (E4)“ ergänzt. Der Verweis auf `work_items/phase2b/README.md` war schon vorhanden.
- **`work_items/phase2b/README.md`:** Fortschritt „[x] WI-20“.
- `work_items/HANDOVER.md` ist nicht geändert (der Auftrag beschreibt nur Änderungen an `AGENTS.md`, siehe offene Punkte).

### Abweichungen vom Vorschlag (mit Begründung)

1. **Semantiktabelle, Zeile „nächstes Element gelöscht“ (Thread `ready`):** Das Zielverhalten bleibt wie vorgeschlagen (`exception`, „element was removed“, `f1`). Die v1-Spalte zeigt aber etwas anderes: `Execution Task.ahk:67` liefert für ein gelöschtes Element einen leeren Wert, `:71` setzt den Thread auf `running`, `:88`–`:94` findet keine Funktion `Element_run_` und ruft `MsgBox` auf, innerhalb der kritischen Sektion (Start `:15`, Ende `:235`). Es wird keine Aufgabe eingereiht, der Thread bleibt `running`. Das ist ein Hänger in v1, kein Ergebnis `exception`. Als M-17 vermerkt.
2. **Zusätzliche Zeile „Parameter oder Klasse geändert, Thread wartet noch“:** v1 liest beim Start aus dem aktuellen Zustand (`:67`, `:72`). Das ist eine Lücke im Vorschlag.
3. **Zeile „laufendes Element, Parameter geändert“:** Die Parameter sind beim Start kopiert (`:72`) und bleiben für Ausführung und Stopp maßgeblich (`:246`, `:211`). Abweichung: `Element_stop_<Klasse>` bekommt in v1 die Klasse aus dem aktuellen Zustand (`:198`). Als M-18 vermerkt.
4. **Zeile „Flow wird gelöscht“:** v1 hat eine Frist von 10 s, danach bricht `DeleteFlow` ab, ohne zu löschen (`Manage Flows.ahk:192`–`:206`). Das war nicht im Vorschlag. Das Verhalten in v2 ist offen und steht in `STATUS.md`. Ein Grund `flow.deleted` existiert in v1 nicht (Callback „stopped“, `Execution Task.ahk:220`–`:224`).
5. **Korrektur einer Aussage in `STATUS.md` (vor dieser Arbeit):** „Die Rollen werten `deadlineMs` nicht aus“ stimmt nicht. `Storage.OnShutdown` nutzt die Frist (`src/storage/Storage.ahk:62`–`:63`). Engine (`src/engine/Engine.ahk:76`) und Manager-Stub (`src/manager/StubManager.ahk:99`) werten sie nicht aus. Korrigiert in Beobachtungsliste und Bekannte Probleme.
6. **F-02:** Die Aussage „seit den ersten Läufen nicht wieder aufgetreten“ stützt sich auf WI-18 (Endstand: 5 parallele Gesamtläufe grün, kein F-02-Fall). Die Ausfälle in WI-18 Runde 1 waren andere Tests (Dialog-Wächter, `test_shutdown`).
7. **E7 und Idle-CPU:** Der Vorschlag nennt „Idle-CPU“ als Beobachtungspunkt. Da E5 das Thema als erfüllt schließt, steht dort nur die optionale Optimierung, mit dem Hinweis „kein Muss“.

### Belege (Zeilenverweise)

- v1 `Execution Task.ahk`: `:31` (Policy an der Wurzel), `:67`–`:72` (Klasse, Parameter beim Start), `:88`–`:94` (MsgBox bei fehlender Funktion), `:110`, `:115`, `:138` (aktueller Zustand bei Verbindungen), `:153`–`:166` (kein Treffer, Thread endet), `:198` (Klasse beim Stopp), `:211` (`Element_stop_`), `:220`–`:224` (Callback „stopped“), `:246` (Ausführung mit Kopie der Parameter).
- v1 weitere: `Instances and Threads.ahk:18` (Policy an `flowSettings`, bestätigt M-11), `:165`–`:188` (Stopp aller Instanzen), `Manage Flows.ahk:190`–`:206` (Löschen mit 10-s-Frist).
- v2: `src/engine/Executor.ahk:84`, `:323`–`:328` (`_NewRun`, Feld `flow`), `src/engine/Engine.ahk:33` (SAFETY_MS 100), `:76` (OnShutdown), `src/storage/Storage.ahk:62`–`:63`, `src/manager/StubManager.ahk:99`, `src/supervisor/Supervisor.ahk:179`–`:189` (F-11).
- Tests: `tests/support/test_client_hub.py` als einziger Nutzer von `PyHub` (grep, verifiziert).

### Offene Punkte

- **v1-Verhalten bei Eigenschaftszugriff auf einen leeren Wert** (`:67`–`:68`, `:161`): vermutet, dass kein Fehler geschieht. Nicht ausgeführt. Die Tabelle bleibt richtig, weil in beiden Fällen kein `exception` entsteht. Die Zeile ist entsprechend markiert.
- **v1 nicht ausgeführt:** Das Laufzeitverhalten von v1 ist nur aus dem Code gelesen. `tools/ahkrun.py` startet nur AHK v2, und AGENTS.md verbietet das direkte Starten von AHK-Skripten. Eine Bestätigung in v1 wäre ein eigener Schritt (Projektinhaber).
- **Reihenfolge bei `wait` (WI-21):** v1 nimmt „die erste Instanz“ in der Reihenfolge von `_getAllInstanceIds` (`Execution Task.ahk:19`, `:38`–`:48`), nicht nach Startzeit. Zu prüfen, welche Reihenfolge v2 braucht.
- **Verhalten bei Fristablauf beim Flow-Löschen** in v2: offen, siehe `STATUS.md`.
- **`work_items/HANDOVER.md`:** nicht geändert. Dort kann die Zeile zu 64 Bit und zum Stand Phase 2b nachgezogen werden, falls gewünscht.
- **Gesamtlauf** nicht ausgeführt (Auftrag). Der letzte Gesamtlauf ist WI-19 (458 passed).
- **Keine Eskalation:** Die Semantiktabelle ist aus dem v1-Code abgeglichen. Unsichere Teile sind als vermutet oder nicht geprüft markiert.
