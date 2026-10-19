#Requires AutoHotkey v2.0
; Unit tests for src/supervisor/Elevation.ahk (WI-0079): the command line of the elevated start.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\Elevation.ahk

; The words as Windows reads them back (CommandLineToArgvW, the rules the new process uses).
Parse(text) {
    n := 0
    p := DllCall("shell32\CommandLineToArgvW", "str", "prog" text, "int*", &n, "ptr")
    out := []
    loop n
        out.Push(StrGet(NumGet(p, (A_Index - 1) * A_PtrSize, "ptr"), "UTF-16"))
    DllCall("LocalFree", "ptr", p)
    out.RemoveAt(1)
    return out
}

TestRun.Case("words with blanks, quotes and a trailing backslash come back unchanged", () => CheckRoundTrip())
CheckRoundTrip() {
    words := ["--session=a", "--data=C:\my dir", 'say "hi"', "C:\dir with space\", "C:\plain\", 'a\"b', "", "x\\"]
    got := Parse(Elevation.ArgText(words))
    Assert.Equal(got.Length, words.Length)
    for i, w in words
        Assert.Equal(got[i], w)
}

TestRun.Case("a plain word stays as it is, a trailing backslash is doubled inside quotes", () => CheckForms())
CheckForms() {
    Assert.Equal(Elevation.ArgText(["--a=b"]), " --a=b")
    Assert.Equal(Elevation.ArgText(["C:\x y\"]), ' "C:\x y\\"')
    Assert.Equal(Elevation.ArgText(['a"b']), ' "a\"b"')
}

TestRun.Case("dropped options are removed, added words are appended", () => CheckDropAdd())
CheckDropAdd() {
    text := Elevation.ArgText(["--elevation-tried", "--fake-admin", "--keep=1"], ["elevation-tried", "fake-admin"], ["--elevation-tried"])
    Assert.Equal(text, " --keep=1 --elevation-tried")
}

TestRun.Finish()
