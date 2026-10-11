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

; Fails (asks for a retry) the first `failures` times, then succeeds. Counts the runs.
BusyThenOk(counter, failures) {
    counter["n"] += 1
    if (counter["n"] <= failures)
        return Map("retry", true, "message", "file held")
    return Map()
}

CaseRetryKeepsTheOrderAndSucceedsLater() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    after := Map("n", 0)
    first := MakeOp(seen, "first", () => BusyThenOk(counter, 2))
    first["retryMs"] := 5000
    q.Add(first)
    q.Add(MakeOp(seen, "second", () => Bump(after)))
    Assert.True(q.RunOne())
    Assert.Equal(seen.Length, 0)     ; asked for a retry, not answered yet
    Assert.Equal(q.Pending, 2)       ; and still at the head
    q.RunOne()
    Assert.Equal(seen.Length, 0)
    q.RunOne()                       ; third run succeeds
    Assert.Equal(counter["n"], 3)
    Assert.Equal(after["n"], 0)      ; the second operation did not overtake
    q.RunOne()
    Assert.Equal(seen.Length, 2)
    Assert.Equal(seen[1]["name"], "first")
    Assert.True(seen[1]["payload"]["ok"])
    Assert.Equal(seen[2]["name"], "second")
}

CaseRetryEndsWithBusyWhenTheTimeIsUp() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    op := MakeOp(seen, "stuck", () => BusyThenOk(counter, 1000))
    op["retryMs"] := 0
    q.Add(op)
    q.RunOne()
    Assert.Equal(seen.Length, 1)
    Assert.Equal(seen[1]["payload"]["ok"], false)
    Assert.Equal(seen[1]["payload"]["error"]["code"], "busy")
    Assert.Equal(q.Pending, 0)
}

; --- WI-25: two queues (requests first), time budget per timer run ------------------------------

Sleepy(counter, ms) {
    counter["n"] += 1
    ; busy wait: Sleep would let the queue's own timer run operations in between
    endAt := Time.NowMs() + ms
    while (Time.NowMs() < endAt)
        continue
    return Map()
}

CaseRequestsOvertakeLogOperationsAndBothKeepTheirOrder() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.AddLow(MakeOp(seen, "log1", () => Bump(counter)))
    q.AddLow(MakeOp(seen, "log2", () => Bump(counter)))
    q.Add(MakeOp(seen, "req1", () => Bump(counter)))
    q.AddLow(MakeOp(seen, "log3", () => Bump(counter)))
    q.Add(MakeOp(seen, "req2", () => Bump(counter)))
    Assert.Equal(q.Pending, 5)
    while (q.RunOne())
        continue
    names := ""
    for entry in seen
        names .= (names = "" ? "" : ",") entry["name"]
    Assert.Equal(names, "req1,req2,log1,log2,log3")
}

CaseBudgetRunsManyOperationsInOneGo() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    loop 300
        q.AddLow(MakeOp(seen, "l" A_Index, () => Bump(counter)))
    ran := q.RunFor(1000)
    Assert.Equal(ran, 300)
    Assert.Equal(q.Pending, 0)
}

CaseBudgetStopsAfterTheOperationThatUsedItUp() {
    Critical("On")   ; the queue's own timer must not run operations while the test counts
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    loop 40
        q.AddLow(MakeOp(seen, "s" A_Index, () => Sleepy(counter, 5)))
    ran := q.RunFor(20)
    ; each operation takes at least 5 ms, so a 20 ms budget cannot cover all 40; at least one runs
    Assert.True(ran >= 1 && ran < 40)
    Assert.Equal(q.Pending, 40 - ran)
}

CaseOneBigOperationIsNeverSplit() {
    Critical("On")   ; the queue's own timer must not run operations while the test counts
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    q.Add(MakeOp(seen, "big", () => Sleepy(counter, 60)))
    q.Add(MakeOp(seen, "next", () => Bump(counter)))
    ran := q.RunFor(10)
    Assert.Equal(ran, 1)
    Assert.Equal(seen.Length, 1)
    Assert.Equal(q.Pending, 1)
}

CaseLogRetryWaitsForItsDelayWhileRequestsGoOn() {
    q := WriteQueue()
    seen := []
    counter := Map("n", 0)
    after := Map("n", 0)
    log := MakeOp(seen, "log", () => BusyThenOk(counter, 1))
    log["retryMs"] := 5000
    log["retryDelayMs"] := 300
    q.AddLow(log)
    Assert.True(q.RunOne())                ; asks for a retry in 300 ms
    Assert.Equal(q.RunOne(), false)        ; not due yet, nothing else is waiting
    Assert.True(q.NextWaitMs() > 100)
    q.Add(MakeOp(seen, "req", () => Bump(after)))
    Assert.True(q.RunOne())                ; a request does not wait for the delay
    Assert.Equal(after["n"], 1)
    Assert.Equal(counter["n"], 1)          ; the log operation did not run again
    Assert.Equal(q.Pending, 1)
}

TestRun.Init()
TestRun.Case("operations run in order and each is answered once", CaseRunsInOrderAndAnswersEachOnce)
TestRun.Case("an operation past its deadline is not run and gets timeout", CaseExpiredDeadlineIsNotRun)
TestRun.Case("an operation before its deadline runs", CaseFutureDeadlineRuns)
TestRun.Case("errors keep their code (AhfError) or become internal", CaseErrorsKeepTheirCode)
TestRun.Case("FailAll answers every waiting operation with the given code", CaseFailAllAnswersEveryWaitingOperation)
TestRun.Case("a failing answer does not stop the queue", CaseFailingAnswerDoesNotStopTheQueue)
TestRun.Case("a retry keeps the order and can succeed later", CaseRetryKeepsTheOrderAndSucceedsLater)
TestRun.Case("a retry past its time is answered with busy", CaseRetryEndsWithBusyWhenTheTimeIsUp)
TestRun.Case("requests overtake log operations, both keep their order", CaseRequestsOvertakeLogOperationsAndBothKeepTheirOrder)
TestRun.Case("a budget runs many small operations in one go", CaseBudgetRunsManyOperationsInOneGo)
TestRun.Case("a budget stops after the operation that used it up", CaseBudgetStopsAfterTheOperationThatUsedItUp)
TestRun.Case("one big operation is never split", CaseOneBigOperationIsNeverSplit)
TestRun.Case("a log retry waits for its delay while requests go on", CaseLogRetryWaitsForItsDelayWhileRequestsGoOn)
TestRun.Finish()
