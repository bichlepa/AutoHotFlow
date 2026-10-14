#Requires AutoHotkey v2.0

; Timing hooks for the load-phase measurement of tools/measure_r3.py (WI-46, F-282). Only measurement entries include
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

class R3Hooks {
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
        return c * 1000.0 / R3Hooks.freq
    }

    static Install() {
        DllCall("QueryPerformanceFrequency", "Int64*", &f := 0)
        R3Hooks.freq := f
        R3Hooks.file := EnvGet("AHF_R3_LOADFILE")
        R3Hooks.Wrap(FlowDefinition, "FromText", R3Hooks.OnFromText)
        R3Hooks.Wrap(FlowExprConvert, "Run", R3Hooks.OnConvert)
        R3Hooks.Wrap(Engine.Prototype, "_OnFlowRead", R3Hooks.OnFlowRead)
        R3Hooks.Wrap(Engine.Prototype, "_OnFlowList", R3Hooks.OnFlowList)
        R3Hooks.Wrap(Engine.Prototype, "_Loaded", R3Hooks.OnLoaded)
        R3Hooks.Wrap(Engine.Prototype, "_VarsLoaded", R3Hooks.OnVarsLoaded)
        R3Hooks.Wrap(VarLoader.Prototype, "_OnAnswer", R3Hooks.OnVarAnswer)
    }

    ; Replaces method `name` of `obj` by hook(orig, self, args*); orig is the original function. hook is a static method of R3Hooks, so its own `this` comes first.
    static Wrap(obj, name, hook) {
        orig := obj.GetOwnPropDesc(name).Call
        obj.DefineProp(name, {Call: (self, args*) => hook(R3Hooks, orig, self, args*)})
    }

    static OnFlowList(orig, self, args*) {
        if (R3Hooks.tList = 0)
            R3Hooks.tList := R3Hooks.Now()
        return orig(self, args*)
    }

    static OnFlowRead(orig, self, args*) {
        t0 := R3Hooks.Now()
        R3Hooks.cur := Map("flow", args[2], "chars", 0, "parse_ms", 0.0, "convert_ms", 0.0, "pending", 0)
        try {
            res := args[4]
            R3Hooks.cur["chars"] := StrLen(res.payload.Get("text", ""))
        }
        try {
            return orig(self, args*)
        } finally {
            R3Hooks.cur["handler_ms"] := R3Hooks.Now() - t0
            R3Hooks.flows.Push(R3Hooks.cur)
            R3Hooks.cur := ""
        }
    }

    static OnFromText(orig, cls, args*) {
        t0 := R3Hooks.Now()
        try {
            return orig(cls, args*)
        } finally {
            if (IsObject(R3Hooks.cur))
                R3Hooks.cur["parse_ms"] := R3Hooks.Now() - t0
        }
    }

    static OnConvert(orig, cls, args*) {
        t0 := R3Hooks.Now()
        try {
            counts := orig(cls, args*)
            if (IsObject(R3Hooks.cur) && counts is Map)
                R3Hooks.cur["pending"] := counts["pending"]
            return counts
        } finally {
            if (IsObject(R3Hooks.cur))
                R3Hooks.cur["convert_ms"] := R3Hooks.Now() - t0
        }
    }

    static OnVarAnswer(orig, self, args*) {
        t0 := R3Hooks.Now()
        try {
            return orig(self, args*)
        } finally {
            R3Hooks.varMs += R3Hooks.Now() - t0
            R3Hooks.varN += 1
        }
    }

    static OnLoaded(orig, self, args*) {
        if (R3Hooks.tLoaded = 0)
            R3Hooks.tLoaded := R3Hooks.Now()
        return orig(self, args*)
    }

    static OnVarsLoaded(orig, self, args*) {
        tReady := R3Hooks.Now()
        result := orig(self, args*)
        R3Hooks.Flush(tReady)
        return result
    }

    static Flush(tReady) {
        if (R3Hooks.file = "")
            return
        text := ""
        for f in R3Hooks.flows {
            text .= '{"type":"flow","flow":"' f["flow"] '","chars":' f["chars"]
                . ',"parse_ms":' Format("{:.3f}", f["parse_ms"]) ',"convert_ms":' Format("{:.3f}", f["convert_ms"])
                . ',"handler_ms":' Format("{:.3f}", f["handler_ms"]) ',"pending":' f["pending"] '}`n'
        }
        text .= '{"type":"vars","handler_ms":' Format("{:.3f}", R3Hooks.varMs) ',"answers":' R3Hooks.varN '}`n'
        text .= '{"type":"phase","files_ms":' Format("{:.3f}", R3Hooks.tLoaded - R3Hooks.tList)
            . ',"vars_ms":' Format("{:.3f}", tReady - R3Hooks.tLoaded) '}`n'
        FileAppend(text, R3Hooks.file, "UTF-8-RAW")
    }
}

R3Hooks.Install()
