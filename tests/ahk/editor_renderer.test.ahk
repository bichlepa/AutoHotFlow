#Requires AutoHotkey v2.0
; Unit tests for src/editor/render/Renderer.ahk and EditorStyle.ahk (WI-0085, E0088, E0090): a scene drawn into a
; GdipCanvas without a window, read back pixel by pixel. No window, no dialog. The cache rules (a run state or a
; trigger state does not rebuild the static layer, a pan inside the layer does not either) are counted in Snapshot.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\editor\EditorView.ahk
#Include ..\..\src\editor\SceneBuilder.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\..\src\editor\render\Renderer.ahk

CANVAS_W := 1000
CANVAS_H := 900
WHITE := 0xFFFFFFFF

; The flow of the tests (positions in flow units): A action (0, 0), C condition (400, 0), U unknown class (800, 0),
; B action (200, 300), L loop (0, 600) with a bar of 40, T trigger (400, 600). Connection c1 from A to B (normal).
FlowText() {
    return '{"allElements": {'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 0, "name": "a"},'
        . '"B": {"ID": "B", "type": "action", "class": "action_Sleep", "package": "Default", "x": 200, "y": 300, "name": "b"},'
        . '"C": {"ID": "C", "type": "condition", "class": "Condition_Expression", "package": "Default", "x": 400, "y": 0,'
        . ' "name": "c"},'
        . '"U": {"ID": "U", "type": "action", "class": "no_such_class", "package": "Default", "x": 800, "y": 0,'
        . ' "name": "u"},'
        . '"L": {"ID": "L", "type": "loop", "class": "Loop_SimpleLoop", "package": "Default", "x": 0, "y": 600,'
        . ' "HeightOfVerticalBar": 40, "name": "l"},'
        . '"T": {"ID": "T", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 400, "y": 600,'
        . ' "name": "t"}},'
        . '"allConnections": {"c1": {"ID": "c1", "from": "A", "to": "B", "ConnectionType": "normal"}}}'
}

; The view of the tests: zoom 1 and the flow point (-20, -20) at the top left corner, so flow (x, y) is canvas (x+20, y+20).
ViewAt(zoom := 1.0, ox := -20, oy := -20, dpi := 96) => EditorView(zoom, ox, oy, dpi, CANVAS_W, CANVAS_H)

; The scene of the flow with run states, trigger states and warnings (Maps, as the window passes them).
SceneOf(view := "", run := "", trigger := "", warnings := "") {
    return SceneBuilder.Build(Json.Parse(FlowText()), IsObject(view) ? view : ViewAt(), run, trigger, warnings)
}

NewCanvas() => GdipCanvas(CANVAS_W, CANVAS_H)

; The canvas pixel of a flow point at the view (the view scale is applied).
PixelOf(view, fx, fy) => [Round((fx - view.OffsetX) * view.Scale), Round((fy - view.OffsetY) * view.Scale)]

ElementById(sc, id) {
    for element in sc.Elements {
        if (element.Id = id)
            return element
    }
    throw AssertFailed("no element '" id "' in the scene")
}

; The pixel at dx, dy from the top left corner of an element (flow units).
ProbeOf(view, sc, id, dx, dy) {
    element := ElementById(sc, id)
    return PixelOf(view, element.X + dx, element.Y + dy)
}

; The number of pixels in the canvas box (x, y, w, h) that differ from color.
CountNot(c, x, y, w, h, color) {
    n := 0
    loop h {
        py := y + A_Index - 1
        loop w {
            if (c.Pixel(x + A_Index - 1, py) != color)
                n += 1
        }
    }
    return n
}

CheckBackground() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        Assert.Equal(c.Pixel(2, 2), EditorStyle.Background, "the background outside the flow")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckFillOfEachKind() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 8, 30)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["action"], "an action is filled with the action fill")
        p := ProbeOf(view, sc, "C", 70, 3)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["condition"], "a condition (diamond) is filled at its top")
        p := ProbeOf(view, sc, "T", 8, 30)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["trigger"], "a trigger is filled with the trigger fill")
        p := ProbeOf(view, sc, "L", 8, 30)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["loop"], "the head of a loop is filled with the loop fill")
        p := ProbeOf(view, sc, "L", 122, 151)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.BreakFill, "the break field of a loop has the break fill")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckRunningElementIsTinted() {
    view := ViewAt()
    sc := SceneOf(view, Map("A", "running"))
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 8, 30)
        argb := c.Pixel(p[1], p[2])
        Assert.True(argb != EditorStyle.Fill["action"], "a running element differs from its fill")
        red := ((argb >> 16) & 0xFF)
        green := ((argb >> 8) & 0xFF)
        Assert.True(red > green + 30, "the tint is red: red " red ", green " green)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckConnectionIsDrawn() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        ; the first segment of c1 runs down from (70, 105) along x = 70 (A to B)
        p := PixelOf(view, 70, 150)
        red := ((c.Pixel(p[1], p[2]) >> 16) & 0xFF)
        Assert.True(red < 0x90, "a dark connection line on its segment, red " red)
        p := PixelOf(view, 76, 150)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Background, "six units beside the line is background")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckLabelOfAYesConnectionIsDrawn() {
    view := ViewAt()
    flow := Json.Parse(FlowText())
    flow["allConnections"]["c1"]["ConnectionType"] := "yes"
    sc := SceneBuilder.Build(flow, view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        ; the label of a yes connection is left of the target: rect (200, 283) 67 x 17 in flow units
        p := PixelOf(view, 200, 283)
        Assert.True(CountNot(c, p[1], p[2], 67, 17, EditorStyle.Background) > 0, "the label puts ink left of B")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckNameIsDrawn() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 6, 58)
        n := CountNot(c, p[1], p[2], 128, 43, EditorStyle.Fill["action"])
        Assert.True(n > 20, "the name of A puts ink into its name area, pixels: " n)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckIconIsDrawn() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 48, 4)           ; inside the border (rows 0 and 1 are the outline)
        n := CountNot(c, p[1], p[2], 44, 36, EditorStyle.Fill["action"])
        Assert.True(n > 20, "the icon of Sleep is drawn into the upper part of its box (faded: few pixels), pixels: " n)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

; The icon fills the whole element box (v1 fits it into the element, not into a strip above the name): the bottom
; band of the element, which the old icon strip (y 10 to 54) and the old name (from y 58) never reached, holds icon ink.
CheckIconFillsTheElementBox() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 0, 0)
        n := CountNot(c, p[1] + 30, p[2] + 92, 80, 12, EditorStyle.Fill["action"])
        Assert.True(n > 0, "the icon reaches the bottom band of the element, pixels: " n)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

; The name is centered in the whole element, not below an icon strip: the single letter "a" of A has strong ink in the
; upper half, above the old name top (flow y 58). Faded icon ink stays below the strong threshold (300 of 1020).
CheckNameUsesTheWholeElement() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 4, 4)            ; inside the outline, down to the old name top (flow y 58)
        n := 0
        loop 132 {
            x := p[1] + A_Index - 1
            loop 54 {
                if (ColorDistance(c.Pixel(x, p[2] + A_Index - 1), EditorStyle.Fill["action"]) > 300)
                    n += 1
            }
        }
        Assert.True(n > 10, "the name is drawn in the upper half of the element, strong pixels: " n)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

; The distance of two colors: the sum of the absolute differences of the four channels (0 to 1020).
ColorDistance(a, b) {
    d := 0
    for shift in [0, 8, 16, 24]
        d += Abs(((a >> shift) & 0xFF) - ((b >> shift) & 0xFF))
    return d
}

; The largest color distance from color of a pixel in the canvas box (x, y, w, h).
MaxDistance(c, x, y, w, h, color) {
    m := 0
    loop h {
        py := y + A_Index - 1
        loop w {
            d := ColorDistance(c.Pixel(x + A_Index - 1, py), color)
            if (d > m)
                m := d
        }
    }
    return m
}

; The largest distance from the fill of an action inside its icon box, drawn with the given icon alpha.
IconDistanceAt(alpha, sc, p) {
    saved := EditorStyle.IconAlpha
    EditorStyle.IconAlpha := alpha
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        return MaxDistance(c, p[1], p[2], 44, 36, EditorStyle.Fill["action"])
    } finally {
        EditorStyle.IconAlpha := saved
        r.Destroy()
        c.Destroy()
    }
}

CheckIconIsFaded() {
    view := ViewAt()
    sc := SceneOf(view)
    p := ProbeOf(view, sc, "A", 48, 4)
    faded := IconDistanceAt(EditorStyle.IconAlpha, sc, p)
    full := IconDistanceAt(1.0, sc, p)
    Assert.True(EditorStyle.IconAlpha <= 0.3, "the icon alpha of the style is faded (<= 0.3)")
    Assert.True(faded > 0, "the faded icon is still visible, distance " faded)
    Assert.True(faded * 100 <= full * 35, "the icon at the style alpha is faded versus full alpha, " faded " vs " full)
}

CheckCornersAreSquare() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "A", 1, 1)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["action"], "the top left corner of an action is square")
        p := ProbeOf(view, sc, "L", 1, 1)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["loop"], "the top left corner of a loop is square")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckLoopIsOneObject() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        ; the seam between the head and the bar (flow y 105) and between the foot and the break field (flow x 105)
        p := ProbeOf(view, sc, "L", 8, 105)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["loop"], "no outline at the seam of head and bar")
        p := ProbeOf(view, sc, "L", 104, 162)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["loop"], "no outline at the seam of foot and break field")
        p := ProbeOf(view, sc, "L", 105, 162)
        argb := c.Pixel(p[1], p[2])
        Assert.True(ColorDistance(argb, EditorStyle.Border) > 200, "no dark outline on the seam pixel, got " argb)
        p := ProbeOf(view, sc, "L", 110, 150)     ; above the word "break"
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.BreakFill, "the break field has the break fill")
        ; the outer outline of the foot is drawn: its pixel is nearer to the border than to the fill
        p := ProbeOf(view, sc, "L", 70, 180)
        argb := c.Pixel(p[1], p[2])
        Assert.True(ColorDistance(argb, EditorStyle.Border) < ColorDistance(argb, EditorStyle.Fill["loop"])
            , "the outer outline of a loop is drawn at its foot")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckUnknownClassIsAPlaceholder() {
    view := ViewAt()
    sc := SceneOf(view)
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "U", 8, 30)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Placeholder, "the unknown class has the placeholder fill")
        Assert.True(EditorStyle.Placeholder != EditorStyle.Fill["action"], "the placeholder differs from an action")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckWarningBadgeIsDrawn() {
    view := ViewAt()
    sc := SceneOf(view, "", "", Map("A", "a warning"))
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        ; the badge is at the bottom right (radius 7 around (128, 93)); the probe is inside the disc, left of the digit
        p := ProbeOf(view, sc, "A", 123, 90)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.WarningBadge, "the warning badge in the bottom right corner")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckTriggerSwitchIsDrawn() {
    view := ViewAt()
    sc := SceneOf(view, "", Map("T", Map("enabled", 1, "armed", 0, "message", "", "default", 0)))
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(sc, c)
        p := ProbeOf(view, sc, "T", 112 - 17, 26 - 17)
        n := CountNot(c, p[1], p[2], 35, 35, EditorStyle.Fill["trigger"])
        Assert.True(n > 0, "the switch of an enabled trigger is drawn over its fill, pixels: " n)
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckStarOnlyForTheDefaultTrigger() {
    ; the star comes from the definition (DefaultTrigger of Trigger_Manual, WI-0088), not from a trigger-state key
    view := ViewAt()
    plain := SceneOf(view, "", Map("T", Map("enabled", 1, "armed", 0, "message", "")))
    raw := Json.Parse(FlowText())
    raw["allElements"]["T"]["DefaultTrigger"] := "1"
    star := SceneBuilder.Build(raw, view, "", Map("T", Map("enabled", 1, "armed", 0, "message", "")))
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(plain, c)
        p := ProbeOf(view, plain, "T", 14, 14)     ; inside the rounded corner, where the star of the default sits
        Assert.Equal(CountNot(c, p[1], p[2], 14, 14, EditorStyle.Fill["trigger"]), 0,
            "no star at the top left of a trigger that is not the default")
        r.Draw(star, c)
        Assert.True(CountNot(c, p[1], p[2], 14, 14, EditorStyle.Fill["trigger"]) > 0,
            "the star of the default trigger is drawn at the top left")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckStateChangeDoesNotRebuildTheLayer() {
    view := ViewAt()
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(SceneOf(view), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 1, "the first frame builds the layer")
        r.Draw(SceneOf(view, Map("A", "running")), c)
        r.Draw(SceneOf(view, Map("A", "exception")), c)
        r.Draw(SceneOf(view, Map("A", 0.5)), c)
        r.Draw(SceneOf(view, "", Map("T", Map("enabled", 0, "armed", 0, "message", "", "default", 0))), c)
        snap := r.Snapshot()
        Assert.Equal(snap["rebuilds"], 1, "run and trigger states change the frame, not the layer")
        Assert.Equal(snap["frames"], 5, "five frames were drawn")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckPanInsideTheLayerDoesNotRebuild() {
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(SceneOf(ViewAt()), c)
        r.Draw(SceneOf(ViewAt(1.0, -40, -30)), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 1, "a small pan is a copy of the layer")
        r.Draw(SceneOf(ViewAt(1.0, -700, -30)), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 2, "a pan out of the layer rebuilds it")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckZoomAndStaticChangeRebuild() {
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(SceneOf(ViewAt()), c)
        r.Draw(SceneOf(ViewAt(1.5)), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 2, "a zoom change rebuilds the layer")
        flow := Json.Parse(FlowText())
        flow["allElements"]["A"]["name"] := "renamed"
        r.Draw(SceneBuilder.Build(flow, ViewAt(1.5)), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 3, "a renamed element rebuilds the layer")
        r.Draw(SceneBuilder.Build(flow, ViewAt(1.5, -20, -20, 144)), c)
        Assert.Equal(r.Snapshot()["rebuilds"], 4, "another DPI rebuilds the layer")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckEmptyFlowAndElementsOutsideAreDrawn() {
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(SceneBuilder.Build(Map(), ViewAt()), c)
        Assert.Equal(c.Pixel(2, 2), EditorStyle.Background, "an empty flow is the background")
        far := Json.Parse(FlowText())
        far["allElements"]["A"]["x"] := -90000
        r.Draw(SceneBuilder.Build(far, ViewAt(3)), c)
        Assert.Equal(r.Snapshot()["frames"], 2, "both frames were drawn")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckDestroyLeavesARendererThatDrawsAgain() {
    view := ViewAt()
    c := NewCanvas()
    r := Renderer()
    try {
        r.Draw(SceneOf(view), c)
        r.Destroy()
        r.Draw(SceneOf(view), c)
        p := ProbeOf(view, SceneOf(view), "A", 8, 30)
        Assert.Equal(c.Pixel(p[1], p[2]), EditorStyle.Fill["action"], "the frame after Destroy is drawn again")
    } finally {
        r.Destroy()
        c.Destroy()
    }
}

CheckStyleTableHasTheFillOfEachKind() {
    for kind in ["trigger", "action", "condition", "loop"]
        Assert.True(EditorStyle.Fill.Has(kind), "a fill for " kind)
    Assert.True(EditorStyle.TextSize > 0, "a text size")
}

Gdip.Startup()
TestRun.Init()

TestRun.Case("the background is the style background outside the flow", CheckBackground)
TestRun.Case("each kind of element has its fill, the break field of a loop too", CheckFillOfEachKind)
TestRun.Case("a running element is tinted red", CheckRunningElementIsTinted)
TestRun.Case("a connection segment is a dark line on its path", CheckConnectionIsDrawn)
TestRun.Case("the label of a yes connection is drawn left of its target", CheckLabelOfAYesConnectionIsDrawn)
TestRun.Case("the name of an element puts ink into its name area", CheckNameIsDrawn)
TestRun.Case("the icon of an element is drawn into its box", CheckIconIsDrawn)
TestRun.Case("the icon fills the whole element box, not a strip above the name", CheckIconFillsTheElementBox)
TestRun.Case("the name is centered in the whole element", CheckNameUsesTheWholeElement)
TestRun.Case("the icon is faded (style alpha) against full alpha", CheckIconIsFaded)
TestRun.Case("the corners of an action and a loop are square", CheckCornersAreSquare)
TestRun.Case("a loop is one object: no outline at its seams", CheckLoopIsOneObject)
TestRun.Case("an unknown class is drawn as a placeholder", CheckUnknownClassIsAPlaceholder)
TestRun.Case("a warning puts a badge in the bottom right corner", CheckWarningBadgeIsDrawn)
TestRun.Case("the switch of a trigger is drawn over its fill", CheckTriggerSwitchIsDrawn)
TestRun.Case("the star is drawn for the default trigger only", CheckStarOnlyForTheDefaultTrigger)
TestRun.Case("a run or trigger state does not rebuild the static layer", CheckStateChangeDoesNotRebuildTheLayer)
TestRun.Case("a pan inside the layer does not rebuild it, a pan out of it does", CheckPanInsideTheLayerDoesNotRebuild)
TestRun.Case("a zoom, a rename or a DPI change rebuilds the layer", CheckZoomAndStaticChangeRebuild)
TestRun.Case("an empty flow and elements far outside the window are drawn", CheckEmptyFlowAndElementsOutsideAreDrawn)
TestRun.Case("a renderer draws again after Destroy", CheckDestroyLeavesARendererThatDrawsAgain)
TestRun.Case("the style has a fill for each kind and a text size", CheckStyleTableHasTheFillOfEachKind)

Gdip.Shutdown()
TestRun.Finish()
