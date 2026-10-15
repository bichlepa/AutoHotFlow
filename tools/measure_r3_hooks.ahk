#Requires AutoHotkey v2.0

; Timing hooks for the load-phase measurement of tools/measure_r3.py (WI-0046, F-0282). Only measurement entries include
; this file (generated in a temporary folder); nothing in src/ does. The product code stays unchanged: the hooks wrap
; methods at run time and keep the timings in memory, and the file named by the environment variable AHF_R3_LOADFILE
; gets one JSON line per measured item when the engine reports ready (so the writes do not disturb the load).
;
; Lines (times in milliseconds, QueryPerformanceCounter):
;   {"type":"flow","flow":..,"chars":..,"parse_ms":..,"convert_ms":..,"handler_ms":..,"pending":..}
;       parse_ms = FlowDefinition.FromText, convert_ms = FlowExprConvert.Run, handler_ms = the whole answer handler
;       Engine._OnFlowRead (parse + convert + bookkeeping; not the frame parse of the message, which is before it)
;   {"type":"vars","handler_ms":..,"answers":..}   cost of the answer handlers of VarLoader (sum, count)
;   {"type":"phase","files_ms":..,"vars_ms":..}      first flow list answer to the last flow loaded (files_ms), last
;       flow loaded to evt.engine.ready (vars_ms)

class R0003Hooks {
    static freq := 0
    static flows := []
    static cur := ""
    static varMs := 0.0
    static varN := 0
    static tList := 0
    static tLoaded := 0
    static file := ""

    static Now() {
        DllCall("QueryPerformanceCounter", "Int64*", &c := 0)
        return c * 1000.0 / R0003Hooks.freq
    }

    static Install() {
        DllCall("QueryPerformanceFrequency", "Int64*", &f := 0)
        R0003Hooks.freq := f
        R0003Hooks.file := EnvGet("AHF_R3_LOADFILE")
        R0003Hooks.Wrap(FlowDefinition, "FromText", R0003Hooks.OnFromText)
        R0003Hooks.Wrap(FlowExprConvert, "Run", R0003Hooks.OnConvert)
        R0003Hooks.Wrap(Engine.Prototype, "_OnFlowRead", R0003Hooks.OnFlowRead)
        R0003Hooks.Wrap(Engine.Prototype, "_OnFlowList", R0003Hooks.OnFlowList)
        R0003Hooks.Wrap(Engine.Prototype, "_Loaded", R0003Hooks.OnLoaded)
        R0003Hooks.Wrap(Engine.Prototype, "_VarsLoaded", R0003Hooks.OnVarsLoaded)
        R0003Hooks.Wrap(VarLoader.Prototype, "_OnAnswer", R0003Hooks.OnVarAnswer)
    }

    ; Replaces method `name` of `obj` by hook(orig, self, args*); orig is the original function. hook is a static method of R0003Hooks, so its own `this` comes first.
    static Wrap(obj, name, hook) {
        orig := obj.GetOwnPropDesc(name).Call
        obj.DefineProp(name, {Call: (self, args*) => hook(R0003Hooks, orig, self, args*)})
    }

    static OnFlowList(orig, self, args*) {
        if (R0003Hooks.tList = 0)
            R0003Hooks.tList := R0003Hooks.Now()
        return orig(self, args*)
    }

    static OnFlowRead(orig, self, args*) {
        t0 := R0003Hooks.Now()
        R0003Hooks.cur := Map("flow", args[2], "chars", 0, "parse_ms", 0.0, "convert_ms", 0.0, "pending", 0)
        try {
            res := args[4]
            R0003Hooks.cur["chars"] := StrLen(res.payload.Get("text", ""))
        }
        try {
            return orig(self, args*)
        } finally {
            R0003Hooks.cur["handler_ms"] := R0003Hooks.Now() - t0
            R0003Hooks.flows.Push(R0003Hooks.cur)
            R0003Hooks.cur := ""
        }
    }

    static OnFromText(orig, cls, args*) {
        t0 := R0003Hooks.Now()
        try {
            return orig(cls, args*)
        } finally {
            if (IsObject(R0003Hooks.cur))
                R0003Hooks.cur["parse_ms"] := R0003Hooks.Now() - t0
        }
    }

    static OnConvert(orig, cls, args*) {
        t0 := R0003Hooks.Now()
        try {
            counts := orig(cls, args*)
            if (IsObject(R0003Hooks.cur) && counts is Map)
                R0003Hooks.cur["pending"] := counts["pending"]
            return counts
        } finally {
            if (IsObject(R0003Hooks.cur))
                R0003Hooks.cur["convert_ms"] := R0003Hooks.Now() - t0
        }
    }

    static OnVarAnswer(orig, self, args*) {
        t0 := R0003Hooks.Now()
        try {
            return orig(self, args*)
        } finally {
            R0003Hooks.varMs += R0003Hooks.Now() - t0
            R0003Hooks.varN += 1
        }
    }

    static OnLoaded(orig, self, args*) {
        if (R0003Hooks.tLoaded = 0)
            R0003Hooks.tLoaded := R0003Hooks.Now()
        return orig(self, args*)
    }

    static OnVarsLoaded(orig, self, args*) {
        tReady := R0003Hooks.Now()
        result := orig(self, args*)
        R0003Hooks.Flush(tReady)
        return result
    }

    static Flush(tReady) {
        if (R0003Hooks.file = "")
            return
        text := ""
        for f in R0003Hooks.flows {
            text .= '{"type":"flow","flow":"' f["flow"] '","chars":' f["chars"]
                . ',"parse_ms":' Format("{:.3f}", f["parse_ms"]) ',"convert_ms":' Format("{:.3f}", f["convert_ms"])
                . ',"handler_ms":' Format("{:.3f}", f["handler_ms"]) ',"pending":' f["pending"] '}`n'
        }
        text .= '{"type":"vars","handler_ms":' Format("{:.3f}", R0003Hooks.varMs) ',"answers":' R0003Hooks.varN '}`n'
        text .= '{"type":"phase","files_ms":' Format("{:.3f}", R0003Hooks.tLoaded - R0003Hooks.tList)
            . ',"vars_ms":' Format("{:.3f}", tReady - R0003Hooks.tLoaded) '}`n'
        FileAppend(text, R0003Hooks.file, "UTF-8-RAW")
    }
}

R0003Hooks.Install()
