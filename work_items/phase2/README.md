# Phase 2: Walking Skeleton, Umsetzungsplan

Ziel: die kleinste lauffähige Version der neuen Architektur, **ohne die alten Elemente**.

Abnahme der Phase (alle Punkte automatisiert in pytest):

1. `Supervisor`, `storage`, `engine` und ein UI-Stub starten, sprechen über den Hub miteinander und fahren sauber herunter (Quittungen, harte Frist).
2. Ein hartcodierter Flow im **v1-Dateiformat** mit drei Elementen (Trigger → Action → Action) läuft in der Engine. Jede Zustandsänderung kommt als Ereignis beim UI-Stub an.
3. Tests simulieren den Absturz und das Einfrieren je eines Prozesses sowie einen Timeout. In keinem Fall hängt etwas, jedes Szenario endet innerhalb einer Frist mit gemeldetem Fehler.
4. Ein kleiner Stresstest (viele parallele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden/trennen) läuft ohne Hänger durch.

Nicht Teil der Phase: echte Elemente, Ausdrucksauswertung, Editor-GUI, Zeichnen, Import/Export, Übersetzungen.

## Pflichtlektüre für jedes Arbeitspaket

1. `AGENTS.md` (Stand und Regeln)
2. `doc/ARCHITEKTUR.md` Abschnitte 1 bis 6
3. `doc/KONVENTIONEN.md`
4. Die Datei des eigenen Arbeitspakets sowie die darin genannten Dokumente

## Gemeinsame Definition of Done

- Code erfüllt `doc/KONVENTIONEN.md` (insbesondere die Tabelle der verbotenen Muster).
- Mindestens die im Paket genannten Tests existieren und laufen grün (`pytest <pfad> -q`).
- Öffentliche Schnittstellen sind in der Paketdatei beschrieben, Abweichungen wurden dort nachgetragen und im Commit begründet.
- Neue oder geänderte Nachrichtentypen stehen in `doc/PROTOKOLL.md`.
- Keine Änderung an `v1/`. Keine Dateien außerhalb der im Paket genannten Pfade, außer nach Absprache (Eintrag unter „Offene Punkte“ in der Paketdatei).
- Kleine Commits, eine Änderung pro Commit, Nachricht beschreibt das Warum.
- Nicht ausführbare oder ungetestete Teile werden in der Paketdatei unter „Ergebnis“ benannt.

## Arbeitspakete

| ID | Titel | Größe | Hängt ab von | Besitzt Pfade |
|---|---|---|---|---|
| [WI-01](WI-01-test-infrastruktur.md) | Test- und Laufinfrastruktur | M | – | `tests/conftest.py`, `tests/support/`, `tests/ahk/lib/`, `tests/requirements.txt` |
| [WI-02](WI-02-json.md) | JSON-Baustein | M | – | `src/core/Json.ahk`, `tests/ahk/json.test.ahk`, `tests/test_json.py` |
| [WI-03](WI-03-core-basics.md) | Ids, Fehler, Argumente, Log-Client | S | – | `src/core/Ids.ahk`, `Errors.ahk`, `Args.ahk`, `Log.ahk`, `tests/ahk/core_*.test.ahk` |
| [WI-04](WI-04-ipc-pipe.md) | Pipe, Rahmen, Weckruf | L | WI-01, WI-03 | `src/core/ipc/Pipe*.ahk`, `Frame.ahk`, `Wake.ahk`, `tests/integration/test_pipe.py` |
| [WI-05](WI-05-ipc-peer.md) | Nachrichtenschicht (Peer, Dispatcher) | M | WI-02, WI-03, WI-04 | `src/core/ipc/Message.ahk`, `Dispatcher.ahk`, `Peer.ahk`, `tests/integration/test_peer.py` |
| [WI-06](WI-06-role-basis.md) | Einstieg und Rollenbasis | S | WI-05 | `src/AutoHotFlow.ahk`, `src/core/Role.ahk`, `tests/integration/test_role.py` |
| [WI-07](WI-07-supervisor.md) | Supervisor (Hub, Prozessüberwachung, Beenden) | L | WI-06 | `src/supervisor/`, `tests/integration/test_supervisor.py` |
| [WI-08](WI-08-engine-core.md) | Engine-Kern (Zustandsautomaten, Flowmodell) | M | WI-02, WI-03 | `src/engine/core/`, `tests/ahk/engine_*.test.ahk` |
| [WI-09](WI-09-element-basis.md) | Element-Basis und Demo-Elemente | M | WI-03 | `src/elements/base/`, `src/elements/skeleton/`, `tests/ahk/element_*.test.ahk` |
| [WI-10](WI-10-engine-role.md) | Engine-Rolle | L | WI-06, WI-08, WI-09 | `src/engine/*.ahk` (außer `core/`), `tests/integration/test_engine.py` |
| [WI-11](WI-11-worker.md) | Worker-Rolle | M | WI-06, WI-09 | `src/worker/`, `tests/integration/test_worker.py` |
| [WI-12](WI-12-storage.md) | Storage-Rolle (Skeleton) | M | WI-06 | `src/storage/`, `tests/integration/test_storage.py` |
| [WI-13](WI-13-ui-stub.md) | UI-Stub | M | WI-06 | `src/manager/Stub*.ahk` |
| [WI-14](WI-14-triggerhost.md) | Triggerhost (Skeleton, optional) | S | WI-06, WI-09 | `src/triggerhost/` |
| [WI-15](WI-15-fault-injection.md) | Fault-Injection-Tests | M | WI-07, WI-10, WI-11, WI-12, WI-13 | `tests/fault/` |
| [WI-16](WI-16-stress.md) | Stresstest und Messung | M | WI-15 | `tests/stress/`, `work_items/phase2/measurements.md` |
| [WI-17](WI-17-abschluss.md) | Abschluss, Status, Überprüfung | S | alle | `doc/`, `AGENTS.md`, `work_items/STATUS.md` |

## Wellen

```
Welle A (parallel):  WI-01  WI-02  WI-03
Welle B (parallel):  WI-04  WI-08  WI-09
Welle C:             WI-05
Welle D:             WI-06
Welle E (parallel):  WI-07  WI-10  WI-11  WI-12  WI-13  WI-14
Welle F:             WI-15  →  WI-16
Welle G:             WI-17
```

## Gemeinsame Verträge (damit Pakete parallel arbeiten können)

Die Namen und Signaturen sind verbindlich. Wer sie ändern muss, trägt es hier nach und benennt es im Commit.

```ahk
; core/Json.ahk
Json.Parse(text) -> Map | Array | String | Integer | Float   ; Objekt = Map (CaseSense Off), true/false = 1/0, null = Json.Null
Json.Stringify(value, indent := 0) -> String          ; Map-Schlüssel sortiert, String/Integer/Float bleiben unterscheidbar
Json.Null                                              ; Singleton für JSON null

; core/Ids.ahk
Ids.Configure(processName)       ; einmal beim Start
Ids.Next(prefix := "") -> String ; "<processName>#<n>", n zählt pro Prozess aufwärts

; core/Errors.ahk
class AhfError extends Error { code }                  ; Basis
class ProtocolError extends AhfError
class TimeoutError  extends AhfError
class ElementError  extends AhfError

; core/Log.ahk
Log.Configure(sink)              ; sink(level, source, text, flowId) wird aufgerufen
Log.Write(level, source, text, flowId := "")

; core/ipc/Pipe*.ahk  (WI-04)
class PipeListener  { __New(pipeName) ; Accept() -> PipeConnection | "" ; Close() }
class PipeConnection {
    static Connect(pipeName, timeoutMs := 3000) -> PipeConnection
    SendFrame(text) -> bool            ; nie blockierend. false = Warteschlange voll / Peer weg
    Pump() -> void                     ; liest vorhandene Rahmen, ruft OnFrame/OnClose
    OnFrame := (conn, text) => ...
    OnClose := (conn, reason) => ...
    PeerHwnd := 0                      ; für Wake
    Close()
}

; core/ipc/Peer.ahk  (WI-05)
class Peer {
    __New(name, hubPipeName, options := {})
    Connect() ; Close()
    Send(to, type, payload := Map()) -> id                        ; Ereignis oder noReply
    Request(to, type, payload, callback, timeoutMs := 5000) -> id ; callback(responseMessage)
    On(typePrefix, handler)           ; handler(msg) -> Map (Antwort-Payload) | unset
    Subscribe(topic)
    OnClosed := () => ...
}

; core/Role.ahk  (WI-06)
class Role {
    __New(args)                       ; args: Map aus Args.Parse
    Start()                           ; Peer verbinden, hello, Registrierung der Standardhandler
    OnReady() / OnShutdown(deadlineMs) / OnPeerLost()    ; überschreiben
}
```

Rollenaufruf: `AutoHotkey64.exe src\AutoHotFlow.ahk --role=<name> --session=<id> --hub=<pipeName> --data=<dir> [--headless]`.
Der Supervisor startet sich ohne `--role` oder mit `--role=supervisor`.

## Testflow der Phase

`tests/data/skeleton_flow.json` im v1-Format (`Trigger_Manual` → `Action_Sleep` (200 ms) → `Action_Do_nothing`). Wird in WI-10 angelegt. Variante mit Fehler (`Action_TestThrow`) und mit Worker-Blockade (`Action_TestWorkerBlock`) gehören zu WI-09 und WI-15.

## Fortschritt (Agenten haken ab, wenn ein Paket seine Akzeptanzkriterien erfüllt)

- [ ] WI-01  - [ ] WI-02  - [ ] WI-03  - [ ] WI-04  - [ ] WI-05  - [ ] WI-06
- [ ] WI-07  - [ ] WI-08  - [ ] WI-09  - [ ] WI-10  - [ ] WI-11  - [ ] WI-12
- [ ] WI-13  - [ ] WI-14 (optional)  - [ ] WI-15  - [ ] WI-16  - [ ] WI-17

## Funde

Probleme, die ein Paket im Zusammenspiel entdeckt, aber nicht allein lösen kann, kommen nach `work_items/phase2/findings.md` (Szenario, Reproduktion, Logs, betroffenes Paket).

## Offene Punkte

- Reihenfolge und Zuschnitt der Pakete sind ein Vorschlag. Wer beim Arbeiten merkt, dass zwei Pakete eine gemeinsame Abhängigkeit unterschätzen, ergänzt sie in der Tabelle.
