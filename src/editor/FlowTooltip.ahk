#Requires AutoHotkey v2.0
#Include ..\core\Lang.ahk
#Include FlowHit.ahk

; The tooltip of the editor (WI-0090, REQ-EDT-020): what lies under the mouse. An element shows its kind, its class (the
; display name of the class) and its name; a trigger its arming error, an element its exception (the message of the
; model), up to FlowTooltip.MAX_WARNINGS warning texts and its MIGRATION IDs. A connection shows its type. Pure: the window
; calls it after the mouse rested (about 0.5 s), cmd.test.hover calls it at once. Lines are joined with a newline.
class FlowTooltip {
    static MAX_WARNINGS := 3

    ; scene: the Scene; hit: a FlowHit or ""; messages: Map elementId -> exception message (EditorModel.messages).
    ; Returns "" when there is nothing to show.
    static Text(scene, hit, messages := "") {
        if (!IsObject(hit) || !IsObject(scene))
            return ""
        if (hit.Kind = "connection")
            return FlowTooltip._Connection(scene, hit.Id)
        element := FlowTooltip._Element(scene, hit.Id)
        if (element = "")
            return ""
        lines := [FlowTooltip._KindText(element.Kind)]
        lines.Push(Lang("Tooltip_class", element.ClassName))
        lines.Push(Lang("Tooltip_name", element.Name))
        if (element.Placeholder != "")
            lines.Push(element.Placeholder)
        if (IsObject(element.Trigger) && element.Trigger.Get("message", "") != "")
            lines.Push(Lang("Tooltip_arming", element.Trigger["message"]))
        if (IsObject(messages) && messages.Has(element.Id))
            lines.Push(Lang("Tooltip_exception", messages[element.Id]))
        shown := 0
        for warning in scene.Warnings {
            if (warning["id"] != element.Id)
                continue
            if (shown = FlowTooltip.MAX_WARNINGS)
                break
            lines.Push(Lang("Tooltip_warning", warning["text"]))
            shown += 1
        }
        ids := FlowTooltip._MigrationIds(element.Migration)
        if (ids != "")
            lines.Push(Lang("Tooltip_migration", ids))
        return FlowTooltip._Join(lines)
    }

    static _Connection(scene, id) {
        for connection in scene.Connections {
            if (connection.Id = id)
                return Lang("Tooltip_connection", connection.Type)
        }
        return ""
    }

    static _Element(scene, id) {
        for element in scene.Elements {
            if (element.Id = id)
                return element
        }
        return ""
    }

    static _KindText(kind) {
        switch kind {
            case "trigger": return Lang("Trigger")
            case "action": return Lang("Action")
            case "loop": return Lang("Loop")
        }
        return kind
    }

    ; The IDs of the MIGRATION places of an element, separated by ", " ("" for none).
    static _MigrationIds(migration) {
        text := ""
        if (!(migration is Array))
            return text
        for place in migration {
            if (!(place is Map) || !(place.Get("ids", "") is Array))
                continue
            for id in place["ids"]
                text .= (text = "" ? "" : ", ") id
        }
        return text
    }

    static _Join(lines) {
        text := ""
        for line in lines
            text .= (text = "" ? "" : "`n") line
        return text
    }
}
