#Requires AutoHotkey v2.0

; The look of the editor drawing (WI-0085, E0088): one table of colors, sizes and line widths. The geometry (the sizes
; of the elements, the routes of the connections) is FlowGeometry's and is not changed here, so a new look needs only
; this file. Colors are ARGB (0xAARRGGBB). Sizes are in flow units, which are device pixels at zoom 1 and 96 DPI, unless
; the name says px (device pixels). Line widths are given at 96 DPI and scaled by the DPI of the view.
;
; The values are a proposal of the port (modernized from v1: a light grey background, white and pastel fills, slate
; borders, Segoe UI Semibold instead of Arial Bold). The owner accepts the look (E0088); the screenshots of the
; acceptance are named in WI-0085.
class EditorStyle {
    static Background := 0xFFEEF2F5
    static GridDot := 0xFFC3CCD6
    static GridDotSize := 2              ; px, the dots above zoom 1 (v1 rule)
    static GridStep := 35                ; flow units (v1 default_Gridx)

    ; element fills by kind, the border and the loop's break field
    static Fill := Map("trigger", 0xFFE3EEFB, "action", 0xFFFFFFFF, "condition", 0xFFFFF4D6, "loop", 0xFFE4F5EA)
    static Border := 0xFF7A8699
    static BorderWidth := 1.5            ; px at 96 DPI
    static BreakFill := 0xFFFCE3D4
    static BreakText := 0xFF8A4B2A
    static Placeholder := 0xFFF5E6E6     ; an element whose class is unknown or whose package is missing
    static PlaceholderBorder := 0xFFB05A5A
    static PlaceholderText := 0xFF7A5050

    ; texts
    static Text := 0xFF1E2430
    static LabelText := 0xFF3B5B8C
    static TextFont := "Segoe UI Semibold"
    static TextSize := 15                ; flow units = px at zoom 1 and 96 DPI (v1 default_textSize)
    static LabelTextFactor := 0.8        ; the label of a connection type, relative to TextSize
    static BreakTextFactor := 0.7        ; the word "break" in the break field (v1 TextOptionsSmall)
    static MinTextPx := 4                ; below this text size (device px) no text is drawn, only the shapes
    static NameInset := 6                ; flow units, inside the element on every side; the name is centered in it

    ; shapes: corner radius by kind (flow units); a condition is a diamond
    static Radius := Map("trigger", 30, "action", 0, "loop", 0)   ; 0: square corners (owner feedback, E0088)
    ; the icon fills the element's box: aspect kept, centered (v1 drawElementIcon), faded and drawn behind the name
    static IconAlpha := 0.2              ; v1 Gdip_DrawImage opacity 0.2

    ; marks of a trigger: the switch (enabled or not) at 80 % x and 25 % y, the star (default manual trigger) at 15 %
    ; x and 20 % y, both MarkSize flow units (v1 SizeOfButtons 35, v1 positions)
    static MarkSize := 35
    static SwitchOn := "e_switch_on.ico"
    static SwitchOff := "e_switch_off.ico"
    static StarFilled := "e_star_filled.ico"

    ; badges (radius BadgeRadius, flow units): the places to migrate (v1 MIGRATION places) at the top right corner of an
    ; element, the warnings and the arming errors of a trigger at the bottom corners (see Renderer.DrawBadges)
    static BadgeRadius := 7
    static BadgeTextSize := 9            ; flow units, the count in a warning badge (WI-0089)
    static BadgeText := 0xFFFFFFFF
    static WarningBadge := 0xFFF39C12    ; warnings of the evaluation, at the bottom right (with their count)
    static ErrorBadge := 0xFFC62828      ; an arming error of a trigger, at the bottom left
    static MigrationBadge := 0xFF3B82F6  ; places of a migrated flow, at the top right

    ; connections
    static ConnectionColor := 0xFF4A5566
    static ConnectionWidth := 2.0        ; px at 96 DPI
    static ExceptionColor := 0xFFC62828
    static RunningLineColor := 0xFFE53935
    static RunningLineWidth := 3.0       ; px at 96 DPI

    ; state overlays drawn over an element every frame: running, exception, recently run (strength 1)
    static RunningFill := 0x66E53935
    static ExceptionFill := 0x66C62828
    static RecentFill := 0x2EE53935

    ; the selection (WI-0097): the outline of a selected element or the line of a selected connection, the selection
    ; rectangle (fill and outline) and the connection being drawn (a line from a part of an element to the pointer)
    static SelectionColor := 0xFF2E7BD6
    static SelectionWidth := 3.0         ; px at 96 DPI
    static SelectionFill := 0x332E7BD6
    static ConnectingWidth := 2.0        ; px at 96 DPI

    ; the buttons of the selection: the icon of each button name (FlowGeometry.ElementButtons, ConnectionButtons), copies
    ; of the v1 icons in assets/icons, drawn at FlowGeometry.BUTTON_SIZE flow units
    static ButtonIcons := Map("edit", "e_edit.ico", "trash", "e_trash.ico", "plus", "e_plus.ico", "plus2", "e_plus.ico"
        , "move1", "e_move.ico", "move2", "e_move.ico")

    ; the fields for new elements (NewElementFields): the white area behind them, their text and the fill of the kind
    ; (the fill of the element kind, as the field shows what is created)
    static FieldArea := 0xFFFAFAFA
    static FieldRadius := 14             ; corner radius in device pixels at 96 DPI (scaled by the DPI)
    static FieldTextFactor := 0.8        ; the text of a field, relative to TextSize
}
