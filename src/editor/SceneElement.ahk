#Requires AutoHotkey v2.0
#Include FlowGeometry.ahk

; An element of a Scene (WI-0084): everything the window needs to draw it, copied out of the flow. Nothing refers into the
; flow model. Run is "" (idle), "running" or "recent" (ran less than a second ago, v1). Trigger is "" for a non-trigger
; element, else Map("enabled", bool, "armed", bool, "message", text). Migration is a list of Maps (the `migration` key,
; copied). Placeholder is the reason text when the element class is unknown, "" otherwise.
class SceneElement {
    __New(id, kind, className, icon, x, y, heightOfVerticalBar, run, trigger, migration, placeholder, warning) {
        this.Id := id
        this.Kind := kind
        this.ClassName := className
        this.Icon := icon
        this.X := x
        this.Y := y
        this.HeightOfVerticalBar := heightOfVerticalBar
        this.Parts := FlowGeometry.Parts(kind, x, y, heightOfVerticalBar)
        this.Bounds := FlowGeometry.Bounds(kind, x, y, heightOfVerticalBar)
        this.Run := run
        this.Trigger := trigger
        this.Migration := migration
        this.Placeholder := placeholder
        this.Warning := warning
    }
}
