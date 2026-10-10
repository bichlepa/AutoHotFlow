# Protokoll AutoHotFlow v2 (IPC)

Status: Entwurf, Protokollversion **1**. Begründung der Technik: [ARCHITEKTUR.md](ARCHITEKTUR.md), Abschnitt 2.2.

---

## 1. Transport

- **Hub:** Der Supervisor betreibt die Pipe `\\.\pipe\ahf.<session>.hub` (`<session>` = Supervisor-PID und Startzeit, hex). Alle anderen Rollen verbinden sich als Client. Es gibt keine direkten Verbindungen zwischen Nicht-Hub-Prozessen.
- **Pipe:** Byte-Modus, duplex, `FILE_FLAG_OVERLAPPED`, `PIPE_REJECT_REMOTE_CLIENTS`, eine Serverinstanz pro Client (der Hub legt nach jedem `Connect` eine neue Instanz an).
- **Rahmen:** `uint32` Länge (little endian) + UTF-8-JSON. Maximale Größe 16 MiB. Größere Nutzdaten (z. B. große Flows) werden über `storage`-Dateien oder Chunking geteilt (`seq/total` in der Nutzlast), nicht über einen größeren Rahmen.
- **Weckruf:** Nach jedem Schreiben sendet der Sender `PostMessage(peerHwnd, 0x8001, 0, 0)` (`WM_AHF_WAKE`). Der Empfänger liest bei Weckruf und zusätzlich per Fallback-Timer (250 ms).
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

**Pflicht für jeden Empfänger:** jede `cmd.`-Anfrage wird beantwortet (auch mit Fehler). Der Absender erzeugt bei Fristablauf selbst ein lokales `res.` mit `timeout` und verwirft spätere Antworten mit unbekannter `corr`.

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
| `process` | `evt.process.*` | `manager`, Tests |

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
| `cmd.app.prepareExit` | supervisor → editor/manager | `{}` | `res: { ok, cancel: bool }` (Benutzer kann abbrechen, Frist = unbegrenzt bis Antwort) |
| `cmd.app.exit` | beliebige UI → supervisor | `{}` | startet Beenden (6.3) |
| `cmd.app.command` | zweite Instanz → supervisor | `{ argv: [...] }` | v1-Kommandozeile (`AHFCommand`), `res: { ok }` |
| `cmd.topic.subscribe` / `cmd.topic.unsubscribe` | Rolle → supervisor | `{ topic }` | `res: { ok }` |

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

1. Rolle verbindet sich, sendet `sys.hello`. Der Hub antwortet mit `sys.welcome`. Bis dahin sendet die Rolle nichts.
2. Rolle abonniert Topics, ruft `cmd.engine.snapshot` auf (UIs) und beginnt, Ereignisse mit `seq` zu verarbeiten.
3. Bricht die Pipe, baut die Rolle neu auf (Backoff 100 ms, 200, 400, ..., max. 2 s, gesamt 10 s), wiederholt `hello` mit `epoch` des Besitzers, abonniert neu, macht Resync. Gelingt das nicht, beendet sich die Rolle (Orphan-Guard).
4. Eine Lücke in `seq` oder ein neues `epoch` löst Resync aus.
5. Der Hub hält pro Client eine Ausgabewarteschlange mit Obergrenze (Standard 1000 Nachrichten oder 8 MiB). Läuft sie über, gilt der Client als hängend (`peer_gone` für ausstehende Anfragen), der Supervisor wird informiert.

## 6. Versionierung und Erweiterung

- `sys.hello.protocol` ist die Ganzzahl-Version. Unterschiede in der Hauptversion führen zu `error.code = "denied"` im `sys.welcome` und Beenden der Rolle.
- Unbekannte Felder in Nutzlasten werden ignoriert, unbekannte `type`-Werte mit `unknown_type` beantwortet (Anfragen) oder geloggt und verworfen (Ereignisse).
- Neue Befehle ergänzen diesen Katalog zusammen mit einem Test in `tests/integration/test_protocol_*.py`.
