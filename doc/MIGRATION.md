# Migration v1 → v2: bewusste Verhaltensänderungen

Wird laufend ergänzt. Stille Verhaltensänderungen sind nicht erlaubt: Alles, was in v2 absichtlich anders ist, steht hier.

| ID | Bereich | v1 | v2 | Grund | Status |
|---|---|---|---|---|---|
| M-01 | Absturz der Engine | Absturz des einen Prozesses beendet alles, laufende Instanzen sind weg | Supervisor startet die Engine neu, laufende Instanzen sind weg, UIs bleiben verbunden und synchronisieren neu | Architektur (Prozesse) | geplant |
| M-02 | Dialog-Elemente (`Message_Box`, `Input_Box`, `Select_file`, `Confirmation_Dialog` usw.) | Dialog öffnet sich aus dem Execution-Thread | Dialog öffnet sich aus einem Worker-Prozess. Fensterreihenfolge/Fokus können leicht abweichen. | Engine darf nicht blockieren | geplant |
| M-03 | Hotkey-Trigger `Disable` | `hotkey, <key>, off` ohne Fensterkontext, kontextgebundener Hotkey kann aktiv bleiben | gleicher `HotIf`-Kontext wie beim Aktivieren | Fehlerbehebung | geplant |
| M-04 | Fehler in `Element_run` | Fehlerpfade riefen in 6 Elementen `x_enabled` statt `x_finish` auf, das Element endete nie | Fehler sind Exceptions, die Engine setzt Ergebnis `exception` | Fehlerbehebung | geplant |
| M-05 | Logs | mehrere Threads schreiben unter globalem Lock | `storage` schreibt als einziger. Dateinamen und Format unverändert. | Architektur | geplant |
| M-06 | Variablen `global`/`static` | direkte Dateizugriffe unter Lock | Engine hält Arbeitskopie im Speicher, `storage` schreibt asynchron (write-behind). Beim Beenden wird gespült. | I/O nie im kritischen Pfad | geplant |
| M-07 | Flow speichern | läuft unter Lock im Aufrufer-Thread, `MsgBox` für Demo-Flows. Schreiben per `FileDelete` + `FileAppend` (Absturz dazwischen verliert die Datei). Das Backup verschiebt `<name>.txt` statt `.json` und erzeugt daher nie ein Backup (`Save.ahk:124-146`). | `storage` schreibt atomar (Temp-Datei + Ersetzen) und legt tatsächlich Backups an (höchstens 10). Hinweis für Demo-Flows kommt als UI-Meldung, nicht aus der Engine. | I/O nie im kritischen Pfad, Datensicherheit | geplant |
| M-08 | Fehlende Pakete beim Laden | `MsgBox` mit Abfrage im Lock, Datei wird bei „Ja“ gelöscht | Engine meldet `cmd.ui.confirmDeleteFlowFile` an den Manager | Dialoge nur in UI | geplant |
| M-09 | Chrome-Paket | vorhanden | entfällt | Entscheidung des Projektinhabers | beschlossen |
| M-10 | Beenden | `criticalSectionCounter`, 4-s-Notbremse | zweiphasig mit Quittungen, Frist 5 s | Architektur | geplant |
