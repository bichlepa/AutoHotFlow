# WI-17 Abschluss, Status, Überprüfung

Größe: S · Hängt ab von: alle · Blockiert: Phase 3

## Ziel

Phase 2 sauber abschließen und die Übergabe an Phase 3 vorbereiten.

## Aufgaben

1. Alle Arbeitspakete gegen ihre Akzeptanzkriterien prüfen (Checkliste in `work_items/phase2/README.md` abhaken).
2. `doc/` mit der Realität abgleichen: Weicht die Implementierung von `ARCHITEKTUR.md`, `PROTOKOLL.md`, `ELEMENT-API-V2.md` ab, wird das **Dokument** korrigiert (oder die Abweichung begründet in `MIGRATION.md`).
3. `work_items/STATUS.md` aktualisieren: erledigt, offen, bekannte Probleme, nächste Schritte, Messwerte.
4. `AGENTS.md` aktualisieren (Abschnitt „Aktueller Stand“).
5. `work_items/phase2/findings.md` durchgehen: jeder Fund hat eine Entscheidung (behoben, bewusst offen, Phase 3).
6. Einen Phase-3-Plan entwerfen: `work_items/phase3/README.md` (Reihenfolge laut Original-Prompt: Common/Variablen und Ausdrucksauswerter → Flow laden/speichern → Ausführung → Elemente in Gruppen → Editor und Zeichnen → Manager). Dazu die offenen Fragen aus `doc/ELEMENT-API-V2.md` Abschnitt 8 und `doc/ARCHITEKTUR.md` Abschnitt 10 (R3, R4, R5) mit konkreten Messaufgaben.
7. Entscheidungen, die der Projektinhaber treffen muss, als gebündelte Fragenliste am Ende von `STATUS.md`.

## Akzeptanzkriterium

Ein neuer Agent kann mit `AGENTS.md`, `doc/` und `work_items/phase3/README.md` ohne Rückfragen loslegen.
