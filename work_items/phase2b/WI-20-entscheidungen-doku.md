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
