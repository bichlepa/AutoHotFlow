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

## Objekte, Maps, Arrays

### Map mit `CaseSense "Off"` behält die Schreibweise der ersten Einfügung

- **Problem:** Offene Prüfung von WI-02: Bleibt die Schreibweise der Schlüssel bei der Aufzählung erhalten?
- **Richtig:** Ja. Die erste Einfügung bestimmt die Schreibweise. Eine spätere Einfügung in anderer Schreibweise ersetzt nur den Wert. Die Aufzählung ist außerdem sortiert (`zebra`, `apple`, `mango` kommen als `apple`, `mango`, `zebra`). Ein eigener `AhfMap` ist deshalb nicht nötig. Zwei Schlüssel, die sich nur in der Schreibweise unterscheiden, werden zu einem: `Json.Parse` weist das ab.
- **Status:** verifiziert (`tests/ahk/json.test.ahk`, "Map CaseSense Off keeps the first spelling of a key" und "... enumerates keys in sorted order"). Die Sortierung ist beobachtet, nicht dokumentiert.

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
