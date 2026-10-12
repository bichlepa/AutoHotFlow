# Teststrategie

Status: Entwurf. Werkzeuge in dieser Umgebung geprüft: AutoHotkey v2 unter `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`, Python 3.13, `psutil` vorhanden, `pytest` muss installiert werden (`pip install -r tests/requirements.txt`).

## 1. Prinzipien

1. **pytest ist der Treiber für alles.** AHK-Code wird als echter Prozess gestartet, nicht simuliert.
2. **Python spricht das Protokoll.** `tests/support/ahfclient.py` implementiert Rahmen, `sys.hello` und Weckruf (`ctypes.windll.user32.PostMessageW`). Damit lässt sich jede Rolle gegen eine echte Hub-Verbindung prüfen. Im Spike bestätigt: `open(r"\\.\pipe\...", "r+b", buffering=0)` verbindet sich mit einer AHK-v2-Pipe.
3. **Nichts hängt unbemerkt.** Jeder Test hat ein hartes Zeitlimit (`pytest-timeout`), jeder gestartete Prozess wird in einer Fixture verfolgt und am Ende samt Kindern beendet (`psutil`).
4. **Isolation.** Jeder Test bekommt ein eigenes temporäres Datenverzeichnis (`--data=<dir>`) und eine eigene Session-ID, damit Pipe-Namen nicht kollidieren und Tests parallel laufen können.
5. **Echte Daten nur als Kopie.** Round-Trip-Tests arbeiten mit Kopien der Flows aus `v1/AppData/Saved Flows` (nach `tests/data/flows/`). Nie in `v1/` schreiben.

## 2. Ebenen

| Ebene | Ort | Wie | Zweck |
|---|---|---|---|
| **L1 Unit (AHK)** | `tests/ahk/*.test.ahk` | Kleine Assert-Bibliothek `tests/ahk/lib/Assert.ahk`, ein Skript pro Datei, Ergebnis als JSON-Zeilen in eine Datei. pytest sammelt die Dateien, startet sie und wertet das Ergebnis aus. | reine Logik: JSON, IDs, Zustandsautomaten, Parser/Evaluator, Rahmenbildung |
| **L2 Integration** | `tests/integration/` | Eine oder zwei Rollen real starten, Python-Client als Gegenstelle. | IPC, Dispatcher, Timeouts, Supervisor-Hub, Storage-Queue |
| **L3 e2e** | `tests/e2e/` | Gesamtsystem (Supervisor, Engine, Storage, Triggerhost, UI-Stub). Python verhält sich wie ein Editor/Manager. | Flow läuft, Ereignisse kommen an, Start/Stop/Shutdown |
| **L4 Fault Injection** | `tests/fault/` | Prozesse beenden (`kill`), einfrieren (`psutil.Process.suspend()`), Pipe schließen, Antworten verzögern. | Absturz, Hänger, Timeout ohne Hänger im Gesamtsystem |
| **L5 Stress** | `tests/stress/` | viele Instanzen, schnelle Start/Stop-Folgen, Clients verbinden und trennen unter Last. Zeitbudget fest, Ergebnis als Bericht. | Race Conditions, Leaks, Nachrichtenstau |
| **L6 Charakterisierung** | `tests/golden/` | Ein- und Ausgaben des v1-Verhaltens als Daten (JSON). v2 muss sie reproduzieren. | Ausdrucksauswertung, Variablenersetzung, Verbindungsauswahl, Laden/Speichern |

## 3. Wichtige Szenarien

**Fault Injection (L4), jedes mit Erwartung „System bleibt bedienbar, nichts hängt, Fehler ist gemeldet“:**

| Szenario | Erwartung |
|---|---|
| Editor-Prozess wird beendet | Supervisor meldet `evt.process.crashed`, Engine und andere Editoren unberührt, Topic-Abos des Editors verschwinden |
| Editor wird eingefroren (`suspend`) | Nach 3 verpassten Pings als hängend erkannt, beendet, restliche Rollen laufen |
| Engine wird beendet | Neustart, `evt.engine.restarted`, Clients machen Resync, Trigger neu armiert |
| Engine wird eingefroren | wie oben nach Ping-Timeout |
| Storage antwortet nicht (eingefroren) | Anfragen laufen in Timeout, Engine blockiert nicht, `evt.storage.error` |
| Worker stürzt während Ausführung ab | Thread endet mit `exception`, Engine läuft weiter, Ersatz wird angefordert (WI-27, `tests/fault/test_worker_lifecycle.py`) |
| Worker blockiert in einem Aufruf, Abbruch oder Jobfrist | Instanz endet sofort, nach 2 s wird der Prozess beendet, der nächste Job läuft auf einem neuen Worker (WI-27) |
| Engine stirbt während eines Worker-Jobs | die neue Engine beendet die Waisen, der Pool baut sich neu auf, der nächste Job läuft (WI-27) |
| Fünf Fehler eines Pools in einer Minute | keine neuen Worker, Worker-Elemente enden mit "worker not available" (WI-27) |
| Snapshot jeder Rolle (`cmd.diag.snapshot`) | allgemeiner Teil und Rollenteil im festen Schema, keine Inhalte von Variablen und Flows (WI-28, `tests/fault/test_snapshot.py`, Schema in `tests/support/snapshotschema.py`) |
| Absturzbericht mit allen Rollen, eingefrorener Rolle, abgestürztem Storage | Ordner `Reports/<Zeit>_<Grund>/` mit je Rolle einem Eintrag und lesbarer Zusammenfassung; die eingefrorene Rolle ist als "keine Antwort" vermerkt, der Bericht ist binnen der Frist da; ohne Storage wartet er und bleibt im Speicher (WI-28, `tests/fault/test_report.py`) |
| Automatischer Bericht nach Absturz, Hänger, Fehlerhäufung | genau ein Bericht je Minute, der Rest wird gezählt, keiner beim Beenden (WI-28) |
| Debug-Fenster: `--command=debug`, Schließen, Fenster | startet die Rolle einmal, Schließen ist kein Absturz, das Fenster öffnet und schließt wie beim Benutzer (WI-28, `tests/fault/test_debug_role.py`; Bedienung von Hand: Ergebnis in `work_items/phase2b/WI-28-diagnose-bericht-debugfenster.md`) |
| Pipe wird vom Client abrupt geschlossen | Hub räumt auf, Ausstehende Anfragen an ihn bekommen `peer_gone` |
| Supervisor wird hart beendet | Alle Kinder beenden sich nach der Orphan-Frist |
| Shutdown mit hängendem Prozess | Gesamtdauer unter Frist plus Toleranz, hängender Prozess hart beendet |
| Anfrage ohne Antwort | Aufrufer erhält `timeout` nach der Frist, spätere Antwort wird verworfen |

**Stresstest (L5), Mindestumfang:**

1. 200 Instanzen eines einfachen Flows parallel starten, alle müssen enden, keine Zustände bleiben `running`.
2. 1000 schnelle Start/Stop-Wechsel eines Flows, danach Zähler und Zustände konsistent.
3. 20 Editoren (Python-Clients) verbinden und trennen im Wechsel, während ein Flow läuft. Keine verlorene Engine-Antwort, Engine-Latenz bleibt im Budget.
4. Dauerlauf (Minuten, nicht Sekunden), Prozessanzahl und Speicher stabil.
5. Ausgabe als Bericht mit Latenzverteilung, damit Vorher/Nachher vergleichbar ist.

Hinweis: Die v1-Hänger waren nie zuverlässig reproduzierbar. Ein Vergleichstest gegen v1 ist deshalb nicht Teil der Abnahme. Stattdessen gilt: Die Szenarien oben laufen in v2 wiederholt (z. B. 50 Durchläufe) ohne ein einziges Hängen.

## 4. Round-Trip und Kompatibilität

- Für jede Datei in `tests/data/flows/*.json`: laden, speichern, erneut laden. Die geparsten Strukturen müssen **inklusive Typen** gleich sein (`"1"` bleibt String). Unbekannte Schlüssel bleiben erhalten.
- Variablen: `.ahfvd`/`.ahfvar`-Paare lesen und schreiben, identischer Inhalt.
- `.ahf`-Export/Import: Round-Trip über ZIP.
- Vorhandene Testflows (Kategorie „Automatic tests“ in `v1/AppData/Saved Flows`) dienen später als Akzeptanzflows für die Engine (laufen, Ergebnis prüfen).

## 5. Struktur des Verzeichnisses `tests/`

```
tests/
├─ requirements.txt           # pytest, pytest-timeout, psutil
├─ conftest.py                # Fixtures: ahk_exe, datadir, run_role, hub (Python-Hub für Rollentests), cleanup
├─ support/
│  ├─ ahfclient.py            # Rahmen, Hello, Wake, request/response mit Timeout
│  ├─ procs.py                # Start/Kill/Suspend-Hilfen, Prozessbaum-Aufräumen
│  └─ ahk.py                  # Suche des AHK-Interpreters (Umgebungsvariable AHF_AHK2_EXE, Standardpfad)
├─ ahk/
│  ├─ lib/Assert.ahk
│  └─ *.test.ahk
├─ integration/  e2e/  fault/  stress/  golden/
└─ data/flows/                # Kopien echter v1-Flows
```

## 6. Ausführung

```
pip install -r tests/requirements.txt
pytest tests/ahk tests/integration -q            # schnell
pytest tests/e2e tests/fault -q                  # Gesamtsystem
pytest tests/stress -q -m stress                 # lang, nur auf Wunsch
```

**Parallel (Standard seit WI-18).** `pytest.ini` setzt `addopts = -n auto --dist loadgroup` (pytest-xdist, auf diesem Rechner 8 Worker). `python -m pytest tests -q` läuft damit in rund 50 s (seriell rund 340 s). Seriell: `-n 0`. Regeln dazu:

- Läufe mit `-m stress` oder `-m soak` schaltet `tests/conftest.py` (`pytest_cmdline_main`) selbst auf einen Prozess. Messungen (Idle-CPU, Latenz, Speicher) dürfen nie parallel zu anderer Last laufen.
- Der Marker für Gruppen ist `@pytest.mark.xdist_group("name")` (mit `--dist loadgroup` laufen Tests derselben Gruppe auf demselben Worker nacheinander). Bisher ist keine Gruppe nötig.
- **Zeitgrenzen (WI-32).** Eine obere Zeitgrenze, die ein Versprechen des Produkts prüft ("die Rolle endet binnen 1 s", "Absturz binnen 1 s gemeldet"), läuft über `support.timing.scaled()`: im seriellen Lauf (`-n 0`, `-m stress`, `-m soak`) gilt sie unverändert (das ist die Referenz), in einem parallelen Lauf (xdist-Worker) mit dem Faktor 3 (`AHF_TIMING_FACTOR` überschreibt ihn, `1` ist streng). Nur **obere** Grenzen werden skaliert, nie untere (ein Timeout darf nicht zu früh feuern), nie Anzahlen oder Ergebnisse. Ein roter Test im parallelen Lauf heißt dann "viel zu langsam", nicht "auf einer ausgelasteten Maschine etwas langsam". Eine neue Zeitgrenze, die ein Produktversprechen prüft, gehört durch `scaled()`; Messungen mit festen Zahlen (Durchsatz, Latenz-Verteilung) gehören nach `-m stress`.
- **Auf Zustände warten, nicht auf Ereignisse.** Ein Test, der erst nach dem `sys.hello` einer Rolle abonniert, kann deren Ereignis (z. B. `evt.engine.ready`) verpassen (PROTOKOLL 5a). Entweder vor dem Start der Rolle abonnieren oder auf den Zustand warten (`Chain.wait_flows`, `cmd.process.list`).
- **Echte Zeit in AHK-Unit-Tests.** `WriteQueue` nimmt eine Uhr entgegen (`WriteQueue(clock)`), die Unit-Tests übergeben eine eigene, und `storage_queue.test.ahk` setzt `Critical`, damit der Timer der Warteschlange nicht mitten im Fall Operationen abarbeitet.
- Jeder Test braucht eigene Namen (Sitzung, Datenverzeichnis, Pipe). Keine Zählung "aller AutoHotkey-Prozesse", Prozesse immer über die Sitzungs-ID im Befehl erkennen (`faultkit.session_processes`).
- AHK-Testskripte brauchen `#SingleInstance Off` (steht in `tests/ahk/lib/Assert.ahk` und den Helfern), sonst fragt AHK beim zweiten gleichzeitigen Start desselben Skripts nach und der Dialog-Wächter beendet den Lauf (Exit 15).

Umgebungsvariablen: `AHF_AHK2_EXE` (Pfad zum Interpreter), `AHF_TEST_KEEP=1` (Datenverzeichnisse nach dem Test behalten).
