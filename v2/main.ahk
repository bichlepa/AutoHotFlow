#Requires AutoHotkey v2.0
#Include engine/Engine.ahk
#Include editor/EditorClient.ahk

class AHFMainLauncher {
    static Version := "2.0.0-alpha"

    __New() {
        this.engine := EngineProcess()
        this.editor := EditorClient()
    }

    runSkeletonDemo() {
        ; 1. Editor requests Engine to start Flow
        startCmd := this.editor.startFlow("flow_demo_101")
        this.engine.ipc.receiveRaw(startCmd)

        ; 2. Editor requests Graceful Shutdown
        shutdownCmd := this.editor.shutdownSystem()
        this.engine.ipc.receiveRaw(shutdownCmd)
    }
}

; Entry point
launcher := AHFMainLauncher()
launcher.runSkeletonDemo()
