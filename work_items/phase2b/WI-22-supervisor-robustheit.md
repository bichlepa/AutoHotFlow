# WI-22 Supervisor: Heartbeat, F-06, Startreihenfolge, 64 Bit, Pipe-Namen

Größe: M · Hängt ab von: WI-18 · Blockiert: WI-23, WI-24, WI-27

## Ziel

Der Supervisor darf gesunde Prozesse nie fälschlich beenden, keine Dialoge zeigen und auch bei mehreren angemeldeten Windows-Benutzern starten.

## 1. Heartbeat: falsch-positive Hänger nach einem Stillstand des Supervisors [gelesen; Standby vermutet]

**Fund:** `Heartbeat.Tick` (`src/supervisor/Heartbeat.ahk`) vergleicht `now - lastPongAt` mit `PONG_TIMEOUT_MS` (6 s). Stand der Supervisor selbst länger still, sind alle Kinder auf einen Schlag "hängend": `MarkHung` sendet `sys.shutdown`, nach 2 s `TerminateProcess`. Engine und Storage starten neu (laufende Instanzen verloren), Manager und Editoren werden **nie** neu gestartet: Der Benutzer hat danach kein Fenster mehr.

Zwei Auslöser:
- **Standby/Ruhezustand:** `Time.NowMs` nutzt `QueryPerformanceCounter`. Dass QPC im Standby weiterzählt, ist allgemeines Wissen, aber nicht belegt [vermutet]. Die AHK-Timer laufen nach dem Aufwachen sofort.
- **Rückstau im Supervisor selbst** (z. B. großer Rahmen im Hub, siehe WI-24): Pongs liegen ungelesen in den Pipes, der Tick sieht veraltete Zeitstempel.

**Korrektur:** Der Supervisor merkt sich den Zeitpunkt seines letzten Ticks. Ist die Lücke größer als `PING_EVERY_MS` (2 s), setzt er `lastPongAt` und `lastPingAt` aller Kinder (und die Startfrist von `starting`-Kindern) auf jetzt, pumpt den Hub einmal und loggt `a1` "supervisor stood still for N ms, heartbeat reset". Optional zusätzlich `WM_POWERBROADCAST` (`PBT_APMRESUMEAUTOMATIC`) auswerten.

**Tests** (`tests/fault/`): Supervisor mit `psutil` 8 s einfrieren, dann fortsetzen: kein `evt.process.hung`, kein `crashed`, alle Pids unverändert. Prüfen, dass die Kinder in dieser Zeit nicht selbst aufgeben (ihr Orphan-Guard greift nur bei gebrochener Pipe; bei Log-Last könnte ihre Sendewarteschlange überlaufen, das als Ergebnis notieren).

## 2. F-06: `clean` in `evt.process.exited` unzuverlässig [vermutet, Fix trivial]

**Fund:** `Children._OnGone` wertet `rec["bye"]` aus, sobald der Prozess-Handle signalisiert. Das `sys.bye` liegt dann schon in der Pipe, ist aber noch nicht gelesen, wenn der Hub seit dem letzten Weckruf nicht gepumpt hat (`Wake.MaxThreads` = 1 kann einen Weckruf verwerfen).

**Korrektur:** In `Supervisor._Tick` den Hub pumpen, bevor `children.Tick` Prozessenden auswertet. Alternativ in `_OnGone` die Verbindung des Kindes vorher pumpen.

**Test:** `tests/fault/test_shutdown.py` 50-mal wiederholen (`AHF_FAULT_REPEAT`), `clean` immer wahr. Ergebnis mit Zahlen festhalten, F-06 in `STATUS.md` schließen.

## 3. Startreihenfolge: kein Dialog vor `OnError` [gelesen]

**Fund:** Die eingebundenen Elementdateien rufen auf Dateiebene `ElementRegistry.Register(...)` auf. Dieser Code läuft beim Laden in Textreihenfolge, also **vor** `AhfMain()` und damit vor jedem `OnError`. Ein Fehler dort (z. B. doppelte Klasse, ungültiger `Mode`) zeigt beim Supervisor einen Fehlerdialog. Die Kinder startet der Supervisor mit `/ErrorStdOut=UTF-8`; laut AHK-v2-Doku (`Scripts.htm`) betrifft dieser Schalter **nur Ladefehler** (Syntax), nicht Laufzeitfehler.

**Korrektur:**
- `OnError` als erste ausführbare Zeile des Einstiegs setzen (vor den `#Include`-Zeilen, deren Dateien Code auf Dateiebene enthalten), mit einem Handler, der auf stderr schreibt und 1 zurückgibt. Rollen und Supervisor ersetzen ihn später durch ihren eigenen.
- Alternativ (sauberer, im Paket entscheiden): Elementdateien enthalten keinen Code auf Dateiebene mehr; die Registrierung erfolgt in einer Funktion, die der Einstieg nach `OnError` aufruft. Das betrifft auch die Vorlage in `doc/ELEMENT-API-V2.md` ("Registrierung"), dort anpassen.
- `#Warn` nie im Dialogmodus (Regel in WI-19).

**Test:** Ein Testelement, dessen Registrierung wirft (nur mit `--test-roles` oder in einem eigenen Testeinstieg), darf über `tools/ahkrun.py` **keinen** Dialog erzeugen (Exit nicht 97), die Meldung steht auf stderr.

## 4. Nur 64 Bit (E4)

Im Einstieg vor allem anderen: `A_PtrSize != 8` → Meldung auf stderr ("AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter"), Exit 2. Einen eigenen Exit-Code nur, wenn der Einstieg dafür einen festlegt; in `doc/PROTOKOLL.md` 4.1 eintragen.

**Test:** `C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe` ist vorhanden. Test startet den Einstieg damit (über `ahkrun.py` mit `AHF_AHK2_EXE` oder eigener Option) und erwartet Exit 2 ohne Dialog. Skip, wenn der Interpreter fehlt.

## 5. Pipe-Name bei mehreren angemeldeten Benutzern [gelesen; Auswirkung vermutet, nicht getestet]

**Fund:** Der Mutex `AHF.supervisor.<session>` wird ohne Präfix angelegt und liegt damit im Namensraum der Windows-Sitzung (`Local\`). Der Pipe-Name `\\.\pipe\ahf.<session>.hub` ist dagegen systemweit. Meldet sich ein zweiter Benutzer an (schneller Benutzerwechsel, Terminalserver) und startet AutoHotFlow, findet er keinen Mutex, legt einen Hub an und scheitert an `FILE_FLAG_FIRST_PIPE_INSTANCE` (Name belegt). Supervisor endet mit Exit 1.

**Korrektur:**
- Pipe-Name mit Windows-Sitzungs-ID (`ProcessIdToSessionId`) und einer kurzen Kennung des Benutzers (z. B. Hash der SID) bilden, an **einer** Stelle (eine Funktion, die Supervisor, zweite Instanz und Rollen nutzen). Mutex ausdrücklich mit `Local\`.
- Optional: Sicherheitsbeschreibung der Pipe auf den aktuellen Benutzer beschränken (`ConvertStringSecurityDescriptorToSecurityDescriptorW`). Als Option im Ergebnis bewerten, nicht zwingend.
- Die Python-Tests bauen den Namen heute selbst (`"ahf.%s.hub" % session`, z. B. `tests/fault/faultkit.py`, `tests/support/test_client_hub.py`): auf eine gemeinsame Hilfsfunktion umstellen oder den Namen aus dem Supervisor-Log lesen.

**Doku:** `doc/PROTOKOLL.md` Abschnitt 1 (Sitzung und Pipe-Name).

**Tests:** Name enthält Sitzungs-ID; eine fremde Pipe mit dem alten Namen blockiert den Start nicht. Zweiter Windows-Benutzer: **nicht prüfbar** in dieser Umgebung, im Ergebnis so vermerken.

## Akzeptanzkriterien

- Alle Tests oben grün, Gesamtlauf (parallel und einmal seriell) grün, Fault-Tests 10-mal wiederholt grün.
- F-06 in `STATUS.md` geschlossen (mit Wiederholungszahl).
- Doku angepasst (`PROTOKOLL.md` 1 und 4.1, `ARCHITEKTUR.md` 6.2 für die Heartbeat-Regel, ggf. `ELEMENT-API-V2.md`).

## Ergebnis

Status: Punkte 1 bis 5 abgeschlossen (2026-10-11). Kennzeichnung: **verifiziert** = gelaufen oder gelesen, **vermutet**, **nicht geprüft**. Keine Eskalation. Zwei Einschränkungen (Gesamtlauf parallel und Zeitbudgets der Fault-Tests) stehen unten unter "Läufe".

Commits: `856ef22` (Test F-06/F-11), `dfe8137` (Punkt 1), `638ce3a` (Punkt 1, Nachtrag `Arm`), `ae919f9` (Punkte 3 und 4, ein Commit, weil beide die ersten Zeilen des Einstiegs ändern), `6870a6f` (Punkt 5), `c7a07fe` (e2e-Tests, siehe Abweichungen); Dokumentation und HOW-TO im Abschlusscommit. Punkt 2 brauchte keine Quelländerung (die Korrektur kam in WI-18), nur den Test.

### Punkt 2 und F-11: war die Reihenfolge in `Supervisor._Tick` die Ursache? [verifiziert: ja]

- Deterministischer Test `tests/ahk/supervisor_tick.test.ahk`, Fall "Tick: a sys.bye that is unread when the process end is seen is read first (F-06, F-11)": Ein Prozess, der schon beendet ist (Handle signalisiert), `Children` im Zustand `stopping`, ein Attrappen-Hub, dessen `Pump()` das ungelesene `sys.bye` erst bei Aufruf übergibt. Ein Tick.
- **Alte Reihenfolge** (`children.Tick` vor `hub.Pump`, dafür `Supervisor.ahk` vorübergehend umgestellt): `clean` ist **falsch** ("expected 1 but got 0"), der Test ist rot. **Aktuelle Reihenfolge** (Pump zuerst, Stand aus WI-18): `clean` ist wahr, grün. Gegenprobe "Exit ohne `sys.bye` ist nicht sauber" und "Hub wird in jedem Tick gepumpt" grün. Damit ist gezeigt, dass die Reihenfolge den beschriebenen Fehler erzeugt und dass die Korrektur ihn behebt. Dass genau dieser Fehler auch den einmaligen Ausfall in WI-18 verursachte, ist weiterhin **vermutet** (nicht reproduzierbar), aber nach den Wiederholungen unten sehr wahrscheinlich.
- Wiederholung: `tests/fault/test_shutdown.py` mit `AHF_FAULT_REPEAT=50`, zweimal (je 200 Tests, `-n 6` bzw. `-n 4`). In keiner Runde wurde `clean` falsch gemeldet. Die Tests, die in diesen Läufen scheiterten (4 und 2 von je 50 Runden des Tests "healthy session"), scheiterten am Zeitbudget (2,75 bis 4,36 s statt 2 s), und die Zeitprüfung steht im Test **vor** der Prüfung von `clean`. In diesen 6 Runden wurde `clean` also nicht geprüft; in den übrigen 94 von 100 Runden war es wahr. Der Ausfall unter Last (1 von 6) trat in WI-18 mit 8 Workern auf, dieselbe Last war hier vorhanden.
- F-06 und F-11 in `STATUS.md` geschlossen.

### Punkt 1: Heartbeat nach einem Stillstand des Supervisors [verifiziert]

- Korrektur: `Heartbeat.Tick` merkt den Zeitpunkt des letzten Ticks. Ist die Lücke größer als `PING_EVERY_MS`, ruft er `Children.ResetLiveness(now)` (neue Methode): Pong- und Pingzeit der `ready`/`stopping`-Kinder und die Startfrist der `starting`-Kinder beginnen bei "jetzt"; ein schon `hung` markiertes Kind behält seine Kill-Zeit. Log `a1` "supervisor stood still for N ms, heartbeat reset". Nachtrag `638ce3a`: `Heartbeat.Arm(now)`, vom Supervisor beim Start des Timers aufgerufen, damit auch ein Stillstand **vor dem ersten Tick** erkannt wird.
- Tests: `tests/ahk/supervisor_tick.test.ahk` (6 Fälle: stilles Kind wird nach 6 s weiter gefunden, Stillstand lässt `ready` und `starting` Kinder in Ruhe, Pingplan beginnt neu, stilles Kind nach dem Stillstand wird weiter gefunden, Stillstand vor dem ersten Tick; die ersten drei Stillstandsfälle waren vor der Korrektur rot). `tests/fault/test_supervisor_stall.py`: Supervisor mit `psutil.suspend()` 8 s einfrieren, fortsetzen, 4 s warten: kein `evt.process.hung`/`crashed`, alle Pids unverändert, alle `ready`, Engine antwortet, Log enthält "supervisor stood still". Ohne die Korrektur **rot**: `storage`, `engine`, `manager` als hängend gemeldet und beendet ("no pong for 6000 ms"). Mit Korrektur grün; der Test fand dabei die Lücke "Stillstand vor dem ersten Tick" (unter Parallellast trat sie auf, `Arm` behebt sie: 4 von 4 grün bei `-n 4`, 10 von 10 im 10-fachen Fault-Lauf).
- **Geben die Kinder in der Einfrierzeit selbst auf?** Nein, für den ungestörten Betrieb [verifiziert]: Nach 8 s waren `storage`, `engine`, `manager` am Leben (Prüfung `alive(pid)` im Test), nach dem Fortsetzen blieben Pids und Zustand gleich, kein Neustart. Begründung (gelesen, `Role._Guard`): Der Orphan-Guard greift nur bei `peer.status = "reconnecting"`, also bei gebrochener Pipe; die Pipe zu einem eingefrorenen Hub bleibt offen. **Nicht getestet:** Ein Kind mit hoher Log-Last. Seine Sendewarteschlange (`PipeConnection.maxQueueFrames` 1000 Rahmen / 8 MiB, dazu der Kernelpuffer von 64 KiB) läuft dann bei langem Stillstand über, die Verbindung schließt mit `queue_overflow`, das Kind baut sie neu auf und beendet sich nach `ORPHAN_MS` (3 s), wenn der Hub nicht zurückkommt. Das Kind würde also nach etwa 1000 ungelesenen Rahmen aufgeben. Siehe F-17.
- Der Auftrag nannte "pumpt den Hub einmal": Das übernimmt schon `Supervisor._Tick` (Pump zuerst, siehe Punkt 2), `Heartbeat` pumpt nicht selbst. Optional `WM_POWERBROADCAST` nicht umgesetzt (die Lückenerkennung deckt Standby ab, ohne dass der Supervisor ein Fenster für die Nachricht braucht). Ob `QueryPerformanceCounter` im Standby weiterzählt, ist weiter **vermutet** und **nicht geprüft**.
- Doku: `doc/ARCHITEKTUR.md` 6.2 (neue Zeile "Supervisor stand still").

### Punkt 3: kein Dialog vor `OnError` [verifiziert, rot dann grün]

- Entscheidung: **`OnError` vor den `#Include`-Zeilen**, nicht Registrierung in einer Funktion. Gründe: (a) AHK führt Code auf Dateiebene in Textreihenfolge aus, eine Anweisung vor den Includes läuft sicher zuerst; (b) in Phase 3 kommen hunderte Elementdateien, eine Funktion je Datei plus generierter Aufrufblock wäre eine große Änderung, die nicht mehr fängt; (c) der Handler deckt jeden anderen Code auf Dateiebene ab (statische Initialisierer). Nachteil: Elementdateien dürfen weiter Code auf Dateiebene haben; das bleibt auf den Registrierungsaufruf beschränkt (Vorlage in `doc/ELEMENT-API-V2.md`, "Registrierung" angepasst).
- Handler `AhfLoadError` im Einstieg: Meldung auf stderr (`a0 entry: error while loading: <Typ>: <Text> (<Datei>, line <n>)`), **`ExitApp(1)`** (Abweichung vom Auftragstext "gibt 1 zurück": Ein Prozess mit kaputter Registrierung soll nicht weiterlaufen; Rückgabe 1 hätte den Fehler verschluckt und die Rolle mit unvollständiger Registry weiterlaufen lassen). `AhfMain` entfernt ihn mit `OnError(AhfLoadError, 0)` kurz vor `Supervisor.Run` bzw. `roleObj.Start()`, weil ein früher Handler, der 1 liefert, spätere Handler verdecken könnte [vermutet, siehe HOW-TO].
- Test: `tests/integration/test_entry.py::test_error_while_loading_files_shows_no_dialog_and_ends_with_exit_1`; Hilfsdatei `tests/integration/helpers/RegisterFailure.ahk` (wirft auf Dateiebene, nur mit `--test-roles --test-register-failure`, im Einstieg einkompiliert). **Vorher rot:** Exit 97, Dialog "ElementRegistry.Register: Test_RegisterFailure has invalid Mode 'remote'" (Text und Screenshot in `%TEMP%\ahf_dialogs`). Nachher Exit 1, Meldung auf stderr. Zusatz: `test_a_start_without_the_test_option_is_not_affected_by_the_helper` (Exit 2, "unknown role").
- Der Architekturwächter meldete `FileAppend` im Einstieg (Regel `file-io`); Ausnahme in `tools/arch_check.py` eingetragen (stderr, kein Datei-Zugriff, wie `Role.Console`).

### Punkt 4: nur 64 Bit [verifiziert, rot dann grün]

- `if (A_PtrSize != 8)` ist die erste Anweisung des Einstiegs (vor allen Includes): Meldung "AutoHotFlow v2 needs the 64-bit AutoHotkey v2 interpreter (this one is 32-bit: <Pfad>)" auf stderr, Exit **2** (derselbe Code wie "ungültige Optionen/unbekannte Rolle", kein neuer Code). In `doc/PROTOKOLL.md` 4.1 ("Exit-Codes des Einstiegs vor dem Start der Rolle") eingetragen.
- Test `test_the_32_bit_interpreter_is_rejected_with_exit_2_and_no_dialog` (`AHF_AHK2_EXE` auf `AutoHotkey32.exe`, Skip wenn die Datei fehlt). Vorher rot: Der 32-Bit-Supervisor lief einfach (Timeout 98). Nachher Exit 2 ohne Dialog.

### Punkt 5: Pipe-Name mit Sitzung und Benutzer [verifiziert bis auf den zweiten Benutzer]

- Neue Datei `src/core/PipeNames.ahk` (**neu in `src/core/`**, vom Auftrag genannt): `PipeNames.Hub(session)` = `ahf.s<Windows-Sitzung>.u<8 Hex FNV-1a der Benutzer-SID>.<session>.hub` (z. B. `ahf.s1.uefa8a195.main.hub`), `PipeNames.Mutex(session)` = `Local\AHF.supervisor.<session>`. Die Rollen bekommen den Namen mit `--hub`, nur Supervisor und zweite Instanz (`SupervisorCommand` erhält `this.pipe`) bilden ihn. Fällt die SID aus, gilt `A_ComputerName\A_UserName`.
- Python-Zwilling `tests/support/pipenames.py` (`hub_pipe`, `legacy_hub_pipe`); alle Stellen, die `"ahf.%s.hub"` selbst bauten (`faultkit`, `test_ui_stub`, `test_supervisor`, `test_process_crash`, `test_worker`), nutzen ihn. Die Pipes der Python-Hubs in anderen Tests (`ahf.engine.%s` u. a.) sind eigene Namen und bleiben.
- Tests (`tests/integration/test_supervisor.py`): `test_hub_pipe_name_carries_the_windows_session_and_the_user` (Name beginnt mit `ahf.s<id>.u`, der Supervisor meldet genau diesen Namen) und `test_a_foreign_pipe_with_the_old_name_does_not_block_the_start` waren **vorher rot** (Supervisor am alten Namen nicht erreichbar bzw. Start scheitert an der fremden Pipe), danach grün. `test_the_instance_mutex_lives_in_the_namespace_of_the_windows_session` war schon vorher grün (ein unpräfixierter Mutex liegt für normale Prozesse ebenfalls in `Local\`) und bleibt als Absicherung.
- **Nicht geprüft:** zweiter angemeldeter Windows-Benutzer (in dieser Umgebung nicht möglich). Dass die Namen sich dann unterscheiden, folgt aus der Bildung (SID-Hash, Sitzungs-ID) [verifiziert nur für den eigenen Benutzer]. Terminalserver/Dienste nicht geprüft.
- **Option Sicherheitsbeschreibung** (Pipe auf den aktuellen Benutzer beschränken, `ConvertStringSecurityDescriptorToSecurityDescriptorW`): bewertet, nicht umgesetzt. Die Standard-Sicherheitsbeschreibung einer Pipe gibt anderen Benutzern nur Lesezugriff [gelesen aus allgemeinem Windows-Wissen, nicht geprüft]; ein Client braucht Schreibzugriff, ein fremder Benutzer käme also vermutlich nicht über das Öffnen hinaus. Eine ausdrückliche DACL wäre die saubere Absicherung und ist ein eigener Schritt (offener Punkt, F-18).
- Doku: `doc/PROTOKOLL.md` Abschnitt 1.

### Läufe

- Vollständiger Lauf **seriell** (`-n 0`): **503 passed, 1 skipped, 11 deselected in 397 s** [verifiziert, Stand nach dem letzten Commit `c7a07fe`]. `tools/arch_check.py`: 61 Dateien, 0 Verstöße.
- Vollständiger Lauf **parallel** (`python -m pytest tests -q`): in dieser Umgebung **nicht reproduzierbar grün**. Sieben Läufe nach den Korrekturen zeigten je 1 bis 14 Fehlschläge, jedes Mal **nur Zeitbudgets und Verbindungsfristen** der Fault- und Supervisor-Tests (z. B. Beenden 2,1 bis 2,8 s statt 2 s, Orphan 5,1 bis 5,9 s statt 5 s, "pipe not available", Start bis `ready` einmal 10,8 s statt 3 s), nie eine Aussage über Korrektheit; wechselnd verteilt auf andere Tests. Laufzeit 65 bis 190 s statt der dokumentierten 48 s. Ursache **vermutet**, nicht nachgewiesen: Die Maschine war deutlich langsamer als bei WI-18/WI-21 (auf ihr liefen zeitweise ein Spiel und die Radeon-Software mit hoher kumulierter CPU-Zeit; auch bei geringer gemessener Last blieb der Lauf bei 65 bis 110 s). **Vergleichslauf mit dem Stand vor WI-22** (`5a705fc`, eigener Worktree neben dem Repository): 8 Fehlschläge in 67 s (die 3 e2e-Fehler und 1 Error derselben Art wie bei mir; die übrigen 4 betreffen `engine_flow`/`engine_scheduler`/`test_v1_variables` und kommen vermutlich von v1-Dateien, die im Worktree fehlen); `test_shutdown` healthy/two-sessions bei `AHF_FAULT_REPEAT=50 -n 4`: **15 von 100** Runden über dem 2-s-Budget gegenüber **2 von 200** mit WI-22. Die Änderungen verlangsamen also nichts messbar.
- Fault-Tests mit `AHF_FAULT_REPEAT=10` (`-n 4`, 202 Tests, nach `638ce3a`): **197 passed, 5 failed**, alle fünf am Zeitbudget (`test_orphans` 5,91 s, `test_pipe_break` 5,34 s, `test_shutdown` healthy 2,07 s, two-sessions 2,14 und 2,25 s). `test_supervisor_stall` 10 von 10 grün. Der erste Versuch mit `-n 6` (vor `Arm`) zeigte 12 Fehlschläge, 10 davon der Stall-Test (Fehler im Test selbst: Log wurde vor dem Ende gelesen, plus die Lücke vor dem ersten Tick, beide behoben), 2 Zeitbudgets.
- Folgerung: Die Fristen der Fault-Tests (2 s, 5 s, 3 s) sind unter dieser Last zu eng; die Fristen wurden **nicht verändert** (Regel aus WI-18). Wer WI-22 abnimmt, sollte den parallelen Lauf auf einer ruhigen Maschine wiederholen.
- Keine Testprozesse übrig (nur ein fremder `AutoHotkeyU32.exe` des Projektinhabers, nicht angefasst).

### Abweichungen vom Plan

- Punkte 3 und 4 in einem Commit (`ae919f9`), weil sie dieselben Zeilen des Einstiegs ändern.
- `AhfLoadError` beendet den Prozess (`ExitApp(1)`), statt 1 zurückzugeben (Begründung bei Punkt 3).
- Punkt 2: kein 50-fach-Lauf allein, sondern zwei (siehe oben), plus der deterministische Test, der die Ursache beweist.
- `tests/e2e/test_ui_stub.py` (`c7a07fe`): vier Stellen verbanden den Beobachter genau einmal mit 5 s; unter Parallellast scheiterte das (F-02, Muster "Pipe nicht verfügbar"). Jetzt `connect_obs` mit Wiederholung bis 20 s. Das Muster scheitert auch ohne WI-22 (Vergleichslauf), ist also keine Folge der Änderungen. F-02 in der Beobachtungsliste bleibt offen; die Zahlen oben sind weiterer Beleg für die Last als Ursache.
- `tools/arch_check.py`: Ausnahme für `FileAppend` im Einstieg.

### Neue Funde

- **F-16: Fristen des Supervisors außer dem Heartbeat laufen weiter nach der Wanduhr.** `Shutdown.deadlineAt`, die Fristen von `Hub.Request` und das Hello-Zeitlimit des Hubs (`Hub.Tick`) vergleichen mit `Time.NowMs()` und kennen den Stillstand nicht. Steht der Supervisor mitten im Beenden still, läuft die Frist ab und `KillAlive` beendet Kinder, die in Wahrheit fertig sind (ihr `sys.bye` liegt dann ungelesen in der Pipe; das Pump-zuerst von `_Tick` mildert das, weil die Byes vor der Prüfung gelesen werden). Gelesen, nicht reproduziert. Vorschlag: gleiche Lückenerkennung zentral im Supervisor-Tick (eine "Stillstand"-Meldung, die Heartbeat, Shutdown und Hub nutzen), in WI-23/WI-24 mitnehmen.
- **F-17: Kind mit hoher Log-Last gibt in einem langen Stillstand des Supervisors auf.** Gelesen (`PipeConnection.maxQueueFrames` 1000, `Role.LOG_QUEUE_MAX`, `ORPHAN_MS`), nicht getestet. Ein Test bräuchte einen Prozess, der in einer Sekunde über tausend Log-Zeilen erzeugt, solange der Hub eingefroren ist.
- **F-18: Pipe nicht auf den Benutzer beschränkt.** Siehe Punkt 5, Option nicht umgesetzt.
- **F-19: Zeitbudgets der Fault- und Supervisor-Tests sind auf dieser Maschine unter Last zu eng.** Siehe Läufe. In `test_shutdown.py` steht die Prüfung der Zeit vor der Prüfung von `clean`, sodass eine zu langsame Runde die Aussage über `clean` verdeckt; die Reihenfolge der Prüfungen im Test sollte `clean` zuerst prüfen (nicht geändert, WI-29).

### Offene Punkte

- Parallelen Gesamtlauf auf ruhiger Maschine wiederholen (siehe Läufe).
- Zweiter Windows-Benutzer, Standby/Ruhezustand: nicht geprüft.
- F-16 bis F-19 in `STATUS.md` übertragen (WI-29).
