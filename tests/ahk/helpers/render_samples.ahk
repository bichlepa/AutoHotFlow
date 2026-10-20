#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Screenshots of the editor drawing (WI-0085, E0088): each flow file is drawn offscreen by the real Renderer at zoom 0.7
; and 1.5 and written as a PNG. No window, no dialog. The owner judges the look from these files; a PNG is not a test.
;
; A_Args[1] = output folder (created if missing), [2] = result file (one line per PNG is appended), [3..] = flow files
; (the parsed flow of each is drawn, as the editor reads it).
;
; Usage: python tools/ahkrun.py --timeout 300 tests/ahk/helpers/render_samples.ahk <folder> <result file> <flow file>...
#Include ..\..\..\src\core\AhfError.ahk
#Include ..\..\..\src\core\Json.ahk
#Include ..\..\..\src\editor\EditorView.ahk
#Include ..\..\..\src\editor\SceneBuilder.ahk
#Include ..\..\..\src\elements\Default\_includes_engine.ahk
#Include ..\..\..\src\editor\render\Renderer.ahk

SAMPLE_W := 1100
SAMPLE_H := EnvGet("AHF_SAMPLE_H") != "" ? Integer(EnvGet("AHF_SAMPLE_H")) : 800   ; the picture height (px)
; the zooms of the pictures; AHF_SAMPLE_ZOOMS="1.0,1.5" (comma separated) overrides them for one run
ZOOMS := EnvZooms()

EnvZooms() {
    list := EnvGet("AHF_SAMPLE_ZOOMS")
    if (list = "")
        return [0.7, 1.5]
    zooms := []
    for part in StrSplit(list, ",")
        zooms.Push(Number(Trim(part)))
    return zooms
}

; The base name of a path without the folder and the extension.
BaseName(path) {
    SplitPath(StrReplace(path, "/", "\"), , , , &name)   ; SplitPath splits at backslashes only
    return name
}

Main(args) {
    outDir := StrReplace(args[1], "/", "\")     ; GDI+ fails (Win32Error) on a path with forward slashes
    resultFile := args[2]
    DirCreate(outDir)
    r := Renderer()
    try {
        loop args.Length - 2 {
            flowPath := args[A_Index + 2]
            raw := Json.Parse(FileRead(flowPath, "UTF-8"))
            for zoom in ZOOMS {
                ; the view starts 40 pixels before the flow's box, so the whole flow is in the picture at the top left
                probe := SceneBuilder.Build(raw, EditorView(zoom, 0, 0, 96, SAMPLE_W, SAMPLE_H))
                ox := probe.Bounds.X - 40 / zoom
                oy := probe.Bounds.Y - 40 / zoom
                scene := SceneBuilder.Build(raw, EditorView(zoom, ox, oy, 96, SAMPLE_W, SAMPLE_H))
                c := GdipCanvas(SAMPLE_W, SAMPLE_H)
                try {
                    r.Draw(scene, c)
                    png := outDir "\" BaseName(flowPath) "_zoom" Format("{:.1f}", zoom) ".png"
                    c.SavePng(png)
                    FileAppend("PNG " png " elements=" scene.Elements.Length " connections="
                        . scene.Connections.Length " warnings=" scene.Warnings.Length "`n", resultFile)
                } finally
                    c.Destroy()
            }
        }
    } finally
        r.Destroy()
    return 0
}

ExitApp(RunGuarded(A_Args))

RunGuarded(args) {
    Gdip.Startup()
    try
        return Main(args)
    catch as failure {
        FileAppend("ERROR " failure.Message " (" failure.File ":" failure.Line ")`n", args[2])
        return 1
    } finally
        Gdip.Shutdown()
}
