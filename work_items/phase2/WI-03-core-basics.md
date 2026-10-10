# WI-03 Ids, Fehler, Argumente, Log-Client

Größe: S · Hängt ab von: – · Blockiert: WI-04, WI-05, WI-08, WI-09

## Ziel

Kleine, abhängigkeitsfreie Bausteine in `src/core/`, die jede Rolle braucht.

## Vorher lesen

`doc/KONVENTIONEN.md` (Abschnitte 3 und 4), `doc/PROTOKOLL.md` Abschnitt 2 (Fehlercodes, ID-Format).

## Zu erstellen

- `src/core/Ids.ahk`: `Ids.Configure(processName)`, `Ids.Next(prefix := "")`. Zähler pro Prozess, beginnt bei 1, **nicht** `A_TickCount`. Rückgabe `"<processName>#<n>"` bzw. `"<prefix><n>"`, wenn `prefix` gesetzt ist.
- `src/core/Errors.ahk`: `AhfError` (Basis, Felder `code`, `message`), `ProtocolError`, `AhfTimeoutError`, `ElementError`, `JsonError` (von WI-02 genutzt, hier definieren). Fehlercodes als Konstanten (`ERR_TIMEOUT := "timeout"` usw., Liste aus PROTOKOLL 2).
- `src/core/Args.ahk`: `Args.Parse(argv)` → `Map`. Unterstützt `--key=value`, `--flag`, Rest als Positionsliste. Pflichtschlüssel für Rollen: `role`, `session`, `hub`, `data`. Fehlende Pflichtschlüssel melden `AhfError` mit lesbarer Meldung.
- `src/core/Log.ahk`: `Log.Configure(sink)`, `Log.Write(level, source, text, flowId := "")`. Levels `a0..a3`, `f0..f3`, `t0..t3` wie v1. `sink` ist eine Funktion. Ohne Sink schreibt `Log` nichts (kein Datei-I/O in `core`). Eine einfache `Log.Memory`-Senke für Tests (Array).
- `src/core/Time.ahk` (optional): `Time.NowMs()` über `QueryPerformanceCounter`, für Messungen und Timeouts, keine IDs.

## Akzeptanzkriterien

- `Ids.Next()` liefert über 100.000 Aufrufe keine Doppelten und ist streng aufsteigend.
- `Args.Parse` behandelt `--session=a=b` (Wert mit `=`), `--flag`, leere Werte, doppelte Schlüssel (letzter gewinnt, loggbar).
- Exceptions lassen sich per `catch AhfError as e` fangen, `e.code` ist gesetzt.
- Kein Zugriff auf Dateien, GUI, Prozesse in diesem Paket.

## Tests

`tests/ahk/core_ids.test.ahk`, `core_args.test.ahk`, `core_errors.test.ahk`, `core_log.test.ahk`.

## Hinweise

- Fehler-Klassen nutzen `extends Error`. Beim Werfen `throw AhfTimeoutError("...")`, `code` ist in der Klasse vorbelegt.

## Ergebnis

Stand: WI-03 abgeschlossen, nicht committet. `python -m pytest tests -q` grün (69 passed, 1 skipped), keine AutoHotkey-Prozesse übrig.

Akzeptanzkriterien (verifiziert durch Tests):

- `Ids.Next()`: 100.000 Aufrufe eindeutig und streng aufsteigend (`core_ids.test.ahk`, "100000 ids are unique").
- `Args.Parse`: `--session=a=b`, `--flag`, `--data=` (leer), Positionsargumente, Großschreibung der Schlüssel, doppelter Schlüssel (letzter gewinnt, Log `a1`), leere Namen werfen `bad_args`. `Args.Require` nennt alle fehlenden Pflichtschlüssel.
- Fehler: `catch AhfError as e` fängt alle Klassen, `e.code` ist gesetzt (`core_errors.test.ahk`, `core_log.test.ahk`).
- Kein Datei-, GUI- oder Prozesszugriff in `src/core/` (gelesen; `Time.ahk` nutzt nur `QueryPerformanceCounter`).

Behoben (Ursache):

- `Log.Write` rief die Senke als `this.sink(...)` auf. Dabei wird das Objekt `Log` als zusätzliches erstes Argument übergeben. Freie Funktionen mit vier Parametern bekamen fünf Argumente ("Too many parameters passed to function"), und die Senke lief gar nicht. Fix: Senke in lokale Variable kopieren, dann `sink(...)` aufrufen.
- `Log.Memory` war eine statische Methode. Als Senke verschob sie ebenfalls die Parameter. Fix: Funktionseigenschaft `static Memory := (...) => ...`. Der Name bleibt, der Vertrag (vier Argumente) bleibt.
- Die Schreibweise der Fehlerklassen und des Vertrags (`Log.Configure(sink)`, `Log.Write(level, source, text, flowId)`) ist unverändert.

Abweichungen:

- `Log.Memory` ist keine Methode mehr, sondern eine Funktionseigenschaft (siehe oben, mit HOW-TO-Eintrag).

Nicht geprüft / offen:

- `test_msgbox_is_captured_and_closed` (`tests/support/test_dialogwatch.py`, nicht WI-03) war in einer Gesamtsuite einmal im Timeout. Bei Wiederholung grün. Ursache nicht untersucht, siehe HOW-TO (Status vermutet).
- `doc/HOW-TO.md` hat die Überschrift "Prozesse, Pipes, Nachrichten" doppelt. Nicht angefasst, da außerhalb des Auftrags.
- Die Checkbox für WI-03 in `work_items/phase2/README.md` ist nicht gesetzt (nicht Teil dieses Auftrags).
