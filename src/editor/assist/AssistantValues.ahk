#Requires AutoHotkey v2.0

; Pure helpers of the assistants of the element settings (WI-0110): the kinds of the assistants, the map from the keys an
; assistant returns to the parameter ids of the form, and the colour formats. A colour is text 0xRRGGBB (the colour of
; PixelGetColor) in the settings; the colour dialog of Windows takes a COLORREF (0x00BBGGRR).
class AssistantValues {
    ; The kinds that a Button field of an element may start (FormField.assistant).
    static KINDS := Map("window", 1, "mouse", 1, "color", 1)

    static IsKnown(kind) => AssistantValues.KINDS.Has(kind)

    ; The values under the parameter ids: Map(id -> value) for every key of the map that the values have. A key that the
    ; map lacks is dropped; the ids are not checked against a form (the caller does that).
    static ToIds(values, mapping) {
        out := Map()
        for key, id in mapping {
            if (values.Has(key))
                out[id] := values[key]
        }
        return out
    }

    ; 0xRRGGBB text to COLORREF (0x00BBGGRR). A text that is no number gives black (0).
    static ToColorref(text) {
        try {
            n := Integer(text)
        } catch {
            return 0                    ; no colour yet: black, as the dialog starts with
        }
        return ((n & 0xFF) << 16) | (n & 0xFF00) | ((n >> 16) & 0xFF)
    }

    ; COLORREF to 0xRRGGBB text.
    static FromColorref(cr) => Format("0x{:06X}", ((cr & 0xFF) << 16) | (cr & 0xFF00) | ((cr >> 16) & 0xFF))
}
