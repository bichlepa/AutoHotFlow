# Protokoll AutoHotFlow v2 (IPC)

Status: Entwurf, Protokollversion **1**. Begründung der Technik: [ARCHITEKTUR.md](ARCHITEKTUR.md), Abschnitt 2.2.

---

## 1. Transport

- **Hub:** Der Supervisor betreibt die Pipe `\\.\pipe\ahf.s<winSession>.u<tag>.<session>.hub` (Name aus `PipeNames.Hub`, `src/core/PipeNames.ahk`; `<winSession>` ist die Windows-Sitzungs-ID aus `ProcessIdToSessionId`, `<tag>` sind 8 Hexziffern des FNV-1a-Hashes der Benutzer-SID, z. B. `ahf.s1.u1a2b3c4d.main.hub`). Die Rollen bilden den Namen nicht selbst, sie bekommen ihn mit `--hub=<name>`. Grund (WI-22): Pipe-Namen gelten für den ganzen Rechner, Mutexe nur je Windows-Sitzung. Bei einem zweiten angemeldeten Benutzer (schneller Benutzerwechsel, Terminalserver) fand die zweite Instanz keinen Mutex, wollte denselben Pipe-Namen bedienen und scheiterte mit Exit 1. Tests nutzen `tests/support/pipenames.py` (`hub_pipe(session)`). Alle anderen Rollen verbinden sich als Client. Es gibt keine direkten Verbindungen zwischen Nicht-Hub-Prozessen.
- **Sitzung (`<session>`):** Standard ist `main` (Option `--session=<id>`, Standard `main`). Abweichung von der ursprünglich geplanten Wahl (Supervisor-PID und Startzeit): Eine zweite Instanz muss den laufenden Hub finden, um ihren Befehl abzugeben (Abschnitt 4.1, `cmd.app.command`). Mit PID und Startzeit kennt sie den Namen nicht. Die Einzelinstanz-Sperre (benannter Mutex `Local\AHF.supervisor.<session>`, ausdrücklich im Namensraum der Windows-Sitzung, `PipeNames.Mutex`) und die Pipe nutzen denselben Schlüssel `<session>`. Mehrere parallele Sitzungen (z. B. Tests) bekommen eigene `--session`-Werte.
- **Pipe:** Byte-Modus, duplex, `FILE_FLAG_OVERLAPPED`, `PIPE_REJECT_REMOTE_CLIENTS`, eine Serverinstanz pro Client (der Hub legt nach jedem `Connect` eine neue Instanz an).
- **Rahmen:** `uint32` Länge (little endian) + UTF-8-JSON. Maximale Größe 16 MiB. Größere Nutzdaten (z. B. große Flows) werden über `storage`-Dateien oder Chunking geteilt (`seq/total` in der Nutzlast), nicht über einen größeren Rahmen.
- **Weckruf:** Nach jedem Schreiben sendet der Sender `PostMessage(peerHwnd, 0x8001, 0, 0)` (`WM_AHF_WAKE`). Der Empfänger liest bei Weckruf und zusätzlich per Fallback-Timer (250 ms). Ein Client, der die Hub-HWND kennt (Peer-Option `hubHwnd`), weckt den Hub schon mit dem `sys.hello` (Abschnitt 5); ohne Weckruf nimmt der Hub den neuen Client erst nach bis zu 250 ms an.
- **Lieferung:** Reihenfolge pro Verbindung erhalten, höchstens einmal, keine Persistenz. Verlorene Nachrichten werden über Timeouts und Resync (Abschnitt 5) behandelt, nicht über Wiederholung.
- **Kodierung:** JSON-Zahlen sind Zahlen, Strings Strings. Flow-Daten behalten die Typen der Datei (z. B. `"zoomFactor": "0.700000"` bleibt ein String).

## 2. Umschlag (Envelope)

Jede Nachricht ist ein JSON-Objekt mit festem Schema. Der Serializer schreibt die Kopffelder **in dieser Reihenfolge zuerst**, damit der Hub `to` ohne vollständiges Parsen der Nutzlast lesen kann.

```json
{
  "to": "engine",
  "from": "editor:Flow 1010290492",
  "id": "editor:Flow 1010290492#17",
  "type": "cmd.flow.start",
  "corr": null,
  "timeoutMs": 5000,
  "payload": { "flowId": "Flow 1010290492" }
}
```

| Feld | Typ | Bedeutung |
|---|---|---|
| `to` | string | Rollenadresse (siehe 3) oder Topic `topic:<name>` für Ereignisse. `"*"` nur für `sys.*`-Rundrufe des Supervisors. |
| `from` | string | Absender-Rollenadresse. Der Hub setzt sie anhand der Verbindung und überschreibt falsche Werte. |
| `id` | string | `<from>#<n>`, `n` ist ein Zähler pro Prozess und Sitzung (nicht `A_TickCount`). |
| `type` | string | Siehe Präfixe unten. |
| `corr` | string oder null | Bei Antworten die `id` der Anfrage. |
| `timeoutMs` | int oder fehlend | Nur bei `cmd.*`, Frist, nach der der Absender die Anfrage als gescheitert behandelt. Standard 5000, `storage`-Operationen 30000. |
| `payload` | object | Typspezifisch (Abschnitt 4). Immer ein Objekt, nie `null`. |

**Typpräfixe**

| Präfix | Bedeutung | Antwort erwartet |
|---|---|---|
| `cmd.` | Befehl oder Anfrage | ja, genau eine `res.` mit `corr` (außer als `noReply` markiert) |
| `res.` | Antwort auf `cmd.`, Typ ist `res.<cmdtype ohne "cmd.">` | – |
| `evt.` | Ereignis, wird an Abonnenten des Topics verteilt | nein |
| `sys.` | Lebenszyklus (Hallo, Ping, Shutdown) | je Typ |

**Antwort:** `payload` enthält `{ "ok": true, ...Daten }` oder `{ "ok": false, "error": { "code": "...", "message": "..." } }`.

**Antwort später (WI-12):** Ein `cmd.`-Handler darf `Deferred.Marker()` zurückgeben und die Antwort später mit `peer.Reply(request, payload)` senden. Solange der Handler den Marker zurückgibt, sendet der Peer nichts. Der Handler ist dann für genau eine `Reply` verantwortlich, auch auf jedem Fehlerpfad (sonst endet der Absender mit seinem Timeout). Genutzt von `storage` (Warteschlange, Abschnitt 4.6). Umgesetzt in `src/core/ipc/Deferred.ahk`, `Dispatcher.ahk`, `Peer.ahk`.

**Fehlercodes:** `timeout`, `unknown_type`, `bad_payload`, `not_found`, `conflict` (Revision), `busy`, `denied`, `internal`, `peer_gone`, `shutting_down`.

**Weiterleitung im Hub (WI-24):** Der Hub liest bei Rahmen von verbundenen Clients nur die Kopffelder (`Message.ParseHead`) und leitet die Nutzlast als Text unverändert weiter. Er ersetzt nur `from` (`Message.WithFrom`). Das gilt für Rahmen **in genau der Form, die `Message.Serialize` schreibt**: Kopffelder in der Reihenfolge `to, from, id, type, corr, [timeoutMs,] payload`, kein Leerraum, `payload` ein Objekt, nach dem Objekt nur noch das schließende `}`. Alles andere (Leerraum, andere Reihenfolge, fehlendes `corr`, Nutzlast kein Objekt, Text hinter der Nutzlast) läuft über den vollständigen Weg (`Message.Parse`, neue `Message`, `Serialize`) wie bisher und wird dort geprüft. Nachrichten an `supervisor` werden immer vollständig geparst. Gemessen: 93-KB-Rahmen kosten im Hub 1,7 ms statt 220 ms. Folge: Der Hub prüft den **Inhalt** der Nutzlast nicht mehr (nur Klammern und Zeichenketten werden gezählt). Eine ungültige Nutzlast weist der Empfänger ab (`Peer._RejectFrame`): ist der Umschlag lesbares JSON, antwortet er auf ein `cmd.` mit `bad_payload`, sonst wird der Rahmen verworfen und gezählt (`badFrames`). Ein Absender, dessen Nutzlast nicht einmal JSON ist, bekommt wie bisher keine Antwort (nur sein eigenes Timeout), denn auch der vollständige Weg kann `from` und `id` dann nicht lesen.

**Pflicht für jeden Empfänger:** jede `cmd.`-Anfrage wird beantwortet (auch mit Fehler). Der Absender erzeugt bei Fristablauf selbst ein lokales `res.` mit `timeout` und verwirft spätere Antworten mit unbekannter `corr`. Ist der Umschlag ungültig, `from`/`id`/`type` aber lesbar, antwortet der Empfänger mit `bad_payload`. Ganz unlesbare Rahmen werden verworfen und gezählt.

**Wahrheitswerte (WI-26, E8):** Auf der Leitung stehen Wahrheitswerte als JSON `true`/`false`, nie als `1`/`0`. Das betrifft alle Felder dieses Dokuments, die als `bool` bezeichnet sind oder wie `ok`, `cancel`, `started`, `clean`, `restart`, `enabled`, `executing`, `exists`, `existed`, `waiting`, `byMeta`, `delete`, `busy`, `truncated` Wahrheitswerte sind. Die Regel in drei Teilen:
- **Schreiben:** `Json.True`, `Json.False` und `Json.Bool(x)` (`src/core/Json.ahk`) erzeugen die Werte, **nur beim Bau der Nachricht unmittelbar vor dem Senden**. AHK v2 hat keinen Bool-Typ, jedes Objekt ist wahr, also ist `Json.False` in einem `if` wahr. Programmzustand und Rückgabewerte bleiben deshalb `1`/`0`. Eine Ausnahme von „beim Bau“ gibt es für `ok`: Der Code setzt `ok` intern weiter als `1`/`0` (`Dispatcher`, `WriteQueue`, `Map("ok", true)`), und `Message.Serialize` wandelt das Feld `ok` der Nutzlast (oberste Ebene, auf einer Kopie) in `true`/`false` um. Das deckt `Peer.Send`/`Peer.Reply`, die Antworten des Hubs und `sys.welcome` ab, weil alles durch `Serialize` geht.
- **Lesen:** `Json.Parse` liefert `true` als `1` und `false` als `0`, damit `if payload["ok"]` in AHK stimmt. Empfänger sind tolerant: `1`/`0` und `true`/`false` gelten gleich (ältere und fremde Clients).
- **Der Hub** reicht die Nutzlast als Text durch (`Message.ParseHead`/`WithFrom`, siehe oben) und ändert Wahrheitswerte nicht. Ein Wert, der den Hub als `true` erreicht, kommt als `true` heraus.
- **Round-Trip:** `Parse` und `Stringify` erhalten Wahrheitswerte nicht typgenau (`true` kommt als `1` zurück). Wer eine geparste Nutzlast weitergibt (Beispiel `StubManager._WireAnswer`), setzt die Wahrheitsfelder wieder mit `Json.Bool`. Flow- und Variablendateien ändern ihr Format nicht (Checkbox-Parameter bleiben Zahlen); sie enthalten kein `true`/`false`.
- **Prüfung:** Python-Testpeers melden jedes empfangene Protokollfeld dieser Liste, das kein JSON-Boolean ist (`tests/support/wirebool.py`, automatisch in jedem Test). `tools/arch_check.py` Regel `wire-bool` meldet Literale wie `"enabled", true` oder `"cancel", 1` in `Map(...)`.

## 3. Adressen und Topics

| Adresse | Rolle |
|---|---|
| `supervisor` | Supervisor (Hub, antwortet selbst auf `sys.*`, `cmd.app.*`) |
| `engine` | Engine |
| `storage` | Storage |
| `triggerhost` | Triggerhost |
| `manager` | Manager |
| `debug` | Debug-Fenster (WI-28, 4.9) |
| `editor:<flowId>` | Editor des Flows `<flowId>` |
| `worker:<n>` | Worker, `n` vom Supervisor vergeben (`cmd.process.spawn`, 4.1) |

**Topics** (Abonnement per `cmd.topic.subscribe {topic}` an `supervisor`, wird bei Wiederverbindung erneuert):

| Topic | Inhalt | Typische Abonnenten |
|---|---|---|
| `engine` | `evt.engine.*`, `evt.flow.list.changed`, `evt.settings.changed` | alle UIs |
| `flow:<flowId>` | `evt.flow.*`, `evt.element.state`, `evt.connection.state`, `evt.instance.*` für diesen Flow | `editor:<flowId>`, `manager` |
| `log` | `evt.log.entry` | `manager` (Log-Fenster) |
| `process` | `evt.process.*` (Felder siehe 4.1a), `evt.app.exitCancelled` | `manager`, Tests |
| `debug` | `evt.debug.dump` (Werte, die Code mit `Debug.Dump` ausgibt, 4.9) | `debug` (Debug-Fenster), Tests |

## 4. Nachrichtenkatalog

Alle Nutzlasten sind Objekte. `flowId`, `elementId`, `connectionId` sind die Bezeichner aus den Flow-Dateien (z. B. `Flow 1010290492`, `element0000000001`).

**Umsetzungsstand am Ende von Phase 2 (WI-17, Abgleich mit `src/`, verifiziert durch Suche der Typnamen im Quelltext):** Alle Nachrichtentypen, die `src/` sendet oder registriert, stehen in diesem Katalog. Umgekehrt sind die folgenden Typen des Katalogs **noch nicht umgesetzt** (Entwurf für Phase 3 oder später). Ein Client darf sich auf sie noch nicht verlassen:

| Bereich | Noch nicht umgesetzt |
|---|---|
| 4.2 Engine-Befehle | `cmd.flow.create`, `cmd.flow.delete`, `cmd.flow.meta.update`, `cmd.flow.save`, `cmd.trigger.enable`, `cmd.trigger.disable`, `cmd.category.*`, `cmd.settings.get/set` |
| 4.3 Engine-Ereignisse | `evt.flow.committed`, `evt.flow.saved`, `evt.connection.state`, `evt.settings.changed` |
| 4.4 Engine ↔ Triggerhost | alle (`cmd.trigger.arm`, `cmd.trigger.disarm`, `evt.trigger.fired`, `evt.trigger.error`); der Triggerhost (WI-14, optional) ist nicht gebaut, die Rolle `triggerhost` ist ein Platzhalter |
| 4.5 | `cmd.engine.var.get` (Worker fragt Variable der Engine) |
| 4.6 | `cmd.storage.settings.get/set` (steht dort bereits als "noch nicht umgesetzt") |
| 4.7 Dialoge | `evt.ui.notice`, `cmd.ui.confirmDeleteFlowFile` |

`cmd.flow.patch` ist umgesetzt, kennt aber nur das Schema und die Revisionsprüfung (die Operationen selbst kommen in Phase 3, siehe 4.2). Die Rolle `editor` ist ein Platzhalter (Exit 3), `manager` gibt es nur als Stub (`--ui=stub`, 4.8).

### 4.1 Lebenszyklus (`sys.*`)

| Typ | Von → An | Nutzlast | Antwort / Wirkung |
|---|---|---|---|
| `sys.hello` | Rolle → supervisor | `{ name, pid, hwnd, protocol: 1, epoch? }` | `sys.welcome` |
| `sys.welcome` | supervisor → Rolle | `{ session, peers: { name: { hwnd } }, settingsRev }` | Rolle ist `ready` |
| `sys.ping` | supervisor → Rolle | `{ n }` | `sys.pong {n}` innerhalb 1 s |
| `sys.pong` | Rolle → supervisor | `{ n }` | – |
| `sys.shutdown` | supervisor → alle | `{ reason: "user"/"logoff"/"crash", deadlineMs }` | Rolle räumt auf, sendet `sys.bye`, beendet sich |
| `sys.bye` | Rolle → supervisor | `{ clean: bool }` | – (keine Antwort). Die letzte Nachricht der Rolle: alles, was sie vorher gesendet hat, steht davor in derselben Verbindung und kommt vorher an. Danach schließt die Rolle ihre Verbindung erst, wenn ihre Sendewarteschlange geschrieben ist (`Peer.CloseWhenFlushed`), spätestens nach dem Rest von `deadlineMs`, höchstens 1000 ms, und beendet sich (WI-30, ARCHITEKTUR 6.3) |
| `sys.busy` | worker → supervisor | `{ busy: bool }` | – (keine Antwort). Der Worker meldet Beginn (`true`) und Ende (`false`) eines Jobs (WI-27, ARCHITEKTUR 6.4). Solange `busy` wahr ist, sendet der Supervisor dem Worker keinen Ping und beurteilt keinen Pong; beim Ende beginnen die Pong-Zeiten neu. Von einer anderen Rolle als `worker:*` wird die Meldung verworfen (Log `a0`) |
| `cmd.app.prepareExit` | supervisor → editor/manager | `{}` | `res: { ok, cancel: bool }` (Benutzer kann abbrechen). Frist: 600000 ms (10 Minuten, `Shutdown.PREPARE_LIMIT_MS`). Bei Ablauf synthetische Antwort `{ ok: false, error: { code: "timeout" } }`, die wie „kein Abbruch“ gilt, der Exit geht weiter. Eine spätere echte Antwort wird verworfen (`droppedAnswers`). Die Phase hat keine harte Frist (ARCHITEKTUR 6.3), die Obergrenze verhindert nur, dass eine Anfrage ohne Ende bleibt |
| `cmd.app.exit` | beliebige UI → supervisor | `{ deadlineMs? }` (optional, Integer 100 bis 60000, sonst Standard `--deadline`, 5000) | startet Beenden (6.3), `res: { ok, started: bool }`; `started` ist false, wenn schon ein Beenden läuft |
| `cmd.app.command` | zweite Instanz → supervisor | `{ argv: [...] }` (Array von Strings, Kommandozeilen-Wörter; die Instanz übergibt `--command=<text>` als `argv` mit einem Eintrag) | `res: { ok, command?, started? }`. Bekannter Befehl (seit WI-28): `debug` startet die Rolle `debug`, falls sie nicht läuft (`started` true), sonst holt es ihr Fenster nach vorn (`evt.debug.show`, `started` false); die Antwort nennt `command: "debug"`. Alles andere wird nur protokolliert (`a1`), die Antwort ist `{ ok }`. Die zweite Instanz beendet sich mit Exit 0 (zugestellt) oder 1 (keine Antwort, Fehler) |
| `cmd.process.list` | beliebige Rolle → supervisor | `{}` | `res: { ok, processes: [ {name, role, state, pid, restarts} ] }`. Momentaufnahme aller Kinder, Zustände nach ARCHITEKTUR 5.3. Dient als Resync für Späteinsteiger (Abschnitt 5a) |
| `cmd.process.spawn` | engine → supervisor | `{ role: "worker" }` | `res: { ok, name }`, `name` ist `worker:<n>` (der Supervisor vergibt `n`, aufsteigend, in einer Sitzung nie doppelt). Der Prozess startet wie jedes Kind (`evt.process.started`, bei `sys.hello` `evt.process.ready`). Fehler: `denied` (Absender nicht `engine`, oder `role` nicht `worker`), `shutting_down` (Beenden läuft), `busy` (schon 16 lebende Worker, `Children.WORKER_LIMIT`), `bad_payload` (`role` fehlt), `internal` (Start gescheitert). WI-27 |
| `cmd.process.kill` | engine → supervisor | `{ name, reason }` | `res: { ok }`. `TerminateProcess` des Kindes `name`. Nur für Namen `worker:<n>`, nur vom Absender `engine`, sonst `denied` (auch für `storage`, `engine`, `manager`). Unbekannter Name: `not_found`. Ein schon beendeter Worker: `ok` (gleichwertig). Das Ende wird wie jedes andere gemeldet, aber als geplant: `evt.process.exited {name, pid, clean: false, exitCode, reason: "killed"}`, kein `crashed`, kein Neustart. Das Beenden zählt nicht für den Exit-Code 5 des Supervisors. `reason` (Text, höchstens 200 Zeichen) steht im Log `a1`. WI-27 |
| `cmd.topic.subscribe` / `cmd.topic.unsubscribe` | Rolle → supervisor | `{ topic }` | `res: { ok }` |
| `evt.app.exitCancelled` | supervisor → Topic `process` | `{ by }` (Rolle, die abgebrochen hat) | – (Beenden abgebrochen, nichts wurde gestoppt) |

**Exit-Codes des Supervisors** (`AutoHotFlow.ahk --role=supervisor`, Standard ohne `--role`):
0 sauber (jedes Kind hat sich selbst beendet), 1 Start fehlgeschlagen (z. B. Mutex, ungültige Optionen), 5 mindestens ein Kind wurde nach Frist oder Hang beendet (`TerminateProcess`). Dieselben Zahlen stehen im Einstieg (`src/AutoHotFlow.ahk`). Die zweite Instanz nutzt 0 und 1 (siehe `cmd.app.command`).

**Exit-Codes einer laufenden Rolle** (`Role`): 0 sauberes Ende nach `sys.shutdown`, 3 Rolle nicht umgesetzt, 4 Hub verloren (Orphan-Guard oder Peer geschlossen), 6 zu viele unbehandelte Fehler (4.1c). Der Supervisor schreibt die Bedeutung bekannter Codes in die Logzeile des Absturzes (`Children.EXIT_TEXT`).

**Exit-Codes des Einstiegs vor dem Start der Rolle** (gelten für jede Rolle und den Supervisor, WI-22): 2 der Interpreter ist nicht 64 Bit (`A_PtrSize != 8`, Entscheidung E4; Meldung auf stderr: "AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter"; dieselbe 2 wie bei ungültigen Optionen oder unbekannter Rolle), 1 ein Fehler beim Laden der Dateien, bevor `AhfMain` läuft (z. B. eine Elementdatei, deren `ElementRegistry.Register` wirft; Meldung auf stderr, kein Dialog). Beide Prüfungen stehen im Einstieg vor allen `#Include`-Zeilen.

### 4.1a Prozessereignisse (Topic `process`, supervisor → Abonnenten)

Jeder Eintrag trägt `name` (der Name, unter dem das Kind gestartet wurde, z. B. `engine`, `echo:a`) und `pid`, wo der Prozess bekannt ist.

| Typ | Nutzlast | Bedeutung |
|---|---|---|
| `evt.process.started` | `{ name, role, pid }` | Prozess gestartet, noch nicht bereit |
| `evt.process.ready` | `{ name, pid }` | `sys.hello` angekommen, Rolle meldet sich bereit |
| `evt.process.hung` | `{ name, reason }` | kein Pong (3 Pings × 2 s) oder kein `sys.hello` innerhalb 10 s. Der Supervisor sendet `sys.shutdown` mit `deadlineMs` 2000, nach 2 s `TerminateProcess` |
| `evt.process.crashed` | `{ name, pid, reason: "exited"/"hung", exitCode, restart: bool }` | unerwartetes Ende (auch nach Hang). `restart` true, wenn neu gestartet wird |
| `evt.process.exited` | `{ name, pid, clean: bool, exitCode, reason? }` | Ende nach Aufforderung (Beenden). `reason` ist nur bei `cmd.process.kill` gesetzt (`"killed"`). Die Felder `clean` und `exitCode` gelten seit WI-22/23 (vorher hier nicht aufgeführt) |
| `evt.process.restarted` | `{ name, attempt }` | Neustart nach Richtlinie (automatisch nur für `storage` und `engine`; mit `--test-roles` zusätzlich `crasher`) |

**Zeitpunkt von `evt.process.exited` und `evt.process.crashed` (WI-30):** Der Supervisor meldet das Ende eines Prozesses erst, wenn er dessen Verbindung bis zum Ende gelesen hat (ein `sys.bye` ist dann sicher verarbeitet und `clean` stimmt), spätestens 500 ms nach dem Prozessende (`Children.EXIT_GRACE_MS`, für ein Kind ohne Verbindung sofort). Die Meldung kann also bis zu 500 ms nach dem Prozessende kommen; im Normalfall kommt sie im selben Tick (200 ms).

**Freiwilliges Ende (WI-28):** Beendet sich ein Kind von selbst mit `sys.bye {clean: true}` und Exit-Code 0, ohne dass der Supervisor es dazu aufgefordert hat (das Debug-Fenster, das der Benutzer schließt), meldet der Supervisor `evt.process.exited {clean: true}` statt `evt.process.crashed`. Ein hängendes Kind (`hung`) wird weiter immer als `crashed` gemeldet.

Neustart-Richtlinie: höchstens 3 Neustarts in 60 s, sonst bleibt der Prozess `crashed` (`restart: false`). `manager` und `editor` werden nie automatisch neu gestartet.

### 4.1b Testrollen (nur mit `--test-roles`)

Die Rollen `echo`, `crasher`, `hanger`, `slow_shutdown` (Quellen in `tests/integration/helpers/`) sind nur im Testeinstieg `tests/integration/helpers/AutoHotFlowTest.ahk` einkompiliert (WI-29) und dort nur mit `--test-roles` registriert. Im Produkteinstieg und ohne das Flag ist ihr Name unbekannt (Exit 2). Zusätzliche Nachrichten der Testrollen:
- `cmd.test.arm` an `crasher` (`{}`, `res: { ok }`): startet einen Timer (300 ms), nach dem `crasher` sich mit `TerminateProcess` (Exit 7) selbst beendet, ohne `sys.bye`. Der Arm-Schritt erlaubt dem Test, den Prozess zu beobachten, bevor er stirbt (Testszenario für `evt.process.crashed`). Ohne Arm tut `crasher` nichts.
- `cmd.test.echo`, `cmd.test.log`, `cmd.test.logstate`, `cmd.test.setlogtarget`, `cmd.test.throwlater` (`echo`): siehe `tests/integration/helpers/EchoRole.ahk`.
- Option `--prepare-limit=<ms>` (nur mit `--test-roles`, 100 bis 600000): setzt die Frist von `cmd.app.prepareExit` herab, damit der Timeout-Test in Sekunden läuft. Ohne das Flag gilt die Konstante.
- Option `--restart-max=<n>` (nur mit `--test-roles`): Zahl der automatischen Neustarts je 60 s statt 3, damit ein Test ein Kind 50-mal neu starten kann (Handle-Leck-Test).
- Option `--worker-limit=<n>` (nur mit `--test-roles`, 1 bis 16): Höchstzahl lebender Worker statt 16, damit der Test von `cmd.process.spawn` (`busy`) nicht 17 Prozesse braucht.
- `echo` (WI-28): `cmd.test.dump {title, value}` ruft `Debug.Dump` auf (4.9).
- `echo` (WI-23): `cmd.test.stderr {text}` schreibt eine Zeile auf stderr; `cmd.test.log {count, level, text}` schreibt `count` Einträge (Standard `a1`); `cmd.test.throwlater {count}` wirft `count` Fehler aus Timern.

### 4.1c Unbehandelte Fehler (`evt.diag.error`, WI-23)

| Typ | Von → An | Nutzlast | Wirkung |
|---|---|---|---|
| `evt.diag.error` (`noReply`) | Rolle → supervisor | `{ name, errorType, message, file, line, stack, mode }` | Der Supervisor schreibt einen `a0`-Eintrag (Quelle `diag`, Text `unhandled <errorType> in <name>: <message> (<file>, line <line>, <mode>)`) und hält die letzten 50 Meldungen vollständig im Speicher (`DiagLog.Errors()`, Grundlage des Absturzberichts, WI-28). |

Gesendet wird sie von `Role._OnUnexpected` für jeden Fehler, den kein `try/catch` fing (`OnError`), bevor der Hook `OnUnexpectedError` läuft. `name` ist der Rollenname (`echo:a`), `errorType` der AHK-Typ (`ValueError`), `file`/`line` die Stelle, `stack` der Aufrufstapel (`Error.Stack`, auf 4000 Zeichen gekürzt), `mode` die Art des Fehlers laut `OnError` (`Return`, `Exit`, `ExitApp`). Fehlende Felder sind leer. Ist der Peer nicht verbunden, geht die Meldung verloren (der Fehler steht im Log der Rolle). Der Supervisor zählt seine eigenen unbehandelten Fehler im selben Ring (Absender `supervisor`).

**Schwelle:** Mehr als 20 unbehandelte Fehler innerhalb von 60 Sekunden (`Role.ERROR_LIMIT`, `Role.ERROR_WINDOW_MS`) beenden die Rolle mit dem Exit-Code **6** (`Role.EXIT_TOO_MANY_ERRORS`, "too many unexpected errors"); die Meldung steht auf stderr und kommt über die Ausgabe des Kindes in das Log. 20 pro Minute sind großzügig: Eine gesunde Rolle hat keinen, ein kaputtes Element oder ein Timer wirft vielleicht ein paar Mal hintereinander, 21 heißt: der Zustand der Rolle ist kaputt, ein Neustart ist besser als ein Zombie. Das Fenster verhindert, dass seltene Fehler über ein langes Leben zusammenzählen. Für `engine` und `storage` greift danach die normale Neustartregel (4.1a: höchstens 3 Neustarts in 60 s), andere Rollen werden als abgestürzt gemeldet (`evt.process.crashed`, `exitCode` 6).

### 4.2 Engine-Befehle (Clients → `engine`)

| Typ | Nutzlast | Antwort (`payload`) |
|---|---|---|
| `cmd.engine.snapshot` | `{ topics?: [..] }` | `{ ok, epoch, seq, flows: [ {flowId,name,category,enabled,executing,rev} ], settings }` |
| `cmd.flow.get` | `{ flowId }` | `{ ok, rev, definition }` (Struktur wie Flow-Datei, Abschnitt 7 der Architektur, ohne Ansichtsdaten des Editors) |
| `cmd.flow.create` | `{ name, category?, definition? }` | `{ ok, flowId }` |
| `cmd.flow.delete` | `{ flowId }` | `{ ok }` |
| `cmd.flow.meta.update` | `{ flowId, name?, category? }` | `{ ok, rev }` |
| `cmd.flow.patch` | `{ flowId, baseRev, ops: [ ... ] }` | `{ ok, rev }` oder `error.code = "conflict"` mit `{ rev, definition }` |
| `cmd.flow.save` | `{ flowId }` | `{ ok, savedRev }` nach `storage`-Quittung |
| `cmd.flow.start` | `{ flowId, triggerId? }` | `{ ok, instanceId }`, bei Richtlinie `wait` und laufendem Flow `{ ok, instanceId, waiting: true }` (die Instanz ist eingereiht), oder `error.code = "busy"` (Richtlinie `skip`) |
| `cmd.flow.stop` | `{ flowId }` | `{ ok }` (Stopp eingeleitet, Abschluss per `evt.instance.ended`). Beendet laufende **und** wartende Instanzen |
| `cmd.flow.toggle` | `{ flowId }` | `{ ok, action: "started"/"stopped" }` |
| `cmd.flow.enable` / `cmd.flow.disable` | `{ flowId }` | `{ ok }` (schaltet alle Trigger) |
| `cmd.trigger.enable` / `cmd.trigger.disable` | `{ flowId, elementId }` | `{ ok, message? }` |
| `cmd.category.*`, `cmd.settings.get/set` | siehe Phase 3 | – |

**Patch-Operationen (`ops`)** (Phase 2 definiert nur das Schema, Phase 3 füllt es):
`{ op: "element.add"/"element.update"/"element.remove"/"connection.add"/"connection.remove"/"flow.settings", ... }`. Jede Operation trägt die minimal nötigen Felder, Reihenfolge ist wesentlich.

### 4.3 Engine-Ereignisse (`evt.*`, Engine → Topics)

Jedes Ereignis trägt `seq` (steigend pro Engine-Epoche) und `epoch`.

| Typ | Topic | Nutzlast |
|---|---|---|
| `evt.engine.ready` | `engine` | `{ epoch }` |
| `evt.engine.restarted` | `engine` | `{ epoch }` (zusätzlich `seq`) → Clients führen `cmd.engine.snapshot` aus. Sendet die Engine selbst, nur nach einem Neustart durch den Supervisor (Option `--restarted=<n>`), nicht beim ersten Start |
| `evt.flow.list.changed` | `engine` | `{ added: [..], removed: [..], changed: [..] }` |
| `evt.flow.state` | `flow:<id>` | `{ flowId, enabled, executing }` |
| `evt.flow.committed` | `flow:<id>` | `{ flowId, rev, byMeta: bool }` (für Editor nach Manager-Umbenennung) |
| `evt.flow.saved` | `flow:<id>` | `{ flowId, savedRev }` |
| `evt.element.state` | `flow:<id>` | `{ flowId, elementId, state: "idle"/"running"/"finished"/"exception", countRuns, lastRun }` |
| `evt.connection.state` | `flow:<id>` | `{ flowId, connectionId, state }` |
| `evt.instance.queued` | `flow:<id>` | `{ flowId, instanceId, position }` (Richtlinie `wait`: die Instanz wartet, `position` ab 1 in der Warteschlange des Flows) |
| `evt.instance.started` / `evt.instance.ended` | `flow:<id>` | `{ flowId, instanceId, reason? }`. Bei einer wartenden Instanz kommt `started` erst beim Übergang nach `running` |
| `evt.settings.changed` | `engine` | `{ settings }` |
| `evt.log.entry` | `log` | `{ ts, level, source, flowId?, text }` (Engine/Storage senden Log über 4.5, nicht hier) |
| `evt.storage.error` | `engine` | `{ op, path, code, message }` (WI-12: `op` = Name der Storage-Operation, Abschnitt 4.6; `code` = Fehlercode der Antwort) |

**Umsetzung in WI-10 (`src/engine/`, Phase 2):**

- Jedes `evt.*` der Engine trägt `epoch` (Startzeit des Engine-Prozesses, UTC mit Millisekunden, als Ganzzahl) und `seq` (ein Zähler pro Engine-Prozess, +1 pro Ereignis).
- `evt.engine.ready` mit `{}` erst nach dem Laden der Flow-Liste. Beim Laden zusätzlich `evt.flow.list.changed` `{added, removed: [], changed: []}`.
- `evt.storage.error` mit `op` = `flows.list` (Liste fehlgeschlagen, wird bis zu 5-mal wiederholt), `flow.read` (Datei nicht lesbar) oder `flow.parse` (Inhalt ungültig). Der Start wird dadurch nicht blockiert.
- `evt.element.state` `{flowId, elementId, state, countRuns, lastRun}`. `lastRun` ist der Zeitstempel des letzten Starts (`yyyy-MM-dd HH:mm:ss`, UTC). `countRuns` ist +1 beim Start und -1 beim Ende (wie v1). `state` ist `running`, solange `countRuns > 0`, sonst `finished`, bei Ergebnis `exception` `exception`. Ein Stopp durch die Engine zählt als Ende (Ergebnis `stopped`, Zustand `finished`). Bei `exception` zusätzlich `message` (Meldung der Ausnahme).
- `evt.instance.ended` `{flowId, instanceId, reason}` mit `reason`: `finished` (letzter Thread regulär beendet), `exception` (letzter Thread ohne passende Verbindung nach einer Ausnahme), `flow.stop`, `toggle`, `policy stop`, `shutdown`, `flow.deleted` (Flow gelöscht oder aus der Tabelle verschwunden), `trigger removed` (eine wartende Instanz fand beim Start ihren Trigger nicht mehr, sie endet ohne `started`). Eine wartende Instanz, die gestoppt wird, endet ebenfalls ohne `started`.
- `evt.flow.state` `{flowId, enabled, executing}` nach `evt.instance.started` bzw. nach `evt.instance.ended`. Beim Ende kommt `evt.flow.state` also **nach** `evt.instance.ended`.
- Wahrheitswerte (`enabled`, `executing`, `waiting`) gehen als `true`/`false` auf die Leitung (Abschnitt 2).
- `cmd.flow.start` `{flowId, triggerId?}`: `{instanceId}`, bei Richtlinie `wait` und laufendem Flow `{instanceId, waiting: true}` (Einreihen, Abschnitt `wait` unten). Ohne `triggerId` der erste Trigger des Flows. Ein Trigger wird vom Start simuliert (`running`, dann `finished`, wie v1 `newInstance`). Fehler: `not_found` (Flow nicht geladen), `bad_payload` (kein Trigger, kein Trigger unter dieser ID, ungültige Richtlinie), `busy` (Richtlinie `skip`).
- Richtlinie: `flowSettings.ExecutionPolicy` des Flows, `default` wird zu `parallel` aufgelöst (globale Einstellung gibt es in Phase 2 noch nicht). Die Entscheidung trifft `ExecutionPolicy.Decide` (WI-08).
- `cmd.flow.stop` `{flowId}`: `{stopped: n}`, Zahl der gestoppten Instanzen, wartende eingeschlossen (WI-21). Die Quittung (`evt.instance.ended`) folgt synchron. Wartende Instanzen werden zuerst beendet, damit der Stopp keine Instanz nachrücken lässt.
- **Richtlinie `wait` (WI-21, E2, M-11):** Startet `cmd.flow.start` einen Flow, der gerade läuft, legt die Engine die Instanz im Zustand `waiting` an und sendet `evt.instance.queued`. Die Antwort enthält `waiting: true`. Reihenfolge FIFO je Flow, in der Reihenfolge der Starts (nicht nach der Reihenfolge der Instanz-IDs, anders als v1, das die erste Instanz in der Reihenfolge der Instanzliste nimmt). Sobald keine gestartete Instanz des Flows mehr existiert, startet die erste wartende (`evt.instance.started`, im nächsten Dispatch-Durchlauf der Engine, nicht im Aufruf, der die vorige beendet hat). `evt.flow.state` bleibt `executing: 1`, solange eine Instanz läuft, stoppt oder wartet. Die Richtlinie wird beim Start gelesen. Der Trigger und die Definition werden beim Nachrücken aus der neuesten Revision gelesen (E1). Es gibt keine Obergrenze der Warteschlange (Beobachtungspunkt).
- `cmd.flow.toggle` `{flowId}`: `{action: "started"/"stopped", instanceId?}`.
- `cmd.flow.enable` / `cmd.flow.disable` `{flowId}`: `{}`. Setzt nur das Flag und sendet `evt.flow.state`. Trigger werden in Phase 2 nicht scharf geschaltet.
- `cmd.engine.snapshot`: `settings` ist `{}` (Einstellungen kommen in Phase 3).
- `cmd.flow.patch` `{flowId, baseRev, ops}` (WI-10, nur Schema und Revision): `baseRev` muss eine Ganzzahl sein, `ops` ein Array (sonst `bad_payload`). Weicht `baseRev` von der aktuellen `rev` ab, antwortet die Engine mit `error.code = "conflict"` und auf Payload-Ebene `rev` und `definition` des aktuellen Stands. Alle `ops` werden vor jeder Anwendung geprüft: unbekannter `op` ist `bad_payload` ("unknown patch operation"), bekannte Operationen (`element.add`, `element.update`, `element.remove`, `connection.add`, `connection.remove`, `flow.settings`) sind `bad_payload` ("not applied before phase 3"). Ein leeres `ops` gibt `{rev}` ohne Änderung zurück.

### 4.4 Engine ↔ Triggerhost

| Typ | Von → An | Nutzlast | Antwort |
|---|---|---|---|
| `cmd.trigger.arm` | engine → triggerhost | `{ triggerKey, flowId, elementId, class, params }` (`params` bereits ausgewertet) | `{ ok, message? }` (Fehler z. B. „Hotkey nicht setzbar“) |
| `cmd.trigger.disarm` | engine → triggerhost | `{ triggerKey }` | `{ ok }` |
| `evt.trigger.fired` | triggerhost → engine (`to: "engine"`) | `{ triggerKey, flowId, elementId, data }` | keine, die Engine entscheidet nach Ausführungsrichtlinie |
| `evt.trigger.error` | triggerhost → engine | `{ triggerKey, message }` | – |

`triggerKey` = `<flowId>/<elementId>`. Bei `evt.engine.restarted` armiert die Engine alle Trigger neu, der Triggerhost verwirft vorher alle bekannten.

### 4.5 Engine ↔ Worker

| Typ | Von → An | Nutzlast | Antwort / Ereignis |
|---|---|---|---|
| `cmd.worker.run` | engine → worker | `{ execId, class, params, imports: { name: value }, env: { flowId, elementId, instanceId, threadId }, timeoutMs? }` | `res: { ok }` (angenommen) |
| `evt.worker.done` | worker → engine | `{ execId, result, message, exports: { name: value } }` | – |
| `cmd.worker.cancel` | engine → worker | `{ execId }` | `res: { ok }`, danach `evt.worker.done` mit `result: "stopped"` |
| `cmd.engine.var.get` | worker → engine | `{ execId, name, scope? }` | `res: { ok, exists, value }` (selten, mit Timeout) |

**Umsetzung in WI-11 (`src/worker/`):**

- `cmd.worker.run` `{execId, class, params, imports, env, timeoutMs?}`: `env` trägt `flowId`, `elementId`, `instanceId`, `threadId`. Antwort `{ok}` sofort, danach läuft das Element. Ein zweiter Lauf während der Ausführung: `busy`. Eine Klasse, die nicht `Mode := "worker"` hat, endet als `evt.worker.done` mit `exception` ("is not a worker element"). `timeoutMs` nutzt der Worker nicht: die Frist für die Annahme setzt der Absender, die Laufzeit des Elements ist nicht begrenzt.
- `evt.worker.done` `{execId, result, message, exports}`: `result` ist `normal`, `yes`, `no`, `head`, `tail`, `exception` oder `stopped`. `exports` ist die Map aus `ctx.Export(name, value)` (nur Text und Zahlen). Der Worker sendet ihn genau einmal pro Lauf.
- `cmd.worker.cancel` `{execId}`: Antwort `{ok}` (sonst `not_found`), danach `evt.worker.done` mit `stopped`. Ein späteres `Finish` des Elements wird verworfen. Ein einzelner langer blockierender Aufruf im Element kann den Abbruch nicht empfangen, weil AHK Nachrichten nur zwischen Befehlszeilen prüft (Schleifen in Scheiben sind unkritisch, siehe `doc/HOW-TO.md`).
- `sys.shutdown` während eines Laufs: `evt.worker.done` mit `stopped` vor `sys.bye`.

**Umsetzung in WI-11 auf Engine-Seite (`src/engine/WorkerBridge.ahk`).** Der Stand von WI-11 (feste Slots `worker:1..n`, Worker von außen gestartet) ist durch WI-27 ersetzt, siehe den folgenden Abschnitt; die Punkte unten gelten nur dort weiter, wo der Abschnitt WI-27 nichts anderes sagt:

- Option `--workers=<n>` der Engine (0 bis 8, Standard 0 = kein Pool). Slots heißen `worker:1` bis `worker:n`. Mit 0 endet jedes Worker-Element sofort mit `exception` "worker not available".
- Ein Worker-Element bleibt `running`, bis `evt.worker.done` kommt. Ist alle Pool-Slots belegt, wartet der Thread (Zustand `ready`), bis einer frei ist. Ist kein Slot mehr nutzbar (alle `down`), endet er mit `exception` "worker not available".
- Antwort `cmd.worker.run` mit Fehler `not_found`, `peer_gone`, `timeout` oder `internal`: Slot wird `down`, Element endet mit `exception` "worker not available: worker:n (<code>)".
- Absturz oder Ende eines Workers: Die Engine abonniert das Topic `process` beim Supervisor (`cmd.topic.subscribe`, nur mit `--workers` > 0) und wertet `evt.process.crashed` und `evt.process.exited` für `worker:n` aus. Das laufende Element endet mit `exception` "worker crashed (worker:n)". `evt.process.ready` macht einen `down`-Slot wieder `idle`.
- `cmd.worker.cancel` bei Stopp der Instanz: Der Thread endet sofort (wie inline, Quittung nicht abgewartet). Der Slot bleibt `busy`, bis der Worker `evt.worker.done` schickt, spätestens nach 2 s (dann `down`, Eintrag im Log `a0`).
- Ergebnisse aus `evt.worker.done`: Exporte werden als Thread-Variablen gesetzt. Ein unbekanntes Ergebnis wird `exception`.
- `cmd.worker.run` übergibt `imports` als Kopie der Instanzvariablen (Scope `instance`) und `env` mit `flowId`, `elementId`, `instanceId`, `threadId`. Die Frist der Annahme (`timeoutMs`) ist 5000 ms.

**Umsetzung in WI-27 (elastischer Pool, ARCHITEKTUR 6.4):**

- **Optionen der Engine:** `--workers=<n>` (Obergrenze N, 0 bis 8, Standard 4; 0 = kein Pool, jedes Worker-Element endet mit `exception` "worker not available"), `--warm-workers=<w>` (Standard 1, höchstens N), `--worker-idle-ms=<ms>` (Standard 60000, 100 bis 3600000). Der Supervisor reicht diese drei Optionen an alle Rollen weiter, wenn er sie bekommt. Ungültige Werte: Engine Exit 2.
- **Slots:** `starting` → (`evt.process.ready`) → `idle` ⇄ `busy`. Worker werden nur durch `cmd.process.spawn` beim Supervisor erzeugt (4.1). Es gibt keine Slots für Worker, die die Engine nicht selbst angefordert hat. Slots und offene Startanfragen sind zusammen höchstens N.
- **Bedarf und Warmstart:** Wartende Worker-Elemente lösen Startanfragen aus (ARCHITEKTUR 6.4). Nach `OnReady` fragt die Engine `cmd.process.list` (Frist 5 s), beendet alle `worker:*` mit `cmd.process.kill` (Grund `orphan of a previous engine`) und fordert dann W Worker an.
- **Beschäftigt:** `sys.busy` (4.1) sendet der Worker, nicht die Engine.
- **`cmd.worker.run`:** `timeoutMs` ist weiter die Frist der Annahme (5000). Neu und nur Engine-intern: eine Jobfrist (`JobTimeoutMs` der Elementklasse), sie steht nicht in der Nachricht.
- **Antwort auf `cmd.worker.run` mit Fehler** (`not_found`, `peer_gone`, `timeout`, `busy`, `internal`): der Slot wird entfernt, der Worker mit `cmd.process.kill` (Grund `run not accepted: <code>`) beendet, das Element endet mit `exception` "worker not available: worker:n (<code>)".
- **Abbruch:** `cmd.worker.cancel` wie bisher. Kommt binnen 2 s kein `evt.worker.done`, entfernt die Engine den Slot und fordert `cmd.process.kill` an (Grund `cancel not confirmed`).
- **Jobfrist:** Ablauf beendet den Thread mit `exception` "worker timeout" und behandelt den Job wie einen Abbruch.
- **Absturz/Ende** (`evt.process.crashed`/`exited` für einen Slot): Slot entfällt, ein laufender Job endet mit `exception` "worker crashed (worker:n)".

### 4.6 Engine ↔ Storage und Log

| Typ | Nutzlast | Antwort |
|---|---|---|
| `cmd.storage.flows.list` | `{}` | `{ ok, files: [ {path, name, mtime} ] }` |
| `cmd.storage.flow.read` | `{ path }` | `{ ok, text }` (rohes JSON, Engine parst) |
| `cmd.storage.flow.write` | `{ path, text, backup: true }` | `{ ok }` (atomar, Backups wie v1) |
| `cmd.storage.var.get` | `{ scope: "global"/"static", flowId?, name }` | `{ ok, exists, type, content }` |
| `cmd.storage.var.set` | `{ scope, flowId?, name, type, content }` | `{ ok }` (write-behind, Engine wartet nicht darauf) |
| `cmd.storage.var.delete` | `{ scope, flowId?, name }` | `{ ok, existed }` (zweimal löschen ist kein Fehler, `existed` ist dann false) |
| `cmd.storage.var.list` | `{ scope, flowId? }` | `{ ok, names }` (sortiert) |
| `cmd.storage.settings.get/set` | `{ settings? }` | `{ ok, settings }` (Phase 3, noch nicht umgesetzt) |
| `evt.log.append` (`noReply`) | `{ ts, level, source, flowId?, text }` | keine. Storage schreibt `Log.txt`, `Log_<source>.txt` und leitet an Topic `log` weiter. |

**Umsetzung in WI-12 (`src/storage/`):**

- Alle Antworten kommen über die Warteschlange (`WriteQueue`, zwei Warteschlangen, Zeitbudget je Timer-Lauf, siehe WI-25 unten). Die Antwort ist `Deferred` (Abschnitt 2). Jede Anfrage wird genau einmal beantwortet, auch bei Frist, Fehler oder Beenden (`shutting_down`).
- Frist: `timeoutMs` der Anfrage (Standard 30000). Eine Operation, die länger als die Frist wartete, wird nicht ausgeführt und mit `timeout` beantwortet.
- `cmd.storage.flows.list`: `path` ist `Flows/<name>.json` relativ zum Datenverzeichnis, `name` der Dateiname ohne `.json` (das ist die `flowId` der Engine). `mtime` als Ganzzahl (Sekunden seit 1970).
- `cmd.storage.flow.read`: `not_found`, wenn die Datei fehlt.
- `cmd.storage.flow.write`: `text` muss ein JSON-Objekt sein (sonst `bad_payload`). Geschrieben wird atomar (Temp-Datei + `MoveFileEx`), mit CRLF wie v1. `backup` (Standard true): vor dem Ersetzen wird die alte Datei nach `Flows/backup/<name>_backup_<yyyyMMddHHmmss><ms>.json` kopiert, höchstens 10 bleiben. Schlägt das Backup fehl, wird nicht geschrieben (`internal`).
- Pfade werden vor jedem Dateizugriff geprüft (`bad_payload` bei `..`, Backslash, Unterordner, falscher Endung). Namen von Variablen und Flow-IDs dürfen keine Pfadzeichen enthalten.
- `cmd.storage.var.*`: `scope` `global` (Dateien in `Variables/`) oder `static` (in `Variables/<flowId>/`). `type` ist `normal` (Inhalt ist der Wert als Text) oder `object` (Inhalt ist JSON-Text, Storage prüft ihn). `var.get` liefert `exists: false`, wenn die Metadatei fehlt. Inhalt wird unverändert geliefert.
- Fehler: `ok:false` mit `error.code` an den Absender, zusätzlich `evt.storage.error` an Topic `engine` (`op` = Name ohne `cmd.storage.`, z. B. `flow.read`, `flow.write`, `var.set`).
- `evt.log.append`: Ein Eintrag wird als Zeile `CRLF, "--- yyyy MM dd HH:mm:ss ~<absender>~<source>~ <text>"` an `Log/Log.txt` und `Log/Log_<source>.txt` angehängt (Zeitstempel lokal wie v1, `ts` kommt in UTC). Die Datei über 100 KB wird vorher nach `<name>_old.txt` umbenannt. Der Eintrag wird als `evt.log.entry` `{ts, level, source, flowId?, text}` an Topic `log` weitergeleitet (`ts` unverändert UTC). Storage selbst schreibt seine Einträge direkt in die Warteschlange, nicht an sich selbst.

- **Warteschlangen, Durchsatz und Obergrenze des Logs (WI-25, F-08):** `WriteQueue` hat zwei Warteschlangen: Anfragen (`cmd.storage.*`) und Logoperationen. Eine wartende Anfrage läuft immer vor der nächsten Logoperation, die Reihenfolge innerhalb jeder Warteschlange bleibt. Ein Timer-Lauf arbeitet Operationen ab, bis das Zeitbudget (`WriteQueue.BUDGET_MS` = 10 ms, geprüft zwischen zwei Operationen) verbraucht ist oder nichts mehr läuft; eine einzelne große Operation (5-MB-Schreiben) wird nie geteilt. Danach gibt der Lauf die Nachrichtenschleife frei (`sys.ping`, neue Anfragen). Logzeilen werden je Datei gebündelt: höchstens 500 Zeilen oder 64 K Zeichen je Operation, die Datei wird einmal geöffnet (Rotation vorher, wie bisher), alle Zeilen werden in einem Zug geschrieben. Ist die Datei von einem anderen Prozess gehalten (F-04), bleibt das Bündel samt neuer Zeilen vorn in der Logwarteschlange und wird bis 3 s alle 20 ms wiederholt; Anfragen laufen währenddessen. Danach gelten die Zeilen als verloren (gezählt, `log line lost`, höchstens 5 Zeilen je Bündel einzeln aufgeführt). `evt.log.entry` geht wie bisher nach dem Schreiben der letzten Datei (`Log_<source>.txt`) des Eintrags an Topic `log`. **Obergrenze:** höchstens 20000 Einträge oder 8 MiB (Zeichen) warten gleichzeitig. Darüber werden neue Einträge verworfen und gezählt (nie blockieren, kein Fehler an den Absender); sobald höchstens die Hälfte belegt ist (oder beim nächsten angenommenen Eintrag), schreibt der Storage einen Eintrag der Quelle `storage`, Ebene `a0`: `<n> log lines dropped (log queue was full, <gesamt> in total)`. Die Grenzen lassen sich für Tests mit `--log-queue-max-lines=<n>` und `--log-queue-max-chars=<n>` senken. **Aufräumen beim Start:** als erste Logoperation löscht der Storage `*.ahf-<pid>.tmp` in `Flows/` und `Variables/` (rekursiv), deren Prozess nicht mehr läuft (ein nicht zu öffnender Prozess gilt als laufend). Atomares Schreiben ruft vor der Umbenennung `FlushFileBuffers` für die Temp-Datei auf.
- **Log-Schwelle und Ringpuffer (WI-23):** Die Option `--log-level=<0..3>` (Standard 2) gilt für den Supervisor und wird von ihm an jede Rolle weitergegeben. Ein Eintrag mit Ziffer über der Schwelle (`a3`, `f3`, `t3` bei Standard) wird **nicht** an die Senke (`storage`) weitergeleitet. Jeder Prozess hält die letzten 500 Einträge aller Ebenen unabhängig von der Senke im Speicher (`Log.Recent()`, Grundlage des Absturzberichts, WI-28). Ungültiger Wert: Rolle Exit 2, Supervisor Exit 1 (Meldung auf stderr). Später eine Einstellung (Phase 3).
- **Log des Supervisors (WI-23):** Der Supervisor ist keine `Role` und hat keinen Peer, sendet seine Einträge aber wie jede Rolle als `evt.log.append` (Absender `supervisor`) über den Hub an `storage`, solange `storage` verbunden ist (`DiagLog`, `src/supervisor/DiagLog.ahk`). Davor und zwischen zwei `storage`-Läufen (Neustart) warten sie in einer Warteschlange (höchstens `Role.LOG_QUEUE_MAX` = 500, die ältesten fallen heraus und werden gezählt), die beim `sys.hello` von `storage` in Reihenfolge geleert wird. Zusätzlich schreibt der Supervisor weiter auf stderr. Ein Fehler beim Senden loggt nicht erneut (Flag gegen Rekursion). Quellen des Supervisors: `supervisor`, `hub`, `children`, `shutdown`.

### 4.7 Dialoge

Die Engine zeigt nie Dialoge. Muss der Benutzer reagieren, nimmt die Engine einen Worker (Dialog-Element, Modus `worker`) oder sendet an die UI-Rolle:

| Typ | Von → An | Nutzlast | Antwort |
|---|---|---|---|
| `evt.ui.notice` | engine/storage → `manager` | `{ level, text, flowId? }` | – (Tray-Hinweis statt MsgBox) |
| `cmd.ui.confirmDeleteFlowFile` | engine → `manager` | `{ path, reason: "missing_packages", packages }` | `res: { ok, delete: bool }` (v1: MsgBox in `LoadFlow`) |

### 4.8 Manager-Stub (WI-13, `src/manager/`, nur `--ui=stub`)

Der Stub ist ein Minimal-Ersatz für `manager` (ARCHITEKTUR 3). Er zeigt, was die Engine meldet. Er hält nur UI-Zustand und keine Wahrheit über die Ausführung.

- **Abonnements:** `engine`, `process`, `log`, nach dem Snapshot zusätzlich `flow:<flowId>` je Flow.
- **Resync:** `cmd.engine.snapshot` nach `evt.engine.ready`, nach `evt.flow.list.changed`, nach `evt.process.restarted` (name `engine`), bei neuer `epoch`, bei einer Lücke in `seq` und bei einer veralteten Antwort (Antwort mit kleinerem `seq` als bereits gesehen wird wiederholt). Doppelte Ereignisse (`seq` bereits gesehen) werden verworfen.
- **Antwort auf `cmd.app.prepareExit`:** `{ ok: true, cancel: false }`, mit Option `--stub-cancel-exit` `cancel: true` (Abschnitt 2).
- **Ereignisse als Logzeilen:** jedes empfangene `evt.*` (außer Topic `log`) wird als `evt.log.append` an `storage` gesendet, Quelle `manager`, Text `ui-event {json}`. Storage schreibt `Log/Log_manager.txt`. Das Feld `recvMs` ist die Wandzeit (ms, UTC) beim Eingang. Die Zeilen `stub.*` sind eigene Einträge des Stubs (`stub.ready`, `stub.snapshot` mit `reason`, `stub.command`, `stub.commandAnswer`, `stub.prepareExit`, `stub.shutdown`).
- **Testbefehl `cmd.test.command` (nur mit `--headless`):** Nutzlast `{ type, payload }`, `type` aus `cmd.flow.start`, `cmd.flow.stop`, `cmd.flow.toggle`, `cmd.engine.snapshot`. Der Stub leitet die Anfrage an `engine` weiter und antwortet mit `{ ok: true, answer: <Antwort der Engine> }`. Andere Typen: `bad_payload`. Die Antwort kommt verzögert (`Deferred`).
- **Optionen, die der Supervisor an alle Rollen weitergibt:** `--ui=<wort>`, `--headless`, `--stub-cancel-exit`, `--log-level=<0..3>` (WI-23), `--workers=<n>`, `--warm-workers=<n>`, `--worker-idle-ms=<ms>` (WI-27, Pool der Engine, 4.5).
- **`evt.engine.restarted`:** Die Engine sendet es selbst (sie besitzt die `epoch`), sobald sie nach einem Neustart die Flows geladen hat, direkt vor `evt.flow.list.changed` und `evt.engine.ready`. Sie erkennt den Neustart an der Option `--restarted=<n>`, die der Supervisor nur bei einem automatischen Neustart anhängt (`n` = Zahl der Neustarts im Fenster). Beim ersten Start fehlt die Option, dann kommt kein `evt.engine.restarted`. Der Stub löst den Resync zusätzlich über `evt.process.restarted` und neue `epoch` aus.

### 4.9 Diagnose II: Snapshot, Absturzbericht, Debug-Fenster (WI-28)

Kein Flow-Debugger (E1), sondern Diagnose des Systems. Alles hier ist nur lesend, bis auf das Schreiben der Berichte durch `storage`.

**`cmd.diag.snapshot`** (beliebige Rolle → jede Rolle, auch `supervisor`; Frist des Aufrufers, Standard 2 s)

| Anfrage | Antwort |
|---|---|
| `{}` (Das Feld `content` ist für den späteren Flow-Debugger reserviert und wird ignoriert: ein Snapshot enthält **nie** Inhalte von Variablen oder Flows, nur Namen, Ids, Zähler und Zustände.) | `{ ok, snapshot }` |

`snapshot` ist ein Objekt mit `schema: 1` und diesen Feldern. Der allgemeine Teil kommt aus der Basisklasse `Role` (`Role.Snapshot`), der Rollenteil `info` aus dem Haken `Role.DiagInfo()` (Standard: leeres Objekt). Ein Fehler im Haken ergibt `info: { error: "<Text>" }`, nie einen Fehler der Antwort.

| Feld | Inhalt |
|---|---|
| `name`, `role`, `pid` | Rollenname (`editor:Flow 1`), Rolle (`editor`), Prozess-ID |
| `startedAt`, `uptimeMs` | Prozessstart (UTC, `yyyy-MM-dd HH:mm:ss`, aus `GetProcessTimes`) und Laufzeit |
| `version`, `ahkVersion`, `bits` | `AhfVersion.Current` (`src/core/AhfVersion.ahk`), `A_AhkVersion`, 64 |
| `rssBytes`, `handles` | Arbeitsspeicher (`GetProcessMemoryInfo`) und Handle-Zahl (`GetProcessHandleCount`) des eigenen Prozesses |
| `peer` | `{ status, pending, lateReplies, badFrames, droppedSends, queuedFrames, queuedBytes, handlerErrors }` (Zähler von `Peer` und seiner Verbindung, `Peer.Stats()`) |
| `log` | `{ queued, dropped, sinkErrors, lastSinkError, level, recent: [ {ts, level, source, text} ] }`: `Role.LogStats()`, `Log.sinkErrors`, die letzten 100 Einträge des Ringpuffers von `Log` (WI-23, Texte auf 500 Zeichen gekürzt) |
| `errors` | `{ count, recent: [ {ts, errorType, message, file, line, stack, mode} ] }`: die letzten 20 unbehandelten Fehler der Rolle (WI-23) mit Stack |
| `info` | Rollenteil, siehe unten |

Rollenteile (`info`):

| Rolle | Felder |
|---|---|
| `engine` | `epoch`, `seq`, `flows: [ {flowId, name, rev, enabled, executing} ]`, `instances: [ {instanceId, flowId, state, threads: [ {threadId, elementId, state, result} ]} ]`, `workers: { size, warm, slots: [ {name, state, execId} ], spawning, failures }` |
| `storage` | `queue: { requests, log }` (Länge der beiden Warteschlangen), `logQueuedEntries`, `logQueuedChars`, `logLinesLost`, `logLinesDropped` |
| `worker` | `job`: leer, wenn kein Job läuft, sonst `{ execId, class, sinceMs }` |
| `manager` (Stub) | `topics`, `epoch`, `lastSeq`, `flows` (Zahl), `events`, `resyncs` |
| `debug` | `topics`, `processes` (Namen), `snapshots` (Rollen mit Snapshot), `logEntries`, `engineEvents`, `dumps`, `paused` |

Der Supervisor beantwortet die Anfrage selbst (er ist keine `Role` und hat keinen Peer). Statt `peer` und `info` hat sein Snapshot: `hub` (`{ links: [ {name, pid, queuedFrames, queuedBytes, topics} ], droppedAnswers, pending }`), `children` (je Kind `{ name, role, state, pid, exitCode, restarts, startedAt, busy, killReason, output: [letzte 100 Zeilen stdout/stderr] }`, auch für beendete Kinder), `diagErrors` (Ring der `evt.diag.error`, bis 50, vollständig mit Stack), `diagLog` (`{ queued, dropped }`), `processEvents` (die letzten 50 Ereignisse des Topics `process`: `{ts, type, payload}`), `reports` (`{ written, unwritten, autoSuppressed }`). `log` und `errors` gibt es auch dort.

**`cmd.diag.report`** (beliebige Rolle → `supervisor`)

| Anfrage | Antwort |
|---|---|
| `{ reason }` (Text, 1 bis 60 Zeichen; Zeichen außer Buchstaben, Ziffern, `.`, `_`, `-` werden im Verzeichnisnamen zu `-`) | `{ ok, path, dir, roles, missing: [ {name, why} ] }` (Antwort verzögert, `Deferred`) |

Ablauf im Supervisor (`DiagReport`, `src/supervisor/DiagReport.ahk`): Er fragt **jede verbundene Rolle** gleichzeitig mit `cmd.diag.snapshot` (Frist je Rolle `DiagReport.SNAPSHOT_MS` = 2000 ms; es gibt kein Warten ohne Frist). Rollen, die nicht verbunden sind (gestartet, abgestürzt, beendet), und Rollen, die nicht antworten, stehen in `missing` mit dem Grund (`not connected (<state>)`, `no answer within 2000 ms`, `error: <code>`). Wenn alle Antworten oder Fristen da sind, fügt der Supervisor seinen eigenen Snapshot hinzu (mit den Ausgabepuffern auch verstorbener Kinder) und baut zwei Dateien: `report.json` (alle Snapshots, `meta`: Grund, Zeit, automatisch ja/nein, Version, Sitzung) und `summary.txt` (lesbare Zusammenfassung: Prozesstabelle, je Rolle die wichtigsten Zahlen, fehlende Rollen, letzte Fehler). Beides geht an `storage` (`cmd.storage.report.write`). Der Supervisor schreibt nie selbst Dateien.

*Automatische Berichte.* Der Supervisor löst `reason = "<auslöser>-<name>"` selbst aus bei: unerwartetem Ende eines Kindes (`crashed-<name>`), erreichter Neustartgrenze (`restart-limit-<name>`), `hung-<name>`, und wenn eine Rolle `DiagReport.ERROR_BURST` (10) unbehandelte Fehler innerhalb von 60 s meldet (`errors-<name>`). **Ratenbegrenzung:** höchstens ein automatischer Bericht je 60 s (`DiagReport.AUTO_MIN_INTERVAL_MS`); weitere Auslöser in dieser Zeit werden verworfen, gezählt (`reports.autoSuppressed`) und mit `a1` geloggt. Während des Beendens (`Children.shuttingDown`) gibt es keinen automatischen Bericht. Manuelle Berichte (`cmd.diag.report`) sind nicht begrenzt.

*Storage nicht erreichbar.* Ist `storage` nicht verbunden (abgestürzt, im Neustart), wartet der fertige Bericht im Speicher des Supervisors auf den neu gestarteten Storage, höchstens `DiagReport.STORAGE_WAIT_MS` (10 s). Kommt `storage` rechtzeitig (`sys.hello`), wird er geschrieben und der Aufrufer beantwortet. Sonst antwortet der Supervisor dem Aufrufer mit `error.code = "peer_gone"` ("storage not available, the report is kept and written when storage is back"). Der Bericht bleibt dann im Speicher (höchstens `DiagReport.KEEP_UNWRITTEN` = 5, der älteste fällt heraus) und wird beim nächsten Verbinden von `storage` geschrieben, unter dem ursprünglichen Zeitstempel.

**`cmd.storage.report.write`** (`supervisor` → `storage`; andere Absender: `denied`)

| Anfrage | Antwort |
|---|---|
| `{ stamp, reason, files: { "<datei>": "<text>" } }`. `stamp` = `yyyyMMdd-HHmmss` (lokale Zeit des Supervisors), `reason` wie oben, Dateinamen nur `[A-Za-z0-9._-]`, keine Pfade | `{ ok, path, dir, removed, logs: [ ... ] }`: `path` = `Reports/<stamp>_<reason>` relativ zum Datenverzeichnis, `dir` absolut, `removed` = Zahl der wegen der Aufbewahrung gelöschten alten Berichte, `logs` = kopierte Logdateien |

Storage legt `Reports/<stamp>_<reason>/` an (existiert es, wird `-2`, `-3` ... angehängt), schreibt die Dateien atomar, kopiert dazu `Log/Log.txt` und `Log/Log_old.txt`, falls vorhanden (eine nicht lesbare Datei wird übersprungen und nicht in `logs` aufgeführt), und behält danach höchstens 20 Berichtsordner (die ältesten nach Namen fallen weg). Die Operation läuft in der Anfragen-Warteschlange (Frist des Aufrufers, 30 s Standard). Fehler: `bad_payload` (Namen), `denied`, `internal`.

**Topic `debug`, `evt.debug.dump`.** `Debug.Dump(value, title := "")` (`src/core/Debug.ahk`) ersetzt `d()` aus v1. Es wandelt `value` in lesbares JSON (Tiefe höchstens 8, höchstens 200 Einträge je Map oder Array, Zyklen und fremde Objekte als `<Typ>`), kürzt bei 60000 Zeichen und sendet `evt.debug.dump { title, ts, json, truncated }` (`truncated` ist ein Wahrheitswert) an `topic:debug`. `from` setzt der Hub. **Blockiert nie, wirft nie:** ohne laufende Rolle, ohne bereite Verbindung oder bei einem Fehler tut es nichts. Höchstens 100 Aufrufe je Sekunde und Prozess (`Debug.MAX_PER_SECOND`), der Rest wird verworfen und gezählt (`Debug.dropped`). Hat niemand das Topic abonniert, verwirft der Hub das Ereignis.

**Rolle `debug`** (0..1 Prozess, `src/debugview/DebugView.ahk` und `DebugGui.ahk`; Option `--headless`). Eigener Prozess wie der Manager-Stub: nie modal, kein `MsgBox`, keine Dateien. Er abonniert `process`, `log`, `engine`, `debug` und `flow:<id>` (nach `cmd.engine.snapshot`, wie der Stub). Er zeigt: Prozesstabelle (`cmd.process.list` plus Ereignisse), den Snapshot je Rolle (Knopf "Aktualisieren" und Haken "alle 2 s": `cmd.diag.snapshot` an jede bereite Rolle und an `supervisor`, Frist 3 s), das Live-Log mit Filter (Ebene und Quelle), den Ereignisstrom der Engine mit Pause, die `Debug.Dump`-Werte und den Knopf "Bericht exportieren" (`cmd.diag.report {reason: "manual"}`, zeigt den Pfad). Gestartet wird sie mit `--start=debug` oder durch `--command=debug` an eine laufende Instanz (`cmd.app.command`). Schließt der Benutzer das Fenster, beendet sich nur diese Rolle (`sys.bye {clean: true}`, Exit 0); der Supervisor wertet das als normales Ende (`evt.process.exited`, kein `crashed`, kein automatischer Bericht), siehe 4.1a. Sie wird nie automatisch neu gestartet und beim Beenden mit den UIs zuerst beendet (Rang 0, ohne `cmd.app.prepareExit`).

- **Testbefehl `cmd.test.debug` (nur mit `--headless`):** `{ action }` mit `state` (Zähler und Listen des Modells: `processes` Namen, `snapshots` Rollennamen, `logEntries`, `engineEvents`, `dumps` Titel, `paused`, `lastExport`), `refresh` (holt die Snapshots, Antwort nach dem letzten), `export` (löst `cmd.diag.report` aus, Antwort mit dessen Ergebnis), `pause`/`resume`, `filter` (`{level, source}`; Antwort `state`), `snapshot` (`{name}`: der gespeicherte Snapshot-Text, `not_found` ohne), `close` (wie das Schließen des Fensters: nur diese Rolle endet, mit `sys.bye {clean: true}`). Andere: `bad_payload`.
- **Echo-Testbefehl `cmd.test.dump { title, value }`** (Testrolle `echo`): ruft `Debug.Dump(value, title)` auf.

## 5. Verbindungsaufbau, Wiederverbindung, Resync

1. Rolle verbindet sich, sendet `sys.hello` mit `hwnd` ihres Fensters (Weckruf-Ziel, Abschnitt 1). Der Hub antwortet mit `sys.welcome`. Bis dahin sendet die Rolle nichts außer `sys.hello`. Der Peer (`src/core/ipc/Peer.ahk`) öffnet die Pipe ohne Warten (ein Versuch, dann Wiederholung per Timer), weckt bei bekannter Hub-HWND (Option `hubHwnd`) den Hub schon mit dem `sys.hello` und meldet `ready` erst nach `sys.welcome`.
2. Rolle abonniert Topics, ruft `cmd.engine.snapshot` auf (UIs) und beginnt, Ereignisse mit `seq` zu verarbeiten.
3. Bricht die Pipe, baut die Rolle neu auf (Backoff 100 ms, 200, 400, ..., max. 2 s, gesamt 10 s), wiederholt `hello` mit `epoch` des Besitzers, abonniert neu, macht Resync. Gelingt das nicht, beendet sich die Rolle (Orphan-Guard).
4. Eine Lücke in `seq` oder ein neues `epoch` löst Resync aus.
5. Der Hub hält pro Client eine Ausgabewarteschlange mit Obergrenze (Standard 1000 Nachrichten oder 8 MiB). Läuft sie über, gilt der Client als hängend (`peer_gone` für ausstehende Anfragen), der Supervisor wird informiert.

6. **Laden großer Datenmengen (WI-24):** Wer viele große Antworten anfordert (die Engine beim Start: ein `cmd.storage.flow.read` je Flow-Datei), schickt nicht alle Anfragen auf einmal, sondern höchstens K gleichzeitig (Engine: K = 2) und die nächste nach der Verarbeitung einer Antwort. So liegt ein `sys.ping` höchstens hinter K Antworten in der Pipe. Der Hub leitet große Rahmen über die Kopffelder weiter (Abschnitt 2), seine Kosten je Rahmen sind unabhängig von der Größe der Nutzlast (gemessen 1,7 ms für 109.232 Zeichen). Die Kosten des Empfängers bleiben: `Message.Parse` des Rahmens (0,16 s) und `Json.Parse` des Flow-Texts (0,14 s) für die größte v1-Datei.

### 5a Ereignisse vor dem Abonnement (Designfrage, WI-07)

Ereignisse werden nur an Abonnenten verteilt, die zum Zeitpunkt des Sendens abonniert sind. Ein Ereignis, das vor dem `cmd.topic.subscribe` einer Rolle gesendet wurde, geht für diese Rolle verloren. Es gibt keine Persistenz und keine Wiederholung (Abschnitt 1, Lieferung).

Daraus folgt die Regel für Späteinsteiger (z. B. ein Manager, der nach dem Start des Supervisors öffnet):
1. Erst abonnieren (`cmd.topic.subscribe`), dann den Ist-Zustand holen (`cmd.process.list` beim Supervisor, `cmd.engine.snapshot` bei der Engine).
2. Ereignisse, die zwischen beiden Schritten kommen, können doppelt vorkommen (Snapshot und Ereignis). Der Empfänger darf sie nicht als Zustandswechsel doppelt zählen; der Snapshot ist maßgeblich.
3. Ein Ereignis, das nie eintraf, wird nicht nachgeholt. Der Snapshot korrigiert es.

Der Supervisor hält für `process` keine Historie. `cmd.process.list` ist die einzige Quelle für den Zustand vor dem Abonnement. `tests/integration/test_supervisor.py` nutzt die Momentaufnahme (`process_list`) zum Warten auf Bereitschaft und für die Zustandsprüfung nach Absturz. Ein gezielter Test, bei dem ein Späteinsteiger Ereignisse verpasst, fehlt (nicht geprüft).

## 6. Versionierung und Erweiterung

- `sys.hello.protocol` ist die Ganzzahl-Version. Unterschiede in der Hauptversion führen zu `error.code = "denied"` im `sys.welcome` und Beenden der Rolle.
- Unbekannte Felder in Nutzlasten werden ignoriert, unbekannte `type`-Werte mit `unknown_type` beantwortet (Anfragen) oder geloggt und verworfen (Ereignisse).
- Neue Befehle ergänzen diesen Katalog zusammen mit einem Test in `tests/integration/test_protocol_*.py`.
