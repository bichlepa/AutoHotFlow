#Requires AutoHotkey v2.0
; Unit tests for src/editor/FlowGeometry.ahk and src/editor/EditorView.ahk (WI-0084, REQ-EDT-020, REQ-EDT-030,
; REQ-USE-090). The expected segments are computed by hand from the formulas of v1 (v1/Source_Draw/GDIp/GDIp.ahk,
; lines 366 to 472), not by running the code under test.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\FlowGeometry.ahk
#Include ..\..\src\editor\EditorView.ahk

; Numbers are compared with a tolerance: the arithmetic of the drawing is in floats.
Near(actual, expected, msg := "") {
    if (Abs(actual - expected) > 0.000001)
        throw AssertFailed(Assert.Join(msg, "expected " expected " but got " actual))
}

; Checks the position and size of a FlowRect.
AssertRect(r, x, y, w, h, msg := "") {
    Near(r.X, x, msg " x")
    Near(r.Y, y, msg " y")
    Near(r.W, w, msg " w")
    Near(r.H, h, msg " h")
}

TestRun.Init()

TestRun.Case("Geometry: the sizes are those of v1", SizesAreV1)
TestRun.Case("Geometry: an action has one part, a loop four (head, bar, foot, break field)", PartsOfLoop)
TestRun.Case("Geometry: the box of a loop reaches to the bottom of its foot", BoundsOfLoop)
TestRun.Case("Segments: target below, to the right", SegmentsBelowRight)
TestRun.Case("Segments: target above and to the left (the route goes around)", SegmentsAboveLeft)
TestRun.Case("Segments: target below and to the left", SegmentsBelowLeft)
TestRun.Case("Segments: from the foot of a loop to its break field", SegmentsLoopTailToBreak)
TestRun.Case("Anchors: a loop leaves at the head for normal from HEAD, else at the foot", StartAnchors)
TestRun.Case("Anchors: a loop is entered at head, break field or foot", AimAnchors)
TestRun.Case("Labels: yes is right-aligned left of the target, other types left-aligned right of it", LabelPlacement)
TestRun.Case("Labels: normal and exception have no label", NoLabelForNormalAndException)
TestRun.Case("Culling: an element and a connection out of the visible area are not drawn", CullingOutOfView)
TestRun.Case("View: the default view puts flow point 0,0 at 140,140 (zoom 0.7, offset -200)", DefaultViewCanvas)
TestRun.Case("View: the scale includes the DPI (zoom x DPI / 96)", DpiScale)
TestRun.Case("View: zoom at a point keeps the flow point under the pointer", ZoomKeepsThePoint)
TestRun.Case("View: zoom stops at the limits 0.1 and 3", ZoomLimits)
TestRun.Case("View: a move by pixels moves the content with the pointer", MoveFollowsThePointer)
TestRun.Case("View: the visible area follows the canvas size", VisibleAreaFollowsCanvas)
TestRun.Case("View: flowSettings are read as texts, missing or wrong values take the defaults", FromFlowSettings)

SizesAreV1() {
    Assert.Equal(FlowGeometry.ELEMENT_WIDTH, 140, "element width")
    Assert.Equal(FlowGeometry.ELEMENT_HEIGHT, 105, "element height")
    Assert.Equal(FlowGeometry.GRID, 35, "grid")
    Assert.Equal(FlowGeometry.MIN_CONNECTION_HEIGHT, 15, "minimum connection height")
    Assert.Equal(FlowGeometry.CONNECTION_MARGIN, 20, "connection margin")
}

PartsOfLoop() {
    a := FlowGeometry.Parts("action", 10, 20, 0)
    Assert.Equal(a.Length, 1, "an action has one part")
    AssertRect(a[1], 10, 20, 140, 105, "action")

    p := FlowGeometry.Parts("loop", 0, 0, 40)
    Assert.Equal(p.Length, 4, "a loop has four parts")
    AssertRect(p[1], 0, 0, 140, 105, "head")
    AssertRect(p[2], 0, 105, 17.5, 40, "bar: width 1/8, height of the bar")
    AssertRect(p[3], 0, 145, 105, 35, "foot: 3/4 of the width, height 1/3")
    AssertRect(p[4], 105, 145, 35, 35, "break field: right quarter of the foot")
}

BoundsOfLoop() {
    b := FlowGeometry.Bounds("loop", 0, 0, 40)
    AssertRect(b, 0, 0, 140, 180, "loop box: head, bar and foot")
    b2 := FlowGeometry.Bounds("trigger", 5, 6, 0)
    AssertRect(b2, 5, 6, 140, 105, "trigger box")
}

; From (70, 105) to (270, 300): the target is below and to the right.
SegmentsBelowRight() {
    s := FlowGeometry.Segments(70, 105, 270, 300)
    Assert.Equal(s.Length, 5, "five segments")
    AssertRect(s[1], 70, 105, 0, 97.5, "down from the source")
    AssertRect(s[2], 70, 202.5, 100, 0, "sideways to the middle")
    AssertRect(s[3], 170, 202.5, 0, 0, "no detour: a point")
    AssertRect(s[4], 170, 202.5, 100, 0, "sideways to the target")
    AssertRect(s[5], 270, 202.5, 0, 97.5, "down into the target")
}

; From (70, 105) to (-130, 0): the target is above and to the left, so the route goes around the source.
SegmentsAboveLeft() {
    s := FlowGeometry.Segments(70, 105, -130, 0)
    AssertRect(s[1], 70, 105, 0, 15, "minimum height: the target is above")
    AssertRect(s[2], -30, 120, 100, 0, "sideways, width half the distance")
    AssertRect(s[3], -30, -15, 0, 135, "up past the target height")
    AssertRect(s[4], -130, -15, 100, 0, "sideways to the target")
    AssertRect(s[5], -130, -15, 0, 15, "down into the target")
}

; From (70, 105) to (-130, 300): below and to the left.
SegmentsBelowLeft() {
    s := FlowGeometry.Segments(70, 105, -130, 300)
    AssertRect(s[1], 70, 105, 0, 97.5, "down from the source")
    AssertRect(s[2], -30, 202.5, 100, 0, "sideways, first half")
    AssertRect(s[3], -30, 202.5, 0, 0, "a point")
    AssertRect(s[4], -130, 202.5, 100, 0, "sideways, second half")
    AssertRect(s[5], -130, 202.5, 0, 97.5, "down into the target")
}

; From the foot of a loop at (0,0), bar 40: (70, 180), to the break field of a loop at (200,300), bar 40: (322.5, 445).
SegmentsLoopTailToBreak() {
    start := FlowGeometry.StartOf("loop", 0, 0, 40, "normal", "TAIL")
    aim := FlowGeometry.AimOf("loop", 200, 300, 40, "BREAK")
    Near(start[1], 70, "start x")
    Near(start[2], 180, "start y")
    Near(aim[1], 322.5, "aim x")
    Near(aim[2], 445, "aim y")
    s := FlowGeometry.Segments(start[1], start[2], aim[1], aim[2])
    AssertRect(s[1], 70, 180, 0, 132.5, "down from the foot")
    AssertRect(s[2], 70, 312.5, 126.25, 0, "sideways")
    AssertRect(s[3], 196.25, 312.5, 0, 0, "a point")
    AssertRect(s[4], 196.25, 312.5, 126.25, 0, "sideways to the break field")
    AssertRect(s[5], 322.5, 312.5, 0, 132.5, "down into the break field")
}

StartAnchors() {
    p := FlowGeometry.StartOf("loop", 0, 0, 40, "normal", "HEAD")
    Near(p[1], 70, "head x")
    Near(p[2], 105, "head: bottom of the head")
    p := FlowGeometry.StartOf("loop", 0, 0, 40, "normal", "TAIL")
    Near(p[2], 180, "tail: bottom of the foot")
    p := FlowGeometry.StartOf("loop", 0, 0, 40, "exception", "HEAD")
    Near(p[2], 180, "exception leaves at the foot")
    p := FlowGeometry.StartOf("action", 0, 0, 0, "normal", "")
    Near(p[1], 70, "action x")
    Near(p[2], 105, "action: bottom centre")
    p := FlowGeometry.StartOf("loop", 0, 0, 40, "Normal", "head")
    Near(p[2], 105, "the texts are compared without regard to case, as in v1")
}

AimAnchors() {
    p := FlowGeometry.AimOf("loop", 200, 300, 40, "HEAD")
    Near(p[1], 270, "head x")
    Near(p[2], 300, "head: top of the loop")
    p := FlowGeometry.AimOf("loop", 200, 300, 40, "TAIL")
    Near(p[2], 445, "tail: foot")
    p := FlowGeometry.AimOf("action", 200, 300, 0, "")
    Near(p[1], 270, "action x")
    Near(p[2], 300, "action: top centre")
}

LabelPlacement() {
    yes := FlowGeometry.LabelOf("yes", 270, 300)
    AssertRect(yes["rect"], 200, 283, 67, 17, "yes: left of the target")
    Assert.Equal(yes["align"], "right", "yes is right-aligned")
    no := FlowGeometry.LabelOf("No", 270, 300)
    AssertRect(no["rect"], 275, 283, 70, 17, "no: right of the target")
    Assert.Equal(no["align"], "left", "no is left-aligned")
}

NoLabelForNormalAndException() {
    Assert.Equal(FlowGeometry.LabelOf("normal", 0, 0), "", "normal")
    Assert.Equal(FlowGeometry.LabelOf("Normal", 0, 0), "", "Normal, any case")
    Assert.Equal(FlowGeometry.LabelOf("exception", 0, 0), "", "exception")
}

CullingOutOfView() {
    visible := FlowRect(0, 0, 100, 100)
    Assert.True(FlowGeometry.ElementVisible(FlowRect(50, 50, 140, 105), visible), "partly visible")
    Assert.True(!FlowGeometry.ElementVisible(FlowRect(200, 200, 140, 105), visible), "out to the right and below")
    Assert.True(!FlowGeometry.ElementVisible(FlowRect(-300, 10, 140, 105), visible), "out to the left")
    Assert.True(FlowGeometry.ConnectionVisible(10, 10, 500, 500, visible), "one end inside")
    Assert.True(!FlowGeometry.ConnectionVisible(200, 10, 300, 90, visible), "both ends right of the area")
    Assert.True(!FlowGeometry.ConnectionVisible(10, -50, 20, -10, visible), "both ends above the area")
}

DefaultViewCanvas() {
    v := EditorView()
    c := v.ToCanvas(0, 0)
    Near(c[1], 140, "x")
    Near(c[2], 140, "y")
    f := v.ToFlow(140, 140)
    Near(f[1], 0, "back to flow x")
    Near(f[2], 0, "back to flow y")
}

DpiScale() {
    v := EditorView(0.7, -200, -200, 144)
    Near(v.Scale, 1.05, "zoom 0.7 at 144 dpi")
    c := v.ToCanvas(0, 0)
    Near(c[1], 210, "canvas x at 144 dpi")
}

ZoomKeepsThePoint() {
    v := EditorView(0.7, -200, -200, 120)
    before := v.ToFlow(300, 200)
    z := v.ZoomStep(1, 300, 200)
    after := z.ToFlow(300, 200)
    Near(after[1], before[1], "x of the point under the pointer")
    Near(after[2], before[2], "y of the point under the pointer")
    Near(z.Zoom, 0.7 * 1.1, "one step in")
    z2 := v.ZoomStep(-1, 10, 400)
    b2 := v.ToFlow(10, 400)
    a2 := z2.ToFlow(10, 400)
    Near(a2[1], b2[1], "zoom out keeps the point too")
    Near(a2[2], b2[2], "zoom out keeps the point too, y")
    Near(z2.Zoom, 0.7 / 1.1, "one step out")
}

ZoomLimits() {
    Assert.Equal(EditorView(2.95).ZoomStep(1, 0, 0).Zoom, 3, "zoom in stops at 3")
    Assert.Equal(EditorView(3).ZoomStep(1, 0, 0).Zoom, 3, "already at the limit")
    Assert.Equal(EditorView(0.11).ZoomStep(-1, 0, 0).Zoom, 0.1, "zoom out stops at 0.1")
    Assert.Equal(EditorView(5).Zoom, 3, "a stored zoom above the limit is clamped")
    Assert.Equal(EditorView(0.01).Zoom, 0.1, "a stored zoom below the limit is clamped")
}

MoveFollowsThePointer() {
    v := EditorView(0.7, -200, -200)
    m := v.Moved(70, 0)
    Near(m.OffsetX, -200 - 70 / 0.7, "dragged right: the content moves right, the offset goes left")
    Near(m.OffsetY, -200, "no vertical move")
    flowBefore := v.ToFlow(100, 100)
    flowAfter := m.ToFlow(170, 100)
    Near(flowAfter[1], flowBefore[1], "the point under the pointer is the same flow point")
}

VisibleAreaFollowsCanvas() {
    r := EditorView(0.7, -200, -200, 96, 700, 350).VisibleArea()
    AssertRect(r, -200, -200, 1000, 500, "visible flow area")
}

FromFlowSettings() {
    v := EditorView.FromFlowSettings(Map("zoomFactor", "0.700000", "Offsetx", "-692.870201", "Offsety", "-421.090989"))
    Near(v.Zoom, 0.7, "zoom text")
    Near(v.OffsetX, -692.870201, "offset x text")
    Near(v.OffsetY, -421.090989, "offset y text")
    d := EditorView.FromFlowSettings(Map("zoomFactor", "abc"))
    Near(d.Zoom, 0.7, "non-numeric zoom: default")
    Near(d.OffsetX, -200, "missing offset: default")
    e := EditorView.FromFlowSettings("")
    Near(e.Zoom, 0.7, "no settings at all: default zoom")
    Near(e.OffsetY, -200, "no settings at all: default offset")
}

TestRun.Finish()
