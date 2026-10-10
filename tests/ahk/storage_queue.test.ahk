#Requires AutoHotkey v2.0
; Unit tests for src/storage/WriteQueue.ahk (WI-12, ARCHITECTURE 6.3): order, one answer per operation,
; deadlines, error codes, a failing answer does not stop the queue, FailAll at shutdown.
; No files and no timers are needed: RunOne is called directly.
#Include lib\Assert.ahk
#Include ..\..\src\storage\WriteQueue.ahk

; Operation helpers as named functions (a lambda cannot throw, see doc/HOW-TO.md).
ThrowBusy() {
    throw AhfError("busy probe", ErrCode.BUSY)
}

ThrowPlain() {
    throw ValueError("plain probe")
}

Bump(counter) {
    counter["n"] += 1
    return Map("answer", "done")
}

ThrowOnFinish(payload) {
    throw ValueError("finish probe")
}

; An operation whose answer is recorded in seen (an Array of Maps name/payload).
MakeOp(seen, name, run, deadline := "") {
    return Map("deadline", deadline, "run", run
        , "finish", (payload) => seen.Push(Map("name", name, "payload", payload)))
}

CaseRunsInOrderAndAnswersEachOnce() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(MakeOp(seen, "a", () => Bump(counter)))
    q.Add(MakeOp(seen, "b", () => Bump(counter)))
    q.Add(MakeOp(seen, "c", () => Bump(counter)))
    Assert.Equal(q.Pending, 3)
    Assert.True(q.RunOne())
    Assert.True(q.RunOne())
    Assert.True(q.RunOne())
    Assert.Equal(q.RunOne(), false)
    Assert.Equal(seen.Length, 3)
    Assert.Equal(seen[1]["name"], "a")
    Assert.Equal(seen[2]["name"], "b")
    Assert.Equal(seen[3]["name"], "c")
    Assert.Equal(counter["n"], 3)
    Assert.True(seen[1]["payload"]["ok"])
    Assert.Equal(seen[1]["payload"]["answer"], "done")
    Assert.Equal(q.Pending, 0)
}

CaseExpiredDeadlineIsNotRun() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(MakeOp(seen, "late", () => Bump(counter), 0))
    q.RunOne()
    Assert.Equal(counter["n"], 0)
    Assert.Equal(seen[1]["payload"]["error"]["code"], "timeout")
    Assert.Equal(seen[1]["payload"]["ok"], false)
}

CaseFutureDeadlineRuns() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(MakeOp(seen, "ok", () => Bump(counter), Time.NowMs() + 60000))
    q.RunOne()
    Assert.Equal(counter["n"], 1)
    Assert.True(seen[1]["payload"]["ok"])
}

CaseErrorsKeepTheirCode() {
    q := WriteQueue()
    seen := []
    q.Add(MakeOp(seen, "busy", ThrowBusy))
    q.Add(MakeOp(seen, "plain", ThrowPlain))
    q.RunOne()
    q.RunOne()
    Assert.Equal(seen[1]["payload"]["error"]["code"], "busy")
    Assert.Equal(seen[2]["payload"]["error"]["code"], "internal")
    Assert.Equal(seen[2]["payload"]["ok"], false)
}

CaseFailAllAnswersEveryWaitingOperation() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(MakeOp(seen, "first", () => Bump(counter)))
    q.Add(MakeOp(seen, "second", () => Bump(counter)))
    q.Add(MakeOp(seen, "third", () => Bump(counter)))
    q.RunOne()
    q.FailAll(ErrCode.SHUTTING_DOWN, "storage is stopping")
    Assert.Equal(q.Pending, 0)
    Assert.Equal(counter["n"], 1)
    Assert.Equal(seen.Length, 3)
    Assert.Equal(seen[2]["payload"]["error"]["code"], "shutting_down")
    Assert.Equal(seen[3]["payload"]["error"]["code"], "shutting_down")
}

CaseFailingAnswerDoesNotStopTheQueue() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(Map("deadline", "", "run", () => Bump(counter), "finish", ThrowOnFinish))
    q.Add(MakeOp(seen, "after", () => Bump(counter)))
    q.RunOne()
    q.RunOne()
    Assert.Equal(counter["n"], 2)
    Assert.Equal(seen.Length, 1)
    Assert.Equal(seen[1]["name"], "after")
}

TestRun.Init()
TestRun.Case("operations run in order and each is answered once", CaseRunsInOrderAndAnswersEachOnce)
TestRun.Case("an operation past its deadline is not run and gets timeout", CaseExpiredDeadlineIsNotRun)
TestRun.Case("an operation before its deadline runs", CaseFutureDeadlineRuns)
TestRun.Case("errors keep their code (AhfError) or become internal", CaseErrorsKeepTheirCode)
TestRun.Case("FailAll answers every waiting operation with the given code", CaseFailAllAnswersEveryWaitingOperation)
TestRun.Case("a failing answer does not stop the queue", CaseFailingAnswerDoesNotStopTheQueue)
TestRun.Finish()
