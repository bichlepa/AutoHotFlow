# WI-35 Bugfix-Schleife bis zur grünen Abnahme

Größe: L (Schleife) · Hängt ab von: WI-34 · Blockiert: Abschluss des Fix-Blocks, Phase-3-Plan
Geschrieben von: Orchestrator (Claude), 2026-10-12, auf Wunsch des Projektinhabers.

## Ziel

Der Fix-Block ist erst abgeschlossen, wenn die Abnahme grün ist: **10 von 10 parallele Gesamtläufe grün, 1 serieller Gesamtlauf grün, `AHF_FAULT_REPEAT=20` für `tests/fault` grün, `-m stress` grün.** Das Paket beendet nicht bei der ersten Behebung. Es läuft als **Schleife**, bis die Abnahme grün ist. Neue Fehler, die dabei auftauchen, werden im selben Paket analysiert und behoben.

Bekannter Ausgangsstand (`work_items/STATUS.md`, Abschnitt "Abnahmelauf WI-34 (2026-10-12, zweiter)"):
- **F-45** `test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out`: parallel 1 von 10, `refreshed` 2 statt 3.
- **F-46** `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted`: seriell 1 von 1, Fault 20x 5 von 20. Das Element meldet `worker not available (peer_gone)` statt `worker crashed`.
- **F-47** `test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms`: seriell 1 von 1, `cmd.worker.cancel` bleibt 5 s unbeantwortet.

**Verdacht zu F-46:** Der Hub antwortet seit WI-34 (F-40, Commits `04192f9`, `27d49cb`) bei Verlust des Ziels sofort mit `peer_gone`. Das kommt vor `evt.process.crashed`. Ein Element, das auf einen Worker wartet, der stirbt, bekommt dann `peer_gone` statt `worker crashed`. Das ist ein **Produktfehler, den F-40 eingeführt haben kann**, kein Testfehler. Nicht belegt. Die Analyse muss das zuerst klären (Abschnitt "Analyse").

## Grundregeln der Schleife (verbindlich)

1. **Kein Fix ohne roten Test.** Jeder Fehler wird zuerst in einem Test rot gezeigt, dann behoben. Ist ein Fehler nicht reproduzierbar, wird er mit Häufigkeit und Log dokumentiert und zählt als "nicht reproduziert", nicht als behoben.
2. **Keine Abkürzungen am Test.** Keine Frist wird gelockert, um einen Fehler zu verdecken. Keine Wiederholung roter Tests über ein Plugin (kein `rerunfailures`). Jede Friständerung wird im Commit begründet und ist nur zulässig, wenn die Frist den Produktwert nicht verletzt (Maßstab: `doc/ARCHITEKTUR.md` Abschnitt 9, Leistungsbudgets, und `scaled()` nur für Obergrenzen, die kein Versprechen sind).
3. **Produktfehler vor Testfehler.** Bevor ein roter Test als Testfehler eingeordnet wird, muss die Ursache im Log oder im Code belegt sein.
4. **Schleifenabbruch:** Die Schleife endet, wenn die Abnahme grün ist (Erfolg). Sie endet mit Bericht an den Projektinhaber, wenn **fünf Fehlerzyklen** nacheinander neue Funde zeigen oder ein Fund eine Architekturentscheidung braucht (dann "ESKALATION").
5. **Lauf-Disziplin:** Jeder Gesamtlauf allein auf dem Rechner, im Hintergrund, Ausgabe in Dateien im Scratchpad. Nach jedem Lauf prüfen, dass keine Testprozesse übrig sind (nur ansehen). Fremde Prozesse des Projektinhabers (AutoHotkeyU32.exe mit "Allgemeine Hilfe.ahk", AutoHotkey64.exe mit AutoHotFlow.ahk ohne Argumente, python.exe der VS-Code-Erweiterung) nicht anfassen.
6. **Testlauf-Regel des Projektinhabers:** Die Umsetzung führt nur die für die Änderung relevanten Tests aus. Die Gesamtläufe fährt die Abnahme, und zwar nur in den Abnahme-Schritten dieser Schleife.

## Rollen in der Schleife

Der Orchestrator führt die Schleife aus und wählt je Schritt das Modell:

| Schritt | Modell | Aufgabe |
|---|---|---|
| Testdurchführung (Abnahme-Läufe, gezielte Wiederholungen, Prozesskontrolle) | **Haiku** | Läufe fahren, Ausgaben sichern, Rot-Liste mit Häufigkeit und Meldung erstellen. Keine Änderungen. |
| Bug-Analyse und Lösungsvorschlag | **Opus** | Ursache belegen (Log, Code lesen), Lösungsvorschlag mit Testplan schreiben. Keine Änderung am Code. |
| Umsetzung (roter Test, Fix, grüner Test, Doku) | **Sonnet** | Den Vorschlag aus der Analyse umsetzen, Test rot zuerst, dann Fix, Commits, Ergebnis in dieser Datei. |

## Schleife

### Schritt 0: Ausgangsstand festhalten (Haiku)
Die Ausgangsfunde F-45, F-46, F-47 mit den Befehlen aus dieser Datei gezielt reproduzieren:
- `AHF_FAULT_REPEAT=20 python -m pytest tests/fault/test_process_crash.py -k killed_worker -n 0 -q` (F-46)
- `python -m pytest tests/integration/test_worker.py -k cancel_of_the_hang -n 0 -q` (F-47)
- `python -m pytest tests/fault/test_debug_role.py -k refresh_shows -n 0 -q` (F-45, mehrmals, z. B. `AHF_FAULT_REPEAT=10`)

Ergebnis: Tabelle mit Häufigkeit, Meldung, Logpfad. In `STATUS.md` unter "Schleife WI-35, Zyklus 0" eintragen.

### Schritt 1: Analyse je offenem Fund (Opus)
Pro offenem Fund (Reihenfolge: F-46, F-47, F-45, dann neue Funde):
1. Ursache belegen: Log (`Log/Log.txt` im Testdatenordner, mit `AHF_TEST_KEEP=1`), Code lesen (`src/supervisor/Hub.ahk`, `src/core/ipc/Peer.ahk`, `src/engine/WorkerBridge.ahk`, `src/worker/`, `src/debugview/DebugView.ahk`).
2. Für F-46 zuerst prüfen, ob die `peer_gone`-Antwort aus F-40 die Ursache ist. Dazu eine Gegenprobe: Der Test muss zeigen, ob `evt.process.crashed` vor oder nach `peer_gone` kommt, und ob das Element dann `worker crashed` bekommen müsste. Die Lösung darf F-40 nicht zurücknehmen (F-40 hat einen eigenen Test, der bestehen bleibt). Die richtige Antwort ist vermutlich: Der Hub gibt `peer_gone` mit einem Grund an, und die Engine, die den Worker-Fall kennt, mappt auf `worker crashed`, oder der Absturz wird über das Prozessereignis vor `peer_gone` abgewartet. Entscheiden und begründen.
3. Lösungsvorschlag mit Testplan schreiben: welcher Test zuerst rot wird, welche Datei sich ändert, welche Frist (falls) betroffen ist.
4. Vorschlag in dieser Datei unter "Analyse Zyklus N" festhalten.

### Schritt 2: Umsetzung (Sonnet)
Nach dem Vorschlag:
1. Test schreiben, der den Fehler zeigt (rot). Lauf belegen.
2. Fix umsetzen, Test grün.
3. Relevante Nachbartests laufen lassen (Liste im Vorschlag).
4. Doku nach Regel 5 (PROTOKOLL, ARCHITEKTUR) im selben Commit.
5. Commit mit Präfix `WI-35: `, Body mit dem Warum.

### Schritt 3: Testdurchführung (Haiku)
Gezielte Wiederholung des betroffenen Tests (F-46: `AHF_FAULT_REPEAT=20`, F-47 und F-45 je 10-mal), dann die Abnahme-Läufe (siehe unten). Ergebnis in `STATUS.md`.

### Schritt 4: Abnahme (Haiku, nur wenn die gezielte Wiederholung grün ist)
In dieser Reihenfolge, jeder Lauf allein:
1. 10 parallele Gesamtläufe `python -m pytest tests -q` hintereinander. Alle grün.
2. Serieller Gesamtlauf `python -m pytest tests -n 0 -q`.
3. `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` (rund 44 Minuten).
4. `python -m pytest tests -m stress -q`.

Ist ein Lauf rot: Liste der roten Tests mit Häufigkeit und Meldung. Neue Funde bekommen die nächste freie F-Nummer (ab F-48). Die Schleife geht mit Schritt 1 für die neuen Funde weiter.

Ist die Abnahme grün: Schritt "Abschluss".

### Schritt 5: Abschluss (Sonnet)
1. `README.md`: Haken "WI-35", "WI-34 Abnahme" und "WI-32 Abnahmeläufe" setzen. Den Stand des Fix-Blocks als abgeschlossen melden.
2. `STATUS.md`: F-37 bis F-47 mit Ergebnis schließen (nur, wenn belegt). F-43 bleibt offen (Entscheidung Projektinhaber), F-36 bleibt "empfohlen", bis eine Entscheidung vorliegt.
3. `HANDOVER.md` und `AGENTS.md`: Fix-Block abgeschlossen, offene Entscheidungen (E14, F-43), Phase-3-Plan als Nächstes.
4. Commit mit Präfix `WI-35: `.

## Stopp-Regeln

- Nach **fünf** Fehlerzyklen ohne grüne Abnahme: Stopp, Bericht mit Stand und offenen Funden an den Projektinhaber.
- Ein Fund, der eine Architekturentscheidung braucht (z. B. Reihenfolge der Ränge beim Beenden, F-43, oder eine Änderung am Protokoll, das mehrere Rollen betrifft): Stopp für diesen Fund, Frage dokumentieren, mit den übrigen Funden weitermachen.
- Eine Friständerung, die den Produktwert verletzt: nicht umsetzen, dokumentieren.

## Zyklen (wird während der Schleife gefüllt)

### Zyklus 0 (Ausgangsstand)
(Ergebnis von Schritt 0 hier eintragen.)

### Analyse Zyklus N
(Opus-Analyse hier eintragen.)

### Umsetzung Zyklus N
(Sonnet-Ergebnis hier eintragen.)

### Testdurchführung Zyklus N
(Haiku-Ergebnis hier eintragen.)

## Akzeptanzkriterien

- Abnahme aus Schritt 4 grün, mit Zahlen in `STATUS.md`.
- F-45, F-46, F-47 behoben, jeweils mit einem Test, der vorher rot war.
- Neue Funde aus der Schleife behoben oder begründet zurückgestellt, mit Test.
- Keine Frist ohne Begründung gelockert. Keine Tests gelöscht oder abgeschwächt.
- Doku (`PROTOKOLL`, `ARCHITEKTUR`, `TESTSTRATEGIE`, `HOW-TO`) nachgeführt.

## Nicht Teil

- F-43 (Kind hält storage beim Beenden auf): Entscheidung des Projektinhabers.
- E14 (Manager-Fenster schließen): Phase 3.
- Phase-3-Plan.
