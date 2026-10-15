#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element of WI-0047 (E0045, REQ-PKG-060): the packages Test and TestTwin both have a class of this name.
; It sets the global variable global_pkg_<Tag> to "TestTwin <qualified ID>", so a test sees which of the two classes ran.
class Action_TestPackageName extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: which package runs (TestTwin)"
    static Category() => "Test"

    static Run(ctx, params) {
        ctx.SetVar("global_pkg_" params.Tag, "TestTwin " ElementRegistry.IdOf(this))
        ctx.Finish("normal")
    }
}
