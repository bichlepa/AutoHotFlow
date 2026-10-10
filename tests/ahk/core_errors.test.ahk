#Requires AutoHotkey v2.0
; Unit tests for src/core/Errors.ahk (WI-03).
#Include lib\Assert.ahk
#Include ..\..\src\core\Errors.ahk

ThrowTimeout() {
    throw AhfTimeoutError("no answer in 5000 ms")
}

ThrowProtocol() {
    throw ProtocolError("unknown message type", ErrCode.UNKNOWN_TYPE)
}

ThrowBaseWithCode() {
    throw AhfError("device busy", "busy")
}

ThrowBaseDefault() {
    throw AhfError("plain")
}

ThrowElement() {
    throw ElementError("hotkey not set")
}

ThrowJson() {
    throw JsonError("unexpected end of text at line 1, column 9")
}

CheckTimeoutCode() {
    err := Assert.Throws(ThrowTimeout, AhfTimeoutError)
    Assert.Equal(err.code, "timeout")
    Assert.Equal(err.Message, "no answer in 5000 ms")
}

CheckCatchAsAhfError() {
    caught := ""
    try {
        ThrowTimeout()
    } catch AhfError as e {
        caught := e.code
    }
    Assert.Equal(caught, "timeout")
}

CheckProtocolErrorExplicitCode() {
    err := Assert.Throws(ThrowProtocol, ProtocolError)
    Assert.Equal(err.code, "unknown_type")
}

CheckProtocolErrorPresetCode() {
    err := ProtocolError("no code given")
    Assert.Equal(err.code, "bad_payload")
}

CheckBaseWithCode() {
    err := Assert.Throws(ThrowBaseWithCode, AhfError)
    Assert.Equal(err.code, "busy")
    Assert.Equal(err.Message, "device busy")
}

CheckBaseDefaultCode() {
    err := Assert.Throws(ThrowBaseDefault, AhfError)
    Assert.Equal(err.code, "internal")
}

CheckElementCode() {
    err := Assert.Throws(ThrowElement, ElementError)
    Assert.Equal(err.code, "exception")
    Assert.True(err is AhfError)
    Assert.True(err is Error)
}

CheckJsonCode() {
    err := Assert.Throws(ThrowJson, JsonError)
    Assert.Equal(err.code, "bad_json")
    Assert.True(err is AhfError)
}

TestRun.Init()

TestRun.Case("AhfTimeoutError presets code timeout", CheckTimeoutCode)
TestRun.Case("a thrown AhfError is caught by catch AhfError as e", CheckCatchAsAhfError)
TestRun.Case("ProtocolError takes an explicit code", CheckProtocolErrorExplicitCode)
TestRun.Case("ProtocolError without code has preset bad_payload", CheckProtocolErrorPresetCode)
TestRun.Case("AhfError takes code as second argument", CheckBaseWithCode)
TestRun.Case("AhfError without code has code internal", CheckBaseDefaultCode)
TestRun.Case("ElementError presets code exception", CheckElementCode)
TestRun.Case("JsonError presets code bad_json", CheckJsonCode)

TestRun.Finish()
