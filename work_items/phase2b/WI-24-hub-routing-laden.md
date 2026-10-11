# WI-24 Hub routet über Kopffelder, Engine lädt gestaffelt, 200-Flow-Test

Größe: M · Hängt ab von: WI-22 (Heartbeat-Regel) · Blockiert: WI-26

## Ziel

Große Nutzlasten (Flow-Dateien, später `cmd.flow.get` für den Editor) dürfen weder den Hub noch die Engine so lange beschäftigen, dass Pings unbeantwortet bleiben. Heute kann eine große Flow-Sammlung den Start verhindern.

## Funde

**Messung [verifiziert]** (Wegwerfskript, größte v1-Datei `Flow 1010290492.json`, 93 KB, Rahmen 109.232 Zeichen, Mittel aus 10 Läufen):

| Was | Kosten |
|---|---|
| Hub: `Message.Parse` + neue `Message` + `Serialize` einer `res.storage.flow.read` | **220 ms** je Rahmen |
| `Message.ReadTo` (liest nur `to`, existiert in `src/core/ipc/Message.ahk`, wird nicht genutzt) | 0,01 ms |
| Engine: `Json.Parse` des Flow-Texts | 99 ms |

**Ablauf heute [gelesen]:**
- `Hub._OnFrame` parst jeden Rahmen vollständig, `Hub._Route` baut eine neue `Message` (um `from` zu setzen) und serialisiert sie neu. Die Kopffelder stehen laut `doc/PROTOKOLL.md` 2 gerade deshalb vorn, damit der Hub das nicht muss.
- `Engine._OnFlowList` schickt **alle** `cmd.storage.flow.read` auf einmal. Die Antworten kommen dicht hintereinander. Ein `sys.ping` steht in der Pipe hinter allen noch nicht verarbeiteten Antworten.

**Folge [vermutet, hochgerechnet]:** Bei einigen MB Flows (z. B. 150 Flows) bleibt der Pong der Engine länger als 6 s aus. Der Supervisor erklärt die Engine für hängend und beendet sie; der Neustart läuft in dieselbe Lage; nach 3 Versuchen bleibt die Engine tot. Der Hub selbst steht dabei je Rahmen 220 ms (WI-22 fängt die Folgen für den Heartbeat ab, nicht die Ursache).

## Aufgaben

1. **Messung vorher** als Test festhalten (`tests/stress/`, Marker `stress`, plus Smoke-Variante): Kosten je Rahmen im Hub für eine große Antwort, Zeit bis `evt.engine.ready` und größte Antwortzeit von `cmd.engine.snapshot` während des Ladens.
2. **Hub routet über Kopffelder:** `Message` bekommt eine Funktion, die die Kopffelder (`to`, `from`, `id`, `type`, `corr`, `timeoutMs`) und die Position der Nutzlast liest, ohne die Nutzlast zu parsen. Sie gilt nur für Rahmen in der kanonischen Reihenfolge von `Message.Serialize`; andere Rahmen (z. B. von Python-Clients, prüfen) laufen über den bisherigen Weg. Der Hub ersetzt `from` im Kopf und hängt die Nutzlast unverändert an. Nachrichten an `supervisor` werden weiter voll geparst.
   - Folge: Der Hub prüft die Nutzlast nicht mehr. Ungültige Nutzlasten weist der Empfänger ab (`Peer._RejectFrame` antwortet mit `bad_payload`). In `doc/PROTOKOLL.md` 2 festhalten.
   - Bestehende Tests zu gefälschtem `from`, ungültigen Rahmen und `bad_payload` müssen grün bleiben (ggf. erwartetes Verhalten bewusst anpassen und begründen).
3. **Engine lädt gestaffelt:** höchstens K Leseanfragen gleichzeitig (Konstante, Vorschlag 2). Zwischen zwei Antworten kommt die Nachrichtenschleife zum Zug, Pings werden beantwortet. Fehler je Datei bleiben wie bisher (`evt.storage.error`).
4. **200-Flow-Test:** 200 Flows im Datenverzeichnis (Kopien der großen v1-Flows unter neuen Namen, zusammen viele MB). Erwartung: Start ohne `hung`/`crashed`, alle Flows geladen, Zeit bis `ready` gemessen, Snapshot-Latenz während des Ladens unter 1 s.
5. **Messung nachher** in `work_items/phase2/measurements.md` (neuer Abschnitt "Phase 2b") oder einer eigenen Datei in diesem Ordner.
6. Ist die Ladezeit der Engine für 200 Flows danach noch störend (Richtwert über 30 s), als Fund für die Frage "nativer JSON-Parser" festhalten. **Keinen** nativen Parser einbauen.

## Akzeptanzkriterien

- Hub-Kosten für einen 93-KB-Rahmen unter 5 ms.
- 200-Flow-Test grün, kein Prozess als hängend gemeldet.
- Gesamtlauf und Stresstests grün.
- Doku: `doc/PROTOKOLL.md` 2 und 5, `doc/ARCHITEKTUR.md` 6.1 (Laden), `doc/HOW-TO.md`.
