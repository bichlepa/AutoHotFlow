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
