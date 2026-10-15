#Requires AutoHotkey v2.0
; Unit tests for src/engine/core/ExecutionPolicy.ahk (WI-0008, v1 newInstance and Execution Task 31-48).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\ExecutionPolicy.ahk

; Each row: [flow policy, flow executing, global policy, expected decision].
DecisionRows() {
    return [
        ; not executing: every policy starts the instance
        ["parallel", false, "parallel", "start"],
        ["skip", false, "parallel", "start"],
        ["wait", false, "parallel", "start"],
        ["stop", false, "parallel", "start"],
        ["default", false, "skip", "start"],
        ; executing, explicit flow policy
        ["parallel", true, "skip", "start"],
        ["skip", true, "parallel", "skip"],
        ["wait", true, "parallel", "wait"],
        ["stop", true, "parallel", "stop_and_start"],
        ; executing, "default" resolves to the global setting
        ["default", true, "parallel", "start"],
        ["default", true, "skip", "skip"],
        ["default", true, "wait", "wait"],
        ["default", true, "stop", "stop_and_start"],
        ; comparison is case-insensitive, as in v1
        ["SKIP", true, "parallel", "skip"],
        ["Stop", true, "parallel", "stop_and_start"],
        ["default", true, "Wait", "wait"]
    ]
}

DecisionTable() {
    for row in DecisionRows() {
        actual := ExecutionPolicy.Decide(row[1], row[2], row[3])
        Assert.Equal(actual, row[4], "policy " row[1] ", executing " row[2] ", global " row[3])
    }
}

DefaultGlobalIsParallel() {
    Assert.Equal(ExecutionPolicy.Decide("default", true), "start")
    Assert.Equal(ExecutionPolicy.Decide("default", false), "start")
}

InvalidFlowPolicyIsRejected() {
    err := Assert.Throws(DecideCall.Bind("bogus", true, "parallel"), AhfError)
    Assert.Equal(err.code, "bad_args")
}

InvalidGlobalPolicyIsRejected() {
    err := Assert.Throws(DecideCall.Bind("default", true, "bogus"), AhfError)
    Assert.Equal(err.code, "bad_args")
}

DefaultAsGlobalIsRejected() {
    err := Assert.Throws(DecideCall.Bind("default", true, "default"), AhfError)
    Assert.Equal(err.code, "bad_args")
}

EmptyPolicyIsRejected() {
    err := Assert.Throws(DecideCall.Bind("", true, "parallel"), AhfError)
    Assert.Equal(err.code, "bad_args")
}

DecideCall(policy, executing, globalPolicy) {
    return ExecutionPolicy.Decide(policy, executing, globalPolicy)
}

TestRun.Init()

TestRun.Case("Decide matches the v1 decision for every policy, executing state and global setting", DecisionTable)
TestRun.Case("Decide uses parallel as global default", DefaultGlobalIsParallel)
TestRun.Case("Decide rejects an unknown flow policy with bad_args", InvalidFlowPolicyIsRejected)
TestRun.Case("Decide rejects an unknown global policy with bad_args", InvalidGlobalPolicyIsRejected)
TestRun.Case("Decide rejects default as global setting", DefaultAsGlobalIsRejected)
TestRun.Case("Decide rejects an empty flow policy", EmptyPolicyIsRejected)

TestRun.Finish()
