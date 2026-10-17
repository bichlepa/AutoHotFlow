#Requires AutoHotkey v2.0
#Include Log.ahk

; Translated texts (E0028, WI-0042): the port of v1 lang() (v1/language/language.ahk) for every role. Elements and the
; engine call the global function Lang(key, args*) (Lang.ahk), which uses this table.
;
; The texts are the v1 files, unchanged: assets/language/<folder>/<code>.ini (basic: the texts of the program), and
; the texts of the element packages, src/elements/<package>/language/<code>.ini (WI-0047; Default: the files of the v1
; package Default). Each folder may have a file per language. A line "key=text" defines a text; section lines
; ("[common]") are ignored, and so is the section [language_info].
;
; As in v1 (lang() with readAll):
;   - "_" in a key is a space: Lang("Parameter_is_empty") finds "Parameter is empty".
;   - a key that is not in the language is looked up in the fallback language (English);
;   - a key that is in neither gives the key itself (with the spaces). v2 also writes an f3 log entry then.
;   - %1%, %2%, ... in the text are replaced by the arguments, every occurrence.
; The language is fixed to English until the settings exist (S0004); v1 read it from the setting UILanguage or the
; language of Windows.
;
; The files are read once, at the first call (one small file per folder and language). They are read-only assets of
; the program, which every role loads itself (ARCHITECTURE 4), not data of the user: storage does not own them.
class LangTable {
    static Code := "en"               ; the language (S0004: setting UILanguage)
    static Fallback := "en"
    static Dir := ""                  ; folder with the language folders; "" = assets\language of the program
    static PackagesDir := ""          ; folder with the element packages; "" = src\elements of the program
    static _texts := ""               ; Map key -> text of Code, or "" before the first load
    static _fallbackTexts := ""

    ; The translated text of key with the arguments filled in.
    static Get(key, args*) {
        if (key = "")
            return ""
        if (!IsObject(LangTable._texts))
            LangTable.Load()
        name := StrReplace(key, "_", " ")
        if (LangTable._texts.Has(name)) {
            text := LangTable._texts[name]
        } else if (LangTable._fallbackTexts.Has(name)) {
            text := LangTable._fallbackTexts[name]
        } else {
            text := name
            Log.Write("f3", "lang", "no text for the key '" name "' (language " LangTable.Code ")")
        }
        return LangTable.Fill(text, args)
    }

    ; Replaces %1%, %2%, ... by the arguments in one pass: an argument text that contains a placeholder is not replaced again.
    ; A placeholder without an argument stays.
    static Fill(text, args) {
        out := ""
        pos := 1
        while (RegExMatch(text, "%(\d+)%", &m, pos)) {
            out .= SubStr(text, pos, m.Pos - pos)
            n := Integer(m[1])
            out .= (n >= 1 && n <= args.Length) ? (IsObject(args[n]) ? "" : String(args[n])) : m[0]
            pos := m.Pos + m.Len
        }
        return out . SubStr(text, pos)
    }

    ; Reads the files of the language and of the fallback language. Called at the first Get; call it again after a
    ; change of Code or Dir (tests).
    static Load() {
        LangTable._texts := LangTable._Read(LangTable.Code)
        LangTable._fallbackTexts := (LangTable.Fallback = LangTable.Code) ? LangTable._texts
            : LangTable._Read(LangTable.Fallback)
    }

    static DefaultDir() => RegExReplace(A_LineFile, "\\src\\core\\[^\\]+$") "\assets\language"
    static DefaultPackagesDir() => RegExReplace(A_LineFile, "\\src\\core\\[^\\]+$") "\src\elements"

    ; Map key -> text of one language from every folder, folder "basic" first, then the others by name, then the
    ; language folders of the element packages by name. A later line with the same key replaces an earlier one, as in
    ; v1. A missing or unreadable file is skipped (f3 log).
    static _Read(code) {
        texts := Map()
        texts.CaseSense := "Off"           ; v1 keys are keys of an AutoHotkey v1 object: case does not matter
        dir := (LangTable.Dir != "") ? LangTable.Dir : LangTable.DefaultDir()
        folders := ["basic"]
        loop files dir "\*", "D" {         ; arch-ok: file-io language assets of the program, read once (ARCHITECTURE 4)
            if (A_LoopFileName != "basic")
                folders.Push(A_LoopFileName)
        }
        paths := []
        for folder in folders
            paths.Push(dir "\" folder "\" code ".ini")
        packages := (LangTable.PackagesDir != "") ? LangTable.PackagesDir : LangTable.DefaultPackagesDir()
        loop files packages "\*", "D"     ; arch-ok: file-io language files of the element packages, read once (ARCHITECTURE 4)
            paths.Push(A_LoopFileFullPath "\language\" code ".ini")
        for path in paths {
            if (!FileExist(path))
                continue
            try {
                text := FileRead(path, "UTF-8")    ; arch-ok: file-io language assets of the program, read once (ARCHITECTURE 4)
            } catch as e {
                Log.Write("f3", "lang", "cannot read " path ": " e.Message)
                continue
            }
            LangTable._Parse(text, texts)
        }
        return texts
    }

    ; The lines of one file into texts (v1 lang_ReadAllTranslations).
    static _Parse(text, texts) {
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        section := ""
        loop parse text, "`n", "`r" {
            line := A_LoopField
            if (RegExMatch(line, "^\s*\[(.*)\]\s*$", &m)) {
                section := m[1]
                continue
            }
            if (section = "language_info")
                continue
            pos := InStr(line, "=")
            if (!pos)
                continue
            key := StrReplace(SubStr(line, 1, pos - 1), "_", " ")
            texts[key] := SubStr(line, pos + 1)
        }
    }
}
