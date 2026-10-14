#Requires AutoHotkey v2.0

; Mapping of the deviation classes of the expression language (doc/EXPRESSION-LANGUAGE.md section 15.1) to the ID of
; their entry in doc/MIGRATION.md (WI-45, E35). The converter reports classes (V1ExprDetect); the loader writes the
; IDs into the flow (FlowExprConvert, key "migration", doc/ARCHITECTURE.md section 7).
;
; Handling, as in tools/golden_classes.py (a test compares the two lists, tests/test_migration_classes.py):
;   accept       known, decided deviation; the converter does not rewrite the text: the place is marked
;   unsupported  syntax that the converter reports and leaves unchanged: the place is marked
;   rewrite      the converter rewrites the text so that the result agrees: nothing to mark (M-27)
;   failed       not a class of the golden data: a text that the new language cannot read and the converter cannot
;                convert (status "failed"); the place is marked with its own ID
;
; The table is a flat list (class, handling, ID) with one entry per line so that the test can read it as text.
class MigrationClasses {
    static ENTRIES := [
        "assignment refused", "accept", "M-38",
        "assignment to a path", "accept", "M-30",
        "assignment value", "accept", "M-29",
        "built-in value", "accept", "M-41",
        "escape sequence", "accept", "M-33",
        "integer division with float", "accept", "M-35",
        "integer overflow", "accept", "M-35",
        "json text", "accept", "M-42",
        "keyword as name", "accept", "M-34",
        "no short circuit", "accept", "M-24",
        "not", "accept", "M-31",
        "number format", "accept", "M-26",
        "number literal forms", "accept", "M-35",
        "number-like texts", "accept", "M-32",
        "object as text", "accept", "M-43",
        "operand as result", "accept", "M-24",
        "path into global or static", "accept", "M-40",
        "script result value", "accept", "M-29",
        "text comparison", "accept", "M-25",
        "true and false", "accept", "M-34",
        "v1 error", "accept", "M-36",
        "v1 ignores text", "accept", "M-36",
        "backtick", "rewrite", "M-27",
        "concatenation dot", "rewrite", "M-27",
        "number literal spelling", "rewrite", "M-27",
        "unsupported syntax", "unsupported", "M-37",
        "unreadable text", "failed", "M-50"
    ]

    static _byClass := ""

    ; Map class -> Map("handling", ..., "id", ...). Built once.
    static Table() {
        if (IsObject(MigrationClasses._byClass))
            return MigrationClasses._byClass
        table := Map()
        i := 1
        while (i + 2 <= MigrationClasses.ENTRIES.Length) {
            table[MigrationClasses.ENTRIES[i]] := Map("handling", MigrationClasses.ENTRIES[i + 1]
                , "id", MigrationClasses.ENTRIES[i + 2])
            i += 3
        }
        MigrationClasses._byClass := table
        return table
    }

    ; True if a place of this class is marked in the flow (handling accept, unsupported or failed).
    static IsMarked(cls) {
        table := MigrationClasses.Table()
        return table.Has(cls) && table[cls]["handling"] != "rewrite"
    }

    ; The MIGRATION ID of a class, "" if the class is unknown.
    static IdOf(cls) {
        table := MigrationClasses.Table()
        return table.Has(cls) ? table[cls]["id"] : ""
    }

    ; The IDs (ascending, each once) of the classes that are marked. Unknown classes and rewrites are left out.
    static IdsOf(classes) {
        seen := Map()
        ids := []
        for cls in classes {
            if (!MigrationClasses.IsMarked(cls))
                continue
            id := MigrationClasses.IdOf(cls)
            if (!seen.Has(id)) {
                seen[id] := true
                ids.Push(id)
            }
        }
        ; insertion sort: IDs have the form M-nn, so the text order is the numeric order
        loop ids.Length - 1 {
            k := A_Index + 1
            item := ids[k]
            m := k - 1
            while (m >= 1 && StrCompare(ids[m], item) > 0) {
                ids[m + 1] := ids[m]
                m -= 1
            }
            ids[m + 1] := item
        }
        return ids
    }
}
