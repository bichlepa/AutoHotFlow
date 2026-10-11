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
