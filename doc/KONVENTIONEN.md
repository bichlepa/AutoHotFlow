# Konventionen für den v2-Code

Gilt für alles unter `src/`, `tests/ahk/` und `tools/`. Sprache der Dokumentation: Deutsch. Sprache im Code (Kommentare, Namen, Logtexte außerhalb von `Lang()`): Englisch, wie in v1.

## 1. Datei und Struktur

- Jede AHK-Datei beginnt mit `#Requires AutoHotkey v2.0`. Rollen-Einstiege zusätzlich `#SingleInstance Off` (mehrere Instanzen derselben Datei sind gewollt) und im Entwicklungsmodus `#Warn All`.
- **Eine Klasse pro Datei**, Dateiname = Klassenname (`Dispatcher.ahk`). Mehrere freie Funktionen nur in `Util`-Dateien.
- **Keine globalen Variablen.** Zustand liegt in Klassen oder als `static`-Mitglied. Ausnahmen (Einstieg `A_Args`-Parsing, Registry-Singleton) stehen in `AutoHotFlow.ahk` bzw. im Rollenmodul.
- Einbindung nur nach den Regeln aus ARCHITEKTUR 8 (`core/` kennt keine Rollen, Rollen kennen einander nicht).
- Kodierung: UTF-8 ohne BOM, Zeilenende wie im Repo (siehe `.gitattributes`).

## 2. Namen

- Klassen, Methoden, Eigenschaften: `PascalCase`. Lokale Variablen und Parameter: `camelCase`. Konstanten: `UPPER_SNAKE`.
- Nachrichtentypen: klein, punktgetrennt (`cmd.flow.start`). IDs aus Flow-Dateien werden nie verändert.
- Private Mitglieder beginnen mit `_`.

## 3. Verbotene Muster (Reviewregeln)

Die Muster mit festem Wortlaut werden **automatisch geprüft**: `python tools/arch_check.py` (Exit 1 bei Verstößen, Ausgabe `datei:zeile: regel: text`) und `tests/test_architecture.py` (Teil des Gesamtlaufs). Regeln: `requires`, `one-class`, `include-core`, `include-roles`, `include-tests`, `dialog`, `file-io`, `blocking`, `inline-element`, `warn`, `critical`, `empty-catch`, `builtin-class`. Eine begründete Ausnahme steht als Kommentar `; arch-ok: <regel> <Begründung>` in derselben oder der vorigen Zeile, oder (für bekannte Altlasten) in der Liste `EXCEPTIONS` in `tools/arch_check.py`. **Neue Regeln werden hier und im Werkzeug (samt Selbsttest) gleichzeitig ergänzt.** Die Prüfung ist bewusst einfach (Zeilen und Muster); `A_TickCount`/Zufall als ID, Zugriff über Prozessgrenzen und fehlendes `try/catch` um Elementcode prüft sie nicht (Review).

| Muster | Wo verboten | Stattdessen |
|---|---|---|
| `MsgBox`, `InputBox`, `FileSelect`, `DirSelect`, jedes blockierende GUI | `engine`, `supervisor`, `storage`, `triggerhost`, `core` | Nachricht an UI/Worker (`evt.ui.notice`, Dialog-Element im Worker) |
| `FileRead/FileAppend/FileOpen/FileDelete/DirCreate/Loop Files` | alles außer `storage` (und Startparameter-Lesen beim Booten) | Anfrage an `storage`. Keine Datei-I/O im Sinne dieser Regel: Schreiben auf stderr (`**`, `Role.Console`) und das Mitlesen der anonymen Pipe der Kinder durch den Supervisor (`ChildPipe`, `PeekNamedPipe`/`ReadFile` auf ein Handle, das keine Datei ist, nie blockierend). |
| `Sleep` (>0), `RunWait`, `WinWait*` ohne Timeout, `Loop` mit Wartezeit | alles außer `worker` | `SetTimer`, Callback |
| `A_TickCount` oder Zufall als ID | überall | `Ids.Next(prefix)` (Zähler pro Prozess) |
| `Critical` | überall | nicht nötig. Wenn doch, mit Begründung im Kommentar |
| `try` ohne Behandlung (leerer `catch`) | überall | loggen oder bewusst begründen |
| Zugriff auf Objekte eines anderen Prozesses, gemeinsamer Speicher, `SendMessage` an andere Rollen | überall | Nachricht über den Hub |
| Elementcode ohne `try/catch` um den Aufruf | `engine`, `worker`, `triggerhost` | zentrale Aufrufstelle `ElementRunner` |

## 4. Fehler und Protokoll

- Ausnahmen: Klassen `AhfError` (Basis), `ElementError`, `ProtocolError`, `AhfTimeoutError`. Jede trägt `code` (siehe Fehlercodes im Protokoll).
- Jede Anfrage hat ein Timeout. Es gibt kein Warten ohne Frist. Ausnahme mit Obergrenze: `cmd.app.prepareExit` (10 Minuten, PROTOKOLL 4.1), weil die Benutzerentscheidung keine feste Frist hat.
- Eingehende Nachrichten werden validiert (Typ, Nutzlast-Pflichtfelder) und bei Fehlern beantwortet, nie ignoriert.
- Zustandsautomaten sind Klassen mit Übergangstabelle (`static Transitions := Map(...)`). Ungültige Übergänge: `false` zurück plus `a0`-Log.

## 5. AHK-v2-Fallen (kurz)

- `Map` zählt in **sortierter** Schlüsselreihenfolge auf, nicht in Einfügereihenfolge. Wo Reihenfolge zählt: `Array` verwenden.
- Objekt-Eigenschaften sind case-insensitiv, `Map`-Schlüssel standardmäßig case-sensitiv. Für Variablennamen und Klassen-IDs `m.CaseSense := "Off"` direkt nach dem Erzeugen setzen (vor dem Einfügen).
- `=` vergleicht Strings case-insensitiv, `==` case-sensitiv. Zahlen und Strings mit Zahlenform: JSON-Typen erhalten, nicht „reparieren“.
- Zugriff auf nicht vorhandene Map-Schlüssel wirft. `m.Get(key, default)` oder `m.Has(key)`.
- `A_LastError` direkt nach dem `DllCall` lesen, jeder weitere Aufruf überschreibt ihn.
- `OnMessage`-Handler und `SetTimer`-Callbacks halten Referenzen. Bei Aufräumen `OnMessage(..., 0)` bzw. `SetTimer(fn, 0)`.
- Lambdas erfassen Variablen per Referenz. In Schleifen ein lokales Binding erzeugen (`(v := x) => ...` oder Hilfsfunktion).
- Beim Erzeugen von Dateien über eine Shell (Heredocs) können `\\` zu `\` zusammenfallen. Quelltext immer mit dem Editor-Werkzeug schreiben, Pipe-Namen aus Konstanten bauen.

## 6. Tests und Doku

- Jede Änderung an `core/`, Zustandsautomaten oder Protokoll bringt einen Test mit.
- Neue Nachrichtentypen werden in `PROTOKOLL.md` ergänzt.
- Bewusste Verhaltensänderungen gegenüber v1 stehen in `MIGRATION.md` (ID, Bereich, v1, v2, Grund).
- Commits sind klein und beschreibend, eine Änderung pro Commit.
