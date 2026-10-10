#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk

; Execution policy decision for a new instance of a flow (WI-08, ARCHITEKTUR 5.1).
;
; Source in v1 (read, not run):
;   - v1/Source_Execution/Execution Task/Instances and Threads.ahk, function newInstance,
;     lines 14 to 44: the policy is read from flowSettings.ExecutionPolicy only if the flow
;     is executing ("executing" property). "default" is replaced by the global setting
;     FlowExecutionPolicy. "skip" skips the instance (callback "skipped"), "stop" stops all
;     instances of the flow and then starts a new one, every other value starts a new instance.
;   - v1/Source_Execution/Execution Task/Execution Task.ahk, lines 31 to 48: the dispatcher
;     reads the policy again, but from the flow root key "ExecutionPolicy", which does not exist
;     in v1 flows (the key is under flowSettings, see v1/Source_Common/Flows/Load.ahk:230).
;     For "wait" the dispatcher lets only the first running instance of a flow go on. In v1 this
;     gate is therefore unreachable (see work_items/phase2/WI-08-engine-core.md, open question 1).
;   - Global default: v1/Source_Common/Settings/Settings.ahk:14 ("parallel").
;   - Valid values: v1/Source_Common/Flows/Load.ahk:231 ("default", "parallel", "skip", "wait",
;     "stop"). Comparison is case-insensitive (v1 "=").
;
; Decision for a new instance:
;   not executing                 -> "start"          (all policies, v1 newInstance is only
;                                                      checked while the flow runs)
;   executing, parallel           -> "start"
;   executing, skip               -> "skip"
;   executing, stop               -> "stop_and_start" (stop the running instances, then start)
;   executing, wait               -> "wait"           (intended v1 behaviour, see Execution
;                                                      Task.ahk:37 to 48; the caller holds the
;                                                      instance until the flow is idle)
class ExecutionPolicy {
    ; The four concrete v1 values. "default" is only valid as flow policy (it resolves to the
    ; global value), never as global setting.
    static GLOBAL_VALUES := ["parallel", "skip", "wait", "stop"]

    ; policy: the flow's flowSettings.ExecutionPolicy. globalPolicy: the global setting, used
    ; when policy is "default" (v1 default: "parallel").
    ; Throws AhfError (code bad_args) for unknown values instead of guessing.
    static Decide(policy, flowIsExecuting, globalPolicy := "parallel") {
        effective := StrLower(policy)
        if (effective = "default")
            effective := StrLower(globalPolicy)
        if (!ExecutionPolicy.Contains(ExecutionPolicy.GLOBAL_VALUES, effective))
            throw AhfError("ExecutionPolicy.Decide: invalid policy '" policy "' (global '" globalPolicy "')", ErrCode.BAD_ARGS)

        if (!flowIsExecuting)
            return "start"
        if (effective = "skip")
            return "skip"
        if (effective = "stop")
            return "stop_and_start"
        if (effective = "wait")
            return "wait"
        return "start"
    }

    ; True if value is in list (case-insensitive, list values are lowercase).
    static Contains(list, value) {
        for item in list {
            if (item = value)
                return true
        }
        return false
    }
}
