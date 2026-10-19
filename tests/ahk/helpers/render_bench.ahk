#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Measurement for WI-0083 (risk R0002, REQ-PRF-060): how long one frame of a flow with 300 elements and 350 connections
; takes in the GDI+ wrapper. Not a unit test; tools/measure_render.py runs it for the cases and reads the result line.
; The scene draws the way v1 draws (Source_Draw/GDIp/GDIp.ahk): per element a rounded fill, a border, an icon and the
; name (font and format created per call, as Gdip_TextToGraphics does), per connection five line segments, a third of
; them with a label yes/no; 30 elements tinted as running. Pens, brushes and icons are created once, as in v1.
; Grid dots: v1 draws them only above zoom 1; the optional argument dots forces them on for information.
;
; A_Args[1] = result file (the line RESULT ... is appended), [2] width, [3] height, [4] view: whole (the whole flow
; visible) or zoom1 (zoom 1, only a part visible, the rest culled), [5] aa: on or off, [6] frames (default 100),
; [7] warm-up frames (default 10), [8] dots: auto (v1 rule), on or off (default auto), [9] parts: the letters of the
; parts that are drawn: e element shapes (fill and border), i icons, t names, c connection segments, l labels,
; r only the elements that are running (their shapes, icons and names), b a BitBlt of a cached layer (a second
; canvas of the same size) into the target (the cost of showing a static layer). Default eticl. A breakdown or a
; remedy run leaves out parts; the result line shows them. [10] icons: big (the files of the Default package,
; 201 x 232 and 195 x 259 pixels) or small (Tooltip.png, 80 x 50 pixels, a proxy for icons scaled once in advance).
;
; Usage: python tools/ahkrun.py --timeout 600 tests/ahk/helpers/render_bench.ahk <result file> 1920 1080 whole on
#Include ..\..\..\src\core\AhfError.ahk
#Include ..\..\..\src\editor\render\Gdip.ahk
#Include ..\..\..\src\editor\render\GdipBrush.ahk
#Include ..\..\..\src\editor\render\GdipPen.ahk
#Include ..\..\..\src\editor\render\GdipFont.ahk
#Include ..\..\..\src\editor\render\GdipFormat.ahk
#Include ..\..\..\src\editor\render\GdipImage.ahk
#Include ..\..\..\src\editor\render\GdipCanvas.ahk

; Deterministic pseudo random numbers, so that every run draws the same scene.
Lcg(&seed, n) {
    seed := Mod(seed * 1103515245 + 12345, 2147483648)
    return Mod(seed // 65536, n)
}

; The flow: 300 elements on a grid of 20 columns (200 x 150 units apart, element 140 x 105), 350 connections between
; random pairs, element names of 10 to 30 characters.
BuildScene() {
    nameText := "Set variable to the value of the expression and wait for the answer of the flow"
    seed := 20261019
    els := []
    loop 300 {
        i := A_Index - 1
        len := 10 + Lcg(&seed, 21)
        els.Push(Map("x", Mod(i, 20) * 200, "y", (i // 20) * 150, "kind", Mod(i, 4), "name", SubStr(nameText, 1, len)
            , "icon", Mod(i, 2), "running", Mod(i, 10) = 3))
    }
    cons := []
    loop 350 {
        a := Lcg(&seed, 300)
        b := Lcg(&seed, 299)
        if (b >= a)
            b += 1
        ea := els[a + 1]
        eb := els[b + 1]
        fx := ea["x"] + 70
        fy := ea["y"] + 105
        tx := eb["x"] + 70
        ty := eb["y"]
        d := 15
        mx := (fx + tx) / 2
        midY := (fy + ty) / 2
        segs := [[fx, fy, fx, fy + d], [fx, fy + d, mx, fy + d], [mx, fy + d, mx, ty - d], [mx, ty - d, tx, ty - d]
            , [tx, ty - d, tx, ty]]
        label := Mod(A_Index, 3) = 0 ? (Mod(A_Index, 6) = 0 ? "yes" : "no") : ""
        cons.Push(Map("segs", segs, "label", label, "mx", mx, "midY", midY
            , "minX", Min(fx, tx), "maxX", Max(fx, tx), "minY", Min(fy, ty), "maxY", Max(fy, ty) + d))
    }
    return Map("els", els, "cons", cons)
}

; The view: zoom and offset in world units. whole fits the flow into the window, zoom1 shows a part at zoom 1.
ViewFor(view, W, H) {
    if (view = "whole") {
        z := Min((W - 40) / 3940, (H - 40) / 2205)
        return Map("z", z, "ox", -20 / z, "oy", -20 / z)
    }
    return Map("z", 1.0, "ox", 1000.0, "oy", 500.0)
}

; The objects that v1 creates once: brushes, pens, icons, and the cached layer of the part b.
MakeResources(W, H, iconSet) {
    res := Map()
    try {
        res["layer"] := GdipCanvas(W, H)
        res["layer"].Clear(0xFFEAF0EA)
        res["fill0"] := GdipBrush(0xFFDDEBFA)
        res["fill1"] := GdipBrush(0xFFFFF4CC)
        res["fill2"] := GdipBrush(0xFFE3F5E3)
        res["fill3"] := GdipBrush(0xFFEFE3FA)
        res["run"] := GdipBrush(0xFFFFD6D6)
        res["text"] := GdipBrush(0xFF000000)
        res["label"] := GdipBrush(0xFF0044AA)
        res["dot"] := GdipBrush(0xFF000000)
        res["border"] := GdipPen(0xFF555566, 2.0)
        res["conn"] := GdipPen(0xFF333333, 2.0)
        iconDir := A_ScriptDir "\..\..\..\src\elements\Default\Icons\"
        if (iconSet = "small") {
            res["icon0"] := GdipImage(iconDir "Tooltip.png")
            res["icon1"] := GdipImage(iconDir "Tooltip.png")
        } else {
            res["icon0"] := GdipImage(iconDir "Sleep.ico")
            res["icon1"] := GdipImage(iconDir "Bug.png")
        }
    } catch as failure {
        DestroyResources(res)
        throw failure
    }
    return res
}

DestroyResources(res) {
    for key, obj in res
        obj.Destroy()
}

; One frame. Returns the counts of what was drawn.
DrawFrame(c, scene, vw, W, H, res, dotsOn, parts) {
    z := vw["z"]
    ox := vw["ox"]
    oy := vw["oy"]
    counts := Map("els", 0, "cons", 0, "labels", 0, "dots", 0)
    doC := InStr(parts, "c")
    doL := InStr(parts, "l")
    doE := InStr(parts, "e")
    doI := InStr(parts, "i")
    doT := InStr(parts, "t")
    doB := InStr(parts, "b")
    doR := InStr(parts, "r")
    c.Clear(0xFFEAF0EA)
    if (doB)
        res["layer"].CopyToDc(c.hdc, 0, 0)
    if (dotsOn) {
        wx := Floor(ox / 35) * 35
        while (wx < ox + W / z) {
            wy := Floor(oy / 35) * 35
            while (wy < oy + H / z) {
                c.FillRect(res["dot"], (wx - ox) * z - 1, (wy - oy) * z - 1, 2, 2)
                counts["dots"] += 1
                wy += 35
            }
            wx += 35
        }
    }
    for cn in scene["cons"] {
        ; culling: the bounding box of the connection must meet the window
        if ((cn["maxX"] - ox) * z < 0 || (cn["minX"] - ox) * z > W || (cn["maxY"] - oy) * z < 0
            || (cn["minY"] - oy) * z > H)
            continue
        counts["cons"] += 1
        if (doC)
            for s in cn["segs"]
                c.DrawLine(res["conn"], (s[1] - ox) * z, (s[2] - oy) * z, (s[3] - ox) * z, (s[4] - oy) * z)
        if (doL && cn["label"] != "") {
            counts["labels"] += 1
            f := GdipFont("Segoe UI", 10.5 * z, 1)
            fmt := GdipFormat(1, 1, false, false)
            try
                c.DrawText(res["label"], f, fmt, cn["label"], (cn["mx"] - ox) * z + 4 * z, (cn["midY"] - oy) * z - 8 * z
                    , 30 * z, 16 * z)
            finally {
                fmt.Destroy()
                f.Destroy()
            }
        }
    }
    for el in scene["els"] {
        sx := (el["x"] - ox) * z
        sy := (el["y"] - oy) * z
        sw := 140 * z
        sh := 105 * z
        if (sx + sw < 0 || sx > W || sy + sh < 0 || sy > H)
            continue
        if (doR && !el["running"])
            continue
        counts["els"] += 1
        if (doE) {
            brush := el["running"] ? res["run"] : res["fill" el["kind"]]
            c.FillRoundRect(brush, sx, sy, sw, sh, 30 * z)
            c.DrawRoundRect(res["border"], sx, sy, sw, sh, 30 * z)
        }
        if (doI)
            c.DrawImage(res["icon" el["icon"]], sx + sw / 2 - 24 * z, sy + 8 * z, 48 * z, 48 * z)
        if (doT) {
            f := GdipFont("Segoe UI", 15 * z, 1)
            fmt := GdipFormat(1, 1, true, true)
            try
                c.DrawText(res["text"], f, fmt, el["name"], sx + 4 * z, sy + 60 * z, sw - 8 * z, 40 * z)
            finally {
                fmt.Destroy()
                f.Destroy()
            }
        }
    }
    return counts
}

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}

Main(args) {
    if (args.Length < 5) {
        FileAppend("ERROR usage: result width height whole|zoom1 on|off [frames] [warm-up] [dots]`n", args[1])
        return 2
    }
    resultFile := args[1]
    W := Integer(args[2])
    H := Integer(args[3])
    view := args[4]
    aa := args[5]
    frames := args.Length >= 6 ? Integer(args[6]) : 100
    warm := args.Length >= 7 ? Integer(args[7]) : 10
    dotsArg := args.Length >= 8 ? args[8] : "auto"
    vw := ViewFor(view, W, H)
    dotsOn := (dotsArg = "on") || (dotsArg = "auto" && vw["z"] > 1.0)
    parts := args.Length >= 9 ? args[9] : "eticl"
    iconSet := args.Length >= 10 ? args[10] : "big"
    scene := BuildScene()
    Gdip.Startup()
    c := GdipCanvas(W, H)
    res := MakeResources(W, H, iconSet)
    try {
        c.SetAntiAlias(aa = "on")
        loop warm
            DrawFrame(c, scene, vw, W, H, res, dotsOn, parts)
        times := []
        first := ""
        loop frames {
            t0 := QpcMs()
            counts := DrawFrame(c, scene, vw, W, H, res, dotsOn, parts)
            times.Push(QpcMs() - t0)
            if (first = "")
                first := counts
        }
        list := ""
        for ms in times
            list .= (A_Index = 1 ? "" : ",") Format("{:.3f}", ms)
        FileAppend(Format("RESULT view={1} width={2} height={3} aa={4} dots={5} parts={6} icons={7} zoom={8:.4f} elements={9} connections={10} labels={11} dots_drawn={12} frames={13} warmup={14} ahk={15} os={16} cpus={17} times={18}`n"
            , view, W, H, aa, dotsOn ? "on" : "off", parts, iconSet, vw["z"], first["els"], first["cons"], first["labels"]
            , first["dots"], frames, warm, A_AhkVersion, A_OSVersion, EnvGet("NUMBER_OF_PROCESSORS"), list), resultFile)
    } finally {
        DestroyResources(res)
        c.Destroy()
        Gdip.Shutdown()
    }
    return 0
}

ExitApp(RunGuarded(A_Args))

RunGuarded(args) {
    try
        return Main(args)
    catch as failure {
        FileAppend("ERROR " failure.Message " (" failure.File ":" failure.Line ")`n", args[1])
        return 1
    }
}
