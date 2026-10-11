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

## Ergebnis

Stand: 2026-10-11. Commits: `0126ecc` (Punkt 2), `87fd20f` (Punkt 3), `c052813` (Punkte 1 und 4), HOW-TO-Commit, `b76288d` (Punkt 5), dieser Commit. Alle Punkte 1 bis 6 abgeschlossen.

### Erledigt

1. **Messung vorher** als Test: `tests/stress/test_big_flows.py` (Hub-Kosten über `tests/ahk/helpers/hub_frame_cost.ahk`, Start mit N großen Flows). Beide waren vor dem Umbau rot (Hub 216 ms; 200 Flows: nur 79 geladen, 122 Leseanfragen nach 30 s abgelaufen, `evt.engine.ready` mit unvollständiger Liste). Smoke im Standardlauf (Hub 10 Läufe, 20 Flows), voll mit `-m stress` (100 Läufe, 200 Flows, 12 MB). Die acht größten v1-Flows liegen als Kopie in `tests/data/bigflows/` (0,4 MB), `v1/` unverändert.
2. **Hub routet über Kopffelder:** `Message.ParseHead` und `Message.WithFrom` (`src/core/ipc/Message.ahk`), `Hub._RouteHead`. Nur Rahmen in der kanonischen Form (siehe `doc/PROTOKOLL.md` 2), nach der Nutzlast darf nur das schließende `}` stehen (Schutz gegen ein zweites `from` hinter der Nutzlast). Alles andere und alles an `supervisor` läuft über den vollständigen Weg. Python-Clients (`tests/support/ahfclient.py`) schreiben die kanonische Form und nehmen den schnellen Weg. Neue Tests: 9 Fälle in `tests/ahk/message.test.ahk`, `test_frames_outside_the_canonical_form_are_routed_with_the_real_sender`. Bestehende Tests zu gefälschtem `from` und `bad_payload` unverändert grün (kein erwartetes Verhalten angepasst).
3. **Engine lädt gestaffelt:** `Engine.LOAD_PARALLEL = 2`, die nächste Anfrage geht nach der Verarbeitung einer Antwort. Zusätzlich (nicht im Auftrag, nötig): Nach der ersten Antwort `timeout`, `peer_gone` oder `shutting_down` werden die übrigen Dateien ohne Anfrage als Fehler gemeldet, sonst würde ein totes `storage` je Datei eine volle Frist (30 s) nacheinander kosten (200 Dateien, 50 Minuten). Tests: `test_engine_reads_at_most_two_flow_files_at_a_time_while_loading`, `test_engine_does_not_ask_for_more_files_when_storage_has_stopped_answering` (beide vor dem Fix rot).
4. **200-Flow-Test:** `test_many_big_flows_load_without_hung_and_with_a_responsive_engine[200]` grün: 201 Flows geladen (200 plus `skeleton`), kein `hung`/`crashed`/`restarted`, keine Lesefehler, Snapshot während des Ladens höchstens 506 ms.
5. **Messung nachher:** `work_items/phase2/measurements.md`, Abschnitt "Phase 2b".
6. **Ladezeit über 30 s:** 45,3 s für 200 Flows (12 MB), also über dem Richtwert. Fund F-23 unten. Kein nativer Parser eingebaut.

### Messwerte (vorher / nachher)

| Größe | Vorher | Nachher |
|---|---|---|
| Hub je 109.232-Zeichen-Rahmen | 216 ms | 1,84 ms (Ziel unter 5 ms) |
| Start bis ready, 20 Flows | 4,46 s | 4,51 s |
| Start bis ready, 200 Flows | 31,25 s (unvollständig, 79 geladen) | 45,3 s (vollständig) |
| Snapshot während des Ladens, 200 Flows, Maximum | 2514 ms | 506 ms |
| Snapshot während des Ladens, 20 Flows, Maximum | 658 ms | 260 ms |

Die längere Ladezeit nachher ist die Folge davon, dass jetzt wirklich alle 200 Flows gelesen werden (vorher wurden 122 nach 30 s verworfen).

### Läufe

- Seriell `python -m pytest tests -q -n 0`: 564 passed, 1 skipped, 13 deselected in 431 s.
- `-m stress`: 12 passed in 450 s.
- Parallel `python -m pytest tests -q` (xdist, `-n auto`): 564 passed, 1 skipped in 64 s. Kein Fehlschlag, nur ein Lauf.
- `tools/arch_check.py`: 0 Verstöße.
- Nach den Läufen keine Testprozesse übrig (nur angesehen, Filter auf `--session=t<12 Hex>`).

### Frage aus WI-23: kann der Hub bei sys.hello hängen?

Ursache des 15-s-Ausbleibens von `sys.hello` **nicht gefunden**; im parallelen Lauf dieses Pakets trat es nicht auf (ein Lauf). Gelesen wurden `Hub.Pump`, `PipeConnection.Pump`, `PipeListener.Accept`, `Wake`.

- **Ausgeschlossen [gelesen]:** unbegrenzte Schleife und unbegrenzte Warteschlange im Hub. Alle Schleifen sind begrenzt: 64 Accepts je `Pump`, je Verbindung höchstens 64 Lesevorgänge à 64 KiB (danach `SetTimer -1`), Ausgabewarteschlange je Verbindung 1000 Rahmen oder 8 MiB (dann wird die Verbindung geschlossen), `Hub.Tick` schließt Verbindungen ohne Hello nach 5 s. `Hub.Request` und `Publish` blockieren nicht.
- **Möglich, nicht ausgeschlossen [gelesen, nicht gemessen]:**
  - (a) Eine einzelne `Hub.Pump` ist ein langer Aufruf: bis zu 4 MiB je Verbindung. Mit 220 ms je großem Rahmen vor WI-24 konnte das Sekunden dauern; in dieser Zeit wird kein neuer Client angenommen. Für weitergeleitete Rahmen ist das mit WI-24 erledigt. Die Tests nutzen beim Hello keine großen Rahmen, (a) erklärt die zwei Fehlläufe also nicht.
  - (b) `PipeConnection._Teardown` wartet bis 2 s je offener Lese- und Schreiboperation auf `CancelIoEx` (`WaitForSingleObject`), `PipeListener._DropInstance` 1 s. Schließen viele Verbindungen gleichzeitig und eine Operation wird nicht abgeschlossen, steht der Hub entsprechend lange. Blockierender Aufruf im Nachrichtenpfad, [vermutet] als Kandidat, nicht nachgewiesen.
  - (c) `Wake.MaxThreads = 1`: ein Weckruf während einer laufenden `Pump` kann verloren gehen, der Fallback-Timer (250 ms) holt ihn nach. Verzögerung höchstens 250 ms plus die Dauer der laufenden Pump, kein Hänger.
- Empfehlung: Beim nächsten Auftreten das Supervisor-Log (`AHF_TEST_KEEP=1`) auf "connection closed: no sys.hello" und auf Wartezeiten beim Schließen prüfen; trifft (b) zu, die Wartezeiten in `_Teardown` kürzen.

### F-16 (Fristen nach der Wanduhr)

Nicht bearbeitet: `Hub.Request`-Fristen (`SetTimer`) und das Hello-Limit laufen weiter nach der Wanduhr; WI-24 ändert daran nichts. Bleibt offen (WI-22).

### Nicht geprüft

- `ParseHead` bei sehr tief verschachtelten Nutzlasten (PCRE-Rekursionsgrenze); bei Fehlern greift der volle Weg (`try`), ein Test dafür fehlt.
- Ein kanonischer Kopf mit kaputtem JSON in der Nutzlast an einen echten AHK-Empfänger über den echten Hub: das Verhalten (Empfänger verwirft, `badFrames`, keine Antwort) ist gelesen (`Peer._RejectFrame`), getestet ist nur der Hubteil (`ParseHead` prüft den Inhalt nicht).
- Andere Rechner und andere Flow-Sammlungen als die 200 Kopien der acht größten v1-Flows.
- Der Test "Start bis ready" mit einem Flow zeigte im Stresslauf 0,56 s Median gegenüber 0,30 s in WI-16; Ursache nicht untersucht (Rechnerlast oder Einfluss von WI-22/23), Budget 3 s gehalten.

### Abweichungen vom Plan

- Abbruch des Ladens nach einem Transportfehler (Punkt 3) ist zusätzlich.
- Der Hub prüft den Nutzlast-Inhalt kanonischer Rahmen nicht mehr (so geplant), dokumentiert in `doc/PROTOKOLL.md` 2 und 5. Ein Rahmen mit doppeltem Schlüssel hinter der Nutzlast wird nicht zugestellt (vorher ebenfalls verworfen).
- Änderungen in `src/core/`: nur `ipc/Message.ahk` (vom Paket genannt).

### Neue Funde

- **F-23: Die Engine zahlt für jede Flow-Datei doppelt.** `Message.Parse` des Rahmens (Flow als escapte Zeichenkette) 161 ms plus `Json.Parse` des Flow-Texts 143 ms für 93 KB; im Storage `Json.Stringify` 54 ms. Das ist der Hauptanteil der 45 s für 200 Flows (rund 0,23 s je Flow im Mittel). Für Punkt 6 / die Frage "nativer JSON-Parser" und Alternativen (Flow als Objekt statt als Text senden, Chunking) festgehalten, nicht umgesetzt. Nach WI-24 ist der Start langsam, aber Pings und Snapshots werden beantwortet (unter 0,6 s).
- **F-24: `flows.list` wird beim Start einmal mit `not_found: no peer 'storage'` beantwortet** (die Engine meldet sich vor `storage`), die Engine wiederholt nach 500 ms und meldet dabei ein `evt.storage.error`. Kein Datenverlust; der Test filtert diesen Fall. Vermutlich unnötiges Fehlerereignis beim normalen Start.
- Drei HOW-TO-Einträge: Kopffelder per RegEx lesen (verifiziert, tiefe Verschachtelung nicht geprüft), JSON-Zeichenketten mit vielen Escapes (verifiziert), Variable `hub` verdeckt Klasse `Hub` (verifiziert).

### Offene Punkte

- F-16, F-23 und F-24 in `STATUS.md` übertragen (WI-29).
- Ursache des 15-s-Hello-Ausbleibens unbekannt, Kandidat (b) prüfen.
- WI-26 (Booleans auf der Leitung) kann auf `ParseHead` aufbauen: der Hub schaut nicht in die Nutzlast.
