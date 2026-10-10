# Protokoll AutoHotFlow v2 (IPC)

Status: Entwurf, Protokollversion **1**. Begründung der Technik: [ARCHITEKTUR.md](ARCHITEKTUR.md), Abschnitt 2.2.

---

## 1. Transport

- **Hub:** Der Supervisor betreibt die Pipe `\\.\pipe\ahf.<session>.hub`. Alle anderen Rollen verbinden sich als Client. Es gibt keine direkten Verbindungen zwischen Nicht-Hub-Prozessen.
- **Sitzung (`<session>`):** Standard ist `main` (Option `--session=<id>`, Standard `main`). Abweichung von der ursprünglich geplanten Wahl (Supervisor-PID und Startzeit): Eine zweite Instanz muss den laufenden Hub finden, um ihren Befehl abzugeben (Abschnitt 4.1, `cmd.app.command`). Mit PID und Startzeit kennt sie den Namen nicht. Die Einzelinstanz-Sperre (benannter Mutex `AHF.supervisor.<session>`) und die Pipe nutzen denselben Schlüssel. Mehrere parallele Sitzungen (z. B. Tests) bekommen eigene `--session`-Werte.
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

**Fehlercodes:** `timeout`, `unknown_type`, `bad_payload`, `not_found`, `conflict` (Revision), `busy`, `denied`, `internal`, `peer_gone`, `shutting_down`.

**Pflicht für jeden Empfänger:** jede `cmd.`-Anfrage wird beantwortet (auch mit Fehler). Der Absender erzeugt bei Fristablauf selbst ein lokales `res.` mit `timeout` und verwirft spätere Antworten mit unbekannter `corr`. Ist der Umschlag ungültig, `from`/`id`/`type` aber lesbar, antwortet der Empfänger mit `bad_payload`. Ganz unlesbare Rahmen werden verworfen und gezählt.

**Umsetzung in AHK (WI-05, `src/core/ipc/`):** Wahrheitswerte schreibt der JSON-Baustein als Zahl (`1`/`0`), weil er keinen Bool-Typ hat (Vertrag WI-02). Empfänger prüfen `ok` daher als Wahrheitswert (`1`, `true`), nicht als Text. Die Python-Gegenstellen senden `true`/`false`. Beide Schreibweisen sind gleichwertig.

## 3. Adressen und Topics

| Adresse | Rolle |
|---|---|
| `supervisor` | Supervisor (Hub, antwortet selbst auf `sys.*`, `cmd.app.*`) |
| `engine` | Engine |
| `storage` | Storage |
| `triggerhost` | Triggerhost |
| `manager` | Manager |
| `editor:<flowId>` | Editor des Flows `<flowId>` |
| `worker:<n>` | Worker, `n` vom Supervisor vergeben |

**Topics** (Abonnement per `cmd.topic.subscribe {topic}` an `supervisor`, wird bei Wiederverbindung erneuert):

| Topic | Inhalt | Typische Abonnenten |
|---|---|---|
| `engine` | `evt.engine.*`, `evt.flow.list.changed`, `evt.settings.changed` | alle UIs |
| `flow:<flowId>` | `evt.flow.*`, `evt.element.state`, `evt.connection.state`, `evt.instance.*` für diesen Flow | `editor:<flowId>`, `manager` |
| `log` | `evt.log.entry` | `manager` (Log-Fenster) |
| `process` | `evt.process.*` (Felder siehe 4.1a), `evt.app.exitCancelled` | `manager`, Tests |

## 4. Nachrichtenkatalog

Alle Nutzlasten sind Objekte. `flowId`, `elementId`, `connectionId` sind die Bezeichner aus den Flow-Dateien (z. B. `Flow 1010290492`, `element0000000001`).

### 4.1 Lebenszyklus (`sys.*`)

| Typ | Von → An | Nutzlast | Antwort / Wirkung |
|---|---|---|---|
| `sys.hello` | Rolle → supervisor | `{ name, pid, hwnd, protocol: 1, epoch? }` | `sys.welcome` |
| `sys.welcome` | supervisor → Rolle | `{ session, peers: { name: { hwnd } }, settingsRev }` | Rolle ist `ready` |
| `sys.ping` | supervisor → Rolle | `{ n }` | `sys.pong {n}` innerhalb 1 s |
| `sys.pong` | Rolle → supervisor | `{ n }` | – |
| `sys.shutdown` | supervisor → alle | `{ reason: "user"/"logoff"/"crash", deadlineMs }` | Rolle räumt auf, sendet `sys.bye`, beendet sich |
| `sys.bye` | Rolle → supervisor | `{ clean: bool }` | – |
| `cmd.app.prepareExit` | supervisor → editor/manager | `{}` | `res: { ok, cancel: bool }` (Benutzer kann abbrechen). Frist: 600000 ms (10 Minuten, `Shutdown.PREPARE_LIMIT_MS`). Bei Ablauf synthetische Antwort `{ ok: false, error: { code: "timeout" } }`, die wie „kein Abbruch“ gilt, der Exit geht weiter. Eine spätere echte Antwort wird verworfen (`droppedAnswers`). Die Phase hat keine harte Frist (ARCHITEKTUR 6.3), die Obergrenze verhindert nur, dass eine Anfrage ohne Ende bleibt |
| `cmd.app.exit` | beliebige UI → supervisor | `{ deadlineMs? }` (optional, Integer 100 bis 60000, sonst Standard `--deadline`, 5000) | startet Beenden (6.3), `res: { ok, started: bool }`; `started` ist false, wenn schon ein Beenden läuft |
| `cmd.app.command` | zweite Instanz → supervisor | `{ argv: [...] }` (Array von Strings, Kommandozeilen-Wörter; die Instanz übergibt `--command=<text>` als `argv` mit einem Eintrag) | `res: { ok }`. Phase 2 protokolliert den Text nur (`a1`), es gibt noch keine Befehle außer dem Test. Die zweite Instanz beendet sich mit Exit 0 (zugestellt) oder 1 (keine Antwort, Fehler) |
| `cmd.process.list` | beliebige Rolle → supervisor | `{}` | `res: { ok, processes: [ {name, role, state, pid, restarts} ] }`. Momentaufnahme aller Kinder, Zustände nach ARCHITEKTUR 5.3. Dient als Resync für Späteinsteiger (Abschnitt 5a) |
| `cmd.topic.subscribe` / `cmd.topic.unsubscribe` | Rolle → supervisor | `{ topic }` | `res: { ok }` |
| `evt.app.exitCancelled` | supervisor → Topic `process` | `{ by }` (Rolle, die abgebrochen hat) | – (Beenden abgebrochen, nichts wurde gestoppt) |

**Exit-Codes des Supervisors** (`AutoHotFlow.ahk --role=supervisor`, Standard ohne `--role`):
0 sauber (jedes Kind hat sich selbst beendet), 1 Start fehlgeschlagen (z. B. Mutex, ungültige Optionen), 5 mindestens ein Kind wurde nach Frist oder Hang beendet (`TerminateProcess`). Dieselben Zahlen stehen im Einstieg (`src/AutoHotFlow.ahk`). Die zweite Instanz nutzt 0 und 1 (siehe `cmd.app.command`).

### 4.1a Prozessereignisse (Topic `process`, supervisor → Abonnenten)

Jeder Eintrag trägt `name` (der Name, unter dem das Kind gestartet wurde, z. B. `engine`, `echo:a`) und `pid`, wo der Prozess bekannt ist.

| Typ | Nutzlast | Bedeutung |
|---|---|---|
| `evt.process.started` | `{ name, role, pid }` | Prozess gestartet, noch nicht bereit |
| `evt.process.ready` | `{ name, pid }` | `sys.hello` angekommen, Rolle meldet sich bereit |
| `evt.process.hung` | `{ name, reason }` | kein Pong (3 Pings × 2 s) oder kein `sys.hello` innerhalb 10 s. Der Supervisor sendet `sys.shutdown` mit `deadlineMs` 2000, nach 2 s `TerminateProcess` |
| `evt.process.crashed` | `{ name, pid, reason: "exited"/"hung", exitCode, restart: bool }` | unerwartetes Ende (auch nach Hang). `restart` true, wenn neu gestartet wird |
| `evt.process.exited` | `{ name, pid }` | Ende nach Aufforderung (Beenden) |
| `evt.process.restarted` | `{ name, attempt }` | Neustart nach Richtlinie (automatisch nur für `storage` und `engine`; mit `--test-roles` zusätzlich `crasher`) |

Neustart-Richtlinie: höchstens 3 Neustarts in 60 s, sonst bleibt der Prozess `crashed` (`restart: false`). `manager` und `editor` werden nie automatisch neu gestartet.

### 4.1b Testrollen (nur mit `--test-roles`)

Die Rollen `echo`, `crasher`, `hanger`, `slow_shutdown` (Quellen in `tests/integration/helpers/`) sind im Einstieg einkompiliert, aber nur mit `--test-roles` registriert. Ohne das Flag ist ihr Name unbekannt (Exit 2). Zusätzliche Nachrichten der Testrollen:
- `cmd.test.arm` an `crasher` (`{}`, `res: { ok }`): startet einen Timer (300 ms), nach dem `crasher` sich mit `TerminateProcess` (Exit 7) selbst beendet, ohne `sys.bye`. Der Arm-Schritt erlaubt dem Test, den Prozess zu beobachten, bevor er stirbt (Testszenario für `evt.process.crashed`). Ohne Arm tut `crasher` nichts.
- `cmd.test.echo`, `cmd.test.log`, `cmd.test.logstate`, `cmd.test.setlogtarget`, `cmd.test.throwlater` (`echo`): siehe `tests/integration/helpers/EchoRole.ahk`.
- Option `--prepare-limit=<ms>` (nur mit `--test-roles`, 100 bis 600000): setzt die Frist von `cmd.app.prepareExit` herab, damit der Timeout-Test in Sekunden läuft. Ohne das Flag gilt die Konstante.

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
| `cmd.flow.start` | `{ flowId, triggerId? }` | `{ ok, instanceId }` oder `error.code = "busy"` (Richtlinie `skip`) |
| `cmd.flow.stop` | `{ flowId }` | `{ ok }` (Stopp eingeleitet, Abschluss per `evt.instance.ended`) |
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
| `evt.engine.restarted` | `engine` | `{ epoch }` → Clients führen `cmd.engine.snapshot` aus |
| `evt.flow.list.changed` | `engine` | `{ added: [..], removed: [..], changed: [..] }` |
| `evt.flow.state` | `flow:<id>` | `{ flowId, enabled, executing }` |
| `evt.flow.committed` | `flow:<id>` | `{ flowId, rev, byMeta: bool }` (für Editor nach Manager-Umbenennung) |
| `evt.flow.saved` | `flow:<id>` | `{ flowId, savedRev }` |
| `evt.element.state` | `flow:<id>` | `{ flowId, elementId, state: "idle"/"running"/"finished"/"exception", countRuns, lastRun }` |
| `evt.connection.state` | `flow:<id>` | `{ flowId, connectionId, state }` |
| `evt.instance.started` / `evt.instance.ended` | `flow:<id>` | `{ flowId, instanceId, reason? }` |
| `evt.settings.changed` | `engine` | `{ settings }` |
| `evt.log.entry` | `log` | `{ ts, level, source, flowId?, text }` (Engine/Storage senden Log über 4.5, nicht hier) |
| `evt.storage.error` | `engine` | `{ op, path, message }` |

**Umsetzung in WI-10 (`src/engine/`, Phase 2):**

- Jedes `evt.*` der Engine trägt `epoch` (Startzeit des Engine-Prozesses, UTC mit Millisekunden, als Ganzzahl) und `seq` (ein Zähler pro Engine-Prozess, +1 pro Ereignis).
- `evt.engine.ready` mit `{}` erst nach dem Laden der Flow-Liste. Beim Laden zusätzlich `evt.flow.list.changed` `{added, removed: [], changed: []}`.
- `evt.storage.error` mit `op` = `flows.list` (Liste fehlgeschlagen, wird bis zu 5-mal wiederholt), `flow.read` (Datei nicht lesbar) oder `flow.parse` (Inhalt ungültig). Der Start wird dadurch nicht blockiert.
- `evt.element.state` `{flowId, elementId, state, countRuns, lastRun}`. `lastRun` ist der Zeitstempel des letzten Starts (`yyyy-MM-dd HH:mm:ss`, UTC). `countRuns` ist +1 beim Start und -1 beim Ende (wie v1). `state` ist `running`, solange `countRuns > 0`, sonst `finished`, bei Ergebnis `exception` `exception`. Ein Stopp durch die Engine zählt als Ende (Ergebnis `stopped`, Zustand `finished`). Bei `exception` zusätzlich `message` (Meldung der Ausnahme).
- `evt.instance.ended` `{flowId, instanceId, reason}` mit `reason`: `finished` (letzter Thread regulär beendet), `exception` (letzter Thread ohne passende Verbindung nach einer Ausnahme), `flow.stop`, `toggle`, `policy stop`, `shutdown`.
- `evt.flow.state` `{flowId, enabled, executing}` nach `evt.instance.started` bzw. nach `evt.instance.ended`. Beim Ende kommt `evt.flow.state` also **nach** `evt.instance.ended`.
- Wahrheitswerte (`enabled`, `executing`) gehen als 0 oder 1 auf die Leitung (Abschnitt 2).
- `cmd.flow.start` `{flowId, triggerId?}`: `{instanceId}`. Ohne `triggerId` der erste Trigger des Flows. Ein Trigger wird vom Start simuliert (`running`, dann `finished`, wie v1 `newInstance`). Fehler: `not_found` (Flow nicht geladen), `bad_payload` (kein Trigger, kein Trigger unter dieser ID, ungültige Richtlinie), `busy` (Richtlinie `skip`, oder `wait`, das in WI-10 nicht umgesetzt ist).
- Richtlinie: `flowSettings.ExecutionPolicy` des Flows, `default` wird zu `parallel` aufgelöst (globale Einstellung gibt es in Phase 2 noch nicht). Die Entscheidung trifft `ExecutionPolicy.Decide` (WI-08).
- `cmd.flow.stop` `{flowId}`: `{stopped: n}`, Zahl der gestoppten Instanzen. Die Quittung (`evt.instance.ended`) folgt synchron.
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

**Umsetzung in WI-11 auf Engine-Seite (`src/engine/WorkerBridge.ahk`):**

- Option `--workers=<n>` der Engine (0 bis 8, Standard 0 = kein Pool). Slots heißen `worker:1` bis `worker:n`. Mit 0 endet jedes Worker-Element sofort mit `exception` "worker not available".
- Ein Worker-Element bleibt `running`, bis `evt.worker.done` kommt. Ist alle Pool-Slots belegt, wartet der Thread (Zustand `ready`), bis einer frei ist. Ist kein Slot mehr nutzbar (alle `down`), endet er mit `exception` "worker not available".
- Antwort `cmd.worker.run` mit Fehler `not_found`, `peer_gone`, `timeout` oder `internal`: Slot wird `down`, Element endet mit `exception` "worker not available: worker:n (<code>)".
- Absturz oder Ende eines Workers: Die Engine abonniert das Topic `process` beim Supervisor (`cmd.topic.subscribe`, nur mit `--workers` > 0) und wertet `evt.process.crashed` und `evt.process.exited` für `worker:n` aus. Das laufende Element endet mit `exception` "worker crashed (worker:n)". `evt.process.ready` macht einen `down`-Slot wieder `idle`.
- `cmd.worker.cancel` bei Stopp der Instanz: Der Thread endet sofort (wie inline, Quittung nicht abgewartet). Der Slot bleibt `busy`, bis der Worker `evt.worker.done` schickt, spätestens nach 2 s (dann `down`, Eintrag im Log `a0`).
- Ergebnisse aus `evt.worker.done`: Exporte werden als Thread-Variablen gesetzt. Ein unbekanntes Ergebnis wird `exception`.
- `cmd.worker.run` übergibt `imports` als Kopie der Instanzvariablen (Scope `instance`) und `env` mit `flowId`, `elementId`, `instanceId`, `threadId`. Die Frist der Annahme (`timeoutMs`) ist 5000 ms.

### 4.6 Engine ↔ Storage und Log

| Typ | Nutzlast | Antwort |
|---|---|---|
| `cmd.storage.flows.list` | `{}` | `{ ok, files: [ {path, name, mtime} ] }` |
| `cmd.storage.flow.read` | `{ path }` | `{ ok, text }` (rohes JSON, Engine parst) |
| `cmd.storage.flow.write` | `{ path, text, backup: true }` | `{ ok }` (atomar, Backups wie v1) |
| `cmd.storage.var.get` | `{ scope: "global"/"static", flowId?, name }` | `{ ok, exists, type, content }` |
| `cmd.storage.var.set` | `{ scope, flowId?, name, type, content }` | `{ ok }` (write-behind, Engine wartet nicht darauf) |
| `cmd.storage.var.delete` / `cmd.storage.var.list` | `{ scope, flowId?, name? }` | `{ ok, names? }` |
| `cmd.storage.settings.get/set` | `{ settings? }` | `{ ok, settings }` |
| `evt.log.append` (`noReply`) | `{ ts, level, source, flowId?, text }` | keine. Storage schreibt `Log.txt`, `Log_<source>.txt` und leitet an Topic `log` weiter. |

### 4.7 Dialoge

Die Engine zeigt nie Dialoge. Muss der Benutzer reagieren, nimmt die Engine einen Worker (Dialog-Element, Modus `worker`) oder sendet an die UI-Rolle:

| Typ | Von → An | Nutzlast | Antwort |
|---|---|---|---|
| `evt.ui.notice` | engine/storage → `manager` | `{ level, text, flowId? }` | – (Tray-Hinweis statt MsgBox) |
| `cmd.ui.confirmDeleteFlowFile` | engine → `manager` | `{ path, reason: "missing_packages", packages }` | `res: { ok, delete: bool }` (v1: MsgBox in `LoadFlow`) |

## 5. Verbindungsaufbau, Wiederverbindung, Resync

1. Rolle verbindet sich, sendet `sys.hello` mit `hwnd` ihres Fensters (Weckruf-Ziel, Abschnitt 1). Der Hub antwortet mit `sys.welcome`. Bis dahin sendet die Rolle nichts außer `sys.hello`. Der Peer (`src/core/ipc/Peer.ahk`) öffnet die Pipe ohne Warten (ein Versuch, dann Wiederholung per Timer), weckt bei bekannter Hub-HWND (Option `hubHwnd`) den Hub schon mit dem `sys.hello` und meldet `ready` erst nach `sys.welcome`.
2. Rolle abonniert Topics, ruft `cmd.engine.snapshot` auf (UIs) und beginnt, Ereignisse mit `seq` zu verarbeiten.
3. Bricht die Pipe, baut die Rolle neu auf (Backoff 100 ms, 200, 400, ..., max. 2 s, gesamt 10 s), wiederholt `hello` mit `epoch` des Besitzers, abonniert neu, macht Resync. Gelingt das nicht, beendet sich die Rolle (Orphan-Guard).
4. Eine Lücke in `seq` oder ein neues `epoch` löst Resync aus.
5. Der Hub hält pro Client eine Ausgabewarteschlange mit Obergrenze (Standard 1000 Nachrichten oder 8 MiB). Läuft sie über, gilt der Client als hängend (`peer_gone` für ausstehende Anfragen), der Supervisor wird informiert.

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
