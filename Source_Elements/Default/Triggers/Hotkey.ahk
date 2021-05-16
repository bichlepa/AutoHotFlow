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
	return "Source_elements\default\icons\keyboard.png"
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
	parametersToEdit.push({type: "Label", label: x_lang("Window")})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Where should the hotkey be active?")})
	parametersToEdit.push({type: "Radio", id: "UseWindow", default: 1, result: "enum", choices: [x_lang("Everywhere"), x_lang("Only active when the specified window is active"), x_lang("Only active whe the specified window exists"), x_lang("Only active when the specified window is not active"), x_lang("Only active whe the specified window does not exist")], enum: ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: x_lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: x_lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", size: "small", label: x_lang("Get_parameters")})
	parametersToEdit.push({type: "button", id: "GetWindowInformation", goto: "Trigger_Hotkey_ButtonWindowAssistant", label: x_lang("Get_Parameters")})

	
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
Element_CheckSettings_Trigger_Hotkey(Environment, ElementParameters)
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
		; create wintitle argument for WinActive() Call
		EvaluatedParameters.winstring := EvaluatedParameters.Wintitle
		if (EvaluatedParameters.ahk_class != "")
			EvaluatedParameters.winstring .= " ahk_class " EvaluatedParameters.ahk_class
		if (EvaluatedParameters.ahk_id != "")
			EvaluatedParameters.winstring .= " ahk_id " EvaluatedParameters.ahk_id
		if (EvaluatedParameters.ahk_pid != "")
			EvaluatedParameters.winstring .= " ahk_pid " EvaluatedParameters.ahk_pid
		if (EvaluatedParameters.ahk_exe != "")
			EvaluatedParameters.winstring .= " ahk_exe " EvaluatedParameters.ahk_exe
		
		;If no window specified, error
		if (EvaluatedParameters.winstring = "" and EvaluatedParameters.winText = "")
		{
			x_enabled(Environment, "exception", x_lang("No window specified"))
			return
		}
	
		; check findhiddentext and findhiddenwindow parameter. Convert them to string
		switch (EvaluatedParameters.findhiddentext)
		{
		case 0:
			EvaluatedParameters.findhiddentext := "off"
		case 1:
			EvaluatedParameters.findhiddentext := "on"
		default:
			x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "findhiddentext", EvaluatedParameters.findhiddentext))
			return
		}
		switch (EvaluatedParameters.findhiddenwindow)
		{
		case 0:
			EvaluatedParameters.findhiddenwindow := "off"
		case 1:
			EvaluatedParameters.findhiddenwindow := "on"
		default:
			x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "findhiddenwindow", EvaluatedParameters.findhiddenwindow))
			return
		}
		
		; set the desired window properties
		SetTitleMatchMode, % EvaluatedParameters.titlematchmode
		DetectHiddenText, % EvaluatedParameters.findhiddentext
		DetectHiddenWindows, % EvaluatedParameters.findhiddenwindow
	}


	; Turn on context sensitivity if required
	if (EvaluatedParameters.UseWindow = "WindowIsActive")
		hotkey, IfWinActive, % EvaluatedParameters.winstring, % EvaluatedParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowExists")
		hotkey, ifwinexist, % EvaluatedParameters.winstring, % EvaluatedParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowIsNotActive")
		hotkey, IfWinNotActive, % EvaluatedParameters.winstring, % EvaluatedParameters.WinText
	else if (EvaluatedParameters.UseWindow = "WindowNotExists")
		hotkey, ifwinNotexist, % EvaluatedParameters.winstring, % EvaluatedParameters.WinText
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

; opens the assistant for getting window information
Trigger_Hotkey_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", winText: "winText", FindHiddenText: "FindHiddenText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; function which will be called when the hotkey is pressed
Trigger_Hotkey_Trigger(Environment, ElementParameters)
{
	x_trigger(Environment)
}
