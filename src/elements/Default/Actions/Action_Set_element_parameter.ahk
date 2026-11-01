#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FlowSwitchOps.ahk
#Include ..\lib\FlowChoices.ahk
#Include ..\lib\ElementParOps.ahk

; Action Set element parameter of the package Default (WI-0129, E0001, E0065): changes one parameter of an element, of the
; flow of this element or of another loaded flow, while the flow runs. Specification: the help text of v1
; (help/en/Actions/Set_element_parameter.html) and v1 Set_element_parameter.ahk. Class ID, parameter IDs and the language
; keys of the v1 names are those of v1.
;
;   ThisFlow        1: the flow of this element; 0: the flow flowID (the ID of a flow, its file name)
;   flowID          the flow when ThisFlow is 0
;   elementID       the element of that flow (its ID, as "element0000000001")
;   parameterID     "<control>/<parameter ID>": the parameter of the element and the control that holds its new value
;                   (ElementParOps; the choices are the parameters of the class of the element)
;   newParameterValue*  the value, in the control of the parameter; its text is evaluated like any parameter (the
;                   content of an edit field: RawString or String, as its own content choice)
;
; The change is one patch of the flow (ctx.SetElementPar, PROTOCOL 4.2 "Element origin"): it is saved automatically, a
; changed trigger is armed again, an open editor sees it, and a running instance keeps the value it started with. The
; value stored is the evaluated value (v1). Errors end the element with "exception" and change nothing.
class Action_Set_element_parameter extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := true    ; it changes flows and triggers, which can act on the system (WI-0081, REQ-SEC-060)
    static Level := "Advanced"
    static Stability := "Experimental"

    static Name() => Lang("Set element parameter")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which flow")},
        {type: "Checkbox", id: "ThisFlow", default: 1, label: Lang("This flow (%1%)", IsObject(ctx) ? ctx.flowId : "")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Which element")},
        {type: "DropDown", id: "elementID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Which parameter")},
        {type: "DropDown", id: "parameterID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("New value")},
        {type: "Edit", id: "newParameterValueEdit", default: "", content: ["RawString", "String"]
            , contentID: "newParameterValueEditContent", contentDefault: "RawString"},
        {type: "Checkbox", id: "newParameterValueCheckbox", default: 0, label: Lang("New value")},
        {type: "Checkbox", id: "newParameterValueCheckboxGray", default: 0, label: Lang("New value")},
        {type: "DropDown", id: "newParameterValueDropDown", default: "", choices: [""], result: "enum", enum: [""]},
        {type: "DropDown", id: "newParameterValueComboBox", default: "", choices: [""], result: "enum", enum: [""]},
        {type: "multilineEdit", id: "newParameterValueMultilineEdit", default: ""
            , content: ["RawString", "String"], contentID: "newParameterValueMultilineEditContent", contentDefault: "RawString"},
        {type: "DropDown", id: "newParameterValueListBox", default: "", choices: [""], result: "enum", enum: [""]},
        {type: "File", id: "newParameterValueFile", default: "", label: Lang("Select a file")},
        {type: "Folder", id: "newParameterValueFolder", default: "", label: Lang("Select a folder")},
        {type: "weekdays", id: "newParameterValueWeekdays", default: ""},
        {type: "DateAndTime", id: "newParameterValueDateAndTime", default: "", format: "datetime"}
    ]

    ; "Set element parameter - <parameter> = <value> - Element '<ID>' - <flow>" (v1 Element_GenerateName): the flow and the
    ; element by their IDs, as v1 wrote them.
    static GenerateName(ctx, params) {
        thisFlow := FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1))
        flowText := thisFlow ? Lang("This flow") : Lang("Flow '%1%'", FlowChoices.Text(FlowSwitchOps.Par(params, "flowID", "")))
        elementText := Lang("Element '%1%'", FlowChoices.Text(FlowSwitchOps.Par(params, "elementID", "")))
        choice := ElementParOps.Split(FlowChoices.Text(FlowSwitchOps.Par(params, "parameterID", "")))
        parameterText := Lang("'%1%'", choice[2])
        valueText := Lang("'%1%'", FlowChoices.Text(FlowSwitchOps.Par(params, choice[1], "")))
        return Lang("Set element parameter") " - " parameterText " = " valueText " - " elementText " - " flowText
    }

    ; The flow list, the element list of the chosen flow and the parameter list of the chosen element (v1 CheckSettings).
    ; The lists come from the editor context (form.ctx: flows, elements and their classes, WI-0129); without it they are
    ; empty. The value control of the chosen parameter is the only one enabled, and it gets the choices of the parameter.
    static CheckSettings(form, params, staticValues) {
        thisFlow := FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1))
        form.Enable("flowID", !thisFlow)
        ctx := FlowChoices.CtxOf(form)
        FlowChoices.Flows(form, "flowID")
        flowId := FlowChoices.Target(ctx, thisFlow, FlowSwitchOps.Par(params, "flowID", ""))
        if (!thisFlow && flowId = "" && IsObject(ctx)) {
            flowId := ctx.flowId
            form.SetValue("flowID", flowId)
        }
        elementIds := []
        labels := []
        if (IsObject(ctx) && flowId != "") {
            for el in ctx.Elements(flowId) {
                elementIds.Push(el["elementId"])
                labels.Push(FlowChoices.Label(el["elementId"], el["name"]))
            }
        }
        form.SetChoices("elementID", labels, elementIds)
        elementId := FlowChoices.Text(FlowSwitchOps.Par(params, "elementID", ""))
        if (!this._Contains(elementIds, elementId))
            elementId := elementIds.Length ? elementIds[1] : ""
        if (elementId != FlowChoices.Text(FlowSwitchOps.Par(params, "elementID", "")))
            form.SetValue("elementID", elementId)

        entries := this._EntriesOf(ctx, flowId, elementId)
        choiceNames := []
        choiceEnums := []
        for entry in entries {
            choiceNames.Push(entry["id"] " - " entry["name"])
            choiceEnums.Push(entry["control"] "/" entry["id"])
        }
        form.SetChoices("parameterID", choiceNames, choiceEnums)
        current := FlowChoices.Text(FlowSwitchOps.Par(params, "parameterID", ""))
        chosen := this._Contains(choiceEnums, current) ? current : (choiceEnums.Length ? choiceEnums[1] : "")
        if (chosen != current)
            form.SetValue("parameterID", chosen)

        chosenParts := ElementParOps.Split(chosen)
        for control in ElementParOps.CONTROLS
            form.Enable(control, control = chosenParts[1])
        for entry in entries {
            if (entry["control"] = chosenParts[1] && entry["id"] = chosenParts[2]) {
                if (entry["choices"] is Array)
                    form.SetChoices(chosenParts[1], entry["choices"], entry["enum"])
                if (entry["name"] != "")
                    form.SetLabel(chosenParts[1], entry["name"])
                break
            }
        }
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, ElementParOps.CONTROLS)
        thisFlow := FlowSwitchOps.IsOn(p.ThisFlow)
        flowId := thisFlow ? ctx.flowId : FlowChoices.Text(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        elementId := FlowChoices.Text(p.elementID)
        if (elementId = "")
            throw ElementError(Lang("Element ID is empty"))
        if (!ctx.HasElement(flowId, elementId))
            throw ElementError(Lang("Flow '%1%' does not have the element with ID '%2%'.", flowId, elementId))
        choice := ElementParOps.Split(FlowChoices.Text(p.parameterID))
        control := choice[1]
        parameterId := choice[2]
        if (!ElementParOps.IsControl(control) || parameterId = "")
            throw ElementError(FlowSwitchOps.InvalidParameter("parameterID"))
        p := ctx.EvalMoreParams(p, params, [control])
        ctx.SetElementPar(flowId, elementId, parameterId, p.%control%)
        ctx.Finish("normal")
    }

    ; The entries of the parameter list of the class of an element of a flow, [] when the class is not known.
    static _EntriesOf(ctx, flowId, elementId) {
        if (!IsObject(ctx) || flowId = "" || elementId = "")
            return []
        qid := ""
        for el in ctx.Elements(flowId) {
            if (el["elementId"] = elementId) {
                qid := el["class"]
                break
            }
        }
        cls := ElementRegistry.Get(qid)
        if (!IsObject(cls))
            return []
        try {
            return ElementParOps.Entries(cls.Parameters(ctx))
        } catch {
            return []                   ; the class has no list the form can show (the element is still set by its ID)
        }
    }

    static _Contains(list, value) {
        for item in list {
            if (item = value)
                return true
        }
        return false
    }
}
