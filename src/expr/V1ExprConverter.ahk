#Requires AutoHotkey v2.0
#Include Expr.ahk
#Include V1ExprDetect.ahk

; Converter of v1 expressions and scripts into the new language (WI-39, doc/EXPRESSION-LANGUAGE.md section 15).
;
;   conv := V1ExprConverter.Convert(text, "expression")      ; or "script"
;   conv["status"]     "unchanged" | "converted" | "unsupported" | "failed"
;   conv["text"]       the text to use; the input itself unless the status is "converted"
;   conv["changes"]    Array of Map("rule", name, "old", text, "new", text) in the order of the text
;   conv["messages"]   Array of texts for the log (why a text is "unsupported" or "failed")
;   conv["classes"]    Array of the deviation classes (doc/EXPRESSION-LANGUAGE.md 15.1, handling "accept" or
;                      "unsupported") that the text shows (V1ExprDetect); "unreadable text" for a "failed" text that
;                      no other class explains. MigrationClasses maps them to MIGRATION IDs (WI-45).
;
; The text is rewritten only where the result of v1 cannot be had otherwise; the rest stays as the user wrote it.
; The rewrite rules (each one is a class of the deviation catalog with the handling "rewrite"):
;   - a backtick in front of a character that v2 does not know as an escape is removed (v1 dropped every backtick)
;   - the concatenation dot gets a space on both sides (v1 accepted "a"."b")
;   - a number literal that v2 would write differently (1.50, 007, 5.) becomes a string literal, in the places where
;     the text form is what counts (the whole expression, the right side of := and .=, an operand of the concatenation,
;     an argument of a function); in a calculation or a comparison it stays a number
; Texts that the new language cannot read afterwards stay as they are: "unsupported" for syntax that is deliberately
; missing (%, ^=, %=, <>, touching strings), "failed" for everything else (v1 could not read most of them either).
;
; The conversion is idempotent: the converted text converts to itself.
; This file reads no variable and calls no function of the application; it is safe in every process.
class V1ExprConverter {
    ; Characters that v2 knows as an escape behind a backtick.
    static KNOWN_ESCAPES := "nrtbvaf`"'``;%,:{}"
    ; Characters a name consists of (besides everything above 0x7F).
    static NAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    static OP_CHARS := "+-*/%=&|<>!:."

    static Convert(text, kind := "expression") {
        if (kind != "expression" && kind != "script")
            throw ValueError("V1ExprConverter.Convert: unknown kind '" kind "'")
        result := Map("status", "unchanged", "text", text, "changes", [], "messages", [], "classes", [])
        if (Trim(text, " `t`r`n") = "")
            return result

        syntax := []
        V1ExprConverter._ScanSyntax(text, syntax)
        step1 := V1ExprConverter._Apply(text, syntax)

        parsed := Expr.Parse(step1, kind)
        if (!parsed["ok"]) {
            err := parsed["errors"][1]
            msg := err["message"]
            unsupported := InStr(msg, "not supported") || InStr(msg, "is not valid; write") || InStr(msg, "two string literals")
            result["status"] := unsupported ? "unsupported" : "failed"
            prefix := unsupported ? "unsupported syntax: " : "not valid in the new language: "
            result["messages"].Push(prefix msg " (line " err["line"] ", column " err["col"] ")")
            if (unsupported) {
                result["classes"] := ["unsupported syntax"]
            } else {
                result["classes"] := V1ExprDetect.Classes(text, "", kind)
                if (result["classes"].Length = 0)
                    result["classes"].Push("unreadable text")
            }
            return result
        }

        result["classes"] := V1ExprDetect.Classes(step1, parsed["ast"], kind)
        literals := []
        V1ExprConverter._WalkLiterals(parsed["ast"], true, literals)
        final := V1ExprConverter._Apply(step1, literals)
        if (syntax.Length = 0 && literals.Length = 0)
            return result

        ; the result must be readable; if it is not, the text is a case for the user
        check := Expr.Parse(final, kind)
        if (!check["ok"]) {
            result["status"] := "failed"
            result["messages"].Push("the converted text is not valid (" check["errors"][1]["message"] "); the text is left as it is")
            return result
        }
        result["status"] := "converted"
        result["text"] := final
        for p in syntax
            result["changes"].Push(Map("rule", p["rule"], "old", p["old"], "new", p["ins"]))
        for p in literals
            result["changes"].Push(Map("rule", p["rule"], "old", p["old"], "new", p["ins"]))
        return result
    }

    ; --- step 1: the v1 text (token level) ------------------------------------------------------------------------

    ; Finds the places where the text has to change before the new parser can read it. Patches are Maps:
    ; pos, len (characters removed), ins (text inserted), old, rule.
    static _ScanSyntax(text, patches) {
        n := StrLen(text)
        i := 1
        while (i <= n) {
            c := SubStr(text, i, 1)
            if (c = '"') {
                i := V1ExprConverter._ScanString(text, i, n, patches)
            } else if (c = ";" && (i = 1 || InStr(" `t`r`n", SubStr(text, i - 1, 1)))) {
                j := InStr(text, "`n", , i)
                i := j ? j : n + 1
            } else if (V1ExprConverter._IsDigit(c)) {
                i := V1ExprConverter._ScanNumber(text, i, n, patches)
            } else if (V1ExprConverter._IsNameChar(c)) {
                i := V1ExprConverter._ScanName(text, i, n)
            } else if (InStr(V1ExprConverter.OP_CHARS, c)) {
                run := V1ExprConverter._OpRun(text, i, n)
                if (run = ".")
                    V1ExprConverter._CheckDot(text, i, n, patches)
                i += StrLen(run)
            } else {
                i += 1
            }
        }
    }

    ; (the comparison operators would throw a TypeError for two texts)
    static _IsDigit(c) => c != "" && InStr("0123456789", c)

    static _IsNameChar(c) => c != "" && (Ord(c) > 0x7F || InStr(V1ExprConverter.NAME_CHARS, c))

    static _OpRun(text, i, n) {
        j := i
        while (j <= n && InStr(V1ExprConverter.OP_CHARS, SubStr(text, j, 1)))
            j += 1
        return SubStr(text, i, j - i)
    }

    ; From the opening quote; returns the index behind the string. An unclosed string ends the scan of the line.
    static _ScanString(text, i, n, patches) {
        j := i + 1
        while (j <= n) {
            ch := SubStr(text, j, 1)
            if (ch = '"')
                return j + 1
            if (ch = "`n")
                return j
            if (ch = "``") {
                nx := SubStr(text, j + 1, 1)
                if (nx = "" || nx = "`n" || nx = "`r") {
                    j += 1
                    continue
                }
                if (!InStr(V1ExprConverter.KNOWN_ESCAPES, nx, true))
                    patches.Push(Map("pos", j, "len", 1, "ins", "", "old", "``" nx, "rule", "backtick"))
                j += 2
                continue
            }
            j += 1
        }
        return n + 1
    }

    ; A digit run at i. A decimal number is skipped as a whole; `5.` followed by something that cannot continue a name
    ; is the literal "5." in v1 (it passes it on as text) and becomes a string.
    static _ScanNumber(text, i, n, patches) {
        j := i
        while (j <= n && V1ExprConverter._IsDigit(SubStr(text, j, 1)))
            j += 1
        if (SubStr(text, j, 1) = ".") {
            k := j + 1
            while (k <= n && V1ExprConverter._IsDigit(SubStr(text, k, 1)))
                k += 1
            if (k > j + 1)
                return k
            nxt := SubStr(text, j + 1, 1)
            if (nxt = "" || InStr(" `t`r`n+-*/=<>!&|,)]};:", nxt)) {
                lit := SubStr(text, i, j + 1 - i)
                patches.Push(Map("pos", i, "len", StrLen(lit), "ins", '"' lit '"', "old", lit, "rule", "number literal spelling"))
                return j + 1
            }
        }
        ; a name that starts with digits (12abc) is an error in the new language and stays as it is
        while (j <= n && V1ExprConverter._IsNameChar(SubStr(text, j, 1)))
            j += 1
        return j
    }

    ; A name and its path (a.b.1): the dots inside belong to the path.
    static _ScanName(text, i, n) {
        j := i
        loop {
            while (j <= n && V1ExprConverter._IsNameChar(SubStr(text, j, 1)))
                j += 1
            if (SubStr(text, j, 1) = "." && V1ExprConverter._IsNameChar(SubStr(text, j + 1, 1)))
                j += 1
            else
                break
        }
        return j
    }

    ; A single dot that is not part of a number or a path is the concatenation operator in v1. The new language needs
    ; a space on both sides of it.
    static _CheckDot(text, i, n, patches) {
        prev := i > 1 ? SubStr(text, i - 1, 1) : ""
        nxt := SubStr(text, i + 1, 1)
        if (!(prev = '"' || prev = ")" || prev = " " || prev = "`t"))
            return
        if (prev != " " && prev != "`t")
            patches.Push(Map("pos", i, "len", 0, "ins", " ", "old", prev ".", "rule", "concatenation dot"))
        if (nxt != "" && !InStr(" `t`r`n", nxt))
            patches.Push(Map("pos", i + 1, "len", 0, "ins", " ", "old", "." nxt, "rule", "concatenation dot"))
    }

    ; --- step 2: number literals on the tree --------------------------------------------------------------------

    ; textForm: true if the text form of the value is what counts at this place of the tree.
    static _WalkLiterals(node, textForm, patches) {
        switch node["type"] {
            case "Number":
                if (textForm)
                    V1ExprConverter._CheckLiteral(node, patches)
            case "Script", "Block":
                for stmt in node["body"]
                    V1ExprConverter._WalkLiterals(stmt, false, patches)
            case "If":
                V1ExprConverter._WalkLiterals(node["cond"], false, patches)
                V1ExprConverter._WalkLiterals(node["then"], false, patches)
                if (node["else"] != "")
                    V1ExprConverter._WalkLiterals(node["else"], false, patches)
            case "ExprStmt":
                V1ExprConverter._WalkLiterals(node["expr"], false, patches)
            case "Assign":
                V1ExprConverter._WalkLiterals(node["target"], false, patches)
                V1ExprConverter._WalkLiterals(node["value"], node["op"] = ":=" || node["op"] = ".=", patches)
            case "Binary":
                isConcat := (node["op"] = ".")
                V1ExprConverter._WalkLiterals(node["left"], isConcat, patches)
                V1ExprConverter._WalkLiterals(node["right"], isConcat, patches)
            case "Unary":
                V1ExprConverter._WalkLiterals(node["operand"], false, patches)
            case "Index":
                V1ExprConverter._WalkLiterals(node["object"], false, patches)
                V1ExprConverter._WalkLiterals(node["key"], false, patches)
            case "Call":
                V1ExprConverter._WalkLiterals(node["callee"], false, patches)
                for arg in node["args"]
                    V1ExprConverter._WalkLiterals(arg, true, patches)
            case "DynVar":
                for part in node["parts"]
                    V1ExprConverter._WalkLiterals(part, false, patches)
        }
    }

    ; A decimal literal whose text form changes (1.50 is 1.5, 007 is 7, a 20 digit integer is a float) becomes a string.
    static _CheckLiteral(node, patches) {
        lit := node["text"]
        if (!RegExMatch(lit, "^\d+(\.\d+)?$"))
            return                              ; true, false, 0x1F, 1e3: not a decimal literal
        try {
            same := (String(Number(lit)) == lit)
        } catch {
            return
        }
        if (same)
            return
        patches.Push(Map("pos", node["pos"], "len", node["end"] - node["pos"], "ins", '"' lit '"', "old", lit,
            "rule", "number literal spelling"))
    }

    ; --- helpers ------------------------------------------------------------------------------------------------

    ; The text with the patches applied. Patches refer to positions of the input text; they do not overlap.
    static _Apply(text, patches) {
        if (patches.Length = 0)
            return text
        sorted := []
        for p in patches
            sorted.Push(p)
        ; insertion sort by position, stable (the patch sets are short)
        loop sorted.Length - 1 {
            k := A_Index + 1
            item := sorted[k]
            m := k - 1
            while (m >= 1 && sorted[m]["pos"] > item["pos"]) {
                sorted[m + 1] := sorted[m]
                m -= 1
            }
            sorted[m + 1] := item
        }
        out := ""
        pos := 1
        for p in sorted {
            out .= SubStr(text, pos, p["pos"] - pos) p["ins"]
            pos := p["pos"] + p["len"]
        }
        return out SubStr(text, pos)
    }
}
