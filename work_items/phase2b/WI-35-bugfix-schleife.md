# WI-35 Bugfix-Schleife bis zur grünen Abnahme

Größe: L (Schleife) · Hängt ab von: WI-34 · Blockiert: Abschluss des Fix-Blocks, Phase-3-Plan
Geschrieben von: Orchestrator (Claude), 2026-10-12, auf Wunsch des Projektinhabers.

## Ziel

Der Fix-Block ist erst abgeschlossen, wenn die Abnahme grün ist: **10 von 10 parallele Gesamtläufe grün, 1 serieller Gesamtlauf grün, `AHF_FAULT_REPEAT=20` für `tests/fault` grün, `-m stress` grün.** Das Paket beendet nicht bei der ersten Behebung. Es läuft als **Schleife**, bis die Abnahme grün ist. Neue Fehler, die dabei auftauchen, werden im selben Paket analysiert und behoben.

Bekannter Ausgangsstand (`work_items/STATUS.md`, Abschnitt "Abnahmelauf WI-34 (2026-10-12, zweiter)"):
- **F-45** `test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out`: parallel 1 von 10, `refreshed` 2 statt 3.
- **F-46** `test_process_crash.py::test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted`: seriell 1 von 1, Fault 20x 5 von 20. Das Element meldet `worker not available (peer_gone)` statt `worker crashed`.
- **F-47** `test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms`: seriell 1 von 1, `cmd.worker.cancel` bleibt 5 s unbeantwortet.

**Verdacht zu F-46:** Der Hub antwortet seit WI-34 (F-40, Commits `04192f9`, `27d49cb`) bei Verlust des Ziels sofort mit `peer_gone`. Das kommt vor `evt.process.crashed`. Ein Element, das auf einen Worker wartet, der stirbt, bekommt dann `peer_gone` statt `worker crashed`. Das ist ein **Produktfehler, den F-40 eingeführt haben kann**, kein Testfehler. Nicht belegt. Die Analyse muss das zuerst klären (Abschnitt "Analyse").

## Grundregeln der Schleife (verbindlich)

1. **Kein Fix ohne roten Test.** Jeder Fehler wird zuerst in einem Test rot gezeigt, dann behoben. Ist ein Fehler nicht reproduzierbar, wird er mit Häufigkeit und Log dokumentiert und zählt als "nicht reproduziert", nicht als behoben.
2. **Keine Abkürzungen am Test.** Keine Frist wird gelockert, um einen Fehler zu verdecken. Keine Wiederholung roter Tests über ein Plugin (kein `rerunfailures`). Jede Friständerung wird im Commit begründet und ist nur zulässig, wenn die Frist den Produktwert nicht verletzt (Maßstab: `doc/ARCHITEKTUR.md` Abschnitt 9, Leistungsbudgets, und `scaled()` nur für Obergrenzen, die kein Versprechen sind).
3. **Produktfehler vor Testfehler.** Bevor ein roter Test als Testfehler eingeordnet wird, muss die Ursache im Log oder im Code belegt sein.
4. **Schleifenabbruch:** Die Schleife endet, wenn die Abnahme grün ist (Erfolg). Sie endet mit Bericht an den Projektinhaber, wenn **fünf Fehlerzyklen** nacheinander neue Funde zeigen oder ein Fund eine Architekturentscheidung braucht (dann "ESKALATION").
5. **Lauf-Disziplin:** Jeder Gesamtlauf allein auf dem Rechner, im Hintergrund, Ausgabe in Dateien im Scratchpad. Nach jedem Lauf prüfen, dass keine Testprozesse übrig sind (nur ansehen). Fremde Prozesse des Projektinhabers (AutoHotkeyU32.exe mit "Allgemeine Hilfe.ahk", AutoHotkey64.exe mit AutoHotFlow.ahk ohne Argumente, python.exe der VS-Code-Erweiterung) nicht anfassen.
6. **Testlauf-Regel des Projektinhabers:** Die Umsetzung führt nur die für die Änderung relevanten Tests aus. Die Gesamtläufe fährt die Abnahme, und zwar nur in den Abnahme-Schritten dieser Schleife.

## Rollen in der Schleife

Der Orchestrator führt die Schleife aus und wählt je Schritt das Modell:

| Schritt | Modell | Aufgabe |
|---|---|---|
| Testdurchführung (Abnahme-Läufe, gezielte Wiederholungen, Prozesskontrolle) | **Haiku** | Läufe fahren, Ausgaben sichern, Rot-Liste mit Häufigkeit und Meldung erstellen. Keine Änderungen. |
| Bug-Analyse und Lösungsvorschlag | **Opus** | Ursache belegen (Log, Code lesen), Lösungsvorschlag mit Testplan schreiben. Keine Änderung am Code. |
| Umsetzung (roter Test, Fix, grüner Test, Doku) | **Sonnet** | Den Vorschlag aus der Analyse umsetzen, Test rot zuerst, dann Fix, Commits, Ergebnis in dieser Datei. |

## Schleife

### Schritt 0: Ausgangsstand festhalten (Haiku)
Die Ausgangsfunde F-45, F-46, F-47 mit den Befehlen aus dieser Datei gezielt reproduzieren:
- `AHF_FAULT_REPEAT=20 python -m pytest tests/fault/test_process_crash.py -k killed_worker -n 0 -q` (F-46)
- `python -m pytest tests/integration/test_worker.py -k cancel_of_the_hang -n 0 -q` (F-47)
- `python -m pytest tests/fault/test_debug_role.py -k refresh_shows -n 0 -q` (F-45, mehrmals, z. B. `AHF_FAULT_REPEAT=10`)

Ergebnis: Tabelle mit Häufigkeit, Meldung, Logpfad. In `STATUS.md` unter "Schleife WI-35, Zyklus 0" eintragen.

### Schritt 1: Analyse je offenem Fund (Opus)
Pro offenem Fund (Reihenfolge: F-46, F-47, F-45, dann neue Funde):
1. Ursache belegen: Log (`Log/Log.txt` im Testdatenordner, mit `AHF_TEST_KEEP=1`), Code lesen (`src/supervisor/Hub.ahk`, `src/core/ipc/Peer.ahk`, `src/engine/WorkerBridge.ahk`, `src/worker/`, `src/debugview/DebugView.ahk`).
2. Für F-46 zuerst prüfen, ob die `peer_gone`-Antwort aus F-40 die Ursache ist. Dazu eine Gegenprobe: Der Test muss zeigen, ob `evt.process.crashed` vor oder nach `peer_gone` kommt, und ob das Element dann `worker crashed` bekommen müsste. Die Lösung darf F-40 nicht zurücknehmen (F-40 hat einen eigenen Test, der bestehen bleibt). Die richtige Antwort ist vermutlich: Der Hub gibt `peer_gone` mit einem Grund an, und die Engine, die den Worker-Fall kennt, mappt auf `worker crashed`, oder der Absturz wird über das Prozessereignis vor `peer_gone` abgewartet. Entscheiden und begründen.
3. Lösungsvorschlag mit Testplan schreiben: welcher Test zuerst rot wird, welche Datei sich ändert, welche Frist (falls) betroffen ist.
4. Vorschlag in dieser Datei unter "Analyse Zyklus N" festhalten.

### Schritt 2: Umsetzung (Sonnet)
Nach dem Vorschlag:
1. Test schreiben, der den Fehler zeigt (rot). Lauf belegen.
2. Fix umsetzen, Test grün.
3. Relevante Nachbartests laufen lassen (Liste im Vorschlag).
4. Doku nach Regel 5 (PROTOKOLL, ARCHITEKTUR) im selben Commit.
5. Commit mit Präfix `WI-35: `, Body mit dem Warum.

### Schritt 3: Testdurchführung (Haiku)
Gezielte Wiederholung des betroffenen Tests (F-46: `AHF_FAULT_REPEAT=20`, F-47 und F-45 je 10-mal), dann die Abnahme-Läufe (siehe unten). Ergebnis in `STATUS.md`.

### Schritt 4: Abnahme (Haiku, nur wenn die gezielte Wiederholung grün ist)
In dieser Reihenfolge, jeder Lauf allein:
1. 10 parallele Gesamtläufe `python -m pytest tests -q` hintereinander. Alle grün.
2. Serieller Gesamtlauf `python -m pytest tests -n 0 -q`.
3. `AHF_FAULT_REPEAT=20 python -m pytest tests/fault -n 0 -q` (rund 44 Minuten).
4. `python -m pytest tests -m stress -q`.

Ist ein Lauf rot: Liste der roten Tests mit Häufigkeit und Meldung. Neue Funde bekommen die nächste freie F-Nummer (ab F-48). Die Schleife geht mit Schritt 1 für die neuen Funde weiter.

Ist die Abnahme grün: Schritt "Abschluss".

### Schritt 5: Abschluss (Sonnet)
1. `README.md`: Haken "WI-35", "WI-34 Abnahme" und "WI-32 Abnahmeläufe" setzen. Den Stand des Fix-Blocks als abgeschlossen melden.
2. `STATUS.md`: F-37 bis F-47 mit Ergebnis schließen (nur, wenn belegt). F-43 bleibt offen (Entscheidung Projektinhaber), F-36 bleibt "empfohlen", bis eine Entscheidung vorliegt.
3. `HANDOVER.md` und `AGENTS.md`: Fix-Block abgeschlossen, offene Entscheidungen (E14, F-43), Phase-3-Plan als Nächstes.
4. Commit mit Präfix `WI-35: `.

## Stopp-Regeln

- Nach **fünf** Fehlerzyklen ohne grüne Abnahme: Stopp, Bericht mit Stand und offenen Funden an den Projektinhaber.
- Ein Fund, der eine Architekturentscheidung braucht (z. B. Reihenfolge der Ränge beim Beenden, F-43, oder eine Änderung am Protokoll, das mehrere Rollen betrifft): Stopp für diesen Fund, Frage dokumentieren, mit den übrigen Funden weitermachen.
- Eine Friständerung, die den Produktwert verletzt: nicht umsetzen, dokumentieren.

## Zyklen (wird während der Schleife gefüllt)

### Zyklus 0 (Ausgangsstand)
Ergebnis in `STATUS.md`, Abschnitt "Schleife WI-35, Zyklus 0". Kurz:
- F-46 (`test_killed_worker_...`, `AHF_FAULT_REPEAT=20`): reproduzierbar, 8 rot von 40 Läufen (2 von 20, dann 6 von 20 mit `AHF_TEST_KEEP=1`). Meldung: `no evt.process.crashed for worker:1` (`test_process_crash.py:37`). Log: `worker not available: worker:1 (peer_gone)`, kein `evt.process.crashed`. Log-Pfade in STATUS.
- F-47 (`cancel_of_the_hang`): 0 von 10 rot, nicht reproduziert.
- F-45 (`refresh_shows`): 0 von 11 rot, nicht reproduziert. `AHF_FAULT_REPEAT` wirkt in diesem Test nicht.

### Analyse Zyklus 1

Stand 2026-10-12, Opus. Keine Änderung an Code oder Tests. Kennzeichnung: **[verifiziert]** = gelesen, gemessen oder im Log gesehen, **[vermutet]**, **[nicht geprüft]**. Keine Eskalation (Begründung unter "Entscheidung des Projektinhabers").

#### F-46: Ursache

Der Verdacht aus dem Kopf dieser Datei stimmt, ist aber nur die halbe Ursache. **Zwei Fehler wirken zusammen**, beide werden erst durch F-40 regelmäßig erreicht:

**Fehler 1 (Engine, `WorkerBridge`): `peer_gone` auf `cmd.worker.run` wird als "Worker lehnt ab" gewertet, nicht als "Worker verloren".** [verifiziert, gelesen]
- `src/engine/WorkerBridge.ahk:377-392` (`_OnRunAnswer`): jede Fehlerantwort, auch `peer_gone`, führt zu `_Lose(slot, "run not accepted: " code)` (Slot weg, `cmd.process.kill`, Fehler gezählt) und `_Finish(execId, "exception", "worker not available: " slot " (" code ")")`.
- Der Weg "worker crashed" liegt nur in `OnProcessEvent` (`WorkerBridge.ahk:260-274`, Zeile 268). Kommt das Prozessereignis danach, ist der Slot schon entfernt (Zeile 263-264 `return`), der Job ist schon beendet.
- Vor F-40 bekam ein offenes `cmd.worker.run` an einen gestorbenen Worker gar keine Antwort (erst nach `ACK_TIMEOUT_MS` = 5 s eine `timeout`-Antwort); `evt.process.crashed` kam vorher und gewann. Seit F-40 antwortet der Hub sofort: `src/supervisor/Hub.ahk:372-395` (`_OnClose`) ruft `_FailRouted` (Zeile 384, Antwort `peer_gone` in Zeile 487-504) **vor** `onLinkLost` (Zeile 387-394). Das Prozessende bewertet erst `Children.Tick` (`src/supervisor/Children.ahk:445-463`), der am Timer des Supervisors hängt (`Supervisor.TICK_MS` = 200, `src/supervisor/Supervisor.ahk:50`, `:149`). `peer_gone` erreicht die Engine also bis zu einem Tick vor `evt.process.crashed`. WI-34 hatte genau diesen Fall als "nicht geprüft" vermerkt (`WI-34-abnahmefunde.md`, Ergebnis Abschnitt 2, "Nicht geprüft", 3. Punkt).
- Warum es offen ist: `Executor._StartThread` meldet `running` (`src/engine/Executor.ahk:302`, `_ElementStarted`) **bevor** `WorkerBridge.Run` das `cmd.worker.run` sendet (`Executor.ahk:343`). Der Test tötet den Worker sofort beim Ereignis `running` (`tests/fault/test_process_crash.py:123-127`). Hat der Hub die Antwort des Workers (`res.worker.run`) noch nicht gelesen, ist die Anfrage offen und bekommt `peer_gone` (rot); sonst nicht (grün). Das erklärt die Häufigkeit von rund 20 bis 25 Prozent. Der Nachbartest `tests/fault/test_worker_lifecycle.py:205-225` wartet 0,3 s nach `running` und trifft das Fenster deshalb nicht [verifiziert, gelesen].

**Fehler 2 (Supervisor, `Children.KillWorker`): ein Worker, dessen Prozess schon beendet, aber noch nicht bewertet ist, wird als "auf Anfrage beendet" umetikettiert.** [verifiziert, gelesen und im Log]
- Fehler 1 schickt `cmd.process.kill` (Grund `run not accepted: peer_gone`). `src/supervisor/Children.ahk:147-159` (`KillWorker`) prüft nur `rec["gone"]` (wird erst in `_OnGone` gesetzt), setzt dann `state := "stopping"` und `killReason := "killed"` (Zeile 154-157) und ruft erst danach `Terminate` (Zeile 158). `Terminate` erkennt das schon beendete Ende (`Children.ahk:370-372`, `WaitForSingleObject`) und tut nichts, aber die Umetikettierung ist schon geschehen. `_OnGone` meldet dann wegen `stopping` `evt.process.exited {reason: "killed"}` statt `evt.process.crashed` (`Children.ahk:566-573`); kein Absturzbericht (`_Incident` nur im Crash-Zweig, Zeile 582).
- Derselbe Fehler steckt in `_EndWorkersOfGoneEngine` (`Children.ahk:472-485`, setzt `stopping`/`engine gone` vor `Terminate`) [gelesen, nicht nachgestellt].
- Der Fehler ist seit WI-27 im Code, aber erst F-40 macht ihn zuverlässig erreichbar: die Engine schickt das `cmd.process.kill` binnen weniger Millisekunden nach dem Tod, das Prozessende wird erst im nächsten Tick bewertet.

**Beleg im Log** [verifiziert]. Alle sechs roten Läufe der Zyklus-0-Wiederholung (`z0n_f46_keep.txt` im Scratchpad der Sitzung) haben dieselbe Zeilenfolge des Supervisors: `1 open request(s) to 'worker:1' answered with peer_gone`, `client 'worker:1' gone (peer_closed)`, dann entweder `killing worker:1 on request: run not accepted: peer_gone` (fünf Läufe) oder `worker:1 ended unexpectedly (exited, exit 15)` (ein Lauf), danach die Engine: `worker not available: worker:1 (peer_gone)`. Zwei Fehlerbilder:

| Logordner (`%TEMP%\ahf-test-...`) | rote Zeile im Test | `running` (recvMs Manager) | Element `exception` | Prozessereignis | Abstand Element-Ende bis Prozessereignis |
|---|---|---|---|---|---|
| `rxcyz_uh` | `:37` kein `crashed` | 818345 | 818367 | `exited {reason: "killed", exitCode: 15}` 818527 | 160 ms |
| `4ts9iptt` | `:37` | 830117 | 830143 | `exited killed`, 15, 830189 | 46 ms |
| `i5kukxg7` | `:37` | 847298 | 847319 | `exited killed`, 15, 847478 | 159 ms |
| `08ntafi6` | `:37` | 855892 | 855913 | `exited killed`, 15, 856075 | 162 ms |
| `8fh96zr1` | `:37` | 867621 | 867642 | `exited killed`, 15, 867742 | 100 ms |
| `oz_cm3b_` | `:135` Text nicht "worker crashed" | 885816 | 885837 | `crashed {reason: "exited"}`, 15, 885831 | Ereignis vor dem Element-Ende beim Manager, die Engine hatte `peer_gone` aber schon verarbeitet (Supervisor-Log: `peer_gone` vor `ended unexpectedly`) |

- **Exit-Code 15 beweist, dass der Test den Prozess beendet hat, nicht der Supervisor**: `psutil.Process.kill()` endet mit 15 (im Scratchpad nachgemessen: `ping` mit `psutil` getötet, Exit-Code 15), `Children.Terminate` mit 1 (`Children.ahk:377`). Der Supervisor hat also einen fremden Tod als eigenes, geplantes Beenden gemeldet.
- Fünf von sechs Ausfällen sind Fehler 2 (Zeile 37 des Tests), einer ist Fehler 1 allein (Zeile 135). Die Zuordnung Ordner zu Zeile stammt aus der pytest-Ausgabe `z0n_f46_keep.txt` (dort steht der Ordner je Fehlschlag).
- Die Zeiten sind `recvMs` des Manager-Stubs (Empfang dort), die Logzeilen selbst haben nur Sekunden. Die Abstände sind also Näherungen, die Reihenfolge ist belegt.

#### F-46: Gegenprobe (kommt `crashed` wegen WI-30 zu spät?)

**Nein.** [verifiziert im Log, gelesen im Code]
- Die Nachfrist von WI-30 (`Children.EXIT_GRACE_MS` = 500, `Children.ahk:489-499`) greift hier nicht: die Verbindung des Workers ist im selben `_OnClose` weg, das auch `peer_gone` sendet (Logzeilen direkt hintereinander), `_ExitReadable` liefert also beim ersten Tick `true`. Die Zeile `... not read to the end within 500 ms; judged now` kommt in keinem der sechs Logs vor.
- Zwischen dem Ende des Elements (also kurz nach dem Tod) und dem Prozessereignis liegen 46 bis 162 ms, immer unter einem Tick (200 ms). Die Verzögerung ist der Takt von `Children.Tick`, nicht WI-30. In WI-34 Lauf `[6]` maß der Test `crashed` 0,011 s nach dem Tod.
- Die Frist des Tests (`CRASH_BUDGET_S` = `scaled(1.0)`, `tests/fault/faultkit.py:44`) wäre jedes Mal eingehalten worden. `crashed` kommt nicht zu spät, sondern **gar nicht** (Fehler 2) oder **nach** `peer_gone` (Fehler 1). Eine Friständerung hilft nicht und ist nicht nötig.

#### F-46: Lösungsoptionen

Maßstab: Produktwert (Element endet mit "worker crashed (worker:n)" binnen `scaled(3.0)` s, `evt.process.crashed` binnen `CRASH_BUDGET_S`, kein Neustart, keine Frist gelockert), PROTOKOLL 2 ("`peer_gone` heißt Ausgang unbekannt"), F-40 bleibt (`test_supervisor.py::test_open_request_to_a_*` mit `scaled(1.0)` s), betroffene Rollen.

| Option | Inhalt | Produktwert | PROTOKOLL 2 | F-40 | Rollen, Risiko |
|---|---|---|---|---|---|
| **A** Engine wertet `peer_gone` auf `cmd.worker.run` als Verlust des Workers | `_OnRunAnswer`: bei Code `peer_gone` endet der Job mit "worker crashed (worker:n)"; Slot weg, `cmd.process.kill` und Fehlerzählung bleiben (`_Lose`). Beide Meldewege (Antwort, Prozessereignis) führen zum selben Ergebnis, die Reihenfolge ist egal (wer zuerst kommt, beendet den Job, der zweite findet keinen Job und keinen Slot mehr) | gewahrt, sofort (kein Warten) | verträglich: "Ausgang unbekannt" bleibt, die Engine wiederholt nichts, sie beendet den Job als abgebrochen und beendet den Worker. Ungenau nur im seltenen Fall "Pipe bricht, Prozess lebt" (Überlauf, Wiederverbindung): auch dann heißt es "worker crashed", der Worker wird aber ohnehin beendet | unberührt | nur Engine. **Allein reicht A nicht**: das `cmd.process.kill` trifft weiter Fehler 2 (5 von 6 Ausfällen) |
| **K** Supervisor etikettiert ein schon beendetes Kind nicht um | `KillWorker` (und `_EndWorkersOfGoneEngine`) prüfen mit `WaitForSingleObject(handle, 0)`, ob der Prozess schon beendet ist; dann kein `stopping`/`killReason`, Logzeile `a1`, das Ende wird normal bewertet (`crashed`). Antwort `ok` wie bisher | stellt `crashed` und den Absturzbericht wieder her | unberührt | unberührt | nur Supervisor. Passt zum bestehenden Text von PROTOKOLL 4.1 ("ein schon beendeter Worker: `ok` (gleichwertig)"). **Allein reicht K nicht**: Fehler 1 bleibt (Lauf `oz_cm3b_`) |
| B Hub wartet mit `peer_gone` auf die Bewertung des Prozessendes | `_FailRouted` für Kinder erst nach `_OnGone` (oder Nachfrist) | gewahrt | verträglich | **verschlechtert F-40**: `peer_gone` kommt bis zu einem Tick (200 ms), im Grenzfall 500 ms später, für jedes Kind (auch `storage`-Lesen). Der Test von F-40 (`scaled(1.0)` s) bliebe wohl grün, die Zusage "sofort" (PROTOKOLL 2, ARCHITEKTUR 6.2) wäre aber aufgeweicht | Hub müsste Kinder und Prozesse kennen (bisher bewusst nicht, `Hub.ahk:13-16`), Kopplung Hub-Children; Pipe-Bruch bei lebendem Prozess braucht eine eigene Frist. Fehler 2 bliebe latent |
| B' Prozessende beim Verlust der Verbindung sofort bewerten | `Hub._OnClose` ruft `onLinkLost` vor `_FailRouted`; `Children.OnLinkLost` bewertet sofort, wenn das Handle schon signalisiert ist (Bedingung von WI-30 ist in genau diesem Moment erfüllt). Dann geht `crashed` auf derselben Pipe vor `peer_gone` an die Engine | gewahrt, `crashed` sogar schneller | verträglich | unberührt | nur Supervisor, aber im empfindlichen Teil (WI-30, WI-33): `_OnGone` liefe im Rückruf des Hubs (Bericht, Publish), der Pfad "Engine endet, Worker beenden" (`Children.ahk:459-460`) müsste mitgenommen werden, sonst entfällt er. Ob das Handle beim Lesen des Pipe-Endes schon signalisiert ist, ist **nicht geprüft**; wenn nicht, bliebe das Rennen (seltener) |
| C `peer_gone` mit Grund, Engine unterscheidet | neues Feld im Fehler (z. B. `reason: peer_closed/queue_overflow/reconnected`), die Engine wartet bei `peer_closed` auf das Prozessereignis | gewahrt, aber mit Warten in der Engine (neue Frist) | verträglich | unberührt | **Protokolländerung** (neues Feld in einer Fehlerantwort des Hubs, gilt für alle Absender), Engine braucht Zustand "verloren, warte auf Ereignis" plus Frist. Der Hub weiß auch mit Grund nicht, ob der Prozess tot ist (`peer_closed` gibt es auch beim sauberen Ende). Würde eine Entscheidung des Projektinhabers brauchen |

#### F-46: Empfehlung

**A + K, zwei Commits, K zuerst.** Begründung:
- Die eigentliche Lehre ist: Die Engine erfährt den Tod eines Workers auf **zwei Wegen ohne festgelegte Reihenfolge** (Antwort des Hubs, Prozessereignis des Supervisors; zwei verschiedene Absender, nur die Pipe zur Engine ordnet sie). Eine Lösung, die eine Reihenfolge herstellt (B, B'), ist zerbrechlich; eine Lösung, die beide Wege gleich bewertet (A), ist es nicht.
- K ist ein eigenständiger Produktfehler (ein echter Absturz verschwindet als "geplantes Beenden", ohne Bericht) und trifft jeden Wettlauf zwischen einem Kill der Engine (Leerlauf, Abbruch ohne Quittung, Jobfrist, `peer_gone`) und einem echten Tod, nicht nur diesen Test.
- Keine Frist ändert sich, F-40 bleibt unverändert, kein neues Nachrichtenfeld, keine neue Kopplung im Hub. Geändert wird Verhalten von zwei Rollen (Engine, Supervisor) innerhalb des bestehenden Protokolls; die Texte in PROTOKOLL 4.1 und 4.5 werden angepasst.
- Restrisiko [vermutet, nicht geprüft]: Liest der Hub das Pipe-Ende, bevor das Prozess-Handle signalisiert ist, und kommt das `cmd.process.kill` der Engine in genau dieser Lücke an, beendet `Terminate` einen schon sterbenden Prozess und meldet `killed`. Die Engine braucht für das Kill einen Rundweg über den Hub (Millisekunden); die Lücke beim Prozessende ist nach Kenntnis von Windows kürzer. Der Integrationstest unten zeigt, ob es vorkommt (20 Wiederholungen).

#### F-46: Testplan für die Umsetzung (Sonnet)

Reihenfolge: erst K, dann A. Jeweils Test rot, Fix, grün, Nachbartests, Doku im selben Commit.

1. **K, rot zuerst** (AHK-Unit, deterministisch): `tests/ahk/supervisor_tick.test.ahk`, neuer Fall "Children: a kill request for a worker whose process has already ended does not turn its crash into a planned exit (F-46, WI-35)". Aufbau mit den vorhandenen Helfern: `AddChild(kids, "worker:1", "ready", t0)`, `rec["role"] := "worker"`, Handle aus `EndedProcessHandle()`, kein Link im `FakeHub`; dann `kids.KillWorker("worker:1", "run not accepted: peer_gone")` **vor** dem ersten Tick, dann `kids.Tick(t0)`. Prüfung: genau ein `evt.process.crashed` mit `reason` "exited", kein `evt.process.exited`, `AnyKilled()` falsch, `State` "crashed". Heute rot (`exited` mit `reason` "killed"). Zweiter Fall, nur grün (Absicherung): ein laufender Worker (`RunningProcessHandle()`) wird mit `KillWorker` beendet und als `exited {reason: "killed"}` gemeldet. Optional dritter Fall rot: Engine endet, ein Worker ist schon tot und unbewertet, `_EndWorkersOfGoneEngine` darf ihn nicht als "engine gone" melden.
   **Fix:** `src/supervisor/Children.ahk`, `KillWorker` und `_EndWorkersOfGoneEngine`: vor dem Umetikettieren `WaitForSingleObject(rec["handle"], 0)`; bei `WAIT_OBJECT_0` nur Logzeile `a1` ("<name> has ended already, its end is judged as its own") und nichts setzen. Antwort von `cmd.process.kill` bleibt `ok`.
2. **A, rot zuerst** (AHK-Unit, deterministisch): `tests/ahk/engine_worker_bridge.test.ahk`, neuer Fall "Pool: a run answered with peer_gone ends the job as worker crashed, removes and kills the worker (F-46, WI-35)", Vorlage `ARunThatTheWorkerRefusesRemovesAndKillsItAndEndsTheJob` (Zeile 276-290) mit Code `peer_gone`. Prüfung: Meldung `"worker crashed (worker:1)"` (heute `"worker not available: worker:1 (peer_gone)"`, rot), `bridge.Count` 0, `cmd.process.kill` für `worker:1` genau einmal, eine Fehlerzählung. Zweiter Fall, nur grün: Prozessereignis und `peer_gone` für denselben Job in **beiden Reihenfolgen**: `onDone` genau einmal, Text gleich, Fehlerzählung 1. Bestehender Fall mit `busy` bleibt "worker not available".
   **Fix:** `src/engine/WorkerBridge.ahk`, `_OnRunAnswer`: bei `code = ErrCode.PEER_GONE` Text "worker crashed (" job["slot"] ")"; `_Lose` bleibt (Grund z. B. "connection lost: peer_gone"). Andere Codes unverändert.
3. **Integration, rot vor beiden Fixes, deterministisch** (zeigt den Fehler im echten Supervisor, ohne Wettlauf): `tests/fault/test_worker_lifecycle.py::test_worker_killed_before_it_answers_the_run_ends_the_element_with_worker_crashed_and_is_reported_as_crashed`. Ablauf: Kette mit warmem Worker, `worker:1` bereit; `chain.freeze(pid)` (vorhanden in der Datei, Zeile 231); Flow mit `Action_TestHangWorker` starten; warten, bis der Snapshot des Supervisors `hub.routedOpen >= 1` zeigt (die Anfrage liegt sicher unbeantwortet beim gefrorenen Worker, kein `sleep`); dann `psutil.Process(pid).kill()`. Prüfungen: `evt.process.crashed` für `worker:1` binnen `CRASH_BUDGET_S` mit `restart` false; **kein** `evt.process.exited` mit `reason` "killed" für `worker:1`; Element endet mit `"worker crashed (worker:1)"`, Instanz binnen `scaled(3.0)` s nach dem Tod. Vor den Fixes jedes Mal rot (immer der `peer_gone`-Weg), nach K allein rot an der Meldung, nach A und K grün. Mit `AHF_FAULT_REPEAT`-Wiederholung, falls die Datei `repeat_ids()` nutzt [nicht geprüft], sonst 20 Einzelläufe.
4. **Original wiederholen:** `AHF_FAULT_REPEAT=20 python -m pytest tests/fault/test_process_crash.py -k killed_worker -n 0 -q` zweimal (vorher 8 rot von 40), Ziel 0 von 40.
5. **Nachbartests:** `tests/fault/test_process_crash.py`, `tests/fault/test_worker_lifecycle.py` (u. a. `test_frozen_worker_does_not_answer_the_run_and_is_replaced` erwartet weiter "worker not available ... (timeout)", Sturmgrenze, Jobfrist mit `exited killed`), `tests/integration/test_worker_pool.py` (Kill-Semantik, `test_kill_ends_the_worker_as_a_planned_exit_...`), `tests/integration/test_worker.py`, `test_worker_busy.py`, `tests/integration/test_supervisor.py -k "peer_gone or crash"` (F-40 bleibt grün), `tests/fault/test_report.py` (Absturzbericht), `tests/test_ahk_runner.py` (alle AHK-Unit-Tests), `tests/test_architecture.py`. Kein Test im Bestand erwartet den Text "(peer_gone)" [verifiziert, Suche in `tests/`].
6. **Doku** (im jeweiligen Commit, Regel 5 und 9): `doc/PROTOKOLL.md` 4.1 `cmd.process.kill` (ein Worker, dessen Prozess schon beendet ist, wird nicht als geplant gemeldet, sein Ende wird normal bewertet, meist `crashed`), 4.5 (beide Listen: `peer_gone` auf `cmd.worker.run` ergibt "worker crashed (worker:n)", heute Zeilen 269 und 282 mit "worker not available"), 2 (Satz: wer den Verlust eines Ziels auch aus Prozessereignissen kennt, muss beide Wege gleich bewerten, die Reihenfolge ist nicht festgelegt). `doc/ARCHITEKTUR.md` 6.2 (Zeile F-40: "Die Rollen brauchen dafür nichts" gilt nicht für den Worker-Pool der Engine; Zeile "Worker bricht ab": Erkennung auch über `peer_gone`), 6.4 "Absturz". `doc/HOW-TO.md`: zwei Einträge ("Zwei Meldewege für denselben Tod: keine Reihenfolge annehmen", "Einen schon beendeten Prozess nicht als auf Anfrage beendet umetikettieren", jeweils mit Status). `STATUS.md` F-46. Kein VS-Code-Task (kein neuer Aufruf). Keine MIGRATION (kein v1-Verhalten betroffen).

#### Entscheidung des Projektinhabers

Nicht nötig [Einschätzung]. A und K ändern kein Nachrichtenformat und keine Frist; K stellt her, was PROTOKOLL 4.1 schon sagt. Zur Kenntnis: Nach A meldet die Engine "worker crashed" auch, wenn nur die Verbindung eines lebenden Workers bricht (Überlauf, Wiederverbindung); der Worker wird dann ohnehin beendet. Option C wäre eine Protokolländerung mit Entscheidung und wird nicht empfohlen.

#### Zusatz: F-47 und F-45

- **F-47** (`test_worker.py::test_cancel_of_the_hang_element_reports_stopped_within_500_ms`, `cmd.worker.cancel` 5 s unbeantwortet): **nicht dieselbe Mechanik** [Beleg aus Code, Ursache nicht geprüft]. Der Test läuft gegen `RoleHub` (`tests/integration/test_role.py:36`, abgeleitet von `WakingHub`/`PyHub`), der seit `27d49cb` wie der echte Hub bei Ende der Zielverbindung sofort `peer_gone` antwortet (`tests/support/pyhub.py:215-223`). Hätte der Worker seine Verbindung verloren, wäre `peer_gone` gekommen, nicht `AhfTimeout`. Es ist also eine unbeantwortete Anfrage an einen lebenden Worker (oder ein verlorener Weckruf/Rahmen). Die verwandte Familie (F-37) gab es schon vor F-40. Ohne Log nicht weiter einzuordnen; beim nächsten Auftreten Snapshot des Workers (`cmd.diag.snapshot`: `peer`-Zähler, `job`) und `AHF_TEST_KEEP=1`.
- **F-45** (`test_debug_role.py::test_refresh_shows_a_process_that_is_not_ready_as_not_ready_instead_of_leaving_it_out`, `refreshed` 2 statt 3): **nicht dieselbe Mechanik** [vermutet]. In diesem Test stirbt kein Ziel, `peer_gone` entsteht nur beim Ende einer Zielverbindung. `DebugView.RefreshSnapshots` (`src/debugview/DebugView.ahk:235-255`) fragt nur Prozesse, die **das Fenster** als `ready` sieht, und zählt nur Antworten (`_OnSnapshot`, Zeile 257-269). Der Test wartet aber nur auf `ready` beim Supervisor (`chain.wait_ready(["storage", "debug"])`, `test_debug_role.py:84`), nicht in der Tabelle des Fensters. Sieht das Fenster `storage` (oder sich selbst) noch nicht als `ready`, fehlt eine Antwort: 2 statt 3, und Zeile 94 bliebe trotzdem grün (der Eintrag "not ready" zählt als Name). Das ist dasselbe Muster wie F-38, nur für `storage`/`debug` statt `worker:1` [vermutet, nicht nachgestellt]. Alternative Ursache: eine Antwort kam nicht binnen `DebugView.SNAPSHOT_MS` [nicht geprüft].

### Umsetzung Zyklus 1

Stand 2026-10-12, Sonnet. Beide Schritte abgeschlossen, keine Eskalation. Zeilenangaben der Analyse stimmten (`KillWorker`, `_EndWorkersOfGoneEngine`, `_OnRunAnswer`).

**Schritt K (Supervisor), Commit `8f9ecdf`**
- Rot zuerst (`tests/ahk/supervisor_tick.test.ahk`, vor dem Fix): `KillOfAnEndedWorkerStaysACrash` ("an ended process is not relabelled as stopping: expected "ready" but got "stopping"") und `EngineEndKeepsTheCrashOfAnEndedWorker` ("expected 0 but got 1"). Nur grün (Absicherung): `KillOfARunningWorkerIsAPlannedExit`.
- Fix: `Children._HasEnded(rec)` (`WaitForSingleObject(handle, 0)`); `KillWorker` loggt `a1` und kehrt zurück, `_EndWorkersOfGoneEngine` überspringt den Worker. Antwort auf `cmd.process.kill` bleibt `ok`. Keine Frist geändert.
- Grün: alle drei Fälle, ganze Datei 40/40.
- Doku im selben Commit: PROTOKOLL 4.1 (`cmd.process.kill`), ARCHITEKTUR 6.4 ("Ende mit der Engine"), HOW-TO "Einen schon beendeten Prozess nicht als auf Anfrage beendet umetikettieren".

**Schritt A (Engine), Commit `f6c32e7`**
- Rot zuerst (`tests/ahk/engine_worker_bridge.test.ahk`): `APeerGoneAnswerToTheRunEndsTheJobAsWorkerCrashed` und `BothOrdersOfPeerGoneAndTheProcessEventEndTheJobOnce` (Reihenfolge "answer first" rot, "event first" war schon grün).
- Rot zuerst (Integration, `tests/fault/test_worker_lifecycle.py::test_worker_killed_before_it_answers_the_run_ends_the_element_with_worker_crashed_and_is_reported_as_crashed`, mit `repeat_ids()`): Worker eingefroren, Wartebedingung `hub.routedOpen >= 1` aus `cmd.diag.snapshot` des Supervisors (das Feld ist exponiert), dann `psutil kill`. Mit K allein: 3 von 3 rot an der Meldung ("worker not available: worker:1 (peer_gone)"). Vor K und A (Children.ahk vorübergehend auf `HEAD~1`): 3 von 3 rot (2 mal "no evt.process.crashed", 1 mal Meldung). Nach K und A: grün.
- Fix: `WorkerBridge._OnRunAnswer`: bei `ErrCode.PEER_GONE` Text "worker crashed (<slot>)"; `_Lose` (Slot weg, `cmd.process.kill`, Fehlerzählung) unverändert; andere Codes unverändert.
- Doku im selben Commit: PROTOKOLL 4.5 (zwei Stellen plus Absturz), ARCHITEKTUR 6.2 (zwei Zeilen) und 6.4 ("Absturz"), HOW-TO "Zwei Meldewege für denselben Tod: keine Reihenfolge annehmen". Alle Einträge: verifiziert.

**Gelaufene Tests (nur die relevanten, keine Gesamtläufe)**
- `tests/test_ahk_runner.py` (alle AHK-Unit-Tests) plus `tests/test_architecture.py`, `-n 0`: 464 grün, 1 übersprungen (war schon so). `tools/arch_check.py`: 0 Verstöße.
- `tests/fault/test_worker_lifecycle.py`, `tests/fault/test_process_crash.py`, `tests/integration/test_worker*.py`, `tests/fault/test_report.py`, `tests/integration/test_supervisor.py`, `tests/test_architecture.py`, `-n 4`: 102 grün.
- Neuer Integrationstest mit `AHF_FAULT_REPEAT=5`: 5 von 5 grün. Gemessen: `crashed` 0,117 s nach dem Kill.
- **Original `AHF_FAULT_REPEAT=20 python -m pytest tests/fault/test_process_crash.py -k killed_worker -n 0 -q`: 20 von 20 grün, zweimal (Vorher 8 rot von 40; jetzt 0 von 40.)**

**Abweichungen:** keine vom Vorschlag. Der Integrationstest nutzt zusätzlich `repeat_ids()` (die Datei importierte es noch nicht). Der AHK-Unit-Test für `_EndWorkersOfGoneEngine` (in der Analyse "optional") ist umgesetzt.

**Offene Punkte**
- Das Restrisiko aus der Analyse (Pipe-Ende vor Prozess-Handle signalisiert, `cmd.process.kill` genau in dieser Lücke) ist in 40 plus 5 Läufen nicht aufgetreten; ein Beweis ist das nicht, die Abnahme (`AHF_FAULT_REPEAT=20 tests/fault`) prüft es weiter.
- `STATUS.md` (F-46 schließen) ist nicht angefasst; das gehört zu Schritt 5 (Abschluss) nach der grünen Abnahme.
- Nicht von mir: die geänderte `.gitignore` im Arbeitsbaum wurde nicht angefasst.

### Analyse Zyklus N
(Opus-Analyse hier eintragen.)

### Umsetzung Zyklus N
(Sonnet-Ergebnis hier eintragen.)

### Testdurchführung Zyklus N
(Haiku-Ergebnis hier eintragen.)

## Akzeptanzkriterien

- Abnahme aus Schritt 4 grün, mit Zahlen in `STATUS.md`.
- F-45, F-46, F-47 behoben, jeweils mit einem Test, der vorher rot war.
- Neue Funde aus der Schleife behoben oder begründet zurückgestellt, mit Test.
- Keine Frist ohne Begründung gelockert. Keine Tests gelöscht oder abgeschwächt.
- Doku (`PROTOKOLL`, `ARCHITEKTUR`, `TESTSTRATEGIE`, `HOW-TO`) nachgeführt.

## Nicht Teil

- F-43 (Kind hält storage beim Beenden auf): Entscheidung des Projektinhabers.
- E14 (Manager-Fenster schließen): Phase 3.
- Phase-3-Plan.
