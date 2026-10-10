# WI-02 JSON-Baustein

Größe: M · Hängt ab von: – (Tests profitieren von WI-01, ein eigenes kleines Runner-Skript genügt zunächst) · Blockiert: WI-05, WI-08, WI-12

## Ziel

Ein JSON-Parser und -Schreiber für AHK v2, der **Datentypen verlustfrei erhält** und die v1-Flow-Dateien round-trip-fähig liest und schreibt.

## Vorher lesen

`doc/ARCHITEKTUR.md` Abschnitt 7 (Kompatibilität), `v1/Lib/Json/` (Jxon, Vorbild für Ausgabeformat), `v1/Source_Common/Flows/Save.ahk` (Ausgabe: Einrückung 2, UTF-8 ohne BOM).

## Zu erstellen

`src/core/Json.ahk` mit `class Json`:

- `static Parse(text)`: Objekt → `Map` (**`CaseSense := "Off"`**, Schlüsselschreibweise bleibt beim Schreiben erhalten), Array → `Array`, String → `String`, Zahl ohne Punkt/Exponent → `Integer`, sonst `Float`, `true` → `1`, `false` → `0`, `null` → `Json.Null`.
- `static Stringify(value, indent := 0)`: `Map` und Array, `String` bleibt String (auch `"1"`), `Integer`/`Float` bleiben Zahl, `Json.Null` → `null`. Schlüssel sortiert (stabile Ausgabe). `indent = 2` erzeugt dasselbe Layout wie v1 (`Jxon_Dump(..., 2)`).
- `static Null` Singleton.
- Fehler: Syntaxfehler werfen `ProtocolError`-ähnliche `JsonError` (Unterklasse `AhfError`, `code = "bad_json"`) mit Zeile/Spalte, **keine** stille Korrektur.
- Unicode: korrekte `\uXXXX`-Behandlung inklusive Surrogatpaare. Steuerzeichen werden beim Schreiben maskiert.

## Offene Prüfung (vor der Implementierung)

Prüfen und im Testdatei-Kommentar festhalten: Behält ein `Map` mit `CaseSense := "Off"` die ursprüngliche Schreibweise der Schlüssel bei der Aufzählung? Falls nein, eigene dünne Klasse (`AhfMap`) bauen, die Original-Schlüssel speichert, und diesen Vertrag hier und in `ELEMENT-API-V2.md` nachtragen.

## Akzeptanzkriterien

- Alle 23 Dateien aus `v1/AppData/Saved Flows/*.json` sowie `demo flows/*.json`: `Parse` → `Stringify(…, 2)` → `Parse` liefert eine strukturell und typgleiche Datenmenge (rekursiver Vergleich inklusive `String` vs `Integer`).
- Zahlen/Strings aus den echten Dateien bleiben unterscheidbar (`"zoomFactor": "0.700000"` bleibt String, `"x": 7` bleibt Zahl).
- Fehlerfälle: abgeschnittener Text, doppelte Kommas, unbekannte Escape-Sequenz, ungültiges UTF-8 erzeugen `JsonError`.
- 10.000 kleine Nachrichten (Umschlag ca. 300 Byte) parsen und schreiben in unter 1 s (Messung im Test protokollieren, kein hartes Gate).

## Tests

`tests/ahk/json.test.ahk` (Unit). `tests/test_json_flows.py` (pytest, ruft einen AHK-Helfer, der Dateien aus einem Verzeichnis round-trip-t und ein JSON-Ergebnis schreibt; vergleicht gegen Python-`json` als Referenz).

## Nicht Teil

Pfad-/Query-Funktionen, Schema-Validierung.

## Hinweise

- In AHK v2 sind `true`/`false` die Zahlen 1/0. In den Beispieldateien kommen keine JSON-Wahrheitswerte vor (geprüft), die Abbildung genügt.
- Performance: keine Zeichenkettenkonkatenation in Schleifen mit jeweils neuer Kopie bei großen Dokumenten; Puffer (`Array` + `StrJoin`) oder `VarSetStrCapacity` nutzen.
