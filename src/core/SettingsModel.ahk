#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Json.ahk

; The global settings (WI-0077, REQ-SET-010, E0044, E0048, E0068, E0069, E0071, PROTOCOL 4.2 "Settings", 4.6 Settings.json).
; This class is the model only: the keys with type, default and range, the checks, the file text and the mapping of the
; settings of v1. It holds no state and sends nothing. Owners (ARCHITECTURE 3): storage keeps the file, the engine keeps the
; runtime copy and publishes it; every other role takes what it needs from evt.settings.changed.
;
; A settings value inside AutoHotFlow is a Map key -> value with the types below. Truth values are 1 and 0 inside (like the
; parsed JSON); ToWire turns them into real JSON booleans for a message or the file (E0008).
;
;   key                       type     default                       range
;   language                  text     "" (language of Windows)      "" or a language code of 2 or 3 letters
;   executionPolicy           text     parallel                      parallel, skip, wait, stop (never "default")
;   workingDir                text     <My Documents>\AutoHotFlow    absolute path (drive or UNC), no " < > | * ?
;   workers                   integer  8                             1 to 16 (E0048)
;   logLevelApp/Flow/Thread   integer  2                             0 to 3 (E0069: one threshold per source group a, f, t)
;   maxExecutionsPerMinute    integer  50000                         0 to 100000000, 0 = no limit (E0071)
;   maxWaitingInstances       integer  100                           0 to 1000000, 0 = no limit
;   maxParallelInstances      integer  100                           0 to 1000000, 0 = no limit
;   userLevel                 text     Beginner                      Beginner, Advanced, Programmer (REQ-USE-010)
;   notifyUnhandledErrors     boolean  true                          (REQ-USE-070, WI-0075)
;   startWithWindows          boolean  false                         (WI-0079)
;   runAsAdmin                boolean  false                         (WI-0079)
;   windowPositions           object   {}                            window name -> {x, y, w, h} (UI state, WI-0073)
class SettingsModel {
    static FORMAT_VERSION := 1
    static MAX_WORKERS := 16
    static DEFAULT_WORKERS := 8
    static DEFAULT_LOG_LEVEL := 2
    static MAX_POSITIONS := 50
    static POLICIES := ["parallel", "skip", "wait", "stop"]
    static USER_LEVELS := ["Beginner", "Advanced", "Programmer"]
    ; The viewers of the help window (WI-0111, E0099): the setting helpViewer.
    static HELP_VIEWERS := ["auto", "webview2", "classic", "browser"]
    ; The Windows language (A_Language, a hexadecimal LCID) -> language code, by the primary language (LCID & 0x3FF).
    ; A language that has no entry gets English. A new language of AutoHotFlow adds a line here.
    static WINDOWS_LANGUAGES := Map(0x07, "de", 0x09, "en", 0x12, "ko", 0x19, "ru")
    static FALLBACK_LANGUAGE := "en"

    static _table := ""

    ; The keys in the order of the file.
    static Keys() {
        keys := []
        for entry in SettingsModel._Spec()
            keys.Push(entry["key"])
        return keys
    }

    ; Map key -> default value.
    static Defaults() {
        out := Map()
        for entry in SettingsModel._Spec()
            out[entry["key"]] := SettingsModel._Default(entry)
        return out
    }

    static Has(key) => SettingsModel._Entry(key) != ""

    static Default(key) {
        entry := SettingsModel._Entry(key)
        if (entry = "")
            throw AhfError("unknown setting '" key "'", ErrCode.BAD_PAYLOAD)
        return SettingsModel._Default(entry)
    }

    ; --- checks -----------------------------------------------------------------------------------------------------

    ; The checked and normalised value of one setting. Throws AhfError (bad_payload) that names the key.
    static Check(key, value) {
        entry := SettingsModel._Entry(key)
        if (entry = "")
            throw AhfError("unknown setting '" key "'", ErrCode.BAD_PAYLOAD)
        try {
            return SettingsModel._CheckValue(entry, value)
        } catch as e {
            if (e is AhfError) {
                wrapped := AhfError("setting '" key "': " e.Message, ErrCode.BAD_PAYLOAD)
                if (e.HasProp("reason"))
                    wrapped.reason := e.reason
                throw wrapped
            }
            throw e
        }
    }

    ; The checked partial set: a Map key -> normalised value. Nothing is applied here; the first bad key throws.
    static CheckPartial(partial) {
        if (!(partial is Map))
            throw AhfError("settings must be an object", ErrCode.BAD_PAYLOAD)
        out := Map()
        for key, value in partial
            out[key] := SettingsModel.Check(key, value)
        return out
    }

    ; A whole set of settings from raw data (the parsed file): a missing or invalid value counts as its default. problems
    ; (ByRef) is an Array of Map(key, kind, text): kind "missing" (not in the data) or "invalid" (checked and refused); a key
    ; that is not a setting is listed as "unknown" and dropped.
    static Normalize(raw, &problems := "") {
        problems := []
        out := SettingsModel.Defaults()
        if (!(raw is Map)) {
            problems.Push(Map("key", "", "kind", "invalid", "text", "the settings are not an object"))
            return out
        }
        for entry in SettingsModel._Spec() {
            key := entry["key"]
            if (!raw.Has(key)) {
                problems.Push(Map("key", key, "kind", "missing", "text", "setting '" key "' is missing, the default is used"))
                continue
            }
            try {
                out[key] := SettingsModel._CheckValue(entry, raw[key])
            } catch as e {
                if (!(e is AhfError))
                    throw e
                problems.Push(Map("key", key, "kind", "invalid", "text", "setting '" key "': " e.Message ", the default is used"))
            }
        }
        for key, _ in raw {
            if (key != "formatVersion" && !SettingsModel.Has(key))
                problems.Push(Map("key", key, "kind", "unknown", "text", "unknown setting '" key "' is dropped"))
        }
        return out
    }

    ; The set current with the checked partial set applied. Returns a new Map.
    static Merge(current, checkedPartial) {
        out := Map()
        for key, value in current
            out[key] := value
        for key, value in checkedPartial
            out[key] := value
        return out
    }

    ; --- file and wire ----------------------------------------------------------------------------------------------

    ; The set as it goes over a message: truth values are real JSON booleans. Returns a new Map.
    static ToWire(settings) {
        out := Map()
        for entry in SettingsModel._Spec() {
            key := entry["key"]
            if (!settings.Has(key))
                continue
            value := settings[key]
            out[key] := (entry["type"] = "bool") ? Json.Bool(value) : value
        }
        return out
    }

    ; The text of Settings.json (UTF-8, indentation 2, keys sorted by Json.Stringify).
    static ToText(settings) {
        wire := SettingsModel.ToWire(settings)
        wire["formatVersion"] := SettingsModel.FORMAT_VERSION
        return Json.Stringify(wire, 2)
    }

    ; The raw data of the text of Settings.json: a Map. Throws JsonError for invalid JSON and AhfError (bad_payload) when the
    ; root is not an object or the file has a format version that this program does not know.
    static FromText(text) {
        data := Json.Parse(text)
        if (!(data is Map))
            throw AhfError("Settings.json: the root must be an object", ErrCode.BAD_PAYLOAD)
        version := data.Get("formatVersion", SettingsModel.FORMAT_VERSION)
        if (!IsInteger(version) || Integer(version) < 1 || Integer(version) > SettingsModel.FORMAT_VERSION)
            throw AhfError("Settings.json: unknown formatVersion '" (IsObject(version) ? "" : version) "'", ErrCode.BAD_PAYLOAD)
        return data
    }

    ; --- language ---------------------------------------------------------------------------------------------------

    ; The language code that the texts use: the setting, or (empty) the language of Windows (REQ-LNG-020). winLang is
    ; A_Language (a parameter for the tests); the environment variable AHF_WINDOWS_LANGUAGE (a hexadecimal LCID) replaces it.
    static LanguageCode(setting, winLang := "") {
        code := IsObject(setting) ? "" : Trim(String(setting))
        if (code != "")
            return StrLower(code)
        if (winLang = "")
            winLang := EnvGet("AHF_WINDOWS_LANGUAGE")   ; replaces the language of Windows (the tests set 0409 = English)
        if (winLang = "")
            winLang := A_Language
        if (!RegExMatch(winLang, "^[0-9A-Fa-f]{4}$"))
            return SettingsModel.FALLBACK_LANGUAGE
        primary := Integer("0x" winLang) & 0x3FF
        return SettingsModel.WINDOWS_LANGUAGES.Get(primary, SettingsModel.FALLBACK_LANGUAGE)
    }

    ; --- settings of v1 ---------------------------------------------------------------------------------------------

    ; The settings of v1 (the parsed settings.json of its data folder) as v2 settings (E0068, MIGRATION): the working
    ; directory, the language, the execution policy, the user level and the three log levels are taken over; start with
    ; Windows and run as administrator are not (otherwise v1 and v2 would both start with Windows), "Log to file" does not
    ; exist in v2 (E0069) and "hide demo flows" comes with the demonstration flows (REQ-MGR-060). A value that v2 refuses is not taken over (the v2 value stays).
    ; Returns Map(settings: Map of v2 keys, taken: [Map(v1, key)], skipped: [Map(v1, reason)]). reason is a Lang key
    ; suffix: "not_taken" (deliberately), "dropped" (no such setting in v2), "later" (the setting comes later), "default_language" (v1 default en), "invalid" (the value is
    ; refused).
    static FromV1(v1) {
        out := Map("settings", Map(), "taken", [], "skipped", [])
        if (!(v1 is Map))
            return out
        pairs := [["UILanguage", "language"], ["FlowWorkingDir", "workingDir"], ["FlowExecutionPolicy", "executionPolicy"]
            , ["ShowElementsLevel", "userLevel"], ["LogLevelApp", "logLevelApp"], ["LogLevelFlow", "logLevelFlow"]
            , ["LogLevelThread", "logLevelThread"]]
        for pair in pairs {
            v1Key := pair[1]
            key := pair[2]
            if (!v1.Has(v1Key))
                continue
            ; v1 writes UILanguage "en" into every settings file, also when the user never chose a language; the file does not
            ; tell the two cases apart, so "en" is not taken over and the user keeps "language of Windows" (REQ-LNG-020).
            if (key = "language" && StrLower(Trim(String(v1[v1Key]))) = "en") {
                out["skipped"].Push(Map("v1", v1Key, "reason", "default_language", "text", ""))
                continue
            }
            try {
                out["settings"][key] := SettingsModel.Check(key, v1[v1Key])
                out["taken"].Push(Map("v1", v1Key, "key", key))
            } catch as e {
                if (!(e is AhfError))
                    throw e
                out["skipped"].Push(Map("v1", v1Key, "reason", "invalid", "text", e.Message))
            }
        }
        for v1Key in ["runAsAdmin"]
            if (v1.Has(v1Key))
                out["skipped"].Push(Map("v1", v1Key, "reason", "not_taken", "text", ""))
        if (v1.Has("LogToFile"))
            out["skipped"].Push(Map("v1", "LogToFile", "reason", "dropped", "text", ""))
        if (v1.Has("HideDemoFlows"))                       ; the setting comes with the demonstration flows (REQ-MGR-060)
            out["skipped"].Push(Map("v1", "HideDemoFlows", "reason", "later", "text", ""))
        return out
    }

    ; --- the table --------------------------------------------------------------------------------------------------

    static _Spec() {
        if (IsObject(SettingsModel._table))
            return SettingsModel._table
        s := []
        s.Push(Map("key", "language", "type", "language", "default", ""))
        s.Push(Map("key", "executionPolicy", "type", "enum", "default", "parallel", "values", SettingsModel.POLICIES))
        s.Push(Map("key", "workingDir", "type", "path", "default", ""))
        s.Push(Map("key", "workers", "type", "int", "default", SettingsModel.DEFAULT_WORKERS, "min", 1, "max", SettingsModel.MAX_WORKERS))
        s.Push(Map("key", "logLevelApp", "type", "int", "default", SettingsModel.DEFAULT_LOG_LEVEL, "min", 0, "max", 3))
        s.Push(Map("key", "logLevelFlow", "type", "int", "default", SettingsModel.DEFAULT_LOG_LEVEL, "min", 0, "max", 3))
        s.Push(Map("key", "logLevelThread", "type", "int", "default", SettingsModel.DEFAULT_LOG_LEVEL, "min", 0, "max", 3))
        s.Push(Map("key", "maxExecutionsPerMinute", "type", "int", "default", 50000, "min", 0, "max", 100000000))
        s.Push(Map("key", "maxWaitingInstances", "type", "int", "default", 100, "min", 0, "max", 1000000))
        s.Push(Map("key", "maxParallelInstances", "type", "int", "default", 100, "min", 0, "max", 1000000))
        s.Push(Map("key", "userLevel", "type", "enum", "default", "Beginner", "values", SettingsModel.USER_LEVELS))
        s.Push(Map("key", "notifyUnhandledErrors", "type", "bool", "default", 1))
        s.Push(Map("key", "startWithWindows", "type", "bool", "default", 0))
        s.Push(Map("key", "runAsAdmin", "type", "bool", "default", 0))
        s.Push(Map("key", "helpViewer", "type", "enum", "default", "auto", "values", SettingsModel.HELP_VIEWERS))
        s.Push(Map("key", "windowPositions", "type", "positions", "default", ""))
        SettingsModel._table := s
        return s
    }

    static _Entry(key) {
        if (IsObject(key))
            return ""
        for entry in SettingsModel._Spec() {
            if (entry["key"] = key)
                return entry
        }
        return ""
    }

    ; The default of an entry. The working directory depends on the user (My Documents); the positions are a new Map each time.
    static _Default(entry) {
        switch entry["type"] {
            case "path":
                return A_MyDocuments "\AutoHotFlow"
            case "positions":
                return Map()
        }
        return entry["default"]
    }

    ; A refusal of a check with its reason: reason is an Array [Lang key, arguments...] for the settings dialog. The
    ; message stays English: the engine answers it so.
    static _Refuse(text, reason) {
        err := AhfError(text, ErrCode.BAD_PAYLOAD)
        err.reason := reason
        return err
    }

    static _CheckValue(entry, value) {
        switch entry["type"] {
            case "language":
                return SettingsModel._CheckLanguage(value)
            case "enum":
                return SettingsModel._CheckEnum(entry["values"], value)
            case "path":
                return SettingsModel._CheckPath(value)
            case "int":
                return SettingsModel._CheckInt(value, entry["min"], entry["max"])
            case "bool":
                return SettingsModel._CheckBool(value)
            case "positions":
                return SettingsModel._CheckPositions(value)
        }
        throw AhfError("no check for the type " entry["type"], ErrCode.INTERNAL)
    }

    static _CheckLanguage(value) {
        if (IsObject(value))
            throw SettingsModel._Refuse("must be text", ["Refusal_must_be_text"])
        code := Trim(String(value))
        if (code = "")
            return ""
        if (!RegExMatch(code, "^[A-Za-z]{2,3}$"))
            throw SettingsModel._Refuse("must be empty or a language code of 2 or 3 letters", ["Refusal_language"])
        return StrLower(code)
    }

    ; The listed value in its own spelling (the match ignores case).
    static _CheckEnum(values, value) {
        if (!IsObject(value)) {
            for item in values {
                if (StrLower(item) = StrLower(String(value)))
                    return item
            }
        }
        list := ""
        for item in values
            list .= (list = "" ? "" : ", ") item
        throw SettingsModel._Refuse("must be one of " list, ["Refusal_one_of", list])
    }

    static _CheckPath(value) {
        if (IsObject(value))
            throw SettingsModel._Refuse("must be text", ["Refusal_must_be_text"])
        path := Trim(String(value))
        if (path = "")
            throw SettingsModel._Refuse("must not be empty", ["Refusal_empty"])
        if (StrLen(path) > 259)
            throw SettingsModel._Refuse("is too long", ["Refusal_too_long"])
        if (!RegExMatch(path, "^([A-Za-z]:\\|\\\\[^\\])"))
            throw SettingsModel._Refuse("must be an absolute path", ["Refusal_absolute_path"])
        if (RegExMatch(SubStr(path, 3), '[<>"|*?\x00-\x1F]'))
            throw SettingsModel._Refuse("contains a character that is not allowed in a path", ["Refusal_path_characters"])
        ; no trailing backslash, except the root of a drive ("C:\")
        while (StrLen(path) > 3 && SubStr(path, -1) = "\")
            path := SubStr(path, 1, -1)
        return path
    }

    static _CheckInt(value, low, high) {
        if (IsObject(value) || !RegExMatch(String(value), "^-?\d+$"))
            throw SettingsModel._Refuse("must be a whole number from " low " to " high, ["Refusal_whole_number", low, high])
        n := Integer(value)
        if (n < low || n > high)
            throw SettingsModel._Refuse("must be a whole number from " low " to " high, ["Refusal_whole_number", low, high])
        return n
    }

    static _CheckBool(value) {
        if (value == Json.True)
            return 1
        if (value == Json.False)
            return 0
        if (!IsObject(value)) {
            text := StrLower(String(value))
            if (text = "1" || text = "true")
                return 1
            if (text = "0" || text = "false")
                return 0
        }
        throw SettingsModel._Refuse("must be true or false", ["Refusal_bool"])
    }

    ; windowPositions: window name -> Map(x, y, w, h), whole numbers. A new Map is returned (the caller's is not kept).
    static _CheckPositions(value) {
        if (!(value is Map))
            throw AhfError("must be an object", ErrCode.BAD_PAYLOAD)
        if (value.Count > SettingsModel.MAX_POSITIONS)
            throw AhfError("holds at most " SettingsModel.MAX_POSITIONS " windows", ErrCode.BAD_PAYLOAD)
        out := Map()
        for name, pos in value {
            if (!RegExMatch(name, "^[A-Za-z0-9_.\- ]{1,60}$"))
                throw AhfError("window name '" name "' is not valid", ErrCode.BAD_PAYLOAD)
            if (!(pos is Map))
                throw AhfError("window '" name "' must be an object with x, y, w and h", ErrCode.BAD_PAYLOAD)
            one := Map()
            for field in ["x", "y", "w", "h"] {
                if (!pos.Has(field))
                    throw AhfError("window '" name "' lacks '" field "'", ErrCode.BAD_PAYLOAD)
                limitLow := (field = "x" || field = "y") ? -100000 : 0
                one[field] := SettingsModel._CheckInt(pos[field], limitLow, 100000)
            }
            out[name] := one
        }
        return out
    }
}
