#Requires AutoHotkey v2.0
#Include engine/Engine.ahk
#Include editor/EditorClient.ahk
#Include manager/ManagerClient.ahk
#Include elements/ElementsLoader.ahk

class AHFMainLauncher {
    static Version := "2.0.0-beta"

    __New() {
        this.engine := EngineProcess()
        ElementsLoader.RegisterAll(this.engine)

        this.editor := EditorClient("demo_flow")
        this.manager := ManagerClient()

        this.setupTrayMenu()
    }

    setupTrayMenu() {
        A_IconTip := "AutoHotFlow v2 (" . AHFMainLauncher.Version . ")"
        TraySetIcon("shell32.dll", 44)

        tray := A_TrayMenu
        tray.Delete()
        tray.Add("Open Manager", (*) => this.manager.Show())
        tray.Add("Open Editor", (*) => this.editor.Show())
        tray.Add()
        tray.Add("Run Demo Flow", (*) => this.runDemoFlow())
        tray.Add()
        tray.Add("Exit AutoHotFlow", (*) => this.shutdown())
    }

    runDemoFlow() {
        startCmd := this.editor.startFlow("demo_flow")
        this.engine.ipc.receiveRaw(startCmd)
    }

    shutdown() {
        shutdownCmd := this.editor.shutdownSystem()
        this.engine.ipc.receiveRaw(shutdownCmd)
        ExitApp()
    }
}

; Entry point
if (A_LineFile == A_ScriptFullPath) {
    launcher := AHFMainLauncher()
    launcher.runDemoFlow()
}
