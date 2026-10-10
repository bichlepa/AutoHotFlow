# WI-03 Ids, Fehler, Argumente, Log-Client

Größe: S · Hängt ab von: – · Blockiert: WI-04, WI-05, WI-08, WI-09

## Ziel

Kleine, abhängigkeitsfreie Bausteine in `src/core/`, die jede Rolle braucht.

## Vorher lesen

`doc/KONVENTIONEN.md` (Abschnitte 3 und 4), `doc/PROTOKOLL.md` Abschnitt 2 (Fehlercodes, ID-Format).

## Zu erstellen

- `src/core/Ids.ahk`: `Ids.Configure(processName)`, `Ids.Next(prefix := "")`. Zähler pro Prozess, beginnt bei 1, **nicht** `A_TickCount`. Rückgabe `"<processName>#<n>"` bzw. `"<prefix><n>"`, wenn `prefix` gesetzt ist.
- `src/core/Errors.ahk`: `AhfError` (Basis, Felder `code`, `message`), `ProtocolError`, `TimeoutError`, `ElementError`, `JsonError` (von WI-02 genutzt, hier definieren). Fehlercodes als Konstanten (`ERR_TIMEOUT := "timeout"` usw., Liste aus PROTOKOLL 2).
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

- Fehler-Klassen nutzen `extends Error`. Beim Werfen `throw TimeoutError("...")`, `code` ist in der Klasse vorbelegt.
