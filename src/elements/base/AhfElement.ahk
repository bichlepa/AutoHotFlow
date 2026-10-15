#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Lang.ahk      ; element files call Lang() in Name() and Parameters(); every role that holds element classes needs it
#Include Dialogs.ahk              ; the only way for an element to show a dialog (E0038, WI-0051)

; Base class of every element (doc/ELEMENT-API-V2.md section 2). Elements are stateless: all
; members are static, the state of one run lives in ctx.State. Subclasses override what they need.
;
; Name() and Category() are not defined here on purpose. A subclass defines Name() as a static
; method, which hides the built-in .Name property of the class object. Use ElementRegistry.IdOf(cls)
; for the class id.
class AhfElement {
    static Mode := "inline"          ; "inline" | "worker" | "trigger" (ARCHITECTURE 2.3)
    static Level := "Beginner"       ; "Beginner" | "Advanced" | "Programmer"
    static Stability := "Stable"     ; "Stable" | "Experimental"
    static Icon := ""                ; file name in Icons/ of the package of the class, "" = none (WI-0047)
    ; Worker elements only: the engine ends the job with the exception "worker timeout" after this many ms and has
    ; the worker killed if it does not react to the cancel (ARCHITECTURE 6.4). 0 = no deadline (v1 had none).
    static JobTimeoutMs := 0
    ; Parameters that the element evaluates itself as an expression or a script (v1: x_EvaluateExpression or
    ; x_EvaluateScript on a RawString), as Map("ParameterId", "expression" | "script"). The loader of flows converts
    ; their texts from v1 syntax (WI-0039). Parameters with an expression content type in Parameters() are found there.
    static V1Syntax := Map()

    ; Runtime entry point of inline and worker elements. The base class has no behavior: a class
    ; that runs without its own Run is a bug and ends the execution with "exception".
    static Run(ctx, params) {
        throw ElementError("element does not implement Run")
    }

    ; Optional abort hook. Timers of ctx are cancelled by ElementRunner.Stop in any case.
    static Stop(ctx, params) {
    }

    ; Editor side (not used in Phase 2): parameter schema and form rules.
    static Parameters(ctx) => []
    static CheckSettings(form, params, staticValues) {
    }
}
