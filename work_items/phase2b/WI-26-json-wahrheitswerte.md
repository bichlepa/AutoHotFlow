# WI-26 JSON: echte Wahrheitswerte auf der Leitung

Größe: S · Hängt ab von: WI-24 (Hub-Umbau in `Message`) · Blockiert: –

## Ziel

Wahrheitswerte gehen als JSON `true`/`false` auf die Leitung statt als `1`/`0` (Entscheidung E8). Die Sonderregeln dazu in Protokoll, Tests und HOW-TO entfallen.

## Hintergrund und Entscheidung (Review 2026-10-11)

- Heute: `Json.Parse` liefert `true`→`1`, `false`→`0`; `Json.Stringify` kennt keinen Bool-Typ und schreibt `1`/`0`. Workarounds stehen in `doc/PROTOKOLL.md` 2 ("Umsetzung in AHK"), 4.3 ("Wahrheitswerte gehen als 0 oder 1"), 4.8 (Stub), `doc/HOW-TO.md` ("Wahrheitswerte gehen als Zahl auf die Leitung", "Boolesche Antworten als Zahl (Stub)", "Wahrheitswerte aus AHK sind 0 und 1 auch in den Python-Tests").
- **AHK v2 hat keinen Bool-Typ**, und jedes Objekt ist wahr (es gibt keinen `__Bool`-Haken). Würde `Parse` eigene Objekte für `true`/`false` liefern, wäre `if payload["ok"]` bei `false` wahr: ein gefährlicher stiller Fehler. Deshalb:
  - **Lesen bleibt:** `true`→`1`, `false`→`0`. Das ist für AHK-Code die richtige Darstellung (`if x` funktioniert) und wird als bewusste Regel dokumentiert.
  - **Schreiben wird korrekt:** neue Singletons `Json.True` und `Json.False` (wie `Json.Null`) und `Json.Bool(x)` (liefert eines von beiden). `Stringify` schreibt sie als `true`/`false`.
  - Alle Wahrheitswerte im Protokoll werden mit `Json.Bool(...)` erzeugt.
  - **Falle auf der Schreibseite:** `Json.False` ist ein Objekt und damit in AHK **wahr**. Ein Map-Eintrag mit `Json.False`, den AHK-Code vor dem Senden mit `if` prüft, ist ein Fehler (Beispiel: `WriteQueue` setzt `payload["ok"]`, `Storage._Finish` prüft `if (payload["ok"])`). Regel: `Json.True`/`Json.False` nur beim Bau der Nachricht unmittelbar vor dem Senden; das Feld `ok` setzt der Code intern weiter als 1/0, und die Sendestellen (`Peer.Reply`, `Peer._Transmit` für Antworten, Hub-Antworten) wandeln `ok` zentral um. Diese Regel in `doc/HOW-TO.md` und `doc/KONVENTIONEN.md` aufnehmen.
  - Empfänger bleiben tolerant (`1`/`0` und `true`/`false` gelten gleich), damit ältere Testclients und Fremdclients funktionieren.
- **Flow- und Variablendateien:** Die v1-Dateien enthalten kein `true`/`false`/`null` (verifiziert in `doc/ARCHITEKTUR.md` 7). Checkbox-Parameter sind dort Zahlen (`"DelimiterComma": 1`) und bleiben es; das Schreibformat der Flows ändert sich in Phase 2b nicht (E8). Round-Trip-Tests der Flows bleiben unverändert grün.

## Aufgaben

1. `Json.True`, `Json.False`, `Json.Bool(x)` in `src/core/Json.ahk`, Unit-Tests in `tests/ahk/json.test.ahk` (Schreiben, Lesen ergibt 1/0, Round-Trip dokumentiert als nicht typerhaltend für Booleans, `Json.Bool` mit 0, 1, "", "0", Objekten).
2. Alle Absender von Wahrheitswerten umstellen. Mindestens: `ok` (Dispatcher, `Peer.Reply`, Hub-Antworten, `sys.welcome`), `cancel`, `started`, `clean`, `restart`, `enabled`, `executing`, `exists`, `existed`, `waiting` (WI-21), alles in Testrollen und im Stub. Vorgehen: alle Stellen mit `true`/`false`/`1`/`0` in Nutzlast-Maps suchen und im Ergebnis auflisten.
3. Python: Hilfsfunktion in `tests/support/` für die Prüfung "echter Boolean" (`is True`/`is False`); in den Protokolltests für die Felder oben strenger prüfen, damit ein Rückfall auffällt.
4. Doku: Workaround-Abschnitte in `doc/PROTOKOLL.md` ersetzen durch die neue Regel (Schreiben `true`/`false`, Lesen tolerant). HOW-TO-Einträge aktualisieren (Status, Verweis auf diese Regel), nicht löschen.
5. Optional, wenn einfach: Regel im Architekturwächter (WI-19), die `Map("ok", true)` ohne `Json.Bool` meldet. Sonst als offenen Punkt notieren.

## Akzeptanzkriterien

- Alle Wahrheitswerte im Protokoll kommen in Python als `bool` an (strenge Tests).
- Gesamtlauf grün, Flow-Round-Trip unverändert.
- Doku ohne die alten Sonderregeln, die neue Regel an einer Stelle (`doc/PROTOKOLL.md` 2).

## Ergebnis

Status: abgeschlossen (Aufgaben 1 bis 5). Zwei Läufe mit bekannten, nicht von WI-26 verursachten Wacklern, siehe unten.

### Was erledigt ist

1. **`Json.True`, `Json.False`, `Json.Bool(x)`** in `src/core/Json.ahk` (Singletons der Klassen `TrueValue`/`FalseValue`, `Stringify` schreibt `true`/`false`, `Parse` liest weiter `1`/`0`). Tests in `tests/ahk/json.test.ahk` (5 neue Fälle): Schreiben, Lesen ergibt 1/0, Round-Trip nicht typerhaltend, `Json.Bool` mit 0, 1, `""`, `"0"`, `"x"`, 5, Map, `Json.True`, `Json.False`, Singletons verschieden von `Json.Null`, Falle „`Json.False` ist wahr“.
2. **Zentrale Umwandlung von `ok`:** `Message.Serialize` schreibt die Nutzlast über `Message._WirePayload`. Ein Feld `ok` der obersten Ebene wird auf einer Kopie zu `Json.True`/`Json.False`; die Nutzlast des Absenders bleibt `1`/`0`, `if payload["ok"]` bleibt richtig. Alle Sendewege laufen durch `Serialize` (verifiziert: `Json.Stringify` wird in `src/` nur in `Message.ahk`, `StubManager._Ui` und `VarFiles.Set` aufgerufen, die beiden letzten schreiben keine Protokollnachricht mit Wahrheitsfeldern). AHK-Tests in `tests/ahk/message.test.ahk` (3 neue Fälle).
3. **Python:** `tests/support/wirebool.py` (`is_bool`, `assert_bool`, `find_violations`, `record`), eingehängt in `FrameDecoder.feed`. Eine Autouse-Fixture in `tests/conftest.py` lässt jeden Test fehlschlagen, dessen Python-Peer ein Protokollfeld der Liste (`ok, cancel, started, clean, restart, enabled, executing, exists, existed, waiting, byMeta, delete`) nicht als JSON-Boolean erhält. Nutzdaten (`definition`, `params`, `imports`, `exports`, `settings`, `content`, `env`) werden nicht durchsucht (E8: Flowformat unverändert, `"enabled": "0"` ist ein Elementparameter). Unit-Tests in `tests/support/test_wirebool.py` (5). Die Protokolltests prüfen die Felder streng mit `is True`/`is False` (`test_engine.py` inkl. `ask`, `test_storage.py` inkl. `ask_ok`, `test_shutdown.py`, `test_process_crash.py`, `test_supervisor.py`, `test_role.py`, `test_ui_stub.py`).
4. **Doku:** `doc/PROTOKOLL.md` Abschnitt 2 hat jetzt die eine Regel (Schreiben, Lesen, Hub, Round-Trip, Prüfung), die Abschnitte 4.3 (Engine) und 4.8 (Stub) haben keine Sonderregel mehr. `doc/HOW-TO.md`: die drei alten Einträge bleiben mit Status „überholt durch WI-26“, neuer Eintrag „`Json.False` ist in AHK wahr“. `doc/KONVENTIONEN.md`: Regel `wire-bool` und Zeile in der Muster-Tabelle.
5. **Architekturwächter:** Regel `wire-bool` in `tools/arch_check.py` (Selbsttest in `tests/test_architecture.py`). Meldet Literale (`"enabled", true`, `"cancel", 1`, auch `0`/`false`) in einem Feld der Liste. `ok` ist ausgenommen, weil zentral umgewandelt. `Get("...", 0)` zählt nicht. Grenze: berechnete Werte (`"enabled", rec.Enabled`) erkennt die Regel nicht (Review).

### Geprüfte und umgestellte Stellen

Umgestellt (Absender von Wahrheitswerten):

- `Message.Serialize`/`_WirePayload`: `ok` für `Peer.Send`, `Peer.Reply`, `Dispatcher`-Antworten, Fehlerantworten von `Peer` und `WriteQueue.Fail`, Hub-Antworten (`Hub._Reply`, Timeout-Antwort, `denied`/`bad_payload`), `sys.welcome`, `Storage._Finish`.
- `src/engine/Engine.ahk`: `evt.flow.state` (`enabled`, `executing`), `cmd.engine.snapshot` (`enabled`, `executing` je Flow), `cmd.flow.start` (`waiting`).
- `src/supervisor/Children.ahk`: `evt.process.exited` (`clean`), `evt.process.crashed` (`restart`).
- `src/supervisor/Supervisor.ahk`: Antwort `cmd.app.exit` (`started`).
- `src/core/Role.ahk`: `sys.bye` (`clean`).
- `src/storage/VarFiles.ahk`: `var.get` (`exists`), `var.delete` (`existed`).
- `src/manager/StubManager.ahk`: `cmd.app.prepareExit` (`cancel`), `cmd.test.command` (die durchgereichte Engine-Antwort wird mit `_WireAnswer` wieder in `true`/`false` gesetzt, weil `Parse` `1`/`0` liefert), UI-Ereignisse `stub.snapshot` (`ok`), `stub.commandAnswer` (`ok`), `stub.prepareExit` (`cancel`).

Geprüft, nicht geändert (mit Grund):

- `Worker.ahk` `"started", false` ist ein interner Auftragsdatensatz, nie gesendet (`arch-ok: wire-bool`). `evt.worker.done`, `cmd.worker.run` und `cmd.worker.cancel` haben keine Wahrheitsfelder.
- `Executor`, `Engine.PATCH_OPS`, `Storage.logBuffers`, `WriteQueue` `retry`, `Children` `bye`/`byeClean`/`gone`, `Hub` `topics`: interner Zustand.
- `StubManager` `ViewModel` und `flowRecs`: gehen an die GUI im selben Prozess, nicht auf die Leitung (bleiben `1`/`0`).
- Testrollen und Helfer (`tests/integration/helpers/*`, `tests/ahk/helpers/*`): senden keine Wahrheitsfelder außer `ok` (zentral). `pipe_client.ahk` `Map("ok", false)` und `sendOk` in `pipe_echo_server.ahk` sind Ergebnisdateien der Tests, keine Leitung.
- `byMeta` (`evt.flow.committed`) und `delete` (`cmd.ui.confirmDeleteFlowFile`): im Quelltext gibt es noch keinen Absender (nicht gebaut, Phase 3). Sie stehen in der Wächterliste und in `doc/PROTOKOLL.md` 2.
- `exports` der Elemente und Variablenwerte: Nutzdaten, Format unverändert.

### Belege (Läufe)

- Rot zuerst: Mit der Autouse-Fixture vor der Umstellung der Absender schlugen 40 Tests im Teardown fehl (z. B. `test_second_run_while_busy_is_answered_with_busy`: `worker:1 res.worker.run payload.ok = 1`). Nach der Umstellung grün. Ein falscher Treffer (`definition.allElements...enabled = '0'`, Flowdaten) führte zur Ausnahmeliste der Nutzdaten.
- AHK-Tests `json.test.ahk` (55 Fälle im Filter) und `message.test.ahk`: grün.
- Serieller Gesamtlauf `python -m pytest tests -q -n 0` (Endstand): **587 passed, 1 skipped, 14 deselected in 467,9 s**. Ein früherer serieller Lauf mit demselben Code: 586 passed, 1 failed (`test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean[0]`, `clean` false für `manager`), siehe F-26.
- Paralleler Lauf `-n 4`: 585 passed, 1 skipped, **2 failed** in 250 s: `tests/fault/test_shutdown.py::test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean[0]` (F-26) und `tests/integration/test_role.py::test_shutdown_sends_bye_and_exits_0_within_one_second` (`shutdown took 1.158 s`, Grenze 1,0 s; Zeitgrenze unter Last).
- `python tools/arch_check.py`: 64 Dateien, 0 Verstöße, 15 durch gelistete Ausnahmen gedeckt.
- Flow-Round-Trip (`tests/test_json_flows.py`) unverändert grün, kein Format geändert.
- Hub-Durchreichung (WI-24): Der schnelle Weg (`ParseHead`/`WithFrom`) berührt die Nutzlast nicht, `true`/`false` gehen als Text durch. Indirekt verifiziert: Python-Clients senden `true`/`false` über den Hub an AHK-Rollen, und AHK-Antworten kommen bei Python als `bool` an. Ein gezielter Test mit einem Rahmen im schnellen Weg und `true` in der Nutzlast wurde nicht geschrieben.

### Abweichungen

- Die Aufgabe nennt `Peer.Reply`, `Peer._Transmit` und Hub-Antworten als Wandelstellen. Umgesetzt ist eine einzige Stelle darunter (`Message.Serialize`), weil alle genannten Wege dort ankommen. Das ist einfacher und vergisst keinen Sendeweg.
- Die Umwandlung von `ok` gilt nur für die oberste Ebene der Nutzlast. Verschachteltes `ok` (z. B. in `answer` bei `cmd.test.command`) setzt der Absender selbst (`StubManager._WireAnswer`).
- Die Wächterliste (`BOOL_FIELDS`) in Python ist eine Namensliste. Ein neues Wahrheitsfeld muss dort, in `tools/arch_check.py` (`WIRE_BOOL_RE`) und in `doc/PROTOKOLL.md` 2 ergänzt werden.

### Nicht geprüft

- Ältere oder fremde Clients, die `1`/`0` senden: Empfänger lesen beides als `1`/`0`, mit echten Fremdclients nicht getestet.
- Wahrheitsfelder künftiger Pakete (Editor, Triggerhost): die Wächterregel erkennt nur Literale und nur Namen aus der Liste.
- Kosten von `Clone` in `_WirePayload` bei sehr großen Nutzlasten mit `ok` (flache Kopie der obersten Ebene, nicht gemessen).

### Neue Funde

- **F-26 (niedrig bis mittel):** `evt.process.exited` meldet für `manager` gelegentlich `clean: false` bei einem sauberen Ende, obwohl F-06 als behoben gilt. Gemessen mit `AHF_FAULT_REPEAT`: Stand vor WI-26 (Commit `f1efb7a`, eigener Worktree) 7 von 150 Läufen von `test_healthy_session_exits_within_2_seconds_and_every_role_says_it_is_clean`. Stand mit WI-26 5 von 480 Läufen in `test_shutdown.py`, darunter auch `test_frozen_storage_is_terminated_at_the_deadline_and_the_others_exit_clean`. Also nicht durch WI-26 verursacht. Ursache nicht untersucht (vermutet: `sys.bye` des Managers wird beim Prozessende noch nicht gelesen, ein weiterer Fall neben dem durch WI-18/WI-22 behobenen). Eintrag in `work_items/STATUS.md`.
- F-16 bis F-25 nicht doppelt angelegt.

### Offene Punkte

- F-26 untersuchen (gehört thematisch zu WI-18/WI-22, nicht zu WI-26). Die Zusage „nie falsch in 2 x 50 Wiederholungen“ aus WI-22 hält unter den heutigen Bedingungen nicht.
- `test_shutdown_sends_bye_and_exits_0_within_one_second` ist unter Parallellast knapp (1,16 s gegen 1,0 s), im seriellen Lauf grün.
- Der Wächter erkennt berechnete Wahrheitswerte nicht. Ersatzweise fängt die Python-Prüfung in jedem Test einen Rückfall auf der Leitung.
