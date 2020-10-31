;Always add this element class name to the global list
x_RegisterElementClass("Trigger_Window_Gets_Active")

;Element type of the element
Element_getElementType_Trigger_Window_Gets_Active()
{
	return "trigger"
}

;Name of the element
Element_getName_Trigger_Window_Gets_Active()
{
	return x_lang("Window_Gets_Active")
}

;Category of the element
Element_getCategory_Trigger_Window_Gets_Active()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Trigger_Window_Gets_Active()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Trigger_Window_Gets_Active()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Trigger_Window_Gets_Active()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Trigger_Window_Gets_Active()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Trigger_Window_Gets_Active(Environment)
{
	
	parametersToEdit := Object()
	parametersToEdit.push({type: "Label", label: x_lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Exclude_title")})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: x_lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: x_lang("Exclude_text_of_a_control_in_window")})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: x_lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: x_lang("Get_parameters")})
	parametersToEdit.push({type: "button", goto: "Trigger_Window_Exists_ButtonWindowAssistant", label: x_lang("Get_Parameters")})

	parametersToEdit.push({type: "Label", label: x_lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1, label: x_lang("Do not trigger if a matching window exists when enabling the trigger")})
	parametersToEdit.push({type: "Label", label: x_lang("Check interval"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "interval", content: "Number", default: 100, WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	tempNameString := ""
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode = 1)
			tempNameString := tempNameString "`n" x_lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 2)
			tempNameString := tempNameString "`n" x_lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 3)
			tempNameString := tempNameString "`n" x_lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString := tempNameString "`n" x_lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString := tempNameString "`n" x_lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString := tempNameString "`n" x_lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString := tempNameString "`n" x_lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString := tempNameString "`n" x_lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString := tempNameString "`n" x_lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString := tempNameString "`n" x_lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return x_lang("Window_Gets_Active") ": " tempNameString
	
	
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Trigger_Window_Gets_Active(Environment, ElementParameters)
{	
	
}

;Called when the trigger is activated
Element_enable_Trigger_Window_Gets_Active(Environment, ElementParameters)
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
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "interval", EvaluatedParameters.interval)) 
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
		x_enabled(Environment, "exception", x_lang("No window specified"))
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
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "findhiddentext", EvaluatedParameters.findhiddentext))
		return
	}
	switch (ElementParameters.findhiddenwindow)
	{
	case 0:
		EvaluatedParameters.findhiddenwindow := "off"
	case 1:
		EvaluatedParameters.findhiddenwindow := "on"
	default:
		x_enabled(Environment, "exception", x_lang("Parameter '%1%' has invalid value: %2%", "findhiddenwindow", EvaluatedParameters.findhiddenwindow))
		return
	}

	; We will set a timer which regularely checks the active window.
	; create a function object
	functionObject := x_NewFunctionObject(environment, "Trigger_Window_Gets_Active_TimerLabel", EvaluatedParameters)
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
Element_postTrigger_Trigger_Window_Gets_Active(Environment, parameters)
{
	; set the a_windowID variable
	x_SetVariable(Environment, "a_WindowID", parameters.windowID, "Thread")
}


;Called when the trigger should be disabled.
Element_disable_Trigger_Window_Gets_Active(Environment, ElementParameters)
{
	; get the function object and disable the timer
	functionObject := x_getTriggerValue(Environment, "functionObject")
	SetTimer, % functionObject, off

	; finish
	x_disabled(Environment, "normal")
}


; opens the assistant for getting window information
Trigger_Window_Exists_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; function which will be regularey called
Trigger_Window_Gets_Active_TimerLabel(Environment, parameters, fistCall = false)
{
	; set some properties before calling WinActive()
	SetTitleMatchMode, % parameters.titlematchmode
	DetectHiddenText, % parameters.findhiddentext
	DetectHiddenWindows, % parameters.findhiddenwindow
	
	if (fistCall)
	{
		; check parameter NotTriggerOnEnable on first call
		if (parameters.NotTriggerOnEnable)
		{
			; if this parameter is set, we need to skip the trigger if the window is already active
			parameters.currentWindowID := WinActive(parameters.winstring, parameters.WinText, parameters.ExcludeTitle, parameters.ExcludeText)
		}
	}

	; call WinActive(). it will return the window ID if the window exists
	windowID := WinActive(parameters.winstring, parameters.WinText, parameters.ExcludeTitle, parameters.ExcludeText)

	; compare the windowID with the last found window 
	if (windowID != parameters.currentWindowID)
	{
		; the result has changed. Save the changed value.
		parameters.currentWindowID := windowID

		if (windowID)
		{
			; if we are here, a window was found that maches the criteria.
			; On last call either active window did not match or an other window was active

			; trigger and pass the windowID, so we can set the a_windowID variable later
			x_trigger(Environment, {windowID: windowID})
		}
	}
}