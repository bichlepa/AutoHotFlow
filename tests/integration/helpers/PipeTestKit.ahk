#Requires AutoHotkey v2.0
; Shared helpers of the pipe test scripts (WI-04): deterministic test frames, result records.
; The frame generator must stay in sync with gen_text() in tests/integration/helpers/rawpipe.py.
#Include ..\..\..\src\core\Json.ahk

class Kit {
    static ALPHA_MIXED := "abc" Chr(0xE9) Chr(0x20AC) "xyz"   ; 1, 1, 1, 2, 3, 1, 1, 1 bytes in UTF-8
    static ALPHA_ASCII := "abcdefghij"

    ; Doubling concatenation: few string operations even for 1 MiB.
    static Repeat(s, n) {
        r := s
        while (StrLen(r) < n)
            r := r r
        return SubStr(r, 1, n)
    }

    ; Frame size in characters (= bytes for the ASCII variant). Covers 1 byte to 1 MiB and
    ; sizes around the 64 KiB read chunk of the connection.
    static GenSize(i) {
        if (i = 0)
            return 1
        if (Mod(i, 500) = 499)
            return 1048576
        if (Mod(i, 200) = 7)
            return 70000
        if (Mod(i, 101) = 0)
            return 65532 + Mod(i // 101, 9)
        if (Mod(i, 10) = 3)
            return 4000
        return 1 + Mod(i * 37, 2000)
    }

    ; Text of frame i: "<i>|" followed by a repeated alphabet, cut to GenSize(i) characters.
    ; Frames with an even index and at most 64 KiB use non-ASCII characters.
    static GenText(i) {
        n := Kit.GenSize(i)
        alpha := (n <= 65536 && Mod(i, 2) = 0) ? Kit.ALPHA_MIXED : Kit.ALPHA_ASCII
        return SubStr(i "|" Kit.Repeat(alpha, n), 1, n)
    }

    ; Appends one JSON object (a Map) as a line to the result file.
    ; The test process polls the file, so opening it can fail for a moment (sharing violation):
    ; retry briefly instead of losing the record.
    static Record(path, m) {
        text := Json.Stringify(m) "`n"
        loop 200 {
            try {
                FileAppend(text, path, "UTF-8-RAW")
                return
            } catch {
                DllCall("Sleep", "uint", 2)
            }
        }
    }

    static HandleCount() {
        count := 0
        DllCall("GetProcessHandleCount", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint*", &count)
        return count
    }

    ; "key=value" words of the command line to a Map.
    static Options(argv, from := 1) {
        m := Map()
        i := from
        while (i <= argv.Length) {
            p := InStr(argv[i], "=")
            if (p > 0)
                m[SubStr(argv[i], 1, p - 1)] := SubStr(argv[i], p + 1)
            i += 1
        }
        return m
    }
}
