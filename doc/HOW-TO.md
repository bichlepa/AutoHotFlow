# How-to AHK v2 (Wissensbasis)

Sammlung von Stolpersteinen, Fehlern und Lösungen bei der Umsetzung in AutoHotkey v2. Gedacht als Hilfe für Agenten und Entwickler, die nach uns am Code arbeiten.

Wer eine Schwierigkeit oder einen eigenen Fehler bemerkt, trägt ihn hier ein (siehe `AGENTS.md`, Regel 9).

## Eintragsformat

```markdown
### <Kurztitel>

- **Problem:** Was schiefging bzw. was schwer war.
- **Falsch:** Der fehlerhafte Ansatz oder Code (kurz).
- **Richtig:** Die funktionierende Lösung (kurz, mit Codebeispiel wenn nötig).
- **Status:** verifiziert (getestet/gelesen) | vermutet | nicht geprüft
- **Quelle:** Doku-Link oder Datei, wo es auftrat (optional).
```

Neue Einträge am Ende der passenden Kategorie anfügen. Veraltete Einträge korrigieren oder löschen, nicht duplizieren.

## Kategorien

- Syntax und Sprache
- Objekte, Maps, Arrays
- Fehlerbehandlung
- Prozesse, Pipes, Nachrichten
- GUI und Hotkeys
- Tests und Werkzeuge

---

## Syntax und Sprache

### Lambda kann kein `throw` enthalten

- **Problem:** Ein Test wollte einen Fehler aus einer Lambda werfen. Das Skript brach beim Laden ab.
- **Falsch:** `TestRun.Case("x", () => throw ValueError("boom"))`
- **Richtig:** `throw` ist eine Anweisung, keine Ausdruck. Eine benannte Funktion verwenden: `ThrowBoom() { throw ValueError("boom") }` und dann `() => Assert.Throws(ThrowBoom, ValueError)`.
- **Status:** verifiziert (Editor-Diagnose und Ladefehler, `tests/ahk/selfcheck.test.ahk`)

### FileAppend schreibt bei neuer Datei ein BOM

- **Problem:** Die Ergebnisdatei der AHK-Tests beginnt mit einem UTF-8-BOM. Ein Python-Leser mit `utf-8` bekommt `﻿` vor dem ersten JSON-Objekt.
- **Falsch:** `FileAppend(line, path, "UTF-8")` und Lesen mit `encoding="utf-8"`.
- **Richtig:** Die Hilfe sagt: Ein BOM wird nur geschrieben, wenn `"UTF-8"` oder `"UTF-16"` angegeben ist, und nur bei neu angelegter Datei. Python liest mit `encoding="utf-8-sig"`. Für Ausgaben ohne BOM (Flow-Dateien) `"UTF-8-RAW"` nehmen: verifiziert in `tests/test_json_flows.py` (keine BOM-Bytes in den geschriebenen Dateien).
- **Status:** verifiziert (Ausgabedatei mit BOM gesehen, Python-Leser mit `utf-8-sig` in `tests/conftest.py`; `UTF-8-RAW` in WI-02)
- **Quelle:** https://www.autohotkey.com/docs/v2/lib/FileAppend.htm

### #Include relativ zur einbindenden Datei

- **Problem:** Test-Skripte binden `lib\Assert.ahk` ein. Die Pfade hängen von der Datei ab, nicht vom Arbeitsverzeichnis.
- **Richtig:** Relative `#Include`-Pfade beziehen sich auf das Verzeichnis der Datei, die `#Include` enthält. `SetWorkingDir` wirkt darauf nicht, weil `#Include` vor dem Start des Skripts verarbeitet wird. Für Pfade in Testdateien, die aus Python erzeugt werden, den absoluten Pfad einsetzen.
- **Status:** verifiziert (Tests mit Skripten im `datadir` und mit `tests/ahk/`)
- **Quelle:** https://www.autohotkey.com/docs/v2/lib/_Include.htm

### Statische Methode als Callback verschiebt die Parameter

- **Problem:** `Log.Configure(Log.Memory)` mit `static Memory(level, source, text, flowId)` lieferte `level` = zweites Argument ("args" statt "a1"). Eine Senke `this.sink(...)` mit einer freien Funktion bekam das Objekt `Log` als zusätzliches erstes Argument: "Too many parameters passed to function" bzw. ein leeres Array (IndexError). Beides wurde in `Log.Write` still geschluckt und nur gezählt, deshalb sah man die Ursache nicht sofort.
- **Falsch:** `static Memory(level, ...)` als Senke übergeben. Oder `this.sink(level, ...)` aufrufen, wenn `sink` eine Funktion ist.
- **Richtig:** Callbacks als Funktionseigenschaft definieren, `static Memory := (level, source, text, flowId := "") => ...`. Beim Aufruf über eine lokale Variable: `sink := this.sink` und dann `sink(level, ...)`. So bekommt die Funktion genau die übergebenen Argumente.
- **Status:** verifiziert (`tests/ahk/core_log.test.ahk`, Fälle "custom sink function" und "sink receives level, source, text and flowId")
- **Quelle:** `src/core/Log.ahk`

### Aufruf ohne Ergebnispfad zeigt einen Dialog

- **Problem:** `python tools/ahkrun.py tests/ahk/core_ids.test.ahk` startete die Testdatei ohne Ergebnispfad. `TestRun.Init` wirft "missing result file argument", der Dialog-Wächter hat ihn gefangen (Exit 97). Das ist korrekt, aber keine gültige Testausführung.
- **Richtig:** Testdateien über pytest laufen lassen (`python -m pytest tests -q`). Der Runner übergibt den Ergebnispfad. Direkt nur mit Ergebnisdatei als Argument: `python tools/ahkrun.py tests/ahk/core_ids.test.ahk C:\...\result.jsonl`.
- **Status:** verifiziert (Dialog-Wächter-Lauf, Exit 97)

### Backslash ist in AHK v2 kein Escape-Zeichen

- **Problem:** Beim Schreiben von JSON-Testtexten und Escape-Erwartungen stimmte die Länge nicht, weil `"\\"` zwei Backslashes ergibt.
- **Falsch:** `"\\"` erwarten, wenn ein Backslash gemeint ist.
- **Richtig:** `"\"` ist ein Backslash, `"\\"` sind zwei. Der Escape-Charakter ist der Backtick: `` `n ``, `` `t ``, `` `r ``. In `"..."` ist ein Anführungszeichen `""`, in `'...'` einfach `"`. JSON-Text mit Escapes in einfachen Hochkommata schreiben: `'"é"'`.
- **Status:** verifiziert (`tests/ahk/json.test.ahk`, Fälle zu Steuerzeichen und Escapes)

### `<` vergleicht Strings numerisch, `Sort` sortiert nur Text

- **Problem:** `"a" < "B"` öffnete den Dialog "Expected a Number but got a String". `Sort(array)` öffnete "Parameter #1 of Sort requires a String".
- **Falsch:** `if (a < b)` für Textordnung. `Sort(arr)` mit einem Array.
- **Richtig:** Textordnung über `Ord()` der Zeichen vergleichen (siehe `Json.Less` in `src/core/Json.ahk`). Ein Array sortiert AHK v2 nicht von sich aus; `Sort` arbeitet nur auf Text mit Trennzeichen.
- **Status:** verifiziert (Ausgabe im Experiment, `Json.SortedKeys` in den Tests)

### `=` und `!=` vergleichen Strings ohne Groß-/Kleinschreibung

- **Problem:** Eine Literalprüfung soll `True` nicht als `true` durchlassen.
- **Falsch:** `SubStr(text, pos, 4) != "true"`.
- **Richtig:** `!==` (und `==`) vergleichen case-sensitiv. `Json.ParseLiteral` nutzt `!==`.
- **Status:** verifiziert für `!==` (Test "invalid literal is rejected" mit `[True]`). `!=` selbst nicht gesondert getestet, Verhalten laut Doku.

### Float als Text: Präzision und Form

- **Problem:** Die Standardumwandlung ist für JSON ungeeignet: Präzision geht verloren, und `1.0` wird zu `1`, also zu einer Ganzzahl beim Lesen.
- **Falsch:** `"" f` oder `String(f)` für JSON-Ausgabe.
- **Richtig:** `Format("{:.15g}", f)`, wenn `Float(s) != f`, dann `Format("{:.17g}", f)`. Fehlt `.` und `e`, `.0` anhängen. `Float("1e400")` liefert `inf`, das muss vorher abgewiesen werden (`f - f != 0`).
- **Status:** verifiziert (`Format`-Ausgaben: `1/3` gibt `0.33333333333333331`, `1e20` gibt `1e+20`, `1.0` gibt `1`; Tests zur Präzision). Die Standardumwandlung eines Floats in Text wurde nicht geprüft.

### Verschachtelte Klasse mit statischem Singleton

- **Problem:** `Json.Null` als Singleton einer eigenen Klasse, ohne eine zweite Klasse in derselben Datei anzulegen.
- **Richtig:** `class Json { class NullValue {} static Null := Json.NullValue() }` funktioniert. `Type()` liefert `Json.NullValue`. Die verschachtelte Klasse muss vor der statischen Zeile stehen, damit der Lader sie kennt (in `Json.ahk` so umgesetzt).
- **Status:** verifiziert (`tests/ahk/json.test.ahk`, Fall "Json.Null is a singleton")

### Performance: Aufrufe pro Zeichen kosten

- **Problem:** Ein Parser mit `SubStr` pro Zeichen und Eigenschaftszugriff pro Zeichen brauchte 2,8 s für 10.000 Nachrichten zu je 364 Zeichen.
- **Richtig:** Textläufe mit einem `RegExMatch`-Aufruf je Zeichenkette holen, Zeichencodes per `NumGet` aus einem UTF-16-Puffer lesen, `SkipWs` ohne Regex, wenn kein Leerzeichen folgt. Danach etwa 1,5 s Parsen und 0,6 s Schreiben (Messlauf, `tests/test_json_flows.py`). Die Restkosten sind die Methodenaufrufe pro Token. Das Ziel "unter 1 s" wurde damit nicht erreicht.
- **Status:** verifiziert (gemessen, Werte schwanken je Lauf)

### Reserviertes Wort `loop` nicht als Variablenname

- **Problem:** In einem Test hieß eine Variable `loop`. Der Editor meldete "The following reserved word 'loop' must not be used as a variable name", dazu Folgefehler wie "Missing operand" an den Stellen, an denen die Variable benutzt wurde.
- **Falsch:** `loop := inst.Threads["t1"]` und `RunElement(loop, "head")`.
- **Richtig:** Anderen Namen wählen (`loopThread`). Das Wort in Zeichenketten (`"type":"loop"`) ist unproblematisch. Die Editor-Diagnose vor dem ersten Testlauf lesen, dann erspart man sich einen Ladefehler.
- **Status:** verifiziert (Editor-Diagnose in `tests/ahk/engine_scheduler.test.ahk`, nach dem Umbenennen laufen die Tests grün)

### Wahrheitswerte sind Integer 1 und 0

- **Problem:** Eine Methode, die `true` oder `false` zurückgibt, liefert in AHK v2 einen Integer. `Assert.Equal(x, false)` prüft deshalb auf Integer, nicht auf einen Bool-Typ. Die Fehlermeldung zeigt "expected 0 (Integer)".
- **Richtig:** Für Rückgabewerte wie `TryTransition` `Assert.Equal(ok, false)` oder `Assert.True(ok)` verwenden. Beide Seiten sind dann Integer.
- **Status:** verifiziert (`tests/ahk/engine_states.test.ahk`, Vergleiche mit `false` und `true`)

### Dieselbe Datei über verschiedene relative `#Include`-Wege

- **Problem:** `src/core/Log.ahk` wird über `Instance.ahk` (und `ThreadState.ahk`) eingebunden und zusätzlich direkt vom Test. Es war unklar, ob AHK dabei eine doppelte Klassendefinition meldet.
- **Richtig:** Kein Fehler. Die Pfade `..\..\core\Log.ahk` und `..\..\src\core\Log.ahk` zeigen auf dieselbe Datei, AHK lädt sie einmal. Mehrfach-Einbindung über Abhängigkeitsketten ist damit unkritisch.
- **Status:** verifiziert (Testläufe `engine_states` und `engine_scheduler` ohne Ladefehler)
- **Quelle:** `src/engine/core/Instance.ahk`, `tests/ahk/engine_states.test.ahk`

### Zähler für Test-IDs im Closure statt global

- **Problem:** Tests brauchen fortlaufende Thread-IDs. Globale Variablen verbietet `doc/KONVENTIONEN.md`, eine `static`-Variable in einer Funktion war schwer zu lesen.
- **Richtig:** Ein Map-Objekt anlegen und die Funktion als Closure übergeben: `counter := Map("n", 1)` und `() => NextId(counter)`. Das Map-Objekt ist veränderlich und wird von allen Aufrufen gemeinsam benutzt.
- **Status:** verifiziert (`MakeIds` in `tests/ahk/engine_scheduler.test.ahk`)

### Funktion in einer Eigenschaft: Aufruf mit Punkt übergibt die Klasse als erstes Argument

- **Problem:** `Role.ConsoleFn("a0", "role", text)` (Funktionseigenschaft mit Lambda) öffnete den Dialog "Expected a String but got a Class". Der erste Parameter war die Klasse `Role`, nicht der Pegel.
- **Falsch:** `static ConsoleFn := (level, source, text) => ...` und der Aufruf `Klasse.ConsoleFn(...)`.
- **Richtig:** Die Funktion über eine statische Methode aufrufen (`Role.Console(...)`). Die Eigenschaft nur als Wert übergeben, z. B. `Log.Configure(Role.ConsoleFn)` oder als Callback. Gleiches Muster wie `Log.Write`, dort über die lokale Kopie `sink := this.sink`.
- **Status:** verifiziert (Dialog beim Start mit unbekannter Rolle, danach grün). Warum AHK den Klassennamen durchreicht, wurde nicht in der Doku nachgelesen: vermutet.
- **Quelle:** `src/core/Role.ahk`

### Lokale Variable mit dem Namen einer Klasse

- **Problem:** In `AhfMain` stand `role := ""`. Danach schlug `Role.ConsoleFn(...)` im selben Gültigkeitsbereich fehl: "This local variable has not been assigned a value. Specifically: role".
- **Falsch:** Lokale Variable `role` neben der Klasse `Role`.
- **Richtig:** AHK v2 behandelt Bezeichner ohne Unterschied der Schreibweise, `role` ist also `Role`. Lokale Namen nicht wie Klassen wählen (`roleObj`).
- **Status:** verifiziert (Dialog beim Start, nach der Umbenennung grün).
- **Quelle:** `src/AutoHotFlow.ahk`

### Feld und Methode mit gleichem Namen: `Property is read-only`

- **Problem:** Eine Klasse hatte ein Feld und eine Methode mit Namen, die sich nur in der Schreibweise unterscheiden. AHK v2 behandelt Bezeichner case-insensitiv, also sind es dieselben Namen. Der Zugriff auf das Feld schlug mit "Property is read-only" fehl.
- **Falsch:** Feld `state` und Methode `State()` in derselben Klasse.
- **Richtig:** Felder und Methoden verschieden benennen (z. B. Feld `stateName`, Methode `State()`), auch wenn die Schreibweise nur leicht abweicht.
- **Status:** verifiziert (im Lauf von WI-07 gefunden; die Fundstelle wurde für diesen Eintrag nicht erneut geprüft)
- **Quelle:** `src/supervisor/` (WI-07)
- **Wieder aufgetreten (WI-10):** `src/engine/Engine.ahk` hatte das Feld `_loaded` und die Methode `_Loaded()`. Der Start der Rolle schlug mit der gleichen Meldung fehl (Exit 2, "bad arguments: Property is read-only"). Behoben durch Umbenennen des Feldes in `_flowsLoaded`. Vor dem Benennen einer Methode `_X()` prüfen, ob es schon ein Feld `_x` gibt.

## Objekte, Maps, Arrays

### Map mit `CaseSense "Off"` behält die Schreibweise der ersten Einfügung

- **Problem:** Offene Prüfung von WI-02: Bleibt die Schreibweise der Schlüssel bei der Aufzählung erhalten?
- **Richtig:** Ja. Die erste Einfügung bestimmt die Schreibweise. Eine spätere Einfügung in anderer Schreibweise ersetzt nur den Wert. Die Aufzählung ist außerdem sortiert (`zebra`, `apple`, `mango` kommen als `apple`, `mango`, `zebra`). Ein eigener `AhfMap` ist deshalb nicht nötig. Zwei Schlüssel, die sich nur in der Schreibweise unterscheiden, werden zu einem: `Json.Parse` weist das ab.
- **Status:** verifiziert (`tests/ahk/json.test.ahk`, "Map CaseSense Off keeps the first spelling of a key" und "... enumerates keys in sorted order"). Die Sortierung ist beobachtet, nicht dokumentiert.

### Schlüssel vor dem Löschen aus einer Map in ein Array kopieren

- **Problem:** Beim Stoppen einer Instanz werden Threads aus einer `Map` entfernt, während über die Map iteriert wird.
- **Richtig:** Die Schlüssel zuerst in ein Array kopieren, dann in dieser Liste laufen (`Instance.Stop`). Ob das Löschen während der `for`-Schleife über eine Map funktioniert, wurde nicht geprüft; die Kopie vermeidet die Frage.
- **Status:** nicht geprüft (nur das Muster mit Kopie ist im Einsatz)
- **Quelle:** `src/engine/core/Instance.ahk`

### Statische Methode `Name()` verdeckt die `.Name`-Eigenschaft der Klasse

- **Problem:** Die Registry wollte die Klassen-ID aus `cls.Name` lesen. Bei Element-Klassen liefert das eine Funktion (Typ `Func`), nicht den Klassennamen, weil `static Name()` die eingebaute Eigenschaft verdeckt.
- **Falsch:** `id := cls.Name` für Klassen mit `static Name() => ...`.
- **Richtig:** Die Klassen-ID als Typ einer Instanz lesen: `Type(cls())` liefert `Action_Sleep`. Elemente haben keinen Konstruktor, der Aufruf ist billig. Siehe `ElementRegistry.IdOf`.
- **Status:** verifiziert (Probe im Scratchpad: `cls.Name` gibt `Func`, `Type(cls())` gibt den Klassennamen; `tests/ahk/element_registry.test.ahk`, Fall "IdOf gives the class name")
- **Quelle:** `src/elements/base/ElementRegistry.ahk`

### `static __New()` setzt die Schlüsselschreibweise einer statischen Map

- **Problem:** Eine `static`-Map soll Schlüssel ohne Groß-/Kleinschreibung speichern. Die Einstellung `CaseSense` lässt sich in der Klassenzeile nicht als Anweisung ausführen.
- **Richtig:** `static __New() { this.classes.CaseSense := "Off" }` läuft beim Laden der Klasse, vor der ersten Nutzung. Danach findet `Has("TRIGGER_MANUAL")` einen Eintrag `Trigger_Manual`.
- **Status:** verifiziert (Probe im Scratchpad: `Has` case-insensitiv; `tests/ahk/element_registry.test.ahk`, Fall "lookup is case-insensitive")
- **Quelle:** `src/elements/base/ElementRegistry.ahk`

### Callback mit Zustand: `ObjBindMethod` statt Lambda in der Schleife

- **Problem:** Die Engine liest je Flow-Datei eine Antwort von `storage`. Der Callback braucht den Namen und den Pfad der Datei, und ein Zähler der offenen Antworten muss von allen Callbacks gemeinsam geändert werden.
- **Falsch:** `for f in files { peer.Request(..., (res) => this._OnRead(st, f["name"], res)) }`. Lambdas erfassen Variablen per Referenz, alle Callbacks sähen am Ende den letzten Eintrag.
- **Richtig:** `peer.Request(..., ObjBindMethod(this, "_OnFlowRead", st, name, path), timeout)`. Die gebundenen Argumente kommen vor dem Argument des Aufrufers, der Callback ist `_OnFlowRead(st, name, path, res)`. Der Zähler ist eine `Map`, damit alle Callbacks dieselbe Änderung sehen.
- **Status:** verifiziert (`tests/integration/test_engine.py`, Laden von zwei Flow-Dateien, Fehlerdatei mit `flow.parse`, Namen und Pfade stimmen).
- **Quelle:** `src/engine/Engine.ahk` (`_OnFlowList`)

### Parameter eines Elements als Objekt mit Eigenschaftszugriff

- **Problem:** `Action_Sleep` liest `params.Duration` und `params.Unit` (Eigenschaftszugriff, wie v1). Die Flow-Datei hat die Parameter als `Map`.
- **Falsch:** Die `Map` direkt als `params` übergeben.
- **Richtig:** Ein Objekt bauen: `p := {}` und für jeden Schlüssel `p.%k% := v` (Objekte und `null` werden zu `""`). Eigenschaftsnamen sind case-insensitiv, wie v1 es braucht.
- **Status:** verifiziert (Sleep mit Duration `200` und Unit `Milliseconds` in `tests/integration/test_engine.py`). Nicht geprüft: ob `Map` mit `HasProp` für Schlüssel genauso falsch antwortet.
- **Quelle:** `src/engine/Executor.ahk` (`_Params`)

## Fehlerbehandlung

### Statische Methode ist kein OnError-Callback

- **Problem:** `OnError(TestRun.OnUnhandled)` mit einer statischen Klassenmethode brach mit "Invalid callback function" ab. Der Fehler trat schon beim Init auf, das Skript endete ohne Ergebnisdatei.
- **Falsch:** `static OnUnhandled(e, mode)` in einer Klasse, dann `OnError(Klasse.OnUnhandled)`.
- **Richtig:** Eine freie Funktion `AhfUnhandledError(e, mode)` übergeben. Sie schreibt eine `fatal`-Zeile und beendet mit `ExitApp(2)`. Damit hängt kein Fehlerdialog den Lauf auf.
- **Status:** verifiziert (`tests/ahk/lib/Assert.ahk`, Test `test_unhandled_error_ends_run_without_dialog`)

### Skript ohne Summary endet mit Exit-Code 0

- **Problem:** Ein Skript, das vor `TestRun.Finish()` endet (etwa nach einem Ladefehler, der still bleibt, oder vergessenem Finish), liefert Exit-Code 0 und keine Summary. Allein am Exit-Code erkennt man den Fehler nicht.
- **Richtig:** Der Runner verlangt die Summary-Zeile zusätzlich zu Exit-Code 0 (`test_ahk_file_completes`).
- **Status:** verifiziert (Test `test_script_without_finish_has_no_summary`, Beobachtung beim Fehlschlag des Init)

### Laufzeitfehler in Lambda gilt als "error", nicht als "fail"

- **Problem:** Unterscheidung zwischen Assert-Fehlschlag und unerwartetem Fehler muss für den Bericht erhalten bleiben.
- **Richtig:** `TestRun.Case` fängt `AssertFailed` als `fail` und jeden anderen Fehler als `error` mit Typ, Meldung und Zeile.
- **Status:** verifiziert (Test `test_failing_and_erroring_cases_are_reported_red`)

### Callback, der wirft, bricht den Zustandsautomaten nicht ab

- **Problem:** Der Callback `onInvalid` eines Zustandsautomaten kann selbst einen Fehler werfen. Ungefangen würde das den Übergang mitten im Aufruf abbrechen.
- **Richtig:** Den Callback in `try/catch` aufrufen, den Fehler als a0-Log schreiben und trotzdem `false` zurückgeben (`ThreadState.ReportInvalid`).
- **Status:** verifiziert (Test "a throwing callback is logged, not raised" in `tests/ahk/engine_states.test.ahk`)
- **Quelle:** `src/engine/core/ThreadState.ahk`

### OnError: Rückgabe 1 hält den Prozess am Leben

- **Problem:** Ein Fehler in einem Timer soll eine Rolle nicht beenden, und der Standarddialog darf nicht erscheinen.
- **Richtig:** Die Funktion für `OnError` gibt `1` zurück. Der Fehler ist dann behandelt, es erscheint kein Dialog, und der Prozess läuft weiter. Getestet: Ein Timer wirft `ValueError`, danach beantwortet die Rolle weitere Befehle, und der Fehler steht im Log (`test_error_in_a_timer_is_logged_and_the_role_keeps_running`).
- **Status:** verifiziert (Test grün). Nicht geprüft: andere Rückgabewerte (z. B. 0) und das Verhalten des Threads, der den Fehler warf, bei anderen Auslösern als Timer.
- **Quelle:** `src/core/Role.ahk` (`Role._OnUnexpected`)

## Prozesse, Pipes, Nachrichten

_Noch keine Einträge._

## Prozesse, Pipes, Nachrichten

### Pipe-Lesen und -Schreiben nur mit überlappten E/A parallel

- **Problem:** Der Python-Client braucht einen Lesethread, während der Hauptthread schreibt. Mit `open(..., "r+b")` (synchroner Handle) wäre das ein Risiko, weil Windows E/A auf demselben synchronen Handle serialisiert. Ein wartendes Lesen würde das Schreiben blockieren.
- **Richtig:** `FILE_FLAG_OVERLAPPED` mit eigenem OVERLAPPED und Event je Richtung (`tests/support/winpipe.py`). Schreiben über ein Lock, Lesen mit Timeout über `WaitForSingleObject` und `CancelIoEx`.
- **Status:** verifiziert (Tests `tests/support/test_client_hub.py`, Anfrage und Antwort während laufendem Lesethread). Der synchrone Fall selbst wurde nicht getestet: vermutet.

### PostMessageW mit NULL-Handle meldet Erfolg

- **Problem:** Ein Test erwartete `False` für `PostMessageW(0, ...)` (kein Fenster). Der Aufruf meldet `TRUE`.
- **Richtig:** Für "Fenster existiert nicht" ein echtes, zerstörtes Fenster-Handle verwenden. Die Rückgabe von `wake()` nicht als Fehlerprüfung nutzen.
- **Status:** verifiziert (fehlschlagender Test, danach entfernt)

### Overlapped-Struktur: Felder mit ctypes

- **Problem:** Der Spike setzte `hEvent` über einen Offset (`2*A_PtrSize + 8`). In Python ist die Struktur bequemer, aber die Feldgrößen müssen stimmen.
- **Richtig:** `ctypes.Structure` mit `c_size_t` für `Internal`/`InternalHigh`, `DWORD` für `Offset`/`OffsetHigh`, `HANDLE` für `hEvent`. Puffer über `ctypes.addressof(...)` als Ganzzahl übergeben, nicht als Array.
- **Status:** verifiziert (Tests laufen durch, Lese- und Schreibpuffer)

### AHK: überlappende Pipe-E/A mit DllCall (Muster, das trägt)

- **Problem:** Server und Client brauchen nicht blockierende Pipes in AHK v2 ohne Threads (WI-04, `src/core/ipc/`).
- **Richtig:**
  - `OVERLAPPED` als `Buffer(32, 0)`, Ereignis (`CreateEventW`, manuell, nicht signalisiert) bei Offset `2*A_PtrSize + 8` eintragen. Struktur, Puffer und Ereignis als Mitglieder halten, nie lokal.
  - Lesen: `ResetEvent`, `ReadFile(h, buf, n, 0, ov)` (Byte-Zähler `NULL` ist bei überlappter E/A erlaubt). Rückgabe 0 und `A_LastError = 997` ist der Normalfall. Fertigstellung nie mit `WaitForSingleObject` auf Rückgabe 0 prüfen, sondern mit `GetOverlappedResult(h, ov, &n, 0)`: `0` mit Fehler `996` (`ERROR_IO_INCOMPLETE`) heißt "noch nicht", jeder andere Fehler ist das Ende. Das gilt auch, wenn `ReadFile`/`WriteFile` sofort `TRUE` lieferte.
  - Gegenseite weg: `109` (`ERROR_BROKEN_PIPE`) beim Lesen, `232` oder `109` beim Schreiben. Ein Lesen mit `0` Bytes im Byte-Modus ist ebenfalls das Ende.
  - Schließen: `CancelIoEx(h, 0)`, auf das Ereignis der ausstehenden Vorgänge warten (begrenzt), erst dann `CloseHandle` und Puffer freigeben. Bereits geschriebene Rahmen bleiben für die Gegenseite lesbar, auch wenn man sofort schließt (getestet: `test_data_written_before_close_is_still_readable`).
  - Server: eine wartende Instanz pro `PipeListener`. `ConnectNamedPipe` kann `535` (`ERROR_PIPE_CONNECTED`) liefern, wenn der Client schneller war: das gilt als verbunden. Die nächste Instanz vor dem Übergeben der verbundenen anlegen, dann sieht ein Client nie "nicht gefunden".
  - Client: `CreateFileW` mit Wiederholung bei `2` und `231`. Für das Warten `DllCall("Sleep")` und `WaitNamedPipeW` nehmen: AHKs eigenes `Sleep` verarbeitet Nachrichten und würde Timer und Weckrufe mitten in den Verbindungsaufbau ziehen.
- **Status:** verifiziert (`tests/integration/test_pipe.py`, 26 Tests, beide Richtungen mit Python-Gegenstelle und AHK-Gegenstelle). Dass AHKs `Sleep` Nachrichten verarbeitet, steht in der Doku und wurde nicht gesondert gemessen.
- **Quelle:** `src/core/ipc/PipeConnection.ahk`, `PipeListener.ahk`

### Der Weckruf deckt nur das Schreiben ab (Folge-Timer und Fallback-Timer)

- **Problem:** Der Weckruf sagt nur "Daten geschrieben", nicht "Daten gelesen". Ein ausstehendes überlapptes `WriteFile` (große Warteschlange) und der Verbindungsabbruch lösen keine Nachricht aus. Mit nur Weckruf stockte der Abfluss großer Rahmen auf 250 ms je Rahmen, und ein Python-Gegenüber, das keinen Weckruf kennt, hätte dauerhaft Verzögerung.
- **Richtig:** Zwei Wege: (1) Hat eine Verbindung noch Rahmen in der Warteschlange, plant `SendFrame`/`Pump` mit `SetTimer(fn, -1)` einen Folge-Pump (damit läuft der Abfluss mit Timer-Auflösung, nicht mit 250 ms). (2) Der Fallback-Timer (250 ms, `Wake.Install`) erkennt Verbindungsabbruch und neue Clients. Gemessen: Abbruch eines Prozesses wird nach 42 bis 98 ms bemerkt (je nach Phase des Timers, höchstens ca. 250 ms). Eine neue Verbindung ohne Weckruf des Clients wird nach höchstens ca. 250 ms angenommen. Clients sollten nach dem Verbinden einen Weckruf an den Hub senden.
- **Status:** verifiziert (Messungen im Testlauf mit `-s`). Die Verhältnisse im echten Hub (viele Clients) sind nicht geprüft.

### Statische Methode ist kein SetTimer-Callback

- **Problem:** `SetTimer(Role.Run, -1)` mit `static Run() {...}` öffnet den Dialog "Invalid callback function". Der Helferprozess hing, bis der Dialog-Wächter ihn beendete (Exit 15, keine Ergebnisdatei).
- **Falsch:** `SetTimer(Klasse.Methode, ...)` mit einer statischen Methode.
- **Richtig:** Funktionseigenschaft `static RunFn := (*) => Role.Run()` und `SetTimer(Role.RunFn, ...)`, oder `ObjBindMethod(Role, "Run")`. Dieselbe Falle wie bei `OnError` (siehe oben). Dieselbe Funktionseigenschaft muss auch zum Abschalten (`SetTimer(fn, 0)`) übergeben werden.
- **Status:** verifiziert (Dialogtext im Wächterordner, Test grün nach der Änderung)

### Wiedereintritt: Pump, SendFrame und Handler unterbrechen einander

- **Problem:** AHK-Threads werden nach 15 ms Laufzeit unterbrochen (Weckruf, Timer). Ein `OnFrame`-Handler, der selbst `SendFrame` aufruft, und ein unterbrechender `Pump` greifen auf dieselben Warteschlangen zu.
- **Richtig:** Pro Verbindung zwei Wächter-Flags (`_pumping`, `_writing`) mit "nochmal"-Flag. Prüfen und Setzen in `prev := Critical("On") ... Critical(prev)` kapseln, weil zwei getrennte Zeilen sonst unterbrochen werden könnten. `Critical("On")` liefert die vorherige Einstellung (`0` aus, `16` an), `Critical(prev)` stellt sie wieder her. Handlerfehler werden gefangen und geloggt, sonst bliebe der Zustandsautomat halb fertig. `OnClose` bei `queue_overflow` aus `SendFrame` heraus wird per `SetTimer(fn, -1)` verzögert, damit die Schleife des Aufrufers nicht durch den Handler verändert wird.
- **Status:** verifiziert für die Funktion (Tests grün, 12000 Ping-Pong-Läufe ohne verlorenen Weckruf). Die Wächter selbst sind nicht gezielt gegen eine echte Unterbrechung getestet (nicht reproduzierbar erzwungen): vermutet.

### Warteschlangengrenze: Rückstand hinter dem laufenden Rahmen, vorher abgeschlossene Schreibvorgänge einsammeln

- **Problem:** Zwei Fehler in Folge. (1) Erste Fassung prüfte `Rückstand + neuer Rahmen > maxQueueBytes`: ein 16-MiB-Rahmen wurde mit `queue_overflow` abgelehnt, wenn noch ein kleiner stand. (2) Zweite Fassung prüfte den Rückstand vor dem Rahmen inklusive des laufenden: nach dem Echo eines 16-MiB-Rahmens hatte der Leser alles gelesen, aber niemand hatte den Abschluss eingesammelt (`Pump` lief noch nicht). Der nächste kleine Rahmen sah 16 MiB Rückstand und löste `queue_overflow` aus (ca. 1 von 5 Läufen von `test_frame_of_exactly_16_mib_is_echoed`).
- **Falsch:** `queueBytes + size > maxQueueBytes`, und der Rückstand zählt den laufenden Rahmen und nicht eingesammelte, längst fertige Schreibvorgänge mit.
- **Richtig:** In `SendFrame` zuerst `_DriveWriteGuarded()` (fertige Schreibvorgänge einsammeln), dann gilt Überlauf, wenn die Bytes **hinter** dem laufenden Rahmen (`queueBytes - queue[1].Size`) `maxQueueBytes` erreicht haben oder `maxQueueFrames` Rahmen anstehen. Der laufende Rahmen ist durch das Rahmenlimit begrenzt und Sache des Kernels. Ein einzelner großer Rahmen ist immer sendbar.
- **Status:** verifiziert (40 aufeinanderfolgende Einzelläufe grün, 3 Gesamtläufe grün; vorher 3 von 20 rot, ein Teil davon dieser Fehler)

### Python-Testleser verlor Bytes beim Abbruch eines Lesevorgangs (`winpipe.read_some`)

- **Problem:** `test_frame_of_exactly_16_mib_is_echoed` wartete gelegentlich 60 s auf eine Antwort, obwohl der AHK-Server sie vollständig geschrieben hatte (Server: `wp=0 q=0`, `echo_big sendOk=1`). Ursache lag in der Python-Testunterstützung: `read_some` wartet 100 ms, bricht dann mit `CancelIoEx` ab und gab danach immer `None` zurück. Schließt der Lesevorgang zwischen Wartezeitende und Abbruch ab (Thread kurz verdrängt, GIL), tut der Abbruch nichts, die Bytes liegen in `n` und wurden verworfen. Ein Rahmen fehlte dann für immer.
- **Falsch:** Nach `CancelIoEx` und `GetOverlappedResult(..., wait=True)` das Ergebnis ignorieren und `None` liefern.
- **Richtig:** Ist `GetOverlappedResult` erfolgreich mit `n > 0`, die Bytes zurückgeben. Ein überlapptes Lesen kann beim Abbruch trotzdem abgeschlossen sein (dasselbe gilt für Schreiben). Gefunden mit Zustandsprotokoll des Servers (`status`-Datensätze in `pipe_echo_server.ahk`): Server fertig, Client ohne Daten.
- **Status:** verifiziert (60 von 60 Läufen eines Schleifen-Skripts grün, vorher Ausfall nach 10 bis 40 Läufen; 40 Einzelläufe und 3 Gesamtläufe grün)
- **Quelle:** `tests/support/winpipe.py` (WI-01), behoben im Zuge von WI-04

### `Round(x, 1)` liefert einen String

- **Problem:** Ein Messwert mit `Round(ms, 1)` landete in der JSON-Datei als `"14.1"` (String), der Python-Test verglich ihn mit einer Zahl.
- **Richtig:** `Round(x, n)` mit `n > 0` ist ein `String`, `Round(x)` ein `Integer`. Für eine Zahl `Round(x, 1) + 0` (Float) schreiben.
- **Status:** verifiziert (`Type(Round(3.14159, 1))` gibt `String`)

### Stand-in-Hub ohne Weckruf: jede Nachricht wartet 250 ms
- **Problem:** `tests/support/pyhub.py` leitet Nachrichten weiter, ohne den Empfänger zu wecken. Der AHK-Peer verarbeitet sie dann erst beim Fallback-Timer. Eine Anfrage mit Antwort kostet dann etwa 250 ms je Richtung, 10.000 Anfragen also rund 40 Minuten.
- **Falsch:** `PyHub` unverändert als Hub für Peer-Tests nutzen.
- **Richtig:** `WakingHub(PyHub)` in `tests/integration/test_peer.py` weckt nach jeder Nachricht die Fenster aller Verbindungen mit bekanntem Fenster (`rawpipe.wake`). Das ist die Pflicht des Senders aus PROTOKOLL 1. `pyhub.py` selbst blieb unverändert (liegt außerhalb des Pakets).
- **Status:** verifiziert (10.000 Anfragen mit `WakingHub` in 9,9 s). Den Wert ohne Weckruf (250 ms) übernehme ich aus der WI-04-Messung, für den Peer-Pfad nicht gesondert gemessen.
- **Quelle:** `tests/integration/test_peer.py`, `work_items/phase2/WI-04-ipc-pipe.md`

### Handler-Rückgabe: nur ein leerer Wert gilt als "nichts zurückgegeben"
- **Problem:** `Dispatcher.Invoke` behandelte jede Nicht-Objekt-Rückgabe als "keine Rückgabe". Ein Handler, der `"text"` zurückgab, bekam `ok:true` statt eines Fehlers.
- **Falsch:** `if (!IsObject(result)) return Map("ok", true)`.
- **Richtig:** `if (!IsObject(result) && result == "")` ergibt `ok:true`. Jede andere Nicht-Map-Rückgabe wird `internal`.
- **Status:** verifiziert (Test "a handler returning a non-Map is an internal error" war rot, nach der Änderung grün; `tests/ahk/dispatcher.test.ahk`).
- **Quelle:** `src/core/ipc/Dispatcher.ahk`

### Verbindungsaufbau ohne Blockade: ein Versuch, Wiederholung per Timer
- **Problem:** `PipeConnection.Connect(name, 3000)` wartet bis zu 3 s mit `Sleep` im Aufrufer. Ein Peer, der beim Start auf den Hub wartet, würde seinen Nachrichtenpfad so lange anhalten.
- **Richtig:** `PipeConnection.Connect(name, 0)` macht genau einen Versuch und wirft sofort. Der Peer wiederholt per `SetTimer` mit Backoff (100, 200, 400 ... höchstens 2 s) und meldet nach der Gesamtfrist (10 s) `hub_unreachable`.
- **Status:** verifiziert (`test_hub_gone_for_longer_than_the_budget_calls_onclosed`: `OnClosed` nach 10,25 s; `test_reconnect_after_hub_restart_resubscribes_and_reports_ready_again`).
- **Quelle:** `src/core/ipc/Peer.ahk` (`_Attempt`, `_ScheduleRetry`)

### Ist der Verbindungsabbau noch der aktuelle? `ObjPtr` statt Vergleich
- **Problem:** Ein `OnClose` einer alten Verbindung darf den Zustand des Peers nicht verändern. Der Vergleich der Objekte ist nicht eindeutig dokumentiert.
- **Richtig:** `ObjPtr(c) != ObjPtr(this._conn)` vergleicht die Identität. Vor dem Zugriff `IsObject` prüfen, weil `this._conn` leer sein kann.
- **Status:** verifiziert für den Abbau-Pfad (Reconnect-Test und Timeout-Test laufen über `_OnConnClose`). Der Fall "alte Verbindung meldet nach dem Wechsel" wurde nicht gezielt erzeugt: nicht geprüft.
- **Quelle:** `src/core/ipc/Peer.ahk` (`_OnConnClose`)

### Ein Timer pro Anfrage: 10.000 Anfragen ohne wachsende Handles
- **Problem:** Jede Anfrage braucht einen Timeout. AHK bietet keine Zählung der aktiven Timer.
- **Richtig:** Ein `SetTimer(fn, -timeoutMs)` pro Anfrage, bei der Antwort `SetTimer(fn, 0)`. Gezählt wird über `Peer.PendingCount` (muss am Ende 0 sein). Die Handle-Zahl des Prozesses bleibt konstant.
- **Status:** verifiziert (10.000 sequentielle Anfragen: Handles 163 → 163 → 163, Pending 0, 0,99 ms je Anfrage). Die Zahl der aktiven Timer selbst ist nicht direkt messbar: nur indirekt über Pending.
- **Quelle:** `tests/integration/test_peer.py::test_10000_sequential_requests_keep_pending_and_handles_flat`

### Wahrheitswerte gehen als Zahl auf die Leitung
- **Problem:** Das Protokoll zeigt `"ok": true`. `Json.Parse` liefert `true` als `1`, und `Json.Stringify` schreibt diesen Integer als Zahl. Beim Vergleich in Python ist `1 == True`, so dass der Test den Unterschied nicht bemerkt.
- **Richtig:** Empfänger prüfen `ok` als Wahrheitswert, nicht als Text. Die Abweichung steht in `doc/PROTOKOLL.md`, Abschnitt 2. Ein eigener Bool-Typ im Json-Baustein wäre die saubere Lösung, ist aber ein Vertragswechsel (WI-02).
- **Status:** verifiziert (gelesen: `Json.Emit` schreibt Integer als Zahl). Die Bytes einer Antwort wurden nicht ausgegeben.
- **Quelle:** `src/core/Json.ahk`, `doc/PROTOKOLL.md`

### Zweimal `start()` über `with`
- **Problem:** `with WakingHub(name).start() as hub:` ruft `start()` zweimal auf, weil `PyHub.__enter__` selbst `start()` aufruft. Zwei Akzeptierschleifen auf demselben Namen wären die Folge.
- **Richtig:** `with WakingHub(name) as hub:` (der `__enter__` startet). Ohne `with` `hub = WakingHub(name).start()` und `hub.stop()` im `finally`.
- **Status:** vermutet (aus dem Quelltext von `tests/support/pyhub.py` gelesen, nicht ausgeführt). Im Code des Pakets so umgesetzt.
- **Quelle:** `tests/support/pyhub.py` (`__enter__`)

### sys.shutdown: Verbindung nicht im Rahmen-Handler schließen

- **Problem:** `sys.shutdown` muss `sys.bye` senden und danach den Prozess beenden. Ein `Peer.Close()` direkt im Handler schließt die Verbindung, während sie gerade den Rahmen abarbeitet. Das Ende des Handlers arbeitet dann mit einem geschlossenen Objekt.
- **Richtig:** Im Handler nur die Arbeit erledigen und `SetTimer(Role.ByeFn, -1)` setzen. Der Timer sendet `sys.bye {clean:true}`, schließt den Peer und ruft `ExitApp(0)`. Gemessen: Exit 0 etwa 240 ms nach dem Befehl, `sys.bye` kommt beim Hub an (`test_shutdown_sends_bye_and_exits_0_within_one_second`).
- **Status:** verifiziert (Test grün, gemessen). Ein direktes `Close` im Handler wurde nicht ausprobiert: nicht geprüft.
- **Quelle:** `src/core/Role.ahk` (`_OnShutdown`, `_FinishShutdown`)

### Hub-Verlust: die Frist des Orphan-Guards im eigenen Timer messen

- **Problem:** Der Peer wiederholt den Verbindungsaufbau bis zu 10 s (Budget). Eine Rolle soll sich aber nach 3 s beenden, und dafür braucht sie eine eigene Uhr.
- **Richtig:** Ein Timer (200 ms) liest `peer.status`. Steht dort `reconnecting`, merkt er sich den Zeitpunkt. Nach 3 s ohne `ready` ruft er `ExitApp(4)` auf. Gemessen: Ende 3,25 s nach dem Stopp des Hubs, kein Prozess übrig (psutil).
- **Status:** verifiziert (`test_hub_gone_role_ends_within_orphan_budget_and_leaves_no_process`). Der Beginn der Frist ist um bis zu 200 ms ungenau, weil er erst beim nächsten Timer-Tick gesetzt wird.
- **Quelle:** `src/core/Role.ahk` (`_Guard`)

### Ereignisse vor dem Abonnement gehen verloren: Snapshot nutzen

- **Problem:** Ein Client, der nach dem Start abonniert, bekommt die früheren `evt.process.*`-Ereignisse nicht. Wer auf `evt.process.ready` wartet, wartet dann vergeblich, wenn das Ereignis schon vorher kam.
- **Falsch:** Auf ein Ereignis warten, das vor `cmd.topic.subscribe` gesendet wurde.
- **Richtig:** Erst abonnieren, dann den Zustand per Momentaufnahme holen (`cmd.process.list` beim Supervisor, `cmd.engine.snapshot` bei der Engine). Ereignisse danach verarbeiten. Siehe `doc/PROTOKOLL.md`, Abschnitt 5a.
- **Status:** verifiziert (WI-07, `test_supervisor.py`, Warten über `process_list`)
- **Quelle:** `doc/PROTOKOLL.md` 5a, `src/supervisor/Children.ahk` (`Snapshot`)

### Hub.Request muss die registrierte Nachrichten-ID verwenden

- **Problem:** Die Antwort auf eine Anfrage des Supervisors muss den Rückruf finden (`corr` = ID der Anfrage). Trägt die Anfrage eine andere ID als die registrierte, findet die Antwort keinen Rückruf. Ohne Timer bliebe der Rückruf dann für immer offen (vor Commit `2bc8424` hatte `Hub.Request` keinen Timer).
- **Falsch:** Die ID für die Nachricht neu erzeugen, nachdem sie im Rückruf-Verzeichnis abgelegt wurde.
- **Richtig:** Die ID einmal erzeugen, im Verzeichnis unter dieser ID ablegen und dieselbe ID in die Nachricht setzen (`Hub.Request` in `src/supervisor/Hub.ahk`). Der Timer startet nach dem Senden und wird beim Abschluss gestoppt.
- **Status:** verifiziert (Test `test_answer_to_a_hub_request_reaches_its_callback_once` in `tests/integration/test_supervisor.py`: die echte Antwort beendet den Exit vor der Frist, kein Timeout im Log). Ein Fehlschlag der Korrelation wurde nicht gezielt provoziert (kein Gegentest mit absichtlich falscher ID).
- **Quelle:** `src/supervisor/Hub.ahk` (`Request`, `_Finish`)
- **Hinweis Log-Zeitpunkt:** Die stderr-Zeilen des Supervisors erscheinen gebündelt, nicht in Echtzeit. Zeitmessungen über das Erscheinen einer Log-Zeile sind unzuverlässig (im Test gemessen: ~2 s Verzug bei 500 ms Frist). Die Reihenfolge lässt sich über die Antwort prüfen, nicht über das Log (so ist der Timeout-Test gebaut). Status: verifiziert (Messung im Testlauf und Probe im Scratchpad)
- **Quelle:** `src/supervisor/Hub.ahk` (`Request`)

### Worker: Antwort vor dem Element, Element per Timer starten

- **Problem:** `cmd.worker.run` soll sofort mit `ok` antworten, das Element läuft danach. Startet der Handler das Element direkt, wartet die Antwort so lange wie das Element.
- **Falsch:** Element im Handler ausführen und dann `return Map()`.
- **Richtig:** Auftrag speichern, `SetTimer(this._startFn, -1)` setzen, Handler antwortet. Dasselbe für das Ergebnis eines Abbruchs (`evt.worker.done` über Timer -1), damit die Antwort auf `cmd.worker.cancel` vor dem Ereignis ankommt (Reihenfolge im Hub-Protokoll geprüft).
- **Status:** verifiziert (`tests/integration/test_worker.py`, Hub-Mitschnitt: `res.worker.cancel` vor `evt.worker.done`)
- **Quelle:** `src/worker/Worker.ahk` (`_CmdRun`, `_StopCurrent`)

### `DllCall("Sleep")` lässt Nachrichten zwischen den Zeilen zu

- **Problem:** `Action_TestHangWorker` (Schleife mit `DllCall("Sleep", 1000)`) sollte laut Kommentar keine Nachrichten annehmen. Tatsächlich beantwortete der Worker `cmd.worker.cancel`, aber erst nach bis zu einer Scheibe: 812 ms bei 1000-ms-Scheiben, 29 ms bei 100-ms-Scheiben (Ziel WI-11: 500 ms).
- **Falsch:** Annahme, ein Aufruf, der in `DllCall` wartet, sei für Nachrichten blind (gilt nur innerhalb eines Aufrufs).
- **Richtig:** AHK prüft Fensternachrichten zwischen den Befehlszeilen. Die Latenz ist daher die Länge der längsten Wartescheibe. Lange Wartezeiten in kurze Schritte teilen (100 ms). Ein einzelner langer Aufruf wird nicht unterbrochen (nicht geprüft, welcher Wert kritisch ist).
- **Status:** verifiziert (Messung: Abbruch 812 ms vs. 29 ms, Testläufe). Die Ursache im AHK-Code nicht nachgelesen: vermutet (Nachrichtenprüfung zwischen Zeilen, Peek-Intervall).
- **Quelle:** `src/elements/skeleton/Action_TestHangWorker.ahk`

### Dialoge (InputBox, MsgBox) sind Fenster der Klasse `#32770`

- **Problem:** Ein Test-Element mit `InputBox(..., "T1")` gab im Worker `Cancel` nach 0,12 s zurück. Der Dialog-Wächter von `ahkrun.py` hatte das Fenster geschlossen und den Lauf mit Exit 97 beendet.
- **Falsch:** Dialog-Elemente mit einem Test unter `ahkrun.py` ausführen und ein echtes Ergebnis erwarten.
- **Richtig:** `InputBox` zeigt einen Standarddialog (Probe: Schaltflächen "OK" und "Abbrechen"). Solche Elemente lassen sich unter dem Wächter nicht testen. Eigener Lauf ohne Wächter oder eine Abstraktion des Dialogs nötig. WI-11 verlangt das nicht; das Element wurde wieder entfernt.
- **Status:** verifiziert (Probe mit `ahkrun.py`, Exit 97; `src/elements/skeleton` ohne das Element)

### Worker crasht: nur der Supervisor sieht den Prozesstod

- **Problem:** Ein Python-Hub bemerkt den Tod eines Workers nicht. Die Engine erfährt davon nichts, der Job hängt.
- **Richtig:** Die Engine abonniert das Topic `process` beim Supervisor (nur mit `--workers`). Der Crash-Test startet den echten Supervisor mit `--start=worker:1`. Der Supervisor nimmt das Stand-in-Storage am Hub an, ohne dass es ein Kind ist.
- **Status:** verifiziert (`test_killed_worker_ends_its_element_with_worker_crashed`, Ende 395 ms nach dem Kill)

### Python-Client: `sys.pong` ist eine Antwort, kein Ereignis

- **Problem:** Der Test wartete mit `wait_event("sys.pong")` vergeblich, obwohl der Worker antwortete.
- **Falsch:** `send` und danach `events()`.
- **Richtig:** `client.request("worker:1", "sys.ping", {...})`. Antworten tragen `corr` und landen nicht im Ereignisstrom von `AhfClient.events()`.
- **Status:** verifiziert (`test_pings_are_answered_while_a_blocking_element_runs`)

### Warteschleife über `events()` verwirft fremde Nachrichten

- **Problem:** Eine Hilfsfunktion las mit `events()` und suchte eine Nachricht. Ereignisse anderer Läufe, die sie nicht suchte, gingen verloren, der Test wartete dann vergeblich.
- **Richtig:** Alle Ereignisse eines Zeitfensters sammeln (`late = [m for m in ... if type == ...]`) oder Ereignisse der Reihe nach mit einer Liste pro Typ bearbeiten.
- **Status:** verifiziert (Testlauf `test_cancel_stops_the_running_element...`, zweites `done` fehlte zunächst)

### Ein frozen Prozess zeigt Ack-Timeout und Orphan-Frist

- **Problem:** Ob Engine und Pool bei einem nicht antwortenden Worker enden, war ungeprüft.
- **Richtig:** `psutil.Process(pid).suspend()` friert den Worker ein. Dann kommt `cmd.worker.run` nicht an (Ack-Timeout 5 s, Element `exception`, "worker not available: worker:1 (timeout)"). Nach einem Abbruch bleibt der Slot 2 s `busy`, dann `down`.
- **Status:** verifiziert (`test_frozen_worker_does_not_answer_the_run_and_the_element_fails_by_timeout`, `test_frozen_worker_does_not_confirm_the_cancel...`)

### cmd-Antwort später: der Peer antwortet sonst sofort

- **Problem:** Storage soll Dateioperationen in einer Warteschlange ausführen (kein I/O im Nachrichtenpfad). `Peer` sendet die Antwort auf ein `cmd.*` aber beim Rücksprung des Handlers, mit dessen Rückgabewert. Eine spätere Antwort war nicht möglich.
- **Falsch:** Die Datei im Handler synchron schreiben und dann antworten. Dann wartet jede andere Nachricht (auch `sys.ping`) die volle Dateizeit.
- **Richtig:** Der Handler gibt `Deferred.Marker()` zurück und legt die Anfrage in die Warteschlange. Die Antwort kommt mit `peer.Reply(msg, payload)`. Jeder Fehlerpfad muss antworten, sonst endet der Absender mit seiner Frist. Die Änderung steht in Commit `419051a` (`src/core/ipc/Deferred.ahk`, `Dispatcher.ahk`, `Peer.ahk`). Sie berührt `core/` und braucht eine Absprache (offen, siehe WI-12 Ergebnis).
- **Status:** verifiziert (`tests/ahk/dispatcher.test.ahk`, Fall "a Deferred marker is passed through"; `tests/integration/test_storage.py`, alle Anfragen über die Warteschlange; Peer- und Worker-Tests grün)

### Atomar ersetzen: MoveFileExW mit Flags, Schreibschutz bleibt sichtbar

- **Problem:** v1 löscht die Datei und schreibt sie neu (`FileDelete` + `FileAppend`). Ein Absturz dazwischen verliert die Datei.
- **Richtig:** Temp-Datei im selben Ordner schreiben (`FileOpen(tmp, "w", "UTF-8-RAW")`), dann `DllCall("MoveFileExW", "Str", tmp, "Str", target, "UInt", 0x9, "Int")`. `0x9` = `MOVEFILE_REPLACE_EXISTING` (1) | `MOVEFILE_WRITE_THROUGH` (8). `A_LastError` direkt nach dem Aufruf lesen. Eine schreibgeschützte Zieldatei lässt das Ersetzen mit Zugriffsfehler scheitern, die alte Datei bleibt unverändert.
- **Status:** verifiziert (`test_read_only_target_fails_with_error_event_and_keeps_the_old_file`, `test_hard_kill_during_a_big_write_...`)

### Testhelfer: `wait_hello` findet das alte `sys.hello` im selben Hub

- **Problem:** `wait_hello(hub, name)` liefert das erste `sys.hello` dieses Namens, das der Hub je gesehen hat. Startet man dieselbe Rolle zweimal im selben Hub, kommt die alte PID zurück. Der Test tötete dann einen schon beendeten Prozess (`psutil.NoSuchProcess`).
- **Falsch:** Eine Rolle nacheinander im selben Hub starten und `wait_hello` jedes Mal aufrufen.
- **Richtig:** Pro Start einen eigenen Hub mit eigenem Pipe-Namen: `with RoleHub(pipe_n) as hub:` (siehe `test_hard_kill_during_a_big_write_...`).
- **Status:** verifiziert (Test war rot, nach der Änderung grün)

### Negative Länge bei `SubStr`: Suffix zählen

- **Problem:** Die Prüfung auf das Ende `_old.txt` nutzte `SubStr(path, -7)`. Das Suffix hat aber 8 Zeichen.
- **Richtig:** `SubStr(path, -8) = "_old.txt"`. Allgemein: die Länge des Suffixes aus dem Literal zählen, nicht schätzen.
- **Status:** vermutet (beim Lesen gefunden und vor dem ersten Lauf korrigiert). Der Zweig "schon `_old`" ist nicht gezielt getestet, die Rotation selbst ist getestet (`test_log_file_over_100_kb_...`).

### `FileRead` mit "UTF-8" und BOM

- **Problem:** v1-Variablendateien beginnen mit einem UTF-8-BOM. Ein BOM-Zeichen am Anfang bricht `Json.Parse` und den Vergleich mit Python.
- **Richtig:** Das Zeichen `Chr(0xFEFF)` am Anfang nach dem Lesen entfernen (`AtomicFile.ReadText`).
- **Status:** verifiziert (`test_v1_variables_are_read_as_stored`, `test_variable_round_trip_...`). Ob AHK das BOM bei `"UTF-8"` selbst entfernt, ist nicht geprüft; der eigene Schritt macht es unabhängig davon.

### Storage-eigene Log-Senke nach `super.Start()`

- **Problem:** `Role.Start` setzt die Log-Senke auf die Weiterleitung über den Peer. Storage hat aber keinen Log-Empfänger außer sich selbst.
- **Richtig:** In `Storage.Start` nach `super.Start()` `Log.Configure(Storage.SelfLogFn)` setzen. Die Senke legt Einträge direkt in die Warteschlange.
- **Status:** nicht geprüft (der Pfad ist nur bei Fehlern aktiv, ein gezielter Test fehlt)

## GUI und Hotkeys

### Klasse aus einer Datei nicht eingebunden: Dialog "local variable ... never assigned"

- **Problem:** `src/manager/StubManager.ahk` rief `StubGui(this)` auf, die Datei `StubGui.ahk` war aber nicht eingebunden. AHK meldet das beim Laden als Warnung, die einen Dialog öffnet: "Warning: This local variable appears to never be assigned a value. Specifically: StubGui". Ohne Wächter hängt der Prozess.
- **Falsch:** Klasse in einer zweiten Datei verwenden, ohne `#Include` in der Datei, die sie nutzt.
- **Richtig:** Jede Klasse, die eine Datei benutzt, mit `#Include` dieser Datei einbinden. Dialoge eines Rollenprozesses stehen unter `%TEMP%\ahf_dialogs\` (Text und PNG).
- **Status:** verifiziert (Dialog erfasst beim Start der Rolle, nach dem Einfügen des `#Include` kein Dialog mehr, Probelauf und `tests/e2e/test_ui_stub.py` grün)
- **Quelle:** `src/manager/StubManager.ahk`

### Gui: Ereignisnamen und Zeilenreihenfolge der ListView

- **Problem:** Die Hilfe zu ListView nennt nur die Ereignisnamen (`Click`, `ItemFocus`, `ItemSelect` u. a.). Die Parameter stehen dort nicht vollständig.
- **Richtig:** Für Zeilenklicks `lv.OnEvent("Click", (lv, row) => ...)` verwenden. Das Muster `LV_DoubleClick(LV, RowNumber)` aus der Hilfe bestätigt die Reihenfolge (Steuerelement, Zeile). Zeilen nach jedem Neuaufbau über `Modify(row, "Select Focus")` wieder markieren, `Delete()` leert die Liste ohne Parameter.
- **Status:** vermutet (Ereignisnamen und Parameter aus der Hilfe gelesen. Der Klick selbst ist nicht automatisiert geprüft, nur der Start des Fensters im Smoke-Lauf: Exit 0, kein Dialog).
- **Quelle:** https://www.autohotkey.com/docs/v2/lib/ListView.htm

### Gui-Fenster schließen beendet nicht den Prozess (Persistent)

- **Problem:** Ein Fenster ohne eigenen Hauptschleifen-Grund endet mit dem letzten Fenster. Der Rollenprozess läuft aber über Timer und Peer weiter.
- **Richtig:** `Role.Start` setzt `Persistent()`. Das Schließen des Fensters ist im Stub das gleiche wie "Beenden" (`cmd.app.exit`), damit kein Zustand verloren geht und die Anzeige nicht versehentlich verschwindet.
- **Status:** verifiziert (Smoke-Lauf: Fenster offen, Supervisor antwortet, `cmd.app.exit` führt zu Exit 0)
- **Quelle:** `src/manager/StubGui.ahk`

## Prozesse, Pipes, Nachrichten (Stub)

### Zeitmessung über Prozessgrenzen: `Time.NowMs` ist nicht vergleichbar

- **Problem:** Der Stub soll Ankunftszeiten von Ereignissen messen. `Time.NowMs` ist ein Zähler der Leistungsmessung (QueryPerformanceCounter) und hat in jedem Prozess einen eigenen Nullpunkt.
- **Falsch:** `recvMs := Time.NowMs()` im Stub und `time.perf_counter()` im Test vergleichen.
- **Richtig:** Wandzeit über `GetSystemTimePreciseAsFileTime` (Puffer 8 Byte, `NumGet(buf, 0, "Int64") / 10000 - 11644473600000` ergibt ms seit 1970 UTC). Das entspricht `time.time() * 1000` in Python. Siehe `StubManager.WallMs`.
- **Status:** verifiziert (Probe: Ankunftszeiten im Log, Latenzen 2 bis 4 ms zwischen Befehl und erstem Ereignis, `tests/e2e/test_ui_stub.py`)

### Ereignisse, die der Stub selbst protokolliert, kommen über Topic `log` zurück

- **Problem:** Der Stub schreibt jedes Ereignis über `storage` in das Logfile. `storage` leitet jeden Eintrag an Topic `log` weiter. Abonniert der Stub `log`, schreibt er jeden Eintrag erneut, und das Protokoll wächst endlos.
- **Richtig:** Einträge vom Topic `evt.log.*` nur zählen, nie protokollieren (`StubManager._OnEvent`).
- **Status:** verifiziert (`logEchoCount` im Probelauf gesetzt, Logdatei ohne Wiederholungen)

### Engine-Neustart: `evt.engine.restarted` wird nicht gesendet

- **Problem:** PROTOCOL 4.3 nennt `evt.engine.restarted`. Die Engine (WI-10) sendet es nicht. Ein neuer Engine-Prozess meldet nur `evt.engine.ready` mit neuer `epoch`.
- **Richtig:** Clients erkennen den Neustart über `evt.process.restarted` (name `engine`, Supervisor), über eine neue `epoch` und über `evt.engine.ready`. Der Stub nutzt alle drei Signale (`_OnEvent`).
- **Status:** verifiziert (Test `test_engine_restart_is_seen_and_resynced_without_restarting_the_stub` mit echtem Kill, Snapshot mit neuer `epoch`). Offen: die Engine sollte `evt.engine.restarted` senden, siehe `work_items/phase2/findings.md`.
- **Quelle:** `doc/PROTOKOLL.md` 4.3

### Log-Zeilen gehen verloren, wenn ein anderer Prozess die Datei offen hat (Storage)

- **Problem:** Unter Last fehlten im Logfile des Stubs Zeilen (Ereignisse der letzten Sekunden). Die Storage-Ausgabe zeigt `storage unexpected OSError: (6) Das Handle ist ungültig`. Der Schreibvorgang der Zeile scheitert, die Zeile geht verloren. Auslöser war der Testleser, der die Datei während des Laufs las.
- **Falsch:** Während eines Laufs eine Logdatei mit `read_bytes` lesen, um auf Einträge zu warten.
- **Richtig:** Während des Laufs das Topic `log` beobachten (Storage leitet jeden Eintrag erst nach dem Schreiben weiter) und die Datei erst nach dem Ende lesen. Die Ursache im Storage (kein Wiederholversuch bei gesperrter Datei) ist offen, siehe `work_items/phase2/WI-13-ui-stub.md`, F-04.
- **Status:** verifiziert (Fehler mit Reproduktion unter Parallellast: 2 bis 3 von 5 Läufen rot vorher; danach 6 von 6 Parallel-Läufe grün). Die Ursache im Storage-Code ist aus dem Fehlertext abgeleitet, nicht im Debugger gesehen: vermutet.
- **Quelle:** `src/storage/LogSink.ahk` (`Append`, `_RotateIfBig`), `tests/e2e/test_ui_stub.py`

### Boolesche Antworten als Zahl (Stub)

- **Problem:** `cancel` soll laut Protokoll ein Bool sein. Der Json-Baustein schreibt `true` als `1`.
- **Richtig:** Im Stub `cancel` als `1` oder `0` senden. Der Empfänger prüft als Wahrheitswert (siehe oben, Abschnitt "Wahrheitswerte gehen als Zahl auf die Leitung").
- **Status:** verifiziert (Probe: `cancel: 0` im Log, Test `test_cancelled_exit_is_answered_and_nothing_stops`)

## Tests und Werkzeuge

### Blockierende Fehlerdialoge: `ahkrun.py` und Dialog-Wächter

- **Problem:** Ein Ladefehler (z. B. Klassenkonflikt), ein unbehandelter Laufzeitfehler oder eine `MsgBox` öffnet einen Dialog. Der Prozess wartet auf Klick, der aufrufende Agent hängt.
- **Falsch:** Skript direkt mit dem Interpreter starten und auf Rückkehr warten.
- **Richtig:** `python tools/ahkrun.py --timeout 30 skript.ahk`. Ladefehler: `/ErrorStdOut=UTF-8` schreibt sie auf stderr. Alle übrigen Dialoge: `tools/ahf_dialogwatch.py` erkennt Fenster der Klasse `#32770` im Prozessbaum, liest den Text (auch RichEdit per `WM_GETTEXT`), speichert Text und PNG unter `%TEMP%\ahf_dialogs\`, schließt den Dialog, beendet den Prozess (Exit-Code 97).
- **Status:** verifiziert (`tests/support/test_dialogwatch.py`: Ladefehler, Laufzeitfehler, `MsgBox`, Timeout). Grenzen: nur Dialoge der Klasse `#32770`, kein eigenes GUI-Fenster. Unter einem gesperrten Desktop `PrintWindow` nicht geprüft.

### ctypes: ohne `argtypes` scheitern 64-Bit-Handles sporadisch

- **Problem:** Der Dialog-Wächter schloss Dialoge nur manchmal (Läufe zwischen 0,5 s und 17 s, einmal Timeout). Ursache: `GetDIBits` ohne `argtypes` wurde ein Handle als C-`int` übergeben, bei Werten über 2**31 gab es `OverflowError`. Die Ausnahme wurde vom Wächter-Thread verschluckt, der Dialog blieb offen.
- **Falsch:** WinAPI-Funktionen mit Handle-Parametern ohne `argtypes`/`restype` aufrufen, und in der Wächterschleife Ausnahmen still verwerfen, bevor das Wesentliche (Dialog schließen) erledigt ist.
- **Richtig:** `argtypes` für jede aufgerufene Funktion setzen. Informationsbeschaffung in `try`, Schließen und Beenden in `finally`.
- **Status:** verifiziert (20 aufeinanderfolgende Läufe, schlechtester 0,58 s).

### Eingebaute Klassennamen von AHK v2 nicht überschreiben

- **Problem:** `class TimeoutError extends AhfError` meldet beim Laden "This class declaration conflicts with an existing Class" und blockiert mit Dialog.
- **Richtig:** Eigene Namen mit Präfix (`AhfTimeoutError`). Eingebaut sind u. a. `Error`, `TimeoutError`, `ValueError`, `TypeError`, `OSError`, `MemberError`, `PropertyError`, `MethodError`, `IndexError`, `KeyError`, `UnsetError`, `TargetError`, `MemoryError`, `ZeroDivisionError`.
- **Status:** verifiziert (`TimeoutError`), Rest der Liste aus der AHK-Doku, nicht einzeln geprüft.

### Der AHK-Interpreter kennt `--version` nicht

- **Problem:** `AutoHotkey64.exe --version` ergibt den Dialog "Script file not found. --version".
- **Richtig:** Version nicht über die Kommandozeile abfragen. Pfad und `#Requires AutoHotkey v2.0` genügen. In einem Skript `A_AhkVersion` ausgeben.
- **Status:** verifiziert (selbst ausgelöst).

### Testprozesse mit Ausgabe in Dateien, nicht über Pipes

- **Problem:** Ein AHK-Prozess, der per `subprocess.PIPE` gestartet wird, kann bei Timeout die Pipe offen halten. `communicate()` hängt dann ebenfalls.
- **Richtig:** stdout und stderr in Dateien im Datenverzeichnis umlenken (`tests/conftest.py`, `run_ahk`). Bei `TimeoutExpired` den Baum mit `psutil` beenden.
- **Status:** verifiziert (Test `test_hung_script_is_killed_at_timeout`, danach kein `AutoHotkey64.exe` übrig)

### Stand-in-Hub hat `sys.pong` verworfen

- **Problem:** Der Ping-Test blieb hängen. Der Python-Hub hatte `sys.pong` ignoriert, statt es zu routen.
- **Richtig:** Nur `sys.hello` wird vom Hub beantwortet, alle anderen Nachrichten werden geroutet. Die Ausnahme für `sys.pong` ist entfernt.
- **Status:** verifiziert (Test `test_ping_is_answered_by_the_client`)

### Rohstring mit Pipe-Namen

- **Problem:** `r"\\.\pipe\"` ist in Python ein Syntaxfehler, weil ein Rohstring nicht mit einem Backslash enden darf.
- **Richtig:** `PIPE_PREFIX = "\\\\.\\pipe\\"` als normale Zeichenkette. Namen werden nur angehängt (`tests/support/winpipe.py`).
- **Status:** verifiziert (Code läuft, Pipe-Verbindungen in den Tests)

### Einmal rotes MsgBox-Dialog-Testergebnis (Timeout 98 statt 97)

- **Problem:** `test_msgbox_is_captured_and_closed` lief in einer Gesamtsuite einmal in den Timeout (Exit 98). Bei Wiederholung in Isolation und in der Gesamtsuite grün.
- **Richtig:** Bei Sporadik zuerst Wiederholungen laufen lassen (`-k msgbox`, drei Läufe). Wenn es wiederkehrt, Dialog-Wächter-Zeitfenster und Prozessbaum-Abfrage prüfen.
- **Status:** vermutet (Timing-Ausreißer, nicht reproduziert; Ursache nicht untersucht)

### Dialog-Wächter-Test sporadisch Exit 98 statt 97

- **Problem:** `tests/support/test_dialogwatch.py::test_runtime_error_dialog_is_captured` lief bei WI-02 rot (98 statt 97). In vier isolierten Läufen war einer rot. Dasselbe Muster wie beim MsgBox-Eintrag oben.
- **Richtig:** Wiederholen (`-k runtime_error`, mehrere Läufe). Den Test nicht als Ursache des eigenen Pakets werten, solange er sporadisch bleibt. Ursache offen.
- **Status:** verifiziert (Wiederholung: 1 von 4 isolierten Läufen rot). Ursache nicht untersucht.

### Ergebnisdatei eines Testhelfers: Zugriff Python und AHK gleichzeitig

- **Problem:** Der Python-Test fragte die JSON-Lines-Datei eines AHK-Helfers alle 5 ms ab. `FileAppend` im `OnClose`-Handler scheiterte dann mit einem Zugriffsfehler. Die Ausnahme wurde im Handler gefangen, der Eintrag ging verloren und der Test meldete "keine Verbindungsabbruch-Meldung". Umgekehrt warf Python `PermissionError` beim Lesen, während AHK schrieb.
- **Falsch:** Ein einziger `FileAppend`-Versuch im Helfer, ein einziger `read_bytes` im Test.
- **Richtig:** Beide Seiten wiederholen kurz (`Kit.Record` bis 200 mal mit `DllCall("Sleep", 2)`, `rawpipe.read_jsonl` bis 50 mal). Eine unvollständige letzte Zeile wird ignoriert.
- **Status:** verifiziert (Fehler reproduzierbar, nach der Änderung 8 Durchläufe der 26 Pipe-Tests ohne Auftreten)
- **Quelle:** `tests/integration/helpers/PipeTestKit.ahk`, `rawpipe.py`

### Testserver in Python: Rückkehr des Handlers schließt die Verbindung

- **Problem:** `PyServer(name, handler=lambda end: None)` schloss die Verbindung sofort, der AHK-Client sah ein sofortiges Ende ("connection closed") statt der erwarteten Daten.
- **Richtig:** Der Handler besitzt die Verbindung. Wer sie von außen benutzen will, lässt ihn blockieren (`lambda end: end.closed.wait(300)`).
- **Status:** verifiziert (eigener Fehler im Test)

### Steuerrahmen im Prüfmodus des Testservers

- **Problem:** Der AHK-Testserver hielt nach `ctl:expect:N` die nächsten N Rahmen für Prüfdaten und las deshalb den nachfolgenden Steuerrahmen `ctl:gen` als Rahmen 0 (Prüfung fehlgeschlagen, alles um eins verschoben).
- **Richtig:** Zuerst den Erzeuger starten (`ctl:gen`), dann `ctl:expect` senden. Im Prüfmodus gibt es keine Steuerrahmen.
- **Status:** verifiziert (eigener Fehler im Test)

### Einmaliger Fehlschlag von `test_ahk_server_python_client_exchanges_10000_frames`

- **Problem:** In einer Gesamtsuite schlug der Test einmal fehl (Meldung nicht gesichert). In 15 Einzelläufen und 3 parallelen Dateiläufen danach nicht mehr.
- **Richtig:** Sehr wahrscheinlich derselbe Fehler wie "Python-Testleser verlor Bytes" (oben): Rahmen für Rahmen durch den Python-Leser, ein verlorener Chunk lässt den Test hängen.
- **Status:** vermutet (nicht reproduziert, daher nicht bewiesen)

### Rollenprozesse über ahkrun.py starten, Ausgabe in Dateien

- **Problem:** Ein Rollentest braucht den Prozess neben einem laufenden Hub. `tools/ahkrun.py` wartet bis zum Ende, und ein Pipe-Puffer für die Ausgabe kann blockieren.
- **Richtig:** `ahkrun.py` als Kindprozess über `procs.start` starten, Ausgabe in Dateien (`--timeout 60`). Die AutoHotkey-PID steht im `sys.hello` (`payload.pid`) und ist Kind von ahkrun (`psutil.Process(pid).ppid()`). Der Exit-Code von ahkrun ist der des Skripts. Den AHK-Prozess per psutil warten, um das Ende genau zu messen.
- **Status:** verifiziert (`tests/integration/test_role.py`, 9 Tests).
- **Quelle:** `tests/integration/test_role.py` (`RoleRun`)

### Einstieg schreibt Meldungen auf stderr, ohne Datei

- **Problem:** Der Einstieg hat noch keine Log-Senke (storage gibt es in dieser Phase noch nicht). "unknown role" und ähnliche Meldungen müssen trotzdem sichtbar sein, ohne Dialog.
- **Richtig:** `FileAppend(text, "**", "UTF-8-RAW")` schreibt auf stderr und legt keine Datei an. Das ist eine Ausnahme zu KONVENTIONEN 3 (dort nur `storage`), begründet mit Konsolenausgabe. `ahkrun.py` reicht stderr an den Aufrufer weiter.
- **Status:** verifiziert (`test_unknown_role_exits_2_with_message_and_no_dialog`, `test_role_without_implementation_reports_not_implemented`).
- **Quelle:** `src/core/Role.ahk` (`Role.Console`)

### psutil-Status hinkt nach `suspend` um 3 bis 73 ms

- **Problem:** Nach `psutil.Process.suspend()` zeigt `psutil.Process.status()` nicht sofort `STATUS_STOPPED`. Der Status hinkt um einige Millisekunden hinterher. Eine einmalige Prüfung direkt nach dem Anhalten ist deshalb unzuverlässig.
- **Falsch:** Einmal `status()` nach `suspend` lesen und sofort prüfen.
- **Richtig:** Den Status in einer kurzen Schleife (10 ms Abstand, Frist 2 s) pollen, bis er `STATUS_STOPPED` ist (`tests/support/test_procs.py`, `test_suspend_and_resume`).
- **Status:** verifiziert (30 Läufe gemessen, Verzögerung bis 73 ms)
- **Quelle:** `tests/support/test_procs.py`

### ahkrun schreibt stderr erst am Ende: Logs laufender Prozesse sind leer

- **Problem:** Ein Rollenprozess, der über `tools/ahkrun.py` läuft, liefert seine Ausgabe auf stderr erst beim Ende. Während er läuft, sind Log-Dateien und Ausgabe leer. Eine Diagnose über die Ausgabe ist dann nicht möglich.
- **Falsch:** Während des Laufs in die Ausgabe schauen, um Zustand zu prüfen.
- **Richtig:** Zustand über Nachrichten abfragen (z. B. `cmd.process.list`, `sys.hello`), die Ausgabe erst nach dem Ende auswerten.
- **Status:** verifiziert (WI-07, Testläufe mit `ahkrun.py`)
- **Quelle:** `tools/ahkrun.py`, `tests/integration/test_role.py`

### Assertion auf Teilstring: `running for session` trifft auch andere Meldungen

- **Problem:** Eine Assertion suchte nach dem Teilstring `running for session`. Die Meldung "already running for session main, forwarding the command" (zweite Instanz) enthält ihn ebenfalls. Der Teilstring trifft also auch einen anderen Fall, als gemeint war.
- **Falsch:** `assert "running for session" in text`.
- **Richtig:** Die ganze Meldung und ihren Anfang prüfen (z. B. Zeilenanfang `session main running`), oder die Meldung über ein Ereignis statt über Text prüfen.
- **Status:** verifiziert (WI-07, Testfall für die zweite Instanz)
- **Quelle:** `src/supervisor/Supervisor.ahk` (`_ForwardIfRunning`), `tests/integration/test_supervisor.py`

### Wahrheitswerte aus AHK sind 0 und 1 auch in den Python-Tests

- **Problem:** Ein Test prüfte `payload["ok"] is False`. AHK schreibt Wahrheitswerte als Zahl (`0`/`1`), der Vergleich mit `False` schlug fehl, obwohl die Antwort richtig war (`0 is False` ist falsch).
- **Falsch:** `assert msg["payload"]["enabled"] is False`.
- **Richtig:** Wahrheit prüfen: `assert not msg["payload"]["enabled"]`, `assert msg["payload"]["executing"] == 1`. Für `ok` dasselbe. Die Regel steht in `doc/PROTOKOLL.md`, Abschnitt 2.
- **Status:** verifiziert (Testlauf WI-10: zwei Tests rot mit `0 is False`, nach der Änderung grün).
- **Quelle:** `tests/integration/test_engine.py`

### Lange Dateitexte über Bash-Heredoc: "unexpected EOF"

- **Problem:** Ein Heredoc mit Python-Code (Anführungszeichen, Backslashes, eingebettete Triple-Quotes) brach im Bash-Werkzeug mit `unexpected EOF while looking for matching` ab, die Datei entstand nicht.
- **Richtig:** Text mit dem Schreib-Werkzeug in eine Datei im Scratchpad schreiben und dann mit einem kurzen Python-Skript an die Zieldatei anhängen oder einsetzen. Die Regel "Dateien mit Edit/Write" aus dem Auftrag gilt auch hier.
- **Status:** verifiziert (Fehlermeldung im Bash-Lauf, WI-11)
