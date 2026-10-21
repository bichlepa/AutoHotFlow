#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Lang.ahk
#Include ..\..\core\Log.ahk
#Include ..\..\elements\base\ElementRegistry.ahk
#Include ..\..\elements\base\ParamEvaluator.ahk
#Include FormField.ahk
#Include FormChecks.ahk

; The settings form of one element, without a window (WI-0105, doc/ELEMENT-API-V2.md sections 2.1 and 3). The form is
; built from Parameters() of the class and filled with the parameters of the element; CheckSettings of the class runs
; at the start (FirstCall is true then) and after every change of a value; the checks of the fields run after that.
; The window (WI-0106) shows the fields and calls SetValue for every change; a test calls the same functions.
;
; Every datum has one owner (AGENTS.md rule 2): the form owns the values, the fields own what they show. The values are
; a Map with case-insensitive keys (the parameter ids, the content IDs and every parameter of the element, also those
; that no field shows, so that Result keeps them). An error of the element code (Parameters, CheckSettings, GenerateName)
; is a warning of the form and a log line; the form goes on (element code never ends the editor, rule 8).
class ElementForm {
    ; cls: the element class; pars: the parameters of the element (a Map or an object); name, standardName: the name of
    ; the element and whether it is the standard name (GenerateName); ctx: "" for now (the context of the flow, WI-0107).
    __New(cls, pars, name := "", standardName := false, ctx := "") {
        this.cls := cls
        this.ctx := ctx
        this.name := FormField.Text(name)
        this.standardName := standardName ? true : false
        this.fields := []
        this.owners := Map()
        this.owners.CaseSense := "Off"
        this.values := Map()
        this.values.CaseSense := "Off"
        this.staticValues := Map()
        this.formWarnings := []
        this.parametersWarning := ""
        this.checking := false
        this._firstCall := false
        this.LoadParameters()
        this.LoadValues(pars)
        this._firstCall := true
        this.Check()
        this._firstCall := false
    }

    ; True during the first CheckSettings call after the form was opened (the v1 x_FirstCallOfCheckSettings).
    FirstCall => this._firstCall

    ; ---- the API of CheckSettings and of the window -------------------------------------------------------------

    ; Enables the field that holds the parameter id (or the label with that id). cond: true or false. Outside a check
    ; the checks of the fields run again (a disabled field is not checked).
    Enable(id, cond := true) {
        field := this.FieldOf(id, "Enable")
        if (!IsObject(field))
            return
        field.isEnabled := cond ? true : false
        if (!this.checking)
            this.Check()
    }

    ; Disables the field that holds the parameter id when cond is true.
    Disable(id, cond := true) {
        this.Enable(id, cond ? false : true)
    }

    ; Sets the value of a parameter or of a content ID. Outside a check, CheckSettings runs again (inside it, only the
    ; value changes: the check that runs is the one that sets it).
    SetValue(id, value) {
        field := this.FieldOf(id, "SetValue")
        if (!IsObject(field))
            return
        if (!field.isValue) {
            Log.Write("a0", "editor", this.ClassId() ": form.SetValue of '" id "': a label holds no value")
            return
        }
        this.values[id] := value
        this.Check()
    }

    ; The value of a parameter or of a content ID ("" when the form has none).
    GetValue(id) {
        if (!IsObject(this.FieldOf(id, "GetValue")))
            return ""
        return this.values.Get(id, "")
    }

    ; Sets the choices of a radio, drop-down, combo box or list box, and their enum values (optional).
    SetChoices(id, list, enums := "") {
        field := this.FieldOf(id, "SetChoices")
        if (IsObject(field)) {
            field.choices := FormField.Names(list)
            field.enum := FormField.Names(enums)
        }
    }

    ; Sets the text of the field of the id.
    SetLabel(id, text) {
        field := this.FieldOf(id, "SetLabel")
        if (IsObject(field))
            field.label := FormField.Text(text)
    }

    ; The values that the choices of a field stand for: its enum values, the texts of the choices when result is "string",
    ; else 1..n (the index).
    ChoiceValues(id) {
        out := []
        field := this.FieldOf(id, "ChoiceValues")
        if (!IsObject(field))
            return out
        if (field.enum.Length) {
            for value in field.enum
                out.Push(value)
        } else if (field.result = "string") {
            for choice in field.choices
                out.Push(choice)
        } else {
            loop field.choices.Length
                out.Push(A_Index)
        }
        return out
    }

    ; The name of the element. With the standard name it comes from GenerateName at every check; the user's name stays
    ; until the standard name is switched on again.
    SetName(text) {
        this.name := FormField.Text(text)
    }

    ; Switches the standard name on or off and checks again (the name is generated when it is on).
    SetStandardName(flag) {
        this.standardName := flag ? true : false
        this.Check()
    }

    ; The warnings of the form now: an Array of Maps "id" (the first parameter id of the field, "" for the form itself)
    ; and "text". Only enabled fields have warnings.
    Warnings() {
        out := []
        for warning in this.formWarnings
            out.Push(warning)
        for field in this.fields {
            for text in field.warnings
                out.Push(Map("id", field.ids.Length ? field.ids[1] : "", "text", text))
        }
        return out
    }

    ; The result: "pars" (a Map of every parameter, the types as they came in or as the user set them), "name" and
    ; "standardName". Parameters that the form does not show are in it too.
    Result() {
        pars := Map()
        for key, value in this.values
            pars[key] := value
        return Map("pars", pars, "name", this.name, "standardName", this.standardName)
    }

    ; ---- internal -----------------------------------------------------------------------------------------------

    ; Builds the fields from Parameters() of the class. An error there leaves the form without fields (a warning).
    LoadParameters() {
        specs := ""
        try {
            specs := this.cls.Parameters(this.ctx)
        } catch as e {
            this.parametersWarning := Lang("Unexpected Error!") " " e.Message
            Log.Write("a0", "editor", this.ClassId() ": Parameters failed: " e.Message)
            return
        }
        if (!(specs is Array)) {
            Log.Write("a0", "editor", this.ClassId() ": Parameters() gives no list of fields")
            return
        }
        for spec in specs {
            field := FormField(spec, A_Index)
            this.fields.Push(field)
            if (!field.isKnown)
                Log.Write("a0", "editor", this.ClassId() ": unknown field type '" field.type "' (its value is kept)")
            for id in field.ids
                this.Own(id, field)
            if (field.contentId != "")
                this.Own(field.contentId, field)
        }
    }

    ; Registers the field as the owner of the id (the first one wins; a second one is a text error of the element).
    Own(id, field) {
        if (this.owners.Has(id)) {
            Log.Write("a0", "editor", this.ClassId() ": parameter id '" id "' is in two fields")
            return
        }
        this.owners[id] := field
    }

    ; Fills the values: the parameters of pars first, then the defaults of the fields that the parameters lack.
    LoadValues(pars) {
        if (pars is Map) {
            for key, value in pars
                this.values[key] := value
        } else if (IsObject(pars)) {
            for key, value in pars.OwnProps()
                this.values[key] := value
        }
        for field in this.fields {
            if (!field.isValue)
                continue
            for n, id in field.ids {
                if (!this.values.Has(id)) {
                    item := Map("id", id, "spec", field.spec, "n", field.idIsList ? n : 0)
                    this.values[id] := ParamEvaluator.RawValue(item, Object())
                }
            }
            if (field.contentId != "" && !this.values.Has(field.contentId))
                this.values[field.contentId] := field.contentDefault
        }
    }

    ; The parameters as an object with property access (the form of the params of the element classes).
    ParamsObject() {
        params := Object()
        for key, value in this.values {
            if (key != "")
                params.%key% := value
        }
        return params
    }

    ; Runs CheckSettings of the class, then the name and the checks of the fields. A nested call (a SetValue of
    ; CheckSettings) does nothing: the running check goes on with the new value.
    Check() {
        if (this.checking)
            return
        this.checking := true
        try {
            this.formWarnings := []
            if (this.parametersWarning != "")
                this.formWarnings.Push(Map("id", "", "text", this.parametersWarning))
            for field in this.fields
                field.warnings := []
            try {
                this.cls.CheckSettings(this, this.ParamsObject(), this.staticValues)
            } catch as e {
                this.AddFormWarning(e, "CheckSettings")
            }
            this.UpdateName(this.ParamsObject())
            this.CheckFields()
        } finally {
            this.checking := false
        }
    }

    ; The standard name: GenerateName of the class, its line feeds shown as " - " (as v1 did).
    UpdateName(params) {
        if (!this.standardName)
            return
        try {
            text := this.cls.GenerateName(this.ctx, params)
            this.name := StrReplace(String(text), "`n", " - ")
        } catch as e {
            this.AddFormWarning(e, "GenerateName")
        }
    }

    ; The checks of the enabled fields with a value: the warnings of FormChecks.
    CheckFields() {
        for field in this.fields {
            if (!field.isEnabled || !field.isValue)
                continue
            contentType := FormChecks.ContentType(field, this.values)
            for id in field.ids {
                value := this.values.Has(id) ? this.values[id] : ""
                for text in FormChecks.Value(field, value, contentType)
                    field.warnings.Push(text)
            }
        }
    }

    ; The field that holds the id, or "" (logged) when there is none.
    FieldOf(id, action) {
        if (this.owners.Has(id))
            return this.owners[id]
        Log.Write("a0", "editor", this.ClassId() ": form." action " of '" id "': no such parameter")
        return ""
    }

    ; A warning of the form for an error of the element code: the text of the error, and a log line.
    AddFormWarning(e, where) {
        text := Lang("Unexpected Error!") " " e.Message
        this.formWarnings.Push(Map("id", "", "text", text))
        Log.Write("a0", "editor", this.ClassId() ": " where " failed: " e.Message)
    }

    ; The class ID for the log (the qualified ID, or "?").
    ClassId() {
        try {
            return ElementRegistry.IdOf(this.cls)
        } catch {
            return "?"
        }
    }
}
