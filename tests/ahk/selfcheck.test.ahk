#Requires AutoHotkey v2.0
; Self check of the assert library (tests/ahk/lib/Assert.ahk). Must stay green.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk

TestRun.Init()

TestRun.Case("Equal passes for equal strings", () => Assert.Equal("abc", "abc"))
TestRun.Case("Equal passes for equal integers", () => Assert.Equal(42, 42))
TestRun.Case("True passes for 1", () => Assert.True(1 = 1))
ThrowBoom() {
    throw ValueError("boom")
}
TestRun.Case("Throws passes for thrown error", () => Assert.Throws(ThrowBoom, ValueError))
TestRun.Skip("Deliberately skipped case", "shows that skipped cases are reported and do not fail the run")

TestRun.Finish()
