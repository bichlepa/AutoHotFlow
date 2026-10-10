#Requires AutoHotkey v2.0

; Test role "hanger" for tests/integration/test_supervisor.py (WI-07). Not part of the product. It
; answers like an echo role. The test freezes it with psutil.suspend(); the supervisor must then see
; that no pong comes and treat it as hung. Registered only with --test-roles.
class HangerRole extends Role {
    RegisterHandlers() {
        this.On("cmd.test.echo", (msg) => Map("echo", msg.payload))
    }
}
