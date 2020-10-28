;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Window_Closes")

;Element type of the element
Element_getElementType_Trigger_Window_Closes()
{
	return "trigger"
}

;Element type of the element
Element_getName_Trigger_Window_Closes()
{
	return lang("Window_Closes")
}

;Category of the element
Element_getCategory_Trigger_Window_Closes()
{
	return lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Window_Closes()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Window_Closes()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Window_Closes()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Window_Closes()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Window_Closes(Environment)
{
	
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title")})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window")})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Get_parameters")})
	parametersToEdit.push({type: "button", goto: "Trigger_Window_Closes_ButtonWindowAssistant", label: lang("Get_Parameters")})

	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Label", label: lang("Check interval"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "interval", content: "Number", default: 100, WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Window_Closes(Environment, ElementParameters)
{
	tempNameString := ""
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode = 1)
			tempNameString := tempNameString "`n" lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 2)
			tempNameString := tempNameString "`n" lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 3)
			tempNameString := tempNameString "`n" lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString := tempNameString "`n" lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString := tempNameString "`n" lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString := tempNameString "`n" lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString := tempNameString "`n" lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString := tempNameString "`n" lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString := tempNameString "`n" lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString := tempNameString "`n" lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return lang("Window_Closes") ": " tempNameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Window_Closes(Environment, ElementParameters)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Window_Closes(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_enabled(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	; check interval
	if (not (EvaluatedParameters.interval > 0))
	{
		x_enabled(Environment, "exception", lang("Parameter '%1%' has invalid value: %2%", "interval", tempinterval)) 
		return
	}

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
		x_enabled(Environment, "exception", lang("No window specified"))
		return
	}
	
	; check findhiddentext and findhiddenwindow parameter. Convert them to string
	switch (ElementParameters.findhiddentext)
	{
	case 0:
		EvaluatedParameters.findhiddentext := "off"
	case 1:
		EvaluatedParameters.findhiddentext := "on"
	default:
		x_enabled(Environment, "exception", lang("Parameter '%1%' has invalid value: %2%", "findhiddentext", EvaluatedParameters.findhiddentext)) 
	}
	switch (ElementParameters.findhiddenwindow)
	{
	case 0:
		EvaluatedParameters.findhiddenwindow := "off"
	case 1:
		EvaluatedParameters.findhiddenwindow := "on"
	default:
		x_enabled(Environment, "exception", lang("Parameter '%1%' has invalid value: %2%", "findhiddenwindow", EvaluatedParameters.findhiddenwindow)) 
	}

	; if there is no matching window on first call of the function object, we will not trigger
	EvaluatedParameters.firstCall := true

	; We will set a timer which regularely checks the active window.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Window_Closes_TimerLabel", EvaluatedParameters)
	x_SetTriggerValue(Environment, "functionObject", functionObject)
	
	; make the first call immediately
	%functionObject%(true)

	; enable the timer
	SetTimer, % functionObject, % EvaluatedParameters.interval

	; finish and return true
	x_enabled(Environment, "normal")
	return true
}

;Called after the trigger has triggered.
;Here you can for example define the variables which are provided by the triggers.
Element_postTrigger_Trigger_Window_Closes(Environment, parameters)
{
	x_SetVariable(Environment, "a_WindowID", parameters.windowID, "Thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Window_Closes(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal", lang("Stopped."))
}


; opens the assistant for getting window information
Trigger_Window_Closes_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}


; function which will be regularey called
Trigger_Window_Closes_TimerLabel(Environment, parameters, fistCall = false)
{
	; set some properties before calling winGet
	SetTitleMatchMode, % parameters.titlematchmode
	DetectHiddenText, % parameters.findhiddentext
	DetectHiddenWindows, % parameters.findhiddenwindow

	if (fistCall)
	{
		; on first call, we need to skip the trigger
		winget, winList, list, % parameters.winstring, % parameters.WinText, % parameters.ExcludeTitle, % parameters.ExcludeText
		
		; convert the pseudo-array to a real array and save current window list
		parameters.currentWinList := []
		loop % winList
		{
			oneWindowID := winList%a_index%
			parameters.currentWinList[oneWindowID] := true
		}
	}

	; call winGet. it will return all matching window IDs
	winget, winList, list, % parameters.winstring, % parameters.WinText, % parameters.ExcludeTitle, % parameters.ExcludeText

	; convert the pseudo-array to a real array
	currentWinList := []
	loop % winList
	{
		oneWindowID := winList%a_index%
		currentWinList[oneWindowID] := true
	}

	; check whether some elements are missing now
	for oneWindowID in parameters.currentWinList
	{
		if (not currentWinList.hasKey(oneWindowID))
		{
			; a window is missing now. Call the trigger
			x_trigger(Environment, {windowID: oneWindowID})
		}
	}

	; save current window list
	parameters.currentWinList := currentWinList
}