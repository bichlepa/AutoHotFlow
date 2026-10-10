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

## GUI und Hotkeys

_Noch keine Einträge._

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
