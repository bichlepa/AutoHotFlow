#Requires AutoHotkey v2.0
#Include FlowGeometry.ahk

; An element of a Scene (WI-0084): everything the window needs to draw it, copied out of the flow. Nothing refers into the
; flow model. Run is "" (idle), "running", "exception", or a number 0 < n <= 1 (the fade of a finished element, v1). Trigger is "" for a non-trigger
; element, else Map("enabled", bool, "armed", bool, "message", text). Migration is a list of Maps (the `migration` key,
; copied). Placeholder is the reason text when the element class is unknown, "" otherwise. Package is the package folder
; of the class (the icon is in its Icons folder); Name is the text drawn on the element (the name the user gave it,
; else the display name of the class).
class SceneElement {
    __New(id, kind, className, icon, x, y, heightOfVerticalBar, run, trigger, migration, placeholder, warning,
        package := "Default", name := "", warningCount := 0) {
        this.Id := id
        this.Kind := kind
        this.ClassName := className
        this.Icon := icon
        this.Package := package
        this.Name := (name = "") ? className : name
        this.X := x
        this.Y := y
        this.HeightOfVerticalBar := heightOfVerticalBar
        this.Parts := FlowGeometry.Parts(kind, x, y, heightOfVerticalBar)
        this.Bounds := FlowGeometry.Bounds(kind, x, y, heightOfVerticalBar)
        this.Run := run
        this.Trigger := trigger
        this.Migration := migration
        this.Placeholder := placeholder
        this.Warning := warning          ; the text of the last warning of the evaluation ("" for none)
        this.WarningCount := warningCount
    }
}
