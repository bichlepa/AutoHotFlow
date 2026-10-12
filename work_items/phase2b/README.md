# Phase 2b: Härtung vor Phase 3, Umsetzungsplan

Stand: 2026-10-11. Branch `v2-port`. Grundlage: Review des Phase-2-Stands (Code-Stand `95a804c`, Gesamtlauf 431 passed, 1 skipped in 346 s) durch den Projektinhaber mit Claude. Die Funde des Reviews stehen vollständig in den Paketdateien, das Gespräch selbst ist für den nächsten Agenten nicht verfügbar.

**Ziel:** Fehler und Lücken, die die Tests des Skeletts nicht zeigen, vor Phase 3 beheben, solange der Code klein ist. Dazu Diagnosewerkzeuge, die den Port der Elemente in Phase 3 erleichtern. **Phase 3 wird hier nicht begonnen** (keine echten Elemente, kein Ausdrucksauswerter, kein Editor, kein echter Manager, kein Triggerhost).

Kennzeichnung der Funde: **[verifiziert]** gelesen und ausprobiert oder gemessen, **[gelesen]** aus dem Code abgeleitet, nicht ausprobiert, **[vermutet]** plausibel, nicht nachgewiesen. Wer einen Fund bearbeitet, prüft ihn zuerst selbst (Test, der ihn zeigt, dann Fix).

## Entscheidungen des Projektinhabers (2026-10-11, verbindlich)

| # | Entscheidung | Wirkt in |
|---|---|---|
| E1 | **Ändern während der Ausführung ist erlaubt** (beobachtbares v1-Verhalten): Die Engine nutzt bei jedem Schritt die neueste committete Revision eines Flows. Langfristiges Ziel ist ein **Debugger**: Ausführung künstlich verlangsamen (z. B. 3 s Pause nach jedem Element), jederzeit pausieren, Breakpoints, Einzelschritt, bei Pause alle Variablen sehen und ändern, den Flow während des Debuggens bearbeiten. Der Debugger wird in Phase 2b **nicht** gebaut, aber nichts darf ihn verbauen. | WI-20, WI-21 |
| E2 | Ausführungsrichtlinie **`wait`** wird umgesetzt (M-11 bestätigt). | WI-21 |
| E3 | **Worker-Pool:** Der Supervisor startet und beendet Worker-Prozesse auf Anfrage der Engine (elastischer Pool). Ein Worker in einem Job ist von der Ping-Prüfung ausgenommen. Fristen für Jobs hält die Engine. | WI-27 |
| E4 | **Nur 64 Bit.** 32 Bit wird nicht unterstützt und beim Start abgewiesen. | WI-20, WI-22 |
| E5 | **Idle-CPU:** Das Ziel "unter 1 %" gilt für das Gesamtsystem (gemessen 0,23 %). Erfüllt, Thema geschlossen. | WI-20 |
| E6 | **Triggerhost (WI-14)** wird früh in Phase 3 mit den echten Triggern gebaut, nicht in Phase 2b. | WI-20 |
| E7 | Bewusst zurückgestellte Punkte werden als **Beobachtungsliste** in `STATUS.md` dokumentiert (beobachten oder später optimieren). | WI-20 |
| E8 | **JSON:** Wahrheitswerte gehen als echte JSON-Booleans auf die Leitung. Das Flow-Dateiformat darf in v2 künftig vom v1-Format abweichen; Pflicht bleibt nur, dass alte Flows und Variablen laden. In Phase 2b ändert sich das **Schreibformat der Flows nicht** (ein neues Format wäre eine eigene Entscheidung in Phase 3). Begründung der Umsetzung in WI-26. | WI-20, WI-26 |

## Pflichtlektüre für jedes Paket

1. `AGENTS.md`
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6 und 8, `doc/KONVENTIONEN.md`, `doc/HOW-TO.md`
3. `doc/PROTOKOLL.md` (für Pakete mit Nachrichten)
4. Diese Datei und die Datei des eigenen Pakets

## Gemeinsame Definition of Done

Wie Phase 2 (`work_items/phase2/README.md`), zusätzlich:

- Erst einen Test schreiben, der den Fund zeigt (rot), dann beheben (grün). Wo das nicht geht, steht im Ergebnis, warum.
- Gesamtlauf grün. Ab WI-18 mit dem parallelen Aufruf, der dort festgelegt wird; vor dem Abschluss eines Pakets zusätzlich einmal seriell, wenn das Paket Zeitverhalten ändert.
- Jede Schnittstellenänderung steht im selben Commit in `doc/PROTOKOLL.md` bzw. `doc/ARCHITEKTUR.md`. Bewusste Abweichungen von v1 in `doc/MIGRATION.md`.
- Schwierigkeiten mit AHK v2 als Eintrag in `doc/HOW-TO.md` (mit Status).
- Am Ende der Paketdatei ein Abschnitt **"Ergebnis"**: was erledigt ist, Belege (Testnamen, Messwerte), was nicht geprüft ist, Abweichungen vom Plan, offene Punkte. Der Projektinhaber lässt jedes Paket danach reviewen.
- Änderungen in `src/core/` sind in diesem Plan ausdrücklich erlaubt, soweit das Paket sie nennt. Andere Änderungen in `src/core/` als "Offener Punkt" vermerken.
- Commits mit Präfix `WI-xx:`.

## Arbeitspakete (in dieser Reihenfolge)

| ID | Titel | Größe | Hängt ab von | Hauptpfade |
|---|---|---|---|---|
| [WI-18](WI-18-testlaufzeit.md) | Testlaufzeit: parallele Ausführung | S | – | `tests/conftest.py`, `tests/requirements.txt`, Testmarker |
| [WI-19](WI-19-architekturwaechter.md) | Architekturwächter (statische Prüfung) | S | WI-18 | `tests/test_architecture.py`, `tools/` |
| [WI-20](WI-20-entscheidungen-doku.md) | Entscheidungen und Beobachtungsliste dokumentieren | S | – | `doc/`, `work_items/STATUS.md`, `AGENTS.md` |
| [WI-21](WI-21-engine-korrektheit.md) | Engine: Loop-Stack, Wiedereintritt, neueste Revision, `wait` | M | WI-20 | `src/engine/` |
| [WI-22](WI-22-supervisor-robustheit.md) | Supervisor: Heartbeat, F-06, Startreihenfolge, 64 Bit, Pipe-Namen | M | WI-18 | `src/supervisor/`, `src/AutoHotFlow.ahk`, `src/core/` |
| [WI-23](WI-23-diagnose-logpfade.md) | Diagnose I: Log des Supervisors, stderr der Kinder, Fehlermeldungen | M | WI-22 | `src/supervisor/`, `src/core/` |
| [WI-24](WI-24-hub-routing-laden.md) | Hub routet über Kopffelder, Engine lädt gestaffelt, 200-Flow-Test | M | WI-22 | `src/supervisor/Hub.ahk`, `src/core/ipc/Message.ahk`, `src/engine/Engine.ahk` |
| [WI-25](WI-25-storage-durchsatz.md) | Storage: Log-Durchsatz und getrennte Warteschlangen (F-08) | M | – | `src/storage/` |
| [WI-26](WI-26-json-wahrheitswerte.md) | JSON: echte Wahrheitswerte auf der Leitung | S | WI-24 | `src/core/Json.ahk`, alle Absender von Wahrheitswerten |
| [WI-27](WI-27-worker-pool.md) | Worker-Pool-Lebenszyklus | L | WI-22, WI-23 | `src/engine/WorkerBridge.ahk`, `src/supervisor/`, `src/worker/` |
| [WI-28](WI-28-diagnose-bericht-debugfenster.md) | Diagnose II: Snapshot, Absturzbericht, Debug-Fenster | L | WI-23 | `src/core/`, `src/supervisor/`, `src/storage/`, neue Rolle `debug` |
| [WI-29](WI-29-aufraeumen-abschluss.md) | Aufräumen und Abschluss | S | alle | `src/AutoHotFlow.ahk`, `src/core/RoleRegistry.ahk`, `work_items/` |

WI-18 zuerst: Es verkürzt jeden folgenden Testlauf. WI-20 ist reine Dokumentation und kann jederzeit früh erledigt werden. Pakete, die dieselben Dateien ändern (z. B. WI-22, WI-23, WI-27 in `src/supervisor/`), nicht parallel bearbeiten.

## Fortschritt

- [x] WI-18  - [x] WI-19  - [x] WI-20  - [x] WI-21  - [x] WI-22  - [x] WI-23
- [x] WI-24  - [x] WI-25  - [x] WI-26  - [x] WI-27  - [x] WI-28  - [x] WI-29

**Gesamtstatus Phase 2b (2026-10-12): abgeschlossen mit offenen Punkten.** Alle Pakete sind umgesetzt. Die Abschlussläufe (WI-29) sind nicht vollständig grün: seriell 704 von 706 Tests grün (1 rot, F-31; 1 übersprungen), parallel grün, Stress 13 von 13, Dauerlauf mit Verbindungswechseln grün, Fault-Tests 20-mal 456 von 460 (4 rot, F-26). Offene Entscheidungen des Projektinhabers und Punkte: `work_items/HANDOVER.md` und das Ergebnis in `WI-29-aufraeumen-abschluss.md`. Phase 3 braucht die Freigabe des Projektinhabers.

## Funde

Neue Funde während der Arbeit bekommen die nächste freie Nummer ab **F-11** und stehen in der Paketdatei unter "Ergebnis" (Szenario, Reproduktion, Entscheidung). WI-29 hat sie in `STATUS.md` übertragen (Tabelle "Funde", F-01 bis F-31).

---

## Nachtrag 2026-10-12: Fix-Block WI-30 bis WI-33

Grundlage: Review der Ergebnisse von WI-18 bis WI-29 durch den Projektinhaber mit Claude (2026-10-12). Das Review fand für F-26 und F-31 konkrete Ursachen im Code und im eigenen parallelen Lauf zwei weitere wackelnde Tests. Phase 3 beginnt erst nach diesem Block und braucht weiter die Freigabe des Projektinhabers.

### Entscheidungen des Projektinhabers (2026-10-12)

Die Punkte E9 bis E13 sind Empfehlungen aus dem Review, die der Projektinhaber mit "Gut" angenommen hat. E14 und E15 hat er ausdrücklich so entschieden.

| # | Entscheidung | Wirkt in |
|---|---|---|
| E9 | **Löschen eines Flows ohne Frist** (WI-21, `Executor.FlowDeleted`) ist bestätigt: Instanzen stoppen sofort, blockierende Worker beendet der Pool nach `ORPHAN_MS`. | WI-32 (Doku) |
| E10 | **Worker enden mit der Engine:** Endet der Engine-Prozess (Absturz oder Ende), beendet der Supervisor alle lebenden `worker:*`. Eine neue Engine baut ihren Pool neu auf. | WI-33 |
| E11 | Die **Obergrenze des Log-Puffers** im Storage (WI-25) bleibt eine interne Konstante, keine Einstellung. | WI-32 (Doku) |
| E12 | **F-16 wird jetzt gelöst:** Alle Fristen des Supervisors berücksichtigen einen Stillstand des Supervisors, nicht nur der Heartbeat. | WI-33 |
| E13 | Bestätigt: Änderungen F-05 und F-07 in `src/core/`, MIGRATION M-11, M-17, M-18 (im Review gelesen, ohne Befund). | WI-32 (Doku) |
| E14 | **Schließen des Manager-Fensters** (beendet heute im Stub die ganze Anwendung): Verhalten des echten Managers wird in **Phase 3** entschieden. | Phase 3 |
| E15 | **Leeres `--data=`** (Logs landen dann in `C:\Log`) ist vorerst egal: Beobachtungsliste, kein Fix. | WI-32 (Doku) |

### Pakete (in dieser Reihenfolge)

| ID | Titel | Größe | Hängt ab von | Hauptpfade |
|---|---|---|---|---|
| [WI-30](WI-30-sauberes-beenden.md) | Sauberes Beenden: keine letzte Nachricht geht verloren (F-26) | M | – | `src/core/ipc/PipeConnection.ahk`, `src/core/Role.ahk`, `src/supervisor/Children.ahk` |
| [WI-31](WI-31-engine-wartet-auf-storage.md) | Engine wartet auf `storage` und setzt abgebrochenes Laden fort (F-31, F-24) | S | – | `src/engine/Engine.ahk` |
| [WI-33](WI-33-worker-und-stillstand.md) | Worker enden mit der Engine (E10), Fristen nach Stillstand (F-16, E12) | S | WI-30 | `src/supervisor/` |
| [WI-32](WI-32-teststabilitaet-abschluss.md) | Teststabilität (paralleler Lauf verlässlich) und Abschluss des Blocks | M | WI-30, WI-31, WI-33 | `tests/`, `work_items/`, `AGENTS.md` |

WI-32 kommt bewusst zuletzt: WI-30 und WI-31 beseitigen zwei Ursachen roter Läufe, WI-32 macht danach den Rest stabil und dient als Abnahme des ganzen Blocks. Änderungen in `src/core/` sind in WI-30 ausdrücklich erlaubt. Die Definition of Done oben gilt unverändert, dazu Regel 10 in `AGENTS.md` (VS-Code-Tasks).

### Fortschritt Fix-Block

- [x] WI-30  - [x] WI-31  - [ ] WI-33  - [ ] WI-32

Neue Funde ab **F-32**.
