#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Measurement for WI-0085 (E0090, REQ-PRF-060): the real Renderer (src/editor/render/Renderer.ahk) draws a flow of 300
; elements and 350 connections, built by SceneBuilder from a flow Map, into a canvas of the window size. Not a unit test;
; it runs by hand (VS Code task "Tool: renderer measurement (WI-0085)"), one case per start, serially and alone.
;
; Three series per case (all on the same renderer):
;   states  a frame in which only the run states change: the scene alternates between two scenes with other elements
;           running (30 running elements each), the layer is not rebuilt. The target is below 16 ms at 1920 x 1080.
;   same    a frame of an unchanged scene (the overlays of the running elements only).
;   rebuild the static layer built again (Invalidate, then a frame): the cost of a change of the flow, the zoom or the
;           pan out of the layer.
; Also the cost of the scene itself (SceneBuilder.Build of a changed flow), which the window pays on a state change
; before the frame: that is not part of the frame and is reported apart.
;
; A_Args[1] = result file (one line RESULT ... is appended), [2] width, [3] height, [4] view: whole (the whole flow
; visible) or zoom1 (zoom 1), [5] frames (default 100), [6] warm-up frames (default 10), [7] rebuilds (default 10).
;
; Usage: python tools/ahkrun.py --timeout 900 tests/ahk/helpers/renderer_bench.ahk <result file> 1920 1080 whole
#Include ..\..\..\src\core\AhfError.ahk
#Include ..\..\..\src\core\Json.ahk
#Include ..\..\..\src\editor\EditorView.ahk
#Include ..\..\..\src\editor\SceneBuilder.ahk
#Include ..\..\..\src\elements\Default\_includes_engine.ahk
#Include ..\..\..\src\editor\render\Renderer.ahk

Lcg(&seed, n) {
    seed := Mod(seed * 1103515245 + 12345, 2147483648)
    return Mod(seed // 65536, n)
}

; The flow as a parsed Map: the same layout as render_bench.ahk (20 columns, 200 x 150 units apart), the four kinds of
; elements in turn (action, condition, loop, trigger), names of 10 to 30 characters, 350 connections between random
; elements, every third one labelled "yes".
BuildFlow() {
    nameText := "Set variable to the value of the expression and wait for the answer of the flow"
    seed := 20261019
    kinds := [["action", "action_Sleep"], ["condition", "Condition_Expression"], ["loop", "Loop_SimpleLoop"],
        ["trigger", "Trigger_Manual"]]
    elements := Map()
    ids := []
    loop 300 {
        i := A_Index - 1
        id := Format("e{:04}", i)
        len := 10 + Lcg(&seed, 21)
        kind := kinds[Mod(i, 4) + 1]
        element := Map("ID", id, "type", kind[1], "class", kind[2], "package", "Default",
            "x", Mod(i, 20) * 200, "y", (i // 20) * 150, "name", SubStr(nameText, 1, len))
        if (kind[1] = "loop")
            element["HeightOfVerticalBar"] := 40
        elements[id] := element
        ids.Push(id)
    }
    connections := Map()
    loop 350 {
        a := Lcg(&seed, 300)
        b := Lcg(&seed, 299)
        if (b >= a)
            b += 1
        cid := Format("c{:04}", A_Index)
        connections[cid] := Map("ID", cid, "from", ids[a + 1], "to", ids[b + 1],
            "ConnectionType", Mod(A_Index, 3) = 0 ? "yes" : "normal")
    }
    return [Map("allElements", elements, "allConnections", connections), ids]
}

; The run states of a scene: the elements whose index mod 10 equals phase run ("running").
RunStates(ids, phase) {
    states := Map()
    for i, id in ids {
        if (Mod(i - 1, 10) = phase)
            states[id] := "running"
    }
    return states
}

; The view of a case: the whole flow fitted into the window, or zoom 1 at a part of the flow.
ViewFor(view, W, H) {
    if (view = "whole") {
        z := Min((W - 40) / 3940, (H - 40) / 2205)
        return EditorView(z, -20 / z, -20 / z, 96, W, H)
    }
    return EditorView(1.0, 1000, 500, 96, W, H)
}

; Mean, median, 95th percentile and maximum of a list of numbers (the list is copied).
Stats(list) {
    sorted := list.Clone()
    loop sorted.Length - 1 {                 ; insertion sort (an Array has no Sort method in v2)
        i := A_Index + 1
        v := sorted[i]
        j := i - 1
        while (j >= 1 && sorted[j] > v) {
            sorted[j + 1] := sorted[j]
            j -= 1
        }
        sorted[j + 1] := v
    }
    sum := 0
    for v in list
        sum += v
    n := list.Length
    return Map("mean", sum / n, "median", sorted[(n + 1) // 2], "p95", sorted[Min(n, Integer(Ceil(n * 0.95)))],
        "max", sorted[n])
}

Main(args) {
    if (args.Length < 4) {
        FileAppend("ERROR usage: result width height whole|zoom1 [frames] [warm-up] [rebuilds]`n", args[1])
        return 2
    }
    resultFile := args[1]
    W := Integer(args[2])
    H := Integer(args[3])
    view := args[4]
    frames := args.Length >= 5 ? Integer(args[5]) : 100
    warm := args.Length >= 6 ? Integer(args[6]) : 10
    rebuilds := args.Length >= 7 ? Integer(args[7]) : 10
    built := BuildFlow()
    raw := built[1]
    ids := built[2]
    vw := ViewFor(view, W, H)
    sceneA := SceneBuilder.Build(raw, vw, RunStates(ids, 3))
    sceneB := SceneBuilder.Build(raw, vw, RunStates(ids, 4))
    c := GdipCanvas(W, H)
    r := Renderer()
    statesTimes := []
    sameTimes := []
    rebuildTimes := []
    buildTimes := []
    try {
        loop warm
            r.Draw(A_Index & 1 ? sceneA : sceneB, c)
        loop frames {
            frameScene := (A_Index & 1) ? sceneA : sceneB
            t0 := Renderer.Now()
            r.Draw(frameScene, c)
            statesTimes.Push(Renderer.Now() - t0)
        }
        loop frames {
            t0 := Renderer.Now()
            r.Draw(sceneA, c)
            sameTimes.Push(Renderer.Now() - t0)
        }
        loop rebuilds {
            r.Invalidate()
            t0 := Renderer.Now()
            r.Draw(sceneA, c)
            rebuildTimes.Push(Renderer.Now() - t0)
        }
        loop rebuilds {
            t0 := Renderer.Now()
            SceneBuilder.Build(raw, vw, RunStates(ids, A_Index & 1 ? 3 : 4))
            buildTimes.Push(Renderer.Now() - t0)
        }
        snap := r.Snapshot()
        st := Stats(statesTimes)
        sm := Stats(sameTimes)
        rb := Stats(rebuildTimes)
        bd := Stats(buildTimes)
        times := ""
        for ms in statesTimes
            times .= (A_Index = 1 ? "" : ",") Format("{:.3f}", ms)
        FileAppend(Format("RESULT view={1} width={2} height={3} zoom={4:.4f} elements={5} connections={6} running=30 "
            . "frames={7} warmup={8} states_mean={9:.3f} states_median={10:.3f} states_p95={11:.3f} states_max={12:.3f} "
            . "same_mean={13:.3f} same_median={14:.3f} same_p95={15:.3f} rebuilds={16} rebuild_mean={17:.3f} "
            . "rebuild_median={18:.3f} rebuild_max={19:.3f} scene_build_mean={20:.3f} scene_build_max={21:.3f} "
            . "layer_rebuilds={22} ahk={23} os={24} cpus={25} times_states={26}`n", view, W, H, vw.Zoom, 300,
            350, frames, warm, st["mean"], st["median"], st["p95"], st["max"], sm["mean"], sm["median"], sm["p95"],
            rebuilds, rb["mean"], rb["median"], rb["max"], bd["mean"], bd["max"], snap["rebuilds"], A_AhkVersion,
            A_OSVersion, EnvGet("NUMBER_OF_PROCESSORS"), times), resultFile)
    } finally {
        r.Destroy()
        c.Destroy()
    }
    return 0
}

ExitApp(RunGuarded(A_Args))

RunGuarded(args) {
    Gdip.Startup()
    try
        return Main(args)
    catch as failure {
        FileAppend("ERROR " failure.Message " (" failure.File ":" failure.Line ")`n", args[1])
        return 1
    } finally
        Gdip.Shutdown()
}
