#Requires AutoHotkey v2.0

class Language {
    static CurrentLanguage := "en"
    static FallbackLanguage := "en"
    static Cache := Map()
    static Translations := Map()

    static Init(langCode := "en", langDir := "") {
        if (langDir == "")
            langDir := A_ScriptDir . "\language"

        Language.CurrentLanguage := langCode
        Language.Cache := Map()
        Language.Translations := Map()

        ; Load fallback language first
        fallbackPath := langDir . "\" . Language.FallbackLanguage . ".ini"
        if FileExist(fallbackPath)
            Language.LoadIni(fallbackPath)

        ; Load current language over fallback
        currentPath := langDir . "\" . langCode . ".ini"
        if FileExist(currentPath)
            Language.LoadIni(currentPath)
    }

    static LoadIni(iniPath) {
        try {
            content := FileRead(iniPath, "UTF-8")
            currentSection := ""
            Loop Parse, content, "`n", "`r" {
                line := Trim(A_LoopField)
                if (line == "" || SubStr(line, 1, 1) == ";")
                    continue

                if (SubStr(line, 1, 1) == "[" && SubStr(line, -1) == "]") {
                    currentSection := SubStr(line, 2, StrLen(line) - 2)
                    continue
                }

                if InStr(line, "=") {
                    pos := InStr(line, "=")
                    key := Trim(SubStr(line, 1, pos - 1))
                    val := Trim(SubStr(line, pos + 1))
                    keyClean := StrReplace(key, "_", " ")
                    Language.Translations[keyClean] := val
                    Language.Translations[key] := val
                }
            }
        } catch {
            ; File read error fallback
        }
    }

    static Translate(key, replacements*) {
        if (key == "")
            return ""

        keyClean := StrReplace(key, "_", " ")
        text := key
        if Language.Translations.Has(keyClean)
            text := Language.Translations[keyClean]
        else if Language.Translations.Has(key)
            text := Language.Translations[key]

        for idx, rep in replacements {
            text := StrReplace(text, "%" . idx . "%", String(rep))
        }

        return text
    }
}

x_lang(key, replacements*) {
    return Language.Translate(key, replacements*)
}
