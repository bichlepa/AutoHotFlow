#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Log.ahk

; Parses the command line of a role process (see work_items/phase2/README.md, role call).
; Accepted forms: --key=value (the value may contain "="), --flag (value 1), and positional words.
class Args {
    ; Keys every role process must receive.
    static RoleKeys := ["role", "session", "hub", "data"]

    ; Returns a Map of options (keys case-insensitive). Positional words go to the byref &positional.
    ; A repeated key keeps the last value and writes a log line with level a1.
    static Parse(argv, &positional := "") {
        options := Map()
        options.CaseSense := "Off"
        positional := []
        for word in argv {
            word := String(word)
            if (SubStr(word, 1, 2) != "--") {
                positional.Push(word)
                continue
            }
            body := SubStr(word, 3)
            if (body = "")
                throw AhfError("Args: empty option name in '" word "'", ErrCode.BAD_ARGS)
            eq := InStr(body, "=")
            if (eq = 0) {
                key := body
                value := 1
            } else {
                key := SubStr(body, 1, eq - 1)
                value := SubStr(body, eq + 1)
                if (key = "")
                    throw AhfError("Args: empty option name in '" word "'", ErrCode.BAD_ARGS)
            }
            if (options.Has(key))
                Log.Write("a1", "args", "duplicate option --" key ", last value wins")
            options[key] := value
        }
        return options
    }

    ; Throws AhfError (code bad_args) listing every missing key. keys is an Array of names.
    static Require(options, keys) {
        missing := []
        for key in keys
            if (!options.Has(key))
                missing.Push(key)
        if (missing.Length = 0)
            return
        names := ""
        for key in missing
            names .= (names = "" ? "" : ", ") "--" key
        throw AhfError("missing required option(s): " names, ErrCode.BAD_ARGS)
    }
}
