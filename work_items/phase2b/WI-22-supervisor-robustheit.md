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
