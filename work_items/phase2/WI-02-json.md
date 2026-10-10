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

## Ergebnis

Stand 2026-10-10, Branch `v2-port`, **nicht committet**.

**Erstellt**

- `src/core/Json.ahk`: `Json.Parse(text)`, `Json.Stringify(value, indent := 0)`, `Json.Null` (Singleton, verschachtelte Klasse `Json.NullValue`), `Json.MAX_DEPTH` (256). Zusätzlich `Json.ParseBytes(buffer)` für UTF-8-Bytes (z. B. `FileRead(path, "RAW")`), siehe Abweichungen.
- `tests/ahk/json.test.ahk`: 43 Fälle, alle grün. Enthält die beiden Fälle der offenen Prüfung.
- `tests/test_json_flows.py`: 3 Tests (Round Trip aller 27 Flow-Dateien aus `v1/AppData/Saved Flows` und `demo flows`, Layout gegen `json.dumps(indent=2, sort_keys=True)`, 10.000-Nachrichten-Messung).
- Hilfsskripte: `tests/ahk/helpers/json_flows.ahk`, `tests/ahk/helpers/json_bench.ahk` (keine Unit-Tests, vom Runner nicht eingesammelt).
- `doc/HOW-TO.md`: neun Einträge zu Json (Syntax, Maps, Float, Performance), einer zu `UTF-8-RAW` ergänzt, einer zum sporadischen Dialog-Wächter-Test.

**Offene Prüfung (Ergebnis: ja)**

Ein `Map` mit `CaseSense "Off"` behält die Schreibweise der ersten Einfügung bei der Aufzählung. Eine spätere Einfügung in anderer Schreibweise ändert nur den Wert. Die Aufzählung ist außerdem sortiert (beobachtet, nicht dokumentiert). Ein eigener `AhfMap` ist nicht nötig, `doc/ELEMENT-API-V2.md` musste nicht geändert werden. Festgehalten in `tests/ahk/json.test.ahk` (Kommentar und zwei Fälle) und in HOW-TO.

**Akzeptanzkriterien**

- Round Trip aller 27 Flow-Dateien: `Parse` → `Stringify(…, 2)` → `Parse` liefert identische Struktur und Typen (verifiziert, `test_all_v1_flow_files_round_trip`). Die Ausgabe ist exakt das Layout von `json.dumps(indent=2, sort_keys=True)` (verifiziert, `test_written_files_have_v1_layout`).
- Typen bleiben erhalten: `"zoomFactor": "0.700000"` bleibt String, `"x": 7` bleibt Zahl (Unit-Tests und Round Trip).
- Fehlerfälle (abgeschnittener Text, doppeltes Komma, unbekanntes Escape, ungültiges UTF-8) erzeugen `JsonError` mit Zeile und Spalte (Unit-Tests, zusätzlich weitere Fälle).
- 10.000 Nachrichten zu 364 Zeichen: **Parsen 1562 ms, Schreiben 625 ms** (Messlauf, `-s`). Das Ziel "unter 1 s" wurde beim Parsen **nicht** erreicht. Es ist kein hartes Gate. Ursache: Methodenaufrufe pro Token im Interpreter, siehe HOW-TO.

**Abweichungen vom Paket**

1. Zusatz `Json.ParseBytes(buffer)`: ungültiges UTF-8 lässt sich nur über die Bytes prüfen, `Parse(text)` bekommt schon einen String. Der Vertrag in `work_items/phase2/README.md` ist nicht angepasst (außerhalb der erlaubten Pfade). Offener Punkt unten.
2. Testdatei heißt `tests/test_json_flows.py` (Vorgabe), nicht `tests/test_json.py` wie in der Paketdatei und der README-Tabelle.
3. Doppelte Schlüssel werden abgewiesen, auch wenn sie sich nur in der Schreibweise unterscheiden. Das Paket schweigt dazu. v1 (`Jxon`) überschreibt still.
4. Ganzzahlen mit mehr als 18 Stellen werden `Float` (AHK-Integer-Grenze, Paket schweigt dazu).
5. Ein einzelnes Surrogat in `\u`-Escapes wird abgewiesen, statt es durchzureichen.
6. Ausgabe mit `` `n `` statt CRLF. Die v1-Dateien enthalten CRLF. Strukturell gleich, Bytes nicht. Die Datei schreibt der Aufrufer (storage) mit `UTF-8-RAW`.
7. `Stringify` schreibt Schlüssel sortiert. Ob die Reihenfolge in den v1-Dateien ebenfalls sortiert ist, wurde nicht gesondert geprüft.
8. Die Hinweiszeile zur Performance nennt `StrJoin`. Das Paket nutzt `.=` über einen Parameter per Referenz und kein `StrJoin` (nicht geprüft, ob `StrJoin` in AHK v2 existiert).

**Nicht geprüft / offen**

- Parse-Performance: ein Parser als eine Funktion mit lokalen Variablen wäre die nächste Stufe, wenn Phase 3 große Flows häufig lädt.
- Zeichenketten-Verkettung bei sehr großen Dokumenten (mehrere MB) nicht gemessen.
- `Json.ParseBytes` nur mit Test-Bytes geprüft, nicht mit dem Storage-Pfad.
- `doc/PROTOKOLL.md` nicht geändert (keine neuen Nachrichtentypen).
- `work_items/phase2/README.md`: Vertrag um `Json.ParseBytes` ergänzen, Checkbox WI-02 abhaken (beides außerhalb der erlaubten Pfade).
- Sporadischer Fehlschlag von `tests/support/test_dialogwatch.py::test_runtime_error_dialog_is_captured` (Exit 98 statt 97, 1 von 4 isolierten Läufen). Nicht von WI-02 verursacht. Während der WI-02-Läufe zweimal rot gesehen: einmal mit diesem Namen (gefilterter Lauf), einmal ein Gesamtlauf ohne erfassten Namen. Danach fünf Gesamtläufe grün.
- Die Paketdatei verlangt "pytest tests -q" grün. Letzte Zeile der letzten Vordergrundausführung: `116 passed, 1 skipped in 19.24s` (1 Skip ist `test_ahk_runner.py:69`, Demo-Skip, nicht von WI-02).
