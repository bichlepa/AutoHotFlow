#Requires AutoHotkey v2.0

; Test role "slow_shutdown" for tests/integration/test_supervisor.py (WI-07). Not part of the product.
; It is healthy but takes SHUTDOWN_DELAY_MS to answer sys.shutdown. Role._OnShutdown sends sys.bye right
; after OnShutdown returns, so the delay is spent here, with a kernel sleep (DllCall Sleep, not AHK's
; Sleep). The supervisor must wait for it and must not terminate it as long as the deadline holds.
; Registered only with --test-roles.
class SlowShutdownRole extends Role {
    static SHUTDOWN_DELAY_MS := 1200

    OnShutdown(deadlineMs) {
        DllCall("Sleep", "uint", SlowShutdownRole.SHUTDOWN_DELAY_MS)
    }
}
