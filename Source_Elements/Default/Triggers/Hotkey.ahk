;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Hotkey")

;Element type of the element
Element_getElementType_Trigger_Hotkey()
{
	return "trigger"
}

;Name of the element
Element_getName_Trigger_Hotkey()
{
	return x_lang("Hotkey")
}

;Category of the element
Element_getCategory_Trigger_Hotkey()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Hotkey()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Hotkey()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Hotkey()
{
	return "keyboard.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Hotkey()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Hotkey(Environment)
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Hotkey")})
	parametersToEdit.push({type: "Hotkey", id: "hotkey"})
	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "BlockKey", default: 1, label: x_lang("Block_key")})
	parametersToEdit.push({type: "Checkbox", id: "Wildcard", default: 0, label: x_lang("Trigger even if other keys are already held down")})
	parametersToEdit.push({type: "Checkbox", id: "WhenRelease", default: 0, label: x_lang("Trigger on release rather than press")})

	parametersToEdit.push({type: "Label", label: x_lang("Scope")})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Where should the hotkey be active?")})
	parametersToEdit.push({type: "Radio", id: "UseWindow", default: 1, result: "enum", choices: [x_lang("Everywhere"), x_lang("Only active when the specified window is active"), x_lang("Only active whe the specified window exists"), x_lang("Only active when the specified window is not active"), x_lang("Only active whe the specified window does not exist")], enum: ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]})
	
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit, {noExcludes: true})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Hotkey(Environment, ElementParameters)
{
	global
	return % x_lang("Hotkey") " - " ElementParameters.Hotkey 
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Hotkey(Environment, ElementParameters, staticValues)
{
	x_Par_Disable("WhenRelease", ElementParameters.BlockKey)
	x_Par_Disable("BlockKey", ElementParameters.WhenRelease)
	
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
Element_enable_Trigger_Hotkey(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; check hotkey
	fullHotkey := EvaluatedParameters.hotkey
	if (fullHotkey = "")
	{
		x_enabled(Environment, "exception", x_lang("The_Hotkey_is_not_set!"))
		return
	}

	; append keywords to hotkey if required
	if (not EvaluatedParameters.BlockKey)
		fullHotkey := "~" fullHotkey
	if (EvaluatedParameters.WhenRelease)
		fullHotkey := fullHotkey " UP"
	if (EvaluatedParameters.Wildcard)
		fullHotkey := "*" fullHotkey

	; save fully modified hotkey
	EvaluatedParameters.fullHotkey := fullHotkey
	
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
	functionObject:= x_NewFunctionObject(environment, "Trigger_Hotkey_Trigger", EvaluatedParameters)
	x_SetTriggerValue(Environment, "functionObject", functionObject)
	x_SetTriggerValue(Environment, "fullHotkey", fullHotkey)

	; enable the hotkey
	hotkey, % EvaluatedParameters.fullHotkey, % functionObject, UseErrorLevel on
	if ErrorLevel
	{
		x_enabled(Environment, "exception", x_lang("The hotkey %1% cannot be set!", fullHotkey))
		return
	}

	; finish and return true
	x_enabled(Environment, "normal", x_lang("The hotkey %1% was set.", fullHotkey))
	return true
}
;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Hotkey(Environment, ElementParameters, TriggerData)
{
	x_SetVariable(Environment, "A_Hotkey", ElementParameters.hotkey, "thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Hotkey(Environment, ElementParameters)
{
	; disable the hotkey
	fullHotkey := x_getTriggerValue(Environment, "fullHotkey")
	hotkey, % fullHotkey, off

	; finish
	x_disabled(Environment, "normal")
}

; function which will be called when the hotkey is pressed
Trigger_Hotkey_Trigger(Environment, ElementParameters)
{
	x_trigger(Environment)
}
