#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Trigonometry of the package Default (WI-0118): writes the sine, cosine, tangent or the arcsine, arccosine,
; arctangent of a number into a variable. Specification: the help text of v1 (help/en/Actions/Trigonometry.md). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Trigonometry.ahk).
;
;   Varname   the variable that gets the result
;   VarValue  the input number
;   Operation Sine, Cosine, Tangent, Arcsine, Arccosine or Arctangent
;   Unit      Radian or Degree: the unit of the angle, the input of Sine, Cosine and Tangent and the output of the
;             arc functions
;
; An arcsine or arccosine of a number outside -1 to 1 ends the element with exception (MIGRATION M-0104): v1 wrote an
; empty text.
class Action_Trigonometry extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Trigonometry")
    static Category() => Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input number")},
        {type: "Edit", id: "VarValue", default: "0.5", content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Operation")},
        {type: "Radio", id: "Operation", default: "Sine", choices: [Lang("Sine"), Lang("Cosine"), Lang("Tangent"),
            Lang("Arcsine"), Lang("Arccosine"), Lang("Arctangent")], result: "enum",
            enum: ["Sine", "Cosine", "Tangent", "Arcsine", "Arccosine", "Arctangent"]},
        {type: "Label", label: Lang("Unit")},
        {type: "Radio", id: "Unit", default: "Radian", choices: [Lang("Radian"), Lang("Degree")], result: "enum",
            enum: ["Radian", "Degree"]}
    ]

    static GenerateName(ctx, params) {
        operation := params.HasProp("Operation") ? Lang(params.Operation) : ""
        return Lang("Trigonometry") " - " operation " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("VarValue") ? params.VarValue : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        operation := p.Operation
        x := p.VarValue
        degrees := (p.Unit = "Degree")
        if (degrees && (operation = "Sine" || operation = "Cosine" || operation = "Tangent"))
            x := x * 3.141592653589793 / 180          ; degrees to radians, as v1
        if ((operation = "Arcsine" || operation = "Arccosine") && (x < -1 || x > 1))
            throw ElementError(Lang("Arcsine and arccosine need a value between -1 and 1: '%1%'.", p.VarValue))
        switch operation {
            case "Sine":      result := Sin(x)
            case "Cosine":    result := Cos(x)
            case "Tangent":   result := Tan(x)
            case "Arcsine":   result := ASin(x)
            case "Arccosine": result := ACos(x)
            case "Arctangent": result := ATan(x)
            default:
                throw ElementError(Lang("Operation '%1%' is not known.", operation))
        }
        if (degrees && (operation = "Arcsine" || operation = "Arccosine" || operation = "Arctangent"))
            result := result * 180 / 3.141592653589793  ; radians to degrees, as v1
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
