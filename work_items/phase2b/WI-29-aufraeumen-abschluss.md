# WI-29 Aufräumen und Abschluss

Größe: S · Hängt ab von: alle · Blockiert: Entwurf von Phase 3

## Ziel

Offene Kleinigkeiten aus Phase 2 beseitigen, den Stand prüfen und dokumentieren, damit danach der Phase-3-Plan entworfen werden kann.

## Aufgaben

1. **Testrollen aus `src/` lösen:** `src/AutoHotFlow.ahk` bindet heute `tests/integration/helpers/*Role.ahk` ein (nur mit `--test-roles` registriert). Vorschlag: eigener Testeinstieg unter `tests/` (z. B. `tests/integration/helpers/AutoHotFlowTest.ahk`), der die Teile des Produkteinstiegs plus die Testrollen einbindet. Der Supervisor startet Kinder mit `A_ScriptFullPath`, Kinder bekommen also automatisch denselben Einstieg. Dafür den Produkteinstieg so teilen, dass der Testeinstieg ihn wiederverwendet (z. B. `src/AhfBoot.ahk` mit allem außer dem Aufruf). Tests auf den Testeinstieg umstellen. Ausnahme im Architekturwächter (WI-19) entfernen.
2. **`src/core/RoleRegistry.ahk`** in zwei Dateien teilen (`PlaceholderRole` eigene Datei). Ausnahme im Wächter entfernen.
3. **Funde übertragen:** neue Funde (ab F-11) aus den Paketdateien in die Fundtabelle von `work_items/STATUS.md`, jeweils mit Entscheidung.
4. **Abschlussläufe** (Ergebnisse in `STATUS.md`):
   - Gesamtlauf parallel und seriell.
   - `python -m pytest tests -m stress -q` (nach F-07 und WI-25 nie vollständig wiederholt).
   - Dauerlauf 600 s **mit** Verbindungswechseln (`AHF_SOAK_CHURN=1`), bisher wegen F-07 nicht gefahren, und mit der in WI-25 angehobenen Rate.
   - Fault-Tests 20-mal (`AHF_FAULT_REPEAT=20`).
5. **Dokumente:** `work_items/STATUS.md`, `work_items/HANDOVER.md`, `AGENTS.md` (aktueller Stand: Phase 2b abgeschlossen, Phase 3 braucht Freigabe), Fortschrittshaken in `work_items/phase2b/README.md`.
6. **Übergabe an das Review:** Liste der Commits je Paket (`git log --oneline`), offene Punkte, nicht Geprüftes.

## Akzeptanzkriterien

- `src/` bindet nichts aus `tests/` ein, jede Datei unter `src/` hat höchstens eine Klasse auf oberster Ebene, der Architekturwächter hat keine dieser beiden Ausnahmen mehr.
- Alle Abschlussläufe grün oder jede Abweichung als Fund mit Entscheidung festgehalten.
- Ein neuer Agent findet über `AGENTS.md` den aktuellen Stand ohne Rückfragen.

## Nicht Teil

Phase-3-Plan (`work_items/phase3/README.md`, WI-17 Schritte 6 und 7). Den entwirft der Projektinhaber danach mit Claude.

## Ergebnis

Status: **abgeschlossen, mit offenen Punkten** (Aufgaben 1 bis 6 erledigt; die Abschlussläufe sind nicht alle grün, jede Abweichung ist als Fund festgehalten).

### Erledigt

- **Aufgabe 1, Testeinstieg (`31afcc2`).** Der Bootcode liegt in `src/AhfBoot.ahk` (alles aus dem früheren Einstieg außer dem Aufruf und den Testrollen). `src/AutoHotFlow.ahk` bindet nur `AhfBoot.ahk` ein und ruft `AhfMain()`. `tests/integration/helpers/AutoHotFlowTest.ahk` bindet `AhfBoot.ahk` und die Testrollen (`EchoRole`, `CrasherRole`, `HangerRole`, `SlowShutdownRole`, `RegisterFailure`) ein und setzt die globale Variable `AhfTestRolesFn`, die `AhfMain` bei `--test-roles` aufruft. Kinder erben den Einstieg über `A_ScriptFullPath` (verifiziert: die Fault- und Supervisor-Tests laufen in den Gesamtläufen). Umgestellt: `tests/fault/faultkit.py`, `tests/integration/test_supervisor.py`, `test_role.py`, `test_entry.py` (der Test für den Ladefehler nutzt den Testeinstieg, die anderen den Produkteinstieg); `tests/e2e/test_ui_stub.py` bleibt beim Produkteinstieg. Die WI-22-Eigenschaften (OnError vor den Includes, Exit 2 bei 32 Bit) stehen unverändert in `AhfBoot.ahk`. Die Ausnahme für `include-tests` ist aus dem Wächter entfernt (`facf064`); die Ausnahme für `FileAppend` in `AhfConsole` zeigt jetzt auf `AhfBoot.ahk`.
- **Aufgabe 2, `RoleRegistry.ahk` (`1a6f5e4`).** `PlaceholderRole` hat eine eigene Datei `src/core/PlaceholderRole.ahk`; die Ausnahme ist entfernt.
- **Zusätzlich, ohne dass die #Include-Kette brach (`1a6f5e4`):** `src/core/Errors.ahk` besteht nur noch aus Includes von `ErrCode.ahk`, `AhfError.ahk`, `ProtocolError.ahk`, `AhfTimeoutError.ahk`, `ElementError.ahk`, `JsonError.ahk` (die 51 Stellen mit `#Include Errors.ahk` bleiben unverändert); `engine/core/Loops.ahk` heißt `LoopStack.ahk`. Beide Ausnahmen sind aus dem Wächter entfernt. `python tools/arch_check.py`: 84 Dateien, 0 Verstöße, 2 Ausnahmen (beide `FileAppend` für stderr). Geprüft nach dem Umbau: `tests/test_architecture.py`, `tests/ahk`, `test_entry.py`, `test_role.py` (40 passed) und die Gesamtläufe unten. ARCHITEKTUR 8 und PROTOKOLL 4.1b beschreiben die neue Struktur (`facf064`).
- **Aufgabe 3, Funde:** F-11 bis F-31 (außer F-25 und F-26, die schon dort standen; F-26 ist aktualisiert) stehen mit Entscheidung oder "offen" in der Fundtabelle von `work_items/STATUS.md`. Eine Nummer F-32 gibt es nicht (WI-28 nennt sie nur als nächste freie Nummer).
- **Aufgabe 4, Abschlussläufe** (Code-Stand `20efac2`, jeder Lauf allein, ein Rechner mit 8 logischen CPUs):

| Lauf | Ergebnis | Dauer |
|---|---|---|
| seriell `pytest tests -n 0 -q` | 704 passed, 1 skipped, **1 failed** (`tests/fault/test_debug_role.py::test_a_debug_role_in_the_session_ends_with_it`, `wait_flows`: 20,0 s ohne geladenen Flow `skeleton`) | 596 s |
| parallel `pytest tests -q` | 705 passed, 1 skipped (ein Lauf) | 113 s |
| `-m stress` | 13 passed | 211 s |
| `AHF_FAULT_REPEAT=20`, `tests/fault -n 0` | 456 passed, **4 failed**: `test_shutdown.py::test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean[5]` und `[12]`, `::test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean[7]` und `[19]` (`clean: false` bei `manager` dreimal, `storage` einmal) = F-26 | 2527 s |
| `AHF_SOAK_CHURN=1`, `-m soak` | 1 passed | 609 s |

  Zusatz: `test_debug_role.py` allein, 5 Läufe seriell: 55 von 55 grün. Der Fehlschlag aus dem seriellen Gesamtlauf (F-31) tritt also nur im langen Lauf auf. Er war schon im seriellen Lauf von WI-28 aufgetreten (anderer Test derselben Datei), also 2 von 2 seriellen Gesamtläufen. Nach den Läufen keine Testprozesse übrig (nur angesehen); es liefen nur fremde Prozesse des Projektinhabers.
- **Aufgabe 5, Dokumente:** `work_items/STATUS.md` (Stand, Paketübersicht, Läufe, Funde, offene Punkte, nächste Schritte), `work_items/HANDOVER.md` (neu geschrieben), `AGENTS.md` (aktueller Stand), Haken und Gesamtstatus in `work_items/phase2b/README.md`.
- **Aufgabe 6, Übergabe:** siehe unten und `work_items/HANDOVER.md`.
- **HOW-TO sortiert (`20efac2`):** 148 Einträge nach Kategorie geordnet, 35 in eine andere Kategorie verschoben, Reihenfolge innerhalb der Kategorie erhalten, kein Text geändert (geprüft: die sortierten Zeilen vor und nach dem Umbau sind gleich). Die doppelte Überschrift "Prozesse, Pipes, Nachrichten (Stub)" ist mit der Hauptkategorie zusammengeführt.

### Nicht geprüft

- Ob F-26 und F-31 mit dem Testeinstieg-Umbau zusammenhängen, ist nicht ausgeschlossen, aber unwahrscheinlich: F-26 ist vorher gemessen (WI-26, WI-27), F-31 trat vorher auf (WI-28). Ein Lauf mit dem alten Einstieg zum Vergleich ist nicht gemacht worden.
- Der parallele Lauf wurde nur einmal wiederholt (grün); die Instabilität unter Last (F-19, `clients_churn[smoke]`, `big_flows[smoke]`, Hub-Frage aus WI-23) ist nicht neu gemessen.
- Ob `AHF_SOAK_CHURN=1` im Soak-Test tatsächlich Verbindungswechsel erzeugt hat: die Variable war im Aufruf gesetzt, die Testausgabe (`-q`) zeigt es nicht.
- Kein Vergleich der Laufzeit und des Speichers des Soak-Tests mit WI-16 (nur bestanden/nicht bestanden).
- Die Assertions in `test_shutdown.py` sind nicht umgestellt (F-19: `clean` zuerst prüfen) und keine Frist ist geändert.

### Abweichungen vom Plan

- Zusätzlich zu den Aufgaben: `Errors.ahk` und `Loops.ahk` aufgelöst (laut Auftrag erlaubt, weil die Include-Kette ohne Probleme blieb) und HOW-TO sortiert.
- Der Testeinstieg nutzt eine globale Variable (`AhfTestRolesFn`) in `AhfBoot.ahk`, obwohl KONVENTIONEN globale Variablen ablehnt: Der Einstieg ist die dort genannte Ausnahme. Alternative wäre eine statische Eigenschaft einer Klasse; die Variable ist die kleinere Änderung.
- Die Phase-3-Planung (`work_items/phase3/`) wurde auftragsgemäß nicht angelegt.

### Offene Entscheidungen für den Projektinhaber

1. Flow-Löschen ohne Frist (WI-21): Entscheidung des Agenten, nicht bestätigt.
2. Soll der Supervisor alle `worker:*` beenden, sobald die Engine endet (WI-27)?
3. Soll die Obergrenze des Log-Puffers (WI-25) in Phase 3 eine Einstellung werden?
4. Ist F-16 (Fristen nach der Wanduhr) in Phase 3 zu lösen?
5. Freigabe für Phase 3 und der Phase-3-Plan.

### Offene Punkte

- **F-26** (`clean: false`, rund 1 % der Läufe, `manager` und `storage`) und **F-31** (Flows nach 20 s nicht geladen, nur im seriellen Gesamtlauf) sind ungeklärt und nicht untersucht. Phase 2b ist deshalb **nicht ohne Einschränkung** abgeschlossen: Der serielle Gesamtlauf ist nicht grün, der Fault-Lauf mit 20 Wiederholungen nicht ohne Fehlschläge.
- Parallele Läufe unter Last sind weiter nicht verlässlich (siehe oben).
- Funde F-12 bis F-18, F-20 bis F-24, F-28 bis F-30 mit Entscheidung in `STATUS.md`.

### Übergabe an das Review

Commits je Paket (Präfix `WI-xx:`, `git log --oneline --grep="^WI-xx:"`):

| Paket | Commits (älteste zuerst) |
|---|---|
| WI-18 | `a6711c5` |
| WI-19 | `4a2a6e4` |
| WI-20 | `f42ed73` |
| WI-21 | `9e84422`, `26cada9`, `58c17d9`, `a06623f`, `5a705fc` |
| WI-22 | `856ef22`, `dfe8137`, `ae919f9`, `6870a6f`, `638ce3a`, `c7a07fe`, `2da8beb` |
| WI-23 | `b47f42c`, `6892034`, `04bf3af`, `f0878c2`, `ef34b5b` |
| WI-24 | `0126ecc`, `87fd20f`, `c052813`, `f9aa362`, `b76288d`, `be3a2a3` |
| WI-25 | `831c9e8`, `41d1265`, `1e0f4d7`, `bff8955`, `f29b267`, `f1efb7a` |
| WI-26 | `1d07f5d`, `787dcf1`, `aa55dfd`, `a55e164`, `7d0bd5d`, `45c501a` |
| WI-27 | `5404731`, `a7fa998`, `55abcbf`, `682a729`, `961fed2`, `9221437`, `edaad96`, `762b4a7`, `0ad3847`, `bcc5c82` |
| WI-28 | `d27d0ef`, `32234b2`, `d35b5d7`, `3e00b94`, `2b1f07e`, `b450a5c`, `fec7d06`, `e744800` |
| WI-29 | `31afcc2`, `1a6f5e4`, `facf064`, `20efac2` und die Dokumentcommits danach |

Für das Review besonders lesen: `src/AhfBoot.ahk` und `tests/integration/helpers/AutoHotFlowTest.ahk` (neuer Einstieg), die Fundtabelle in `STATUS.md`, die offenen Entscheidungen oben.
