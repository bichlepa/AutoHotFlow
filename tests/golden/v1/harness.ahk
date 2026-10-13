; Golden data harness for the AutoHotkey v1 code base (AutoHotkey_H 1.1.32, 32 bit).
;
; RUN ONLY WITH v1\AutoHotKey\AutoHotFlow.exe through tools/golden_v1.py (which uses tools/ahkrun.py
; --interpreter). This is v1 syntax; the v2 interpreter cannot load it. The file is not named
; *.test.ahk on purpose, so pytest does not collect it as a v2 test.
;
; It includes the unchanged v1 sources for tokenizer, parser, evaluator, variable access and JSON,
; replaces everything these files need from the rest of v1 (shared object store, critical section,
; logger, lang, flow and element properties) with small stand-ins, runs the cases of one input file
; and writes one JSON line per case to the output file.
;
; Arguments: <input.json> <output.jsonl> <working dir> [first case index (1 based)]
;   input.json: {"cases": [ ... ]} written by tools/golden_v1.py (normalized, all numbers as text)
;   working dir: temp folder; global and static variables of v1 live in <working dir>\Variables
;
; Nothing here opens a dialog. A case that hangs is ended by the watchdog (result "timeout" and the
; process exits; the generator restarts after that case).

#NoEnv
#SingleInstance Off
SetBatchLines, -1

; ---- globals the v1 sources expect (super-global: declared outside of functions) ----
global _WorkingDir := ""
global _execution := ""
global _share := ""
global empty := ""
global G_Log := ""
global G_Running := false
global G_CaseStart := 0
global G_CaseId := ""
global G_OutPath := ""

if (A_Args.Length() < 3)
{
	FileAppend, usage: harness.ahk input.json output.jsonl workdir [first]`n, *
	ExitApp, 2
}
_WorkingDir := A_Args[3]
FileCreateDir, %_WorkingDir%

; ---- v1 sources, read-only. Order does not matter for functions and classes; the file
; "Global variables.ahk" has top-level code (it creates <working dir>\Variables), so _WorkingDir is set above.
#Include %A_ScriptDir%\..\..\..\v1\Lib\Json\Jxon.ahk
#Include %A_ScriptDir%\..\..\..\v1\Lib\Objects\Objects.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Common\Variables\Code tokenizer.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Common\Variables\Code parser.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Common\Variables\Code evaluator.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Common\Variables\Expression evaluator.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Common\Variables\Global variables.ahk
#Include %A_ScriptDir%\..\..\..\v1\Source_Execution\Variables\Variables.ahk

G_Main()
ExitApp, 0

; =====================================================================================
; Stand-ins for what the v1 sources need from the rest of v1
; =====================================================================================

_EnterCriticalSection()
{
}
_LeaveCriticalSection()
{
}

; v1: language\language.ahk. Returns the key with the numbered arguments filled in; no translation.
lang(langvar, langReplacements*)
{
	result := langvar
	for index, value in langReplacements
		result := StrReplace(result, "%" index "%", value)
	return result
}

; v1: Source_Common\Debug\Logger.ahk. Collects the entries; the harness writes them into the result.
logger(LogLevel, LoggingText, logSource = "common", showGui = false)
{
	entry := []
	entry.push(LogLevel)
	entry.push(LoggingText)
	entry.push(logSource)
	G_Log.push(entry)
}

; v1: Source_Execution\API\API for Elements.ahk (x_GetWorkingDir) needs the flow settings; fixed here.
x_GetWorkingDir(Environment)
{
	return "<flow working dir>"
}

_getFlowProperty(FlowID, path)
{
	if (path = "name")
		return "GoldenFlow"
	return ""
}
_getElementProperty(FlowID, ElementID, path)
{
	if (path = "name")
		return "GoldenElement"
	return ""
}
_getShared(path)
{
	if (path = "AhfVersion")
		return "golden"
	return ""
}

; ---- copies of the v1 property accessors of Source_Common\Multithreading\Shared Variables.ahk
; (same code, without the critical section; they work on the object _execution) ----
_getInstanceProperty(InstanceID, path, clone = true)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
		value := ObjFullyClone(objectPath[1][objectPath[2]])
	Else
		value := objectPath[1][objectPath[2]]
	return value
}
_setInstanceProperty(InstanceID, path, value, clone = true)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID], path)
	if (clone)
		objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
}
_deleteInstanceProperty(InstanceID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID], path)
	objectPath[1].delete(objectPath[2])
}
_getInstancePropertyObjectIdList(InstanceID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID], path)
	result := []
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	return result
}
_existsInstanceProperty(InstanceID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID], path)
	result := objectPath[1].haskey(objectPath[2])
	return result
}
_getThreadProperty(InstanceID, ThreadID, path, clone = true)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
		value := ObjFullyClone(objectPath[1][objectPath[2]])
	Else
		value := objectPath[1][objectPath[2]]
	return value
}
_setThreadProperty(InstanceID, ThreadID, path, value, clone = true)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	if (clone)
		objectPath[1][objectPath[2]] := ObjFullyClone(value)
	Else
		objectPath[1][objectPath[2]] := value
}
_deleteThreadProperty(InstanceID, ThreadID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	objectPath[1].delete(objectPath[2])
}
_getThreadPropertyObjectIdList(InstanceID, ThreadID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	result := []
	for key, value in objectPath[1][objectPath[2]]
	{
		result.push(key)
	}
	return result
}
_existsThreadProperty(InstanceID, ThreadID, path)
{
	objectPath := parseObjectPath(_execution.instances[InstanceID].threads[ThreadID], path)
	result := objectPath[1].haskey(objectPath[2])
	return result
}
parseObjectPath(obj, path)
{
	loop,parse,path,% "."
	{
		lastPathPart:=A_LoopField
		objLast:=obj
		obj:=obj[A_LoopField]
	}
	return [objLast, lastPathPart]
}

; =====================================================================================
; JSON output
; =====================================================================================

; true if the value is a pure number (the test that Jxon_Dump uses)
G_IsNumber(v)
{
	if (IsObject(v) or v = "")
		return false
	return (ObjGetCapacity([v], 1) == "")
}

G_Quote(s)
{
	s := "" s
	s := StrReplace(s, "\", "\\")
	s := StrReplace(s, """", "\""")
	s := StrReplace(s, "`n", "\n")
	s := StrReplace(s, "`r", "\r")
	s := StrReplace(s, "`t", "\t")
	s := StrReplace(s, "`b", "\b")
	s := StrReplace(s, "`f", "\f")
	out := ""
	Loop, parse, s
	{
		code := Asc(A_LoopField)
		if (code < 32 or code > 126)
			out .= Format("\u{:04X}", code)
		else
			out .= A_LoopField
	}
	return """" out """"
}

; natural JSON of a value: objects as JSON objects or arrays (arrays when the keys are 1..n),
; pure numbers bare (when they are valid JSON numbers), everything else as string
G_Raw(v)
{
	if IsObject(v)
	{
		isArray := true
		count := 0
		for k, x in v
		{
			count++
			if (k != count or ObjGetCapacity([k], 1) != "")
			{
				isArray := false
				break
			}
		}
		out := ""
		first := true
		for k, x in v
		{
			if (not first)
				out .= ","
			first := false
			if (not isArray)
				out .= G_Quote(k) ":"
			out .= G_Raw(x)
		}
		return isArray ? "[" out "]" : "{" out "}"
	}
	if (G_IsNumber(v) and RegExMatch(v, "^-?\d+(\.\d+)?$"))
		return "" v
	return G_Quote(v)
}

; typed value: {"type": "number"|"text"|"object", "value": ..., "text": "" . value (not for objects)}
G_Typed(v)
{
	if IsObject(v)
		return "{""type"":""object"",""value"":" G_Raw(v) "}"
	if (G_IsNumber(v))
		return "{""type"":""number"",""value"":" G_Raw(v) ",""text"":" G_Quote("" v) "}"
	return "{""type"":""text"",""value"":" G_Quote(v) ",""text"":" G_Quote("" v) "}"
}

; value from the normalized input: {"t": "n"|"s"|"o", "v": ...}
G_FromTyped(tv)
{
	if (tv.t = "n")
		return tv.v + 0
	if (tv.t = "o")
		return tv.v
	return tv.v
}

; =====================================================================================
; Case execution
; =====================================================================================

G_Watchdog:
if (G_Running and A_TickCount - G_CaseStart > 8000)
{
	G_Running := false
	line := "{""id"":" G_Quote(G_CaseId) ",""outcome"":""timeout""}`n"
	FileAppend, % line, % G_OutPath, UTF-8-RAW
	ExitApp, 3
}
return

G_Main()
{
	global G_OutPath, G_Running, G_CaseStart, G_CaseId
	inputPath := A_Args[1]
	G_OutPath := A_Args[2]
	first := A_Args[4] ? A_Args[4] : 1
	FileRead, src, *P65001 %inputPath%
	data := Jxon_Load(src)
	cases := data.cases
	if (first = 1)
	{
		line := "{""harness"":{""ahkVersion"":" G_Quote(A_AhkVersion) ",""unicode"":" (A_IsUnicode ? 1 : 0) ",""ptrSize"":" A_PtrSize "}}`n"
		FileAppend, % line, % G_OutPath, UTF-8-RAW
	}
	SetTimer, G_Watchdog, 250
	index := first
	while (index <= cases.MaxIndex())
	{
		c := cases[index]
		G_CaseId := c.id
		G_CaseStart := A_TickCount
		G_Running := true
		line := G_RunCase(c)
		G_Running := false
		FileAppend, % line "`n", % G_OutPath, UTF-8-RAW
		index++
	}
}

G_RunCase(c)
{
	global _execution, _WorkingDir, G_Log
	G_Log := []

	; fresh working directory for global and static variables. Removing and creating a folder takes
	; about 0.4 s on this machine, so it is only done when the previous case left something there.
	left := false
	Loop, Files, %_WorkingDir%\Variables\*.*, FDR
	{
		left := true
		break
	}
	if (left)
	{
		FileRemoveDir, %_WorkingDir%\Variables, 1
		FileCreateDir, %_WorkingDir%\Variables
	}

	; fresh object store: one instance with one thread
	instanceID := "instance1"
	threadID := "thread1"
	newThread := {}
	newThread.id := threadID
	newThread.ThreadID := threadID
	newThread.loopvars := {}
	newThread.loopvarsHidden := {}
	newThread.threadvars := {}
	newThread.threadvarsHidden := {}
	newInstance := {}
	newInstance.id := instanceID
	newInstance.InstanceID := instanceID
	newInstance.FlowID := "flow1"
	newInstance.InstanceVars := {}
	newInstance.InstanceVarsHidden := {}
	newInstance.threads := {}
	newInstance.threads[threadID] := newThread
	_execution := {}
	_execution.instances := {}
	_execution.instances[instanceID] := newInstance
	env := {InstanceID: instanceID, ThreadID: threadID, FlowID: "flow1", ElementID: "element1"}

	; initial variables
	for scope, vars in c.vars
	{
		for name, tv in vars
		{
			value := G_FromTyped(tv)
			if (scope = "instance")
				InstanceVariable_Set(env, name, value)
			else if (scope = "thread")
				ThreadVariable_Set(env, name, value)
			else if (scope = "loop")
				LoopVariable_Set(env, name, value)
			else if (scope = "global")
				GlobalVariable_Set(env, name, value)
			else if (scope = "static")
				StaticVariable_Set(env, name, value)
		}
	}
	G_Log := []   ; the setup is not part of the case

	common := c.common ? true : false
	kind := c.kind
	parts := []
	parts.push("""id"":" G_Quote(c.id))
	parts.push("""kind"":" G_Quote(kind))

	class_parser.errors := []
	class_evaluator.errors := []
	outcome := "ok"
	valueJson := ""
	extra := []

	; No try/catch around the run, on purpose: inside a try block the commands that set ErrorLevel
	; (FileDelete of a missing file ...) throw an exception, which v1 does not do (it never calls these
	; functions inside a try). An uncaught error opens a dialog; tools/ahkrun.py catches it and the
	; generator records the case as "uncaught_error".
	{
		if (kind = "expression")
		{
			r := Var_EvaluateExpression(env, c.text, common)
			if (r.error != "")
			{
				outcome := class_parser.errors.MaxIndex() ? "parse_error" : "eval_error"
				extra.push("""errorText"":" G_Quote(r.error))
			}
			else
				valueJson := G_Typed(r.result)
		}
		else if (kind = "script")
		{
			r := var_evaluateScript(env, c.text, common)
			if (r.errors.MaxIndex())
				outcome := "eval_error"
			else if (class_parser.errors.MaxIndex())
				outcome := "parse_error_ignored"
			valueJson := G_Typed(r.res)
		}
		else if (kind = "replace")
		{
			pars := c.convertObjects ? "ConvertObjectToString" : ""
			if (common)
				r := Var_replaceVariables_Common(env, c.text, pars)
			else
				r := Var_replaceVariables(env, c.text, pars)
			valueJson := G_Typed(r)
		}
		else if (kind = "checkname")
		{
			r := Var_CheckName(c.text, true)
			r2 := Var_CheckName(c.text)
			valueJson := G_Typed(r)
			extra.push("""boolResult"":" G_Typed(r2))
		}
		else if (kind = "destination")
		{
			if (common)
				r := Var_RetrieveDestination_Common(c.text, c.location)
			else
				r := Var_RetrieveDestination(c.text, c.location)
			valueJson := G_Typed(r)
		}
		else if (kind = "varget")
		{
			if (common)
				r := Var_Get_Common(env, c.text)
			else
				r := Var_Get(env, c.text)
			valueJson := G_Typed(r)
			if (common)
				t := Var_GetType_Common(env, c.text)
			else
				t := Var_GetType(env, c.text)
			extra.push("""varType"":" G_Quote(t))
			if (not common)
				extra.push("""location"":" G_Quote(Var_GetLocation(env, c.text)))
		}
		else if (kind = "varset")
		{
			value := G_FromTyped(c.value)
			if (common)
				Var_Set_Common(env, c.text, value, c.location)
			else
				Var_Set(env, c.text, value, c.location)
			valueJson := G_Typed("")
		}
		else
		{
			outcome := "unknown_kind"
		}
	}

	parts.push("""outcome"":" G_Quote(outcome))
	if (valueJson != "")
		parts.push("""value"":" valueJson)

	; structured errors of the parser and the evaluator
	errs := []
	for i, err in class_parser.errors
		errs.push("{""phase"":""parse"",""description"":" G_Quote(err.description) ",""line"":" G_Raw(err.line) ",""col"":" G_Raw(err.col) ",""token"":" G_Quote(err.value) "}")
	for i, err in class_evaluator.errors
		errs.push("{""phase"":""eval"",""description"":" G_Quote(err.description) ",""line"":" G_Raw(err.line) ",""col"":" G_Raw(err.col) ",""token"":" G_Quote(err.value) "}")
	parts.push("""errors"":[" G_Join(errs, ",") "]")

	for i, x in extra
		parts.push(x)

	parts.push("""variables"":" G_DumpVariables(env))

	logs := []
	for i, entry in G_Log
		logs.push("[" G_Quote(entry[1]) "," G_Quote(entry[2]) "," G_Quote(entry[3]) "]")
	parts.push("""log"":[" G_Join(logs, ",") "]")

	return "{" G_Join(parts, ",") "}"
}

G_Join(list, sep)
{
	out := ""
	for i, x in list
	{
		if (i > 1)
			out .= sep
		out .= x
	}
	return out
}

; all variables of all scopes after the run (hidden ones are not listed)
G_DumpVariables(env)
{
	global _execution
	instance := _execution.instances[env.InstanceID]
	thread := instance.threads[env.ThreadID]
	scopes := []
	scopes.push("""instance"":" G_DumpObjectVars(instance.InstanceVars))
	scopes.push("""thread"":" G_DumpObjectVars(thread.threadvars))
	scopes.push("""loop"":" G_DumpObjectVars(thread.loopvars))

	list := Var_GetListOfGlobalVars(env)
	out := ""
	for i, name in list
	{
		if (i > 1)
			out .= ","
		out .= G_Quote(name) ":" G_Typed(GlobalVariable_Get(env, name))
	}
	scopes.push("""global"":{" out "}")

	list := Var_GetListOfStaticVars(env)
	out := ""
	for i, name in list
	{
		if (i > 1)
			out .= ","
		out .= G_Quote(name) ":" G_Typed(StaticVariable_Get(env, name))
	}
	scopes.push("""static"":{" out "}")
	return "{" G_Join(scopes, ",") "}"
}

G_DumpObjectVars(obj)
{
	out := ""
	first := true
	for name, value in obj
	{
		if (not first)
			out .= ","
		first := false
		out .= G_Quote(name) ":" G_Typed(value)
	}
	return "{" out "}"
}
