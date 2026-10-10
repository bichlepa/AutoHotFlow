# STATUS: AutoHotFlow → AHK v2

Stand: 2026-10-10. Branch `v2-port`. Phase 0 und Phase 1 abgeschlossen, **Phase 2 geplant, nicht begonnen.**

## Erledigt

- **Phase 0:** Bestandsaufnahme in `work_items/ANALYSE.md` (Inventar, Element-API, Lock-Befunde, v1-Stellen, Aufwand). Lock-Audit-Skript in `work_items/analysis_v1/`.
- **Phase 1:** Architektur in `doc/` (`ARCHITEKTUR.md`, `PROTOKOLL.md`, `ELEMENT-API-V2.md`, `TESTSTRATEGIE.md`, `KONVENTIONEN.md`, `MIGRATION.md`).
- **Spike:** Named Pipe + Weckruf in AHK v2 funktioniert (`work_items/spikes/`).
- **Repo-Umbau:** v1 liegt unverändert in `v1/` (Chrome-Paket vom Projektinhaber entfernt). Arbeitsdokumente in `work_items/`.
- **Phase 2:** 17 Arbeitspakete mit Abhängigkeiten, Verträgen und Akzeptanzkriterien in `work_items/phase2/`.

## Entscheidungen des Projektinhabers (aus der Freigabe)

1. Mehrere Prozesse. Entscheidung über Editor-Prozesse vom Assistenten getroffen: ein Editor-Prozess pro Flow.
2. Zeichnen: vom Assistenten entschieden, im Editor-Prozess, später trennbar.
3. Worker-Prozesse für blockierende und AHK-Skript-Elemente (wie bisher).
4. Zielversion AHK v2.
5. Alte Flows müssen laden.
6. Eigener Branch (`v2-port`), kein `v2/`-Ordner, temporärer `v1/`-Ordner.
7. Chrome-Paket entfällt.
8. Testaufbau frei wählbar: pytest.
9. Kein v1-Fix-Branch, direkter Port.

## Bewertung der Fragen 1 und 2 (Entscheidungsgrundlage)

- AHK v2 hat keine Threads im selben Prozess, Pseudo-Threads sind kooperativ. Echte Parallelität gibt es nur über Prozesse.
- Gemessen: ein AHK-v2-Prozess startet in ~30 ms, belegt ~14 MB und braucht 0 % CPU im Leerlauf. Mehrere Editor-Prozesse sind daher billig, und nicht fokussierte Fenster aktualisieren sich unabhängig voneinander.
- Zeichnen im Editor-Prozess: jeder Editor zeichnet nur seinen Flow, ohne geteiltes Lock, parallel zu den anderen. Nachteil: ein langer Frame blockiert die Eingabe desselben Editors. Gegenmaßnahmen und Trennkriterium (Frame > 16 ms bei ca. 300 Elementen) stehen in `doc/ARCHITEKTUR.md` 2.1. Das Risiko ist **nicht gemessen**, sondern Annahme, die in Phase 3 geprüft wird.

## Neue Befunde seit Phase 0

- Die gespeicherten Flows mischen JSON-Strings (17.453) und JSON-Zahlen (703), keine Wahrheitswerte oder `null`. Der JSON-Baustein muss Typen erhalten (WI-02).
- Das v1-Backup beim Speichern ist wirkungslos (`Save.ahk:126` verschiebt eine `.txt`-Datei) und das Speichern ist nicht atomar (`FileDelete` + `FileAppend`). Eingetragen in `doc/MIGRATION.md` (M-07).
- `Trigger_Hotkey.Element_enable` ruft im Fehlerpfad `x_finish` statt `x_enabled` auf (Zeile 134), `Element_disable` ohne `HotIf`-Kontext. Eingetragen in `doc/MIGRATION.md` (M-03).

## Bekannte Probleme aus v1 (nicht gefixt, werden durch den Port gegenstandslos)

Siehe `work_items/ANALYSE.md` Abschnitt 3. Kurz: Dialoge/Datei-I/O/Element-Code unter Lock, `throw` ohne Lock-Freigabe, `x_enabled` statt `x_finish` in 6 Elementen, unquotiertes `callback`, nicht definierte `instance`, `currentlyLoadingFlow` ohne Reset, nicht lauffähige Testsuite.

## Offen

- Umsetzung von Phase 2 (siehe `work_items/phase2/README.md`).
- Messung des Zeichnens im Editor (Phase 3).
- Aufteilung von Metadaten und Laufzeitcode je Rolle (ARCHITEKTUR R3), Messung in Phase 3.
- Genaue Semantik der Ausführungsrichtlinien (`default`, `parallel`, `skip`, `wait`, `stop`) wird in WI-08 aus dem v1-Code übernommen.

## Nächste Schritte

1. Arbeitspakete WI-01 bis WI-03 starten (Welle A, parallel).
2. Danach WI-04, WI-08, WI-09 (Welle B), weiter nach `work_items/phase2/README.md`.
