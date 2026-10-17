#Requires AutoHotkey v2.0
; Unit tests for src/core/NoticeThrottle.ahk (WI-0075, PROTOCOL 4.7): the first notice of a key goes out at once, the ones
; within the window are held back and counted, and the count is taken once.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\NoticeThrottle.ahk

FirstOfAKeyGoesOutAtOnce() {
    t := NoticeThrottle(10000)
    Assert.Equal(t.Offer("exception|f", 1000), true, "the first notice goes out")
    Assert.Equal(t.Offer("limit|g", 1000), true, "another key is not held back")
}

NoticesWithinTheWindowAreHeldAndCounted() {
    t := NoticeThrottle(10000)
    t.Offer("exception|f", 1000)
    Assert.Equal(t.Offer("exception|f", 2000), false, "held back")
    Assert.Equal(t.Offer("exception|f", 9999), false, "still within the window")
    Assert.Equal(t.Take("exception|f"), 2, "the count of the held back notices")
    Assert.Equal(t.Take("exception|f"), 0, "the count is taken once")
}

WindowEndsAfterTenSeconds() {
    t := NoticeThrottle(10000)
    t.Offer("k", 1000)
    Assert.Equal(t.Offer("k", 10999), false, "one ms before the end")
    Assert.Equal(t.Offer("k", 11000), true, "the window has ended at 11 s")
}

SentRestartsTheWindow() {
    t := NoticeThrottle(10000)
    t.Offer("k", 1000)
    t.Sent("k", 11000)                 ; a trailing notice with the count went out at 11 s
    Assert.Equal(t.Offer("k", 15000), false, "the window started with the trailing notice")
}

DueMsIsTheTimeLeftOfTheWindow() {
    t := NoticeThrottle(10000)
    Assert.Equal(t.DueMs("k", 5000), 0, "a key without notices is not due")
    t.Offer("k", 1000)
    Assert.Equal(t.DueMs("k", 4000), 7000, "seven seconds left")
    Assert.Equal(t.DueMs("k", 12000), 0, "the window has ended")
}

TestRun.Init()

TestRun.Case("The first notice of a key goes out at once, another key is not held back", FirstOfAKeyGoesOutAtOnce)
TestRun.Case("Notices within the window are held back and counted once", NoticesWithinTheWindowAreHeldAndCounted)
TestRun.Case("The window lasts 10 s", WindowEndsAfterTenSeconds)
TestRun.Case("A notice that goes out restarts the window", SentRestartsTheWindow)
TestRun.Case("DueMs is the time left of the window", DueMsIsTheTimeLeftOfTheWindow)

TestRun.Finish()
