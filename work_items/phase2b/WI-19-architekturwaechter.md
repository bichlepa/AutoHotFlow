# WI-19 Architekturwächter (statische Prüfung)

Größe: S · Hängt ab von: WI-18 · Blockiert: –

## Ziel

Die Regeln aus `doc/KONVENTIONEN.md` und `doc/ARCHITEKTUR.md` 8 werden heute nur im Review geprüft. In Phase 3 portieren mehrere Agenten rund 150 Elemente. Eine statische Prüfung als pytest-Test findet Regelbrüche, bevor sie eingecheckt werden.

## Zu erstellen

- `tools/arch_check.py`: liest alle `.ahk` unter `src/` (später auch `src/elements/**`), entfernt Kommentare (`;` bis Zeilenende, `/* ... */`) und Zeichenkettenliterale vor der Mustersuche, meldet Verstöße als `datei:zeile: regel: text`. Aufrufbar von Hand (`python tools/arch_check.py`), Exit 1 bei Verstößen.
- `tests/test_architecture.py`: ruft die Prüfung auf und schlägt mit der vollständigen Liste fehl. Zusätzlich Selbsttests der Prüfung mit kleinen Beispieltexten (jede Regel mindestens ein Treffer und ein Nicht-Treffer).

## Regeln (Startumfang)

| Regel | Inhalt |
|---|---|
| `requires` | Jede Datei beginnt mit `#Requires AutoHotkey v2.0`. |
| `one-class` | Höchstens eine Klasse auf oberster Ebene je Datei, Dateiname = Klassenname (verschachtelte Klassen erlaubt). |
| `include-core` | `src/core/**` bindet nichts aus Rollenordnern ein. |
| `include-roles` | Ein Rollenordner bindet keinen anderen Rollenordner ein (erlaubt: `core/`, `elements/`, später `ui_common/` nur für UI-Rollen). Der Einstieg `src/AutoHotFlow.ahk` ist ausgenommen. |
| `include-tests` | `src/` bindet nichts aus `tests/` ein. |
| `dialog` | `MsgBox`, `InputBox`, `FileSelect`, `DirSelect` nicht in `core`, `engine`, `supervisor`, `storage`, `triggerhost`. |
| `file-io` | `FileRead`, `FileAppend`, `FileOpen`, `FileDelete`, `FileMove`, `FileCopy`, `DirCreate`, `DirDelete`, `Loop Files` nur in `storage`. |
| `blocking` | `Sleep` mit Wert > 0, `RunWait`, `WinWait*` ohne Timeout nur in `worker` (und in Elementen mit `Mode := "worker"`). |
| `inline-element` | Elemente mit `static Mode := "inline"` enthalten keine Muster aus `dialog`, `file-io`, `blocking`. |
| `warn` | `#Warn` nur mit Ziel `StdOut` oder `OutputDebug`, nie als Dialog. |
| `critical` | `Critical` nur mit Begründung im Kommentar derselben oder der vorigen Zeile. |
| `empty-catch` | Kein leerer `catch`-Block ohne Kommentar mit Begründung. |
| `builtin-class` | Keine Klasse mit dem Namen einer eingebauten AHK-v2-Klasse (`Error`, `TimeoutError`, `ValueError`, `OSError`, `TypeError`, `MemberError`, `IndexError`, `Map`, `Array`, `Buffer`, `Gui`, ...). |

Ausnahmen: entweder als Kommentar an der Stelle (`; arch-ok: <regel> <Begründung>`) oder als Liste mit Begründung in `tools/arch_check.py`. Heute bekannte Ausnahmen:
- `Role.Console` schreibt mit `FileAppend` auf stderr (`"**"`), begründet in `src/core/Role.ahk` (F-05).
- `src/AutoHotFlow.ahk` bindet Testrollen aus `tests/` ein (wird in WI-29 aufgelöst, dann Ausnahme entfernen).
- `src/core/RoleRegistry.ahk` enthält zwei Klassen (wird in WI-29 aufgelöst).
- `Critical` in `PipeConnection`, `Engine.Emit`, `Executor._Advance` (Begründungen stehen dort teilweise schon; fehlende ergänzen).

## Akzeptanzkriterien

- Der Test ist grün auf dem aktuellen Code, jede Ausnahme hat eine Begründung.
- Jede Regel hat einen Selbsttest mit Treffer und Nicht-Treffer.
- `doc/KONVENTIONEN.md` Abschnitt 3 verweist auf die Prüfung; neue Regeln werden dort und im Werkzeug gleichzeitig ergänzt.

## Nicht Teil

Vollständiger AHK-Parser. Die Prüfung ist bewusst einfach (Zeilen und Muster). Falsch-positive Treffer werden über `arch-ok` begründet, nicht durch komplizierte Logik vermieden.

## Ergebnis

Status: abgeschlossen.

### Erledigt

- `tools/arch_check.py`: liest alle `.ahk` unter `src/` (rekursiv, also auch `src/elements/**`), blankt Kommentare und Zeichenketteninhalte, meldet `datei:zeile: regel: text`, Exit 1 bei Verstößen. Alle 13 Regeln der Tabelle sind umgesetzt (`requires`, `one-class`, `include-core`, `include-roles`, `include-tests`, `dialog`, `file-io`, `blocking`, `inline-element`, `warn`, `critical`, `empty-catch`, `builtin-class`). Ausnahmen: Kommentar `; arch-ok: <regel> <Begründung>` (Begründung Pflicht, sonst eigener Verstoß `arch-ok`) und Liste `EXCEPTIONS` mit Begründung. Eine Ausnahme, die nichts mehr trifft, wird als `exception-unused` gemeldet (damit WI-29 sie entfernen muss).
- `tests/test_architecture.py`: `test_source_tree_obeys_the_architecture_rules` (schlägt mit der vollständigen Liste fehl), Prüfung der Ausnahmeliste, Abdeckungstest (jede Regel hat einen Fall), je Regel Treffer und Nicht-Treffer (`test_rule_hits_and_misses[<regel>]`) plus Detailtests (Rollen, Elementmodus, `arch-ok`, `catch`-Varianten, `#Warn`, `Critical(Off)`, Exit-Code des Werkzeugs).
- Doku: `doc/KONVENTIONEN.md` Abschnitt 3 verweist auf das Werkzeug, `AGENTS.md` (Werkzeuge), `doc/HOW-TO.md` (zwei Einträge).

### Belege (verifiziert)

- Verstöße auf dem unveränderten Code (HEAD, mit `git archive` in den Scratchpad entpackt): **7 unbegründete + 13 über die Ausnahmeliste gedeckte**. Die 7: 5x `critical` (`PipeConnection.ahk` 170/252/267, `Engine.ahk` 88, `Executor.ahk` 233) und 2x `empty-catch` (`Role.ahk` 49, `Hub.ahk` 287). Nach den Korrekturen unten: **0 Verstöße, 13 durch Ausnahmen gedeckt**.
- `python -m pytest tests/test_architecture.py -n0`: 27 passed.
- Gesamtlauf `python -m pytest tests -q` (parallel): **458 passed, 1 skipped in 48,4 s** (vorher 431 + 1; 27 neue Tests). Danach keine Testprozesse übrig (nur der fremde AutoHotkey-Prozess des Projektinhabers, nichts beendet).

### Entscheidung je Fund

- `critical` an 5 Stellen: **echter Verstoß gegen die Begründungspflicht**, Code unverändert, nur Kommentar ergänzt (`; reason: ...` in derselben Zeile). Betrifft `PipeConnection.ahk`, `Engine.ahk`, `Executor.ahk`.
- `empty-catch` in `Role.Console` und `Hub._Deny`: **echter Verstoß** (Begründung stand außerhalb des Blocks); Kommentar in den Block gesetzt, kein Verhalten geändert.
- Falsch-Positive: keine. Beim Bau wurden zwei Fehler der Prüfung selbst gefunden und behoben (HOW-TO): `Critical("On")` wurde wegen geblankter Zeichenketten nicht erkannt; `catch as e {}` wurde übersehen.

### Ausnahmeliste (`EXCEPTIONS` in `tools/arch_check.py`), 13 Treffer

| Datei | Regel | Treffer | Begründung |
|---|---|---|---|
| `core/Role.ahk` | `file-io` | 1 | `Role.Console` schreibt mit `FileAppend` auf stderr (`"**"`), kein Dateizugriff (F-05). |
| `AutoHotFlow.ahk` | `include-tests` | 4 | Testrollen aus `tests/integration/helpers/`; WI-29 löst auf. |
| `core/RoleRegistry.ahk` | `one-class` | 1 | `PlaceholderRole` neben `RoleRegistry`; WI-29 löst auf. |
| `core/Errors.ahk` | `one-class` | 6 | Fehlerhierarchie (`ErrCode` + 5 Klassen) in einer Datei; **neu, nicht im Paket genannt**. |
| `engine/core/Loops.ahk` | `one-class` | 1 | Datei heißt `Loops.ahk`, Klasse `LoopStack`; **neu, nicht im Paket genannt**. |

Das `Critical`-Muster brauchte keine Listenausnahme, weil die Begründungen als Kommentare ergänzt wurden.

### Abweichungen

- Zwei Ausnahmen mehr als im Paket (`Errors.ahk`, `Loops.ahk`). Aufteilen von `Errors.ahk` und Umbenennen von `Loops.ahk` berührt viele `#Include` und ist nicht klein; als offener Punkt belassen.
- Regel `critical` meldet nur das Einschalten (`Critical`, `Critical("On")`, Zahl > 0), nicht `Critical("Off")` oder die Wiederherstellung `Critical(prev)`.
- `file-io` umfasst zusätzlich `DirMove`, `DirCopy`, `Loop Read`; nicht enthalten sind lesende Abfragen wie `FileExist`/`FileGetSize`/`DirExist`.
- `blocking`: `WinWait*` gilt als ohne Timeout, wenn der Aufruf weniger als 3 Argumente hat (einzeilig gezählt). `Sleep(0)` und `Sleep(-1)` sind erlaubt. `KeyWait`/`ClipWait` werden nicht geprüft.
- Entscheidung für Elemente: Außerhalb von `Mode := "worker"` gelten `dialog`, `file-io` und `blocking` auch für Basisdateien und Trigger-Elemente; `Mode := "inline"` meldet als `inline-element`.
- Die Prüfung `exception-unused` gilt nur für `src/` des Repos, nicht für fremde `--root`-Verzeichnisse.

### Nicht geprüft

- Wirkung der Prüfung auf Elementcode aus Phase 3 (es gibt nur die 8 Skeleton-Elemente); `ui_common/`, `triggerhost/`, `editor/` existieren nicht, ihre Regeln sind nur durch Selbsttests mit Beispieltexten belegt.
- Mehrzeilige Zeichenketten (Fortsetzungsabschnitte `( ... )`) und `#Include` mit `%A_ScriptDir%` werden nicht ausgewertet (Includes mit `%` übersprungen).
- Zeilenendungen: Es wurde nur gegen die vorhandenen Dateien getestet (CRLF und LF im Repo gemischt, beides lief).

### Offene Punkte

- WI-29: Ausnahmen `AutoHotFlow.ahk`/`include-tests` und `RoleRegistry.ahk`/`one-class` auflösen und aus der Liste streichen (der Test erzwingt es über `exception-unused`).
- `Errors.ahk` aufteilen (eine Klasse je Datei) oder die Konvention ausdrücklich lockern; `Loops.ahk` in `LoopStack.ahk` umbenennen. Vorschlag: in WI-29 mitnehmen.
