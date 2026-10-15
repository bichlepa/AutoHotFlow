#Requires AutoHotkey v2.0
#Include ..\..\..\src\elements\base\ElementRegistry.ahk

; Test helper (WI-0022 point 3): code on file level that throws while the entry point is still loading, as a
; broken element file would (its ElementRegistry.Register call runs before AhfMain). It only acts with
; --test-roles AND --test-register-failure, so a product start never runs it.
class Test_RegisterFailure extends AhfElement {
    static Mode := "remote"      ; not a valid mode: Register throws
}

AhfTestRegisterFailure()

AhfTestRegisterFailure() {
    armed := 0
    for word in A_Args
        if (word = "--test-roles" || word = "--test-register-failure")
            armed += 1
    if (armed = 2)
        ElementRegistry.Register(Test_RegisterFailure)
}
