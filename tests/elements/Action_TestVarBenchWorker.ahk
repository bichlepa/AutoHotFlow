#Requires AutoHotkey v2.0
#Include ..\..\src\core\Time.ahk
#Include ..\..\src\elements\base\AhfElement.ahk
#Include ..\..\src\elements\base\ElementRegistry.ahk

; Test element of WI-0050 (worker): measures the round trip of a variable request. It sets bench_x, then calls
; GetVar("bench_x") Count times and writes "median p95 max" in ms (three decimals) of the single calls into
; global_varbench_<Tag>. Pause (ms, default 0) waits between two calls (DllCall Sleep, so no message is handled in it).
; A large Count makes it a long-running element that asks all the time (fault tests: engine or worker killed while it
; asks).
class Action_TestVarBenchWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: variable request round trip, in a worker"
    static Category() => "Test"

    static Run(ctx, params) {
        count := Integer(params.Count)
        pause := params.HasProp("Pause") && params.Pause != "" ? Integer(params.Pause) : 0
        ctx.SetVar("bench_x", 1)
        times := []
        loop count {
            t0 := Time.NowMs()
            ctx.GetVar("bench_x")
            times.Push(Time.NowMs() - t0)
            if (pause > 0)
                DllCall("Sleep", "UInt", pause)
        }
        sorted := Action_TestVarBenchWorker.Sorted(times)
        n := sorted.Length
        text := Format("{:.3f} {:.3f} {:.3f}", sorted[Max(1, Ceil(n / 2))], sorted[Max(1, Ceil(n * 0.95))], sorted[n])
        ctx.SetVar("global_varbench_" params.Tag, text)
        ctx.Finish("normal")
    }

    static Sorted(values) {
        a := values.Clone()
        loop a.Length - 1 {
            j := A_Index + 1
            while (j > 1 && a[j] < a[j - 1]) {
                tmp := a[j], a[j] := a[j - 1], a[j - 1] := tmp
                j--
            }
        }
        return a
    }
}

ElementRegistry.Register(Action_TestVarBenchWorker)
