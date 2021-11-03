
;Name of the element
Element_getName_Trigger_Hotstring()
{
	return x_lang("Hotstring")
}

;Category of the element
Element_getCategory_Trigger_Hotstring()
{
	return x_lang("User_interaction")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Hotstring()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Trigger_Hotstring()
{
	return "keyboard.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Hotstring()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Hotstring(Environment)
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Hotstring")})
	parametersToEdit.push({type: "Edit", id: "hotstring", default: "btw", content: ["RawString", "String"], contentID: "IsRaw", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "RequireEndingCharacter", default: 1, label: x_lang("Require an ending character")})
	parametersToEdit.push({type: "Checkbox", id: "OmitEndingCharacter", default: 0, label: x_lang("Omit the ending character after replacemenet")})
	parametersToEdit.push({type: "Checkbox", id: "TriggerInsideAnotherWord", default: 0, label: x_lang("Trigger inside another word")})
	parametersToEdit.push({type: "Checkbox", id: "CaseSensitive", default: 0, label: x_lang("Case sensitive")})
	parametersToEdit.push({type: "Checkbox", id: "AutomaticBackspacing", default: 1, label: x_lang("Backspace automatically the entered hotstring")})
	parametersToEdit.push({type: "Checkbox", id: "ResetRecognizer", default: 0, label: x_lang("Reset hotstring recognizer after each triggering")})

	parametersToEdit.push({type: "Label", label: x_lang("Replace text")})
	parametersToEdit.push({type: "Checkbox", id: "RawMode", default: 0, label: x_lang("Raw mode")})
	parametersToEdit.push({type: "Edit", id: "KeysToSend", default: "by the way", content: ["RawString", "String"], contentID: "KeysToSendContentType", ContentDefault: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Send mode")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: "Input", choices: [x_lang("Input mode"), x_lang("Event mode"), x_lang("Play mode")], result: "enum", enum: ["Input", "Event", "Play"]})

	parametersToEdit.push({type: "Label", label: x_lang("Scope")})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Where should the hotstring be active?")})
	parametersToEdit.push({type: "Radio", id: "UseWindow", default: 1, result: "enum", choices: [x_lang("Everywhere"), x_lang("Only active when the specified window is active"), x_lang("Only active whe the specified window exists"), x_lang("Only active when the specified window is not active"), x_lang("Only active whe the specified window does not exist")], enum: ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]})
	
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit, {noExcludes: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Hotstring(Environment, ElementParameters)
{
	global
	return % x_lang("Hotstring") " - " ElementParameters.hotstring " - " ElementParameters.KeysToSend 
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Hotstring(Environment, ElementParameters, staticValues)
{

	x_Par_Enable("OmitEndingCharacter", ElementParameters.RequireEndingCharacter)
	x_Par_Disable("ResetRecognizer", ElementParameters.AutomaticBackspacing)
	if (ElementParameters.AutomaticBackspacing)
		x_Par_SetValue("ResetRecognizer", 1)
	
	; only show window parameters if window is used
	showWindowPars := ElementParameters.UseWindow = "WindowIsActive"
		or ElementParameters.UseWindow = "WindowExists"
		or ElementParameters.UseWindow = "WindowNotExists"
		or ElementParameters.UseWindow = "WindowIsNotActive"
	x_Par_Enable("TitleMatchMode", showWindowPars)
	x_Par_Enable("Wintitle", showWindowPars)
	x_Par_Enable("excludeTitle", showWindowPars)
	x_Par_Enable("FindHiddenText", showWindowPars)
	x_Par_Enable("winText", showWindowPars)
	x_Par_Enable("ExcludeText", showWindowPars)
	x_Par_Enable("ahk_class", showWindowPars)
	x_Par_Enable("ahk_exe", showWindowPars)
	x_Par_Enable("ahk_id", showWindowPars)
	x_Par_Enable("ahk_pid", showWindowPars)
	x_Par_Enable("FindHiddenWindow", showWindowPars)
	x_Par_Enable("GetWindowInformation", showWindowPars)
	
}

;Called when the trigger is activated
Element_enable_Trigger_Hotstring(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; start to create the string for the Hotstring() function
	fullHotstring := ":X"

	if (not EvaluatedParameters.RequireEndingCharacter)
		fullHotstring .= "*"
	if (EvaluatedParameters.TriggerInsideAnotherWord)
		fullHotstring .= "?"
	if (EvaluatedParameters.CaseSensitive)
		fullHotstring .= "C"
	if (not EvaluatedParameters.AutomaticBackspacing)
		fullHotstring .= "B0"
	if (EvaluatedParameters.OmitEndingCharacter)
		fullHotstring .= "O"
	if (EvaluatedParameters.ResetRecognizer)
		fullHotstring .= "Z"
	; send mode
	fullHotstring .= "S" substr(EvaluatedParameters.SendMode, 1, 1)

	fullHotstring .= ":" EvaluatedParameters.hotstring

	; save fully modified hotkey
	EvaluatedParameters.fullHotstring := fullHotstring
	
	; decide whether we will send in raw mode or not
	if (EvaluatedParameters.RawMode)
		rawTextOption := "{raw}"
	else
		rawTextOption := ""

	if (EvaluatedParameters.UseWindow = "WindowIsActive"
		or EvaluatedParameters.UseWindow = "WindowExists"
		or EvaluatedParameters.UseWindow = "WindowNotExists"
		or EvaluatedParameters.UseWindow = "WindowIsNotActive")
	{
		
		; evaluate window parameters
		EvaluatedWindowParameters := windowFunctions_evaluateWindowParameters(EvaluatedParameters)
		if (EvaluatedWindowParameters.exception)
		{
			x_finish(Environment, "exception", EvaluatedWindowParameters.exception)
			return
		}
		
		; set the desired window properties
		SetTitleMatchMode, % EvaluatedWindowParameters.titlematchmode
		DetectHiddenText, % EvaluatedWindowParameters.findhiddentext
		DetectHiddenWindows, % EvaluatedWindowParameters.findhiddenwindow
	}

	; Turn on context sensitivity if required
	if (EvaluatedParameters.UseWindow = "WindowIsActive")
		hotkey, IfWinActive, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowExists")
		hotkey, ifwinexist, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowIsNotActive")
		hotkey, IfWinNotActive, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowNotExists")
		hotkey, ifwinNotexist, % EvaluatedWindowParameters.winstring, % EvaluatedWindowParameters.WinText
	else
		hotkey, IfWinActive ; turn off context sensitivity
	
	; create a function object
	functionObject:= x_NewFunctionObject(environment, "Trigger_Hotstring_Trigger", EvaluatedParameters)
	x_SetTriggerValue(Environment, "functionObject", functionObject)
	x_SetTriggerValue(Environment, "fullHotstring", EvaluatedParameters.fullHotstring)
	x_SetTriggerValue(Environment, "KeysToSend", rawTextOption EvaluatedParameters.KeysToSend)
	x_SetTriggerValue(Environment, "SendMode", EvaluatedParameters.sendMode)
	x_SetTriggerValue(Environment, "SendEndingCharacter", not EvaluatedParameters.OmitEndingCharacter and EvaluatedParameters.AutomaticBackspacing)

	; enable the hotkey
	try
	{
		Hotstring(EvaluatedParameters.fullHotstring, functionObject, "on")
	}
	catch
	{
		x_enabled(Environment, "exception", x_lang("The hotstring %1% cannot be set!", EvaluatedParameters.fullHotstring))
		return
	}

	; finish and return true
	x_enabled(Environment, "normal", x_lang("The hotkey %1% was set.", EvaluatedParameters.fullHotstring))
	return true
}
;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Hotstring(Environment, ElementParameters, TriggerData)
{
	x_SetVariable(Environment, "A_EndChar", TriggerData.endChar, "thread")
	x_SetVariable(Environment, "A_Hotstring", ElementParameters.hotstring, "thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Hotstring(Environment, ElementParameters)
{
	; disable the hotkey
	fullHotstring := x_getTriggerValue(Environment, "fullHotstring")
	Hotstring(fullHotstring, , "off")

	; finish
	x_disabled(Environment, "normal")
}

; function which will be called when the hotkey is pressed
Trigger_Hotstring_Trigger(Environment, ElementParameters)
{
	; after trigger, we will send the replace text immediately
	KeysToSend := x_getTriggerValue(Environment, "KeysToSend")
	
	if (KeysToSend)
	{
		SendMode := x_getTriggerValue(Environment, "SendMode")
		SendEndingCharacter := x_getTriggerValue(Environment, "SendEndingCharacter")

		; set send mode
		SendMode, % SendMode
		
		if (SendEndingCharacter)
			KeysToSend .= A_EndChar

		; send keystrokes
		Send, % KeysToSend 
	}

	; trigger the trigger
	x_trigger(Environment, {endChar: A_EndChar})
}
