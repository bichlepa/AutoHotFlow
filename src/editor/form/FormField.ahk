#Requires AutoHotkey v2.0
#Include ..\..\elements\base\ParamEvaluator.ahk

; One field of the settings form of an element (WI-0105, doc/ELEMENT-API-V2.md section 2.1): the normalised form of one
; entry of Parameters(). The values belong to ElementForm, not to the field. A field knows what it shows, which ids it
; holds and whether it is enabled. The keys are read with ParamEvaluator.Field, so an entry may be an object or a Map.
class FormField {
    ; The field types of v1 (lower case: the comparison ignores case). A label and a button hold no value.
    static KNOWN := Map("label", 1, "edit", 1, "multilineedit", 1, "checkbox", 1, "radio", 1, "slider", 1
        , "dropdown", 1, "combobox", 1, "hotkey", 1, "button", 1, "file", 1, "folder", 1, "weekdays", 1
        , "dateandtime", 1, "listbox", 1)
    static NO_VALUE := Map("label", 1, "button", 1)

    __New(spec, index) {
        this.spec := spec
        this.index := index
        this.type := ParamEvaluator.Field(spec, "type")
        this.kind := StrLower(String(this.type))
        this.isKnown := FormField.KNOWN.Has(this.kind)
        this.isValue := this.isKnown ? !FormField.NO_VALUE.Has(this.kind) : true
        idSpec := ParamEvaluator.Field(spec, "id")
        this.idIsList := idSpec is Array
        this.ids := FormField.Names(idSpec)
        this.label := FormField.Text(ParamEvaluator.Field(spec, "label"))
        this.choices := FormField.Names(ParamEvaluator.Field(spec, "choices"))
        this.enum := FormField.Names(ParamEvaluator.Field(spec, "enum"))
        this.content := FormField.Names(ParamEvaluator.Field(spec, "content"))
        this.contentId := FormField.Text(FormField.First(ParamEvaluator.Field(spec, "contentID")))
        this.contentDefault := FormField.Text(FormField.First(ParamEvaluator.Field(spec, "contentDefault")))
        this.warnIfEmpty := ParamEvaluator.Truthy(ParamEvaluator.Field(spec, "WarnIfEmpty"))
        ; the value a choice stands for without enum values: "string" the text, else the index (the v1 result)
        this.result := StrLower(FormField.Text(ParamEvaluator.Field(spec, "result")))
        this.multi := ParamEvaluator.Truthy(ParamEvaluator.Field(spec, "multi"))
        this.format := StrLower(FormField.Text(ParamEvaluator.Field(spec, "format")))   ; DateAndTime: Time, Date or DateTime
        this.isEnabled := true
        this.warnings := []
    }

    ; The text of a value that is a text (an object gives ""), as the form shows it.
    static Text(v) => IsObject(v) ? "" : String(v)

    ; The first entry of a list, or the value itself (a content default may be an Array).
    static First(v) => (v is Array) ? (v.Length ? v[1] : "") : v

    ; The entries of a list as an Array of texts: an Array is copied, "" gives an empty Array, a text one entry.
    static Names(v) {
        out := []
        if (v is Array) {
            for item in v
                out.Push(FormField.Text(item))
        } else if (v != "") {
            out.Push(FormField.Text(v))
        }
        return out
    }
}
