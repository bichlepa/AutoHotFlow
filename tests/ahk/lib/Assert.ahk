#Requires AutoHotkey v2.0
#SingleInstance Off
; Minimal unit test library for tests/ahk/*.test.ahk (see doc/TESTSTRATEGIE.md, level L1).
;
; Usage in a test file:
;   #Include lib\Assert.ahk
;   TestRun.Init()                         ; reads the result file path from A_Args[1]
;   TestRun.Case("name", () => Assert.Equal(1, 1))
;   TestRun.Skip("name", "reason")
;   TestRun.Finish()                       ; writes the summary line and exits
;
; Output: one JSON object per line in the result file. Types:
;   {"type":"case","name":..,"status":"pass"|"fail"|"error"|"skip","message":..}
;   {"type":"fatal","message":..}          ; unhandled error outside of a case
;   {"type":"summary","passed":n,"failed":n,"errors":n,"skipped":n}
; Exit code is 0 only if no case failed or errored and the run finished normally.

class AssertFailed extends Error {
}

class Assert {
    ; Compares type and value. Strings are compared case-sensitively.
    static Equal(actual, expected, msg := "") {
        if (Type(actual) != Type(expected) || !(actual == expected))
            throw AssertFailed(Assert.Join(msg, "expected " Assert.Show(expected) " but got " Assert.Show(actual)))
    }

    ; Passes if v is true (non-zero number, or boolean 1).
    static True(v, msg := "") {
        if (!v)
            throw AssertFailed(Assert.Join(msg, "expected true but got " Assert.Show(v)))
    }

    ; Calls fn(). Passes if it throws; if errorClass is given, the error must be an instance of it.
    ; Returns the caught error.
    static Throws(fn, errorClass := "", msg := "") {
        try {
            fn()
        } catch as e {
            if (errorClass != "" && !(e is errorClass))
                throw AssertFailed(Assert.Join(msg, "expected " errorClass.Name " but got " Type(e) ": " e.Message))
            return e
        }
        throw AssertFailed(Assert.Join(msg, "expected an exception but none was thrown"))
    }

    static Join(msg, text) {
        return (msg = "") ? text : msg ": " text
    }

    static Show(v) {
        if (IsObject(v))
            return "<" Type(v) ">"
        if (Type(v) = "String")
            return '"' v '"' " (String)"
        return v " (" Type(v) ")"
    }
}

; Errors outside of a case end the run at once with a clear record (no error dialog may block the run).
; A plain function is used: static class methods are not valid OnError callbacks in AHK v2.
AhfUnhandledError(e, mode) {
    try {
        FileAppend('{"type":"fatal","message":"' TestRun.Escape(Type(e) ": " e.Message " (line " e.Line ")") '"}' "`n", TestRun.resultPath, "UTF-8")
    }
    ExitApp(2)
}

class TestRun {
    static resultPath := ""
    static passed := 0
    static failed := 0
    static errors := 0
    static skipped := 0
    static initialized := false

    ; Reads the result path from the first command line argument and installs the error handler.
    static Init() {
        if (this.initialized)
            return
        this.initialized := true
        if (A_Args.Length < 1)
            throw ValueError("TestRun.Init: missing result file argument")
        this.resultPath := A_Args[1]
        try FileDelete(this.resultPath)
        OnError(AhfUnhandledError)
    }

    ; Runs fn. Assert failures become "fail", any other exception becomes "error".
    static Case(name, fn) {
        this.Init()
        try {
            fn()
            this.passed++
            this.Write("case", name, "pass", "")
        } catch AssertFailed as e {
            this.failed++
            this.Write("case", name, "fail", e.Message)
        } catch as e {
            this.errors++
            this.Write("case", name, "error", Type(e) ": " e.Message " (line " e.Line ")")
        }
    }

    static Skip(name, reason := "") {
        this.Init()
        this.skipped++
        this.Write("case", name, "skip", reason)
    }

    ; Writes the summary and exits. The exit code is 0 only without failures or errors.
    static Finish() {
        this.Init()
        line := '{"type":"summary","passed":' this.passed ',"failed":' this.failed
            . ',"errors":' this.errors ',"skipped":' this.skipped '}'
        FileAppend(line "`n", this.resultPath, "UTF-8")
        ExitApp((this.failed + this.errors) ? 1 : 0)
    }

    static Write(type, name, status, message) {
        line := '{"type":"' type '","name":"' this.Escape(name) '","status":"' status '","message":"' this.Escape(message) '"}'
        FileAppend(line "`n", this.resultPath, "UTF-8")
    }

    static Escape(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`t", "\t")
        return s
    }
}
