#Requires AutoHotkey v2.0
; Unit tests for src/core/Args.ahk (WI-03).
#Include lib\Assert.ahk
#Include ..\..\src\core\Args.ahk
#Include ..\..\src\core\Log.ahk

ParseEqualsInValue() {
    opts := Args.Parse(["--session=a=b"])
    Assert.Equal(opts["session"], "a=b")
}

ParseFlag() {
    opts := Args.Parse(["--headless"])
    Assert.True(opts.Has("headless"))
    Assert.Equal(opts["headless"], 1)
}

ParseEmptyValue() {
    opts := Args.Parse(["--data="])
    Assert.True(opts.Has("data"))
    Assert.Equal(opts["data"], "")
}

ParsePositional() {
    opts := Args.Parse(["--role=engine", "one", "two"], &positional)
    Assert.Equal(opts["role"], "engine")
    Assert.Equal(positional.Length, 2)
    Assert.Equal(positional[1], "one")
    Assert.Equal(positional[2], "two")
}

ParseKeysAreCaseInsensitive() {
    opts := Args.Parse(["--Role=engine"])
    Assert.Equal(opts["role"], "engine")
}

ParseDuplicateKeyLastWinsAndLogs() {
    Log.Configure(Log.Memory)
    Log.memoryLines := []
    opts := Args.Parse(["--role=a", "--role=b"])
    Log.Configure("")
    Assert.Equal(opts["role"], "b")
    Assert.Equal(Log.memoryLines.Length, 1)
    Assert.Equal(Log.memoryLines[1]["level"], "a1")
    Assert.True(InStr(Log.memoryLines[1]["text"], "--role"))
}

ParseEmptyOptionNameThrows() {
    err := Assert.Throws(() => Args.Parse(["--"]), AhfError)
    Assert.Equal(err.code, "bad_args")
}

ParseEmptyKeyWithValueThrows() {
    err := Assert.Throws(() => Args.Parse(["--=x"]), AhfError)
    Assert.Equal(err.code, "bad_args")
}

RequireAllPresent() {
    opts := Args.Parse(["--role=engine", "--session=s", "--hub=h", "--data=d"])
    Args.Require(opts, Args.RoleKeys)
}

RequireReportsEveryMissingKey() {
    opts := Args.Parse(["--role=engine"])
    err := Assert.Throws(() => Args.Require(opts, Args.RoleKeys), AhfError)
    Assert.Equal(err.code, "bad_args")
    Assert.True(InStr(err.Message, "--session"))
    Assert.True(InStr(err.Message, "--hub"))
    Assert.True(InStr(err.Message, "--data"))
    Assert.True(!InStr(err.Message, "--role"))
}

TestRun.Init()

TestRun.Case("--key=value keeps an equals sign in the value", ParseEqualsInValue)
TestRun.Case("--flag is stored as 1", ParseFlag)
TestRun.Case("--key= gives an empty string", ParseEmptyValue)
TestRun.Case("words without -- are returned as positional list", ParsePositional)
TestRun.Case("keys are case-insensitive", ParseKeysAreCaseInsensitive)
TestRun.Case("a repeated key keeps the last value and logs a1", ParseDuplicateKeyLastWinsAndLogs)
TestRun.Case("an empty option name throws AhfError bad_args", ParseEmptyOptionNameThrows)
TestRun.Case("an empty key before = throws AhfError bad_args", ParseEmptyKeyWithValueThrows)
TestRun.Case("Require passes when all role keys are present", RequireAllPresent)
TestRun.Case("Require names every missing key in the message", RequireReportsEveryMissingKey)

TestRun.Finish()
