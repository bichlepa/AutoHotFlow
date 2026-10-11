# WI-26 JSON: echte Wahrheitswerte auf der Leitung

Größe: S · Hängt ab von: WI-24 (Hub-Umbau in `Message`) · Blockiert: –

## Ziel

Wahrheitswerte gehen als JSON `true`/`false` auf die Leitung statt als `1`/`0` (Entscheidung E8). Die Sonderregeln dazu in Protokoll, Tests und HOW-TO entfallen.

## Hintergrund und Entscheidung (Review 2026-10-11)

- Heute: `Json.Parse` liefert `true`→`1`, `false`→`0`; `Json.Stringify` kennt keinen Bool-Typ und schreibt `1`/`0`. Workarounds stehen in `doc/PROTOKOLL.md` 2 ("Umsetzung in AHK"), 4.3 ("Wahrheitswerte gehen als 0 oder 1"), 4.8 (Stub), `doc/HOW-TO.md` ("Wahrheitswerte gehen als Zahl auf die Leitung", "Boolesche Antworten als Zahl (Stub)", "Wahrheitswerte aus AHK sind 0 und 1 auch in den Python-Tests").
- **AHK v2 hat keinen Bool-Typ**, und jedes Objekt ist wahr (es gibt keinen `__Bool`-Haken). Würde `Parse` eigene Objekte für `true`/`false` liefern, wäre `if payload["ok"]` bei `false` wahr: ein gefährlicher stiller Fehler. Deshalb:
  - **Lesen bleibt:** `true`→`1`, `false`→`0`. Das ist für AHK-Code die richtige Darstellung (`if x` funktioniert) und wird als bewusste Regel dokumentiert.
  - **Schreiben wird korrekt:** neue Singletons `Json.True` und `Json.False` (wie `Json.Null`) und `Json.Bool(x)` (liefert eines von beiden). `Stringify` schreibt sie als `true`/`false`.
  - Alle Wahrheitswerte im Protokoll werden mit `Json.Bool(...)` erzeugt.
  - **Falle auf der Schreibseite:** `Json.False` ist ein Objekt und damit in AHK **wahr**. Ein Map-Eintrag mit `Json.False`, den AHK-Code vor dem Senden mit `if` prüft, ist ein Fehler (Beispiel: `WriteQueue` setzt `payload["ok"]`, `Storage._Finish` prüft `if (payload["ok"])`). Regel: `Json.True`/`Json.False` nur beim Bau der Nachricht unmittelbar vor dem Senden; das Feld `ok` setzt der Code intern weiter als 1/0, und die Sendestellen (`Peer.Reply`, `Peer._Transmit` für Antworten, Hub-Antworten) wandeln `ok` zentral um. Diese Regel in `doc/HOW-TO.md` und `doc/KONVENTIONEN.md` aufnehmen.
  - Empfänger bleiben tolerant (`1`/`0` und `true`/`false` gelten gleich), damit ältere Testclients und Fremdclients funktionieren.
- **Flow- und Variablendateien:** Die v1-Dateien enthalten kein `true`/`false`/`null` (verifiziert in `doc/ARCHITEKTUR.md` 7). Checkbox-Parameter sind dort Zahlen (`"DelimiterComma": 1`) und bleiben es; das Schreibformat der Flows ändert sich in Phase 2b nicht (E8). Round-Trip-Tests der Flows bleiben unverändert grün.

## Aufgaben

1. `Json.True`, `Json.False`, `Json.Bool(x)` in `src/core/Json.ahk`, Unit-Tests in `tests/ahk/json.test.ahk` (Schreiben, Lesen ergibt 1/0, Round-Trip dokumentiert als nicht typerhaltend für Booleans, `Json.Bool` mit 0, 1, "", "0", Objekten).
2. Alle Absender von Wahrheitswerten umstellen. Mindestens: `ok` (Dispatcher, `Peer.Reply`, Hub-Antworten, `sys.welcome`), `cancel`, `started`, `clean`, `restart`, `enabled`, `executing`, `exists`, `existed`, `waiting` (WI-21), alles in Testrollen und im Stub. Vorgehen: alle Stellen mit `true`/`false`/`1`/`0` in Nutzlast-Maps suchen und im Ergebnis auflisten.
3. Python: Hilfsfunktion in `tests/support/` für die Prüfung "echter Boolean" (`is True`/`is False`); in den Protokolltests für die Felder oben strenger prüfen, damit ein Rückfall auffällt.
4. Doku: Workaround-Abschnitte in `doc/PROTOKOLL.md` ersetzen durch die neue Regel (Schreiben `true`/`false`, Lesen tolerant). HOW-TO-Einträge aktualisieren (Status, Verweis auf diese Regel), nicht löschen.
5. Optional, wenn einfach: Regel im Architekturwächter (WI-19), die `Map("ok", true)` ohne `Json.Bool` meldet. Sonst als offenen Punkt notieren.

## Akzeptanzkriterien

- Alle Wahrheitswerte im Protokoll kommen in Python als `bool` an (strenge Tests).
- Gesamtlauf grün, Flow-Round-Trip unverändert.
- Doku ohne die alten Sonderregeln, die neue Regel an einer Stelle (`doc/PROTOKOLL.md` 2).
