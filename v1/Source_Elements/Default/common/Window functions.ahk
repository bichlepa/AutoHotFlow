; this file contains some functions which are used for elements which interact with a window
; warning! Those functions are not ment to be used by elements from other packages. Incompatible changes are likely in future. If you want to use them, then make a copy of this file and add it to your package.

; returns a list of all window parameters
windowFunctions_getWindowParametersList(options = "")
{
	result := ["TitleMatchMode", "Wintitle", "winText", "FindHiddenText", "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"]

	if (not options.noExcludes)
	{
		result.push("excludeTitle", "ExcludeText")
	}
	return result
}

; adds all required fields for a window identification
windowFunctions_addWindowIdentificationParametrization(parametersToEdit, options = "")
{
	if (options.withControl)
	{
		parametersToEdit.push({type: "Label", label: x_lang("Control_Identification")})

		parametersToEdit.push({type: "Label", label: x_lang("Method_for_control_Identification"), size: "small"})
		parametersToEdit.push({type: "Radio", id: "IdentifyControlBy", result: "enum", default: "Class", choices: [x_lang("Text_in_control"), x_lang("Classname and instance number of the control"), x_lang("Unique control ID")], enum: ["Text", "Class", "ID"]})
		
		parametersToEdit.push({type: "Label", label: x_lang("Control_Identification"), size: "small"})
		parametersToEdit.push({type: "Radio", id: "ControlTextMatchMode", default: 2, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
		parametersToEdit.push({type: "Edit", id: "Control_identifier", content: "String", WarnIfEmpty: true})
	}
	Else
	{
		parametersToEdit.push({type: "Label", label: x_lang("Window identification")})
	}

	parametersToEdit.push({type: "Label", label: x_lang("Title_of_Window"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})

    if (not options.noExcludes)
    {
        parametersToEdit.push({type: "Label", label: x_lang("Exclude_title"), size: "small"})
        parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
    }

	parametersToEdit.push({type: "Label", label: x_lang("Text_of_a_control_in_Window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: x_lang("Detect hidden text")})

    if (not options.noExcludes)
    {
        parametersToEdit.push({type: "Label", label: x_lang("Exclude_text_of_a_control_in_window"), size: "small"})
        parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
    }

	parametersToEdit.push({type: "Label", label: x_lang("Window_Class"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Process_Name"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Unique_window_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Unique_Process_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})

	parametersToEdit.push({type: "Label", label: x_lang("Hidden window"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: x_lang("Detect hidden window")})

	if (options.withControl)
	{
		parametersToEdit.push({type: "Label", label: x_lang("Assistant")})
		if (not options.noExcludes)
			parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistantWithControl", label: x_lang("Import control and window identification")})
		else
			parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistantWithControlNoExcludes", label: x_lang("Import control and window identification")})
	}
	Else
	{
		parametersToEdit.push({type: "Label", label: x_lang("Assistant"), size: "small"})
		if (not options.noExcludes)
			parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistant", label: x_lang("Import window identification")})
		else
			parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistantNoExcludes", label: x_lang("Import window identification")})
	}
}

; generates a string based on the configuration for the element name
windowFunctions_generateWindowIdentificationName(ElementParameters)
{
    nameString := ""
	
	if (ElementParameters.IdentifyControlBy)
	{
		if (ElementParameters.IdentifyControlBy = "Text")
			nameString := nameString "`n" x_lang("Control text %1%", ElementParameters.Control_identifier)
		else if (ElementParameters.IdentifyControlBy = "Class")
			nameString := nameString "`n"  x_lang("Control class %1%", ElementParameters.Control_identifier)
		else if (ElementParameters.IdentifyControlBy = "ID")
			nameString := nameString "`n"  x_lang("Control ID %1%", ElementParameters.Control_identifier)
	}

	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode = 1)
			nameString := nameString "`n" x_lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 2)
			nameString := nameString "`n" x_lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 3)
			nameString := nameString "`n" x_lang("Title is exatly") ": " ElementParameters.Wintitle
	}

	if (ElementParameters.excludeTitle)
		nameString := nameString "`n" x_lang("Exclude_title") ": " ElementParameters.excludeTitle
    
	if (ElementParameters.winText)
		nameString := nameString "`n" x_lang("Control_text") ": " ElementParameters.winText

	if (ElementParameters.ExcludeText)
		nameString := nameString "`n" x_lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		nameString := nameString "`n" x_lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		nameString := nameString "`n" x_lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		nameString := nameString "`n" x_lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		nameString := nameString "`n" x_lang("Process_ID") ": " ElementParameters.ahk_pid
    
    return nameString
}

windowFunctions_CheckSettings(ElementParameters)
{

	x_Par_Disable("TitleMatchMode", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("Wintitle", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("excludeTitle", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("winText", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("FindHiddenText", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("ExcludeText", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("ahk_class", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("ahk_exe", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("ahk_id", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("ahk_pid", ElementParameters.IdentifyControlBy = "ID")
	x_Par_Disable("FindHiddenWindow", ElementParameters.IdentifyControlBy = "ID")

	x_Par_Enable("ControlTextMatchMode", ElementParameters.IdentifyControlBy = "Text")

}

; evaluates window Parameter
; param evaluatedParameters has to contain pre-evaluated parameters (with function x_AutoEvaluateParameters())
; returns a struct which can be passed to windowFunctions_getWindowID()
; on error, returns an object with key "exception" which contains the exception message. Use it to call x_finish() or x_enabled()
windowFunctions_evaluateWindowParameters(EvaluatedParameters)
{
	; create wintitle argument for winexist() Call
	tempwinstring := EvaluatedParameters.Wintitle
	if (EvaluatedParameters.ahk_class)
		tempwinstring := tempwinstring " ahk_class " EvaluatedParameters.ahk_class
	if (EvaluatedParameters.ahk_id)
		tempwinstring := tempwinstring " ahk_id " EvaluatedParameters.ahk_id
	if (EvaluatedParameters.ahk_pid)
		tempwinstring := tempwinstring " ahk_pid " EvaluatedParameters.ahk_pid
	if (EvaluatedParameters.ahk_exe)
		tempwinstring := tempwinstring " ahk_exe " EvaluatedParameters.ahk_exe
	
	;If no window specified, error
	if (EvaluatedParameters.IdentifyControlBy != "ID" and tempwinstring = "" and EvaluatedParameters.winText = "")
	{
		return {exception: x_lang("No window specified")}
	}
	
	; check findhiddentext and findhiddenwindow parameter. Convert them to string
	switch (EvaluatedParameters.findhiddentext)
	{
	case 0:
		findhiddentext := "off"
	case 1:
		findhiddentext := "on"
	default:
		return {exception: x_lang("Parameter '%1%' has invalid value: %2%", "findhiddentext", EvaluatedParameters.findhiddentext)}
	}
	switch (EvaluatedParameters.findhiddenwindow)
	{
	case 0:
		findhiddenwindow := "off"
	case 1:
		findhiddenwindow := "on"
	default:
		return {exception: x_lang("Parameter '%1%' has invalid value: %2%", "findhiddenwindow", EvaluatedParameters.findhiddenwindow)}
	}

    returnValue := {}
	if (EvaluatedParameters.HasKey("IdentifyControlBy"))
    	returnValue.IdentifyControlBy := EvaluatedParameters.IdentifyControlBy
	if (EvaluatedParameters.HasKey("ControlTextMatchMode"))
    	returnValue.ControlTextMatchMode := EvaluatedParameters.ControlTextMatchMode
	if (EvaluatedParameters.HasKey("Control_identifier"))
    	returnValue.Control_identifier := EvaluatedParameters.Control_identifier

    returnValue.winString := tempwinstring
    returnValue.findhiddentext := findhiddentext
    returnValue.findhiddenwindow := findhiddenwindow
    returnValue.TitleMatchMode := EvaluatedParameters.TitleMatchMode
    returnValue.winText := EvaluatedParameters.winText
	if (EvaluatedParameters.HasKey("ExcludeTitle"))
   	 returnValue.ExcludeTitle := EvaluatedParameters.ExcludeTitle
	if (EvaluatedParameters.HasKey("ExcludeText"))
    	returnValue.ExcludeText := EvaluatedParameters.ExcludeText
    returnValue.ahk_id := EvaluatedParameters.ahk_id
    returnValue.ahk_pid := EvaluatedParameters.ahk_pid
    returnValue.ahk_exe := EvaluatedParameters.ahk_exe
    returnValue.ahk_class := EvaluatedParameters.ahk_class
    return returnValue
}

; finds the window ID 
; EvaluatedParameters must have the result of function windowFunctions_evaluateWindowParameters() 
; returns window ID if window was found and 0 if window was not found
; on error, returns an object with key "exception" which contains the exception message. Use it to call x_finish() or x_enabled()
windowFunctions_getWindowID(EvaluatedParameters)
{
    if (not (EvaluatedParameters.hasKey("TitleMatchMode") and EvaluatedParameters.hasKey("findhiddenwindow") and EvaluatedParameters.hasKey("findhiddentext")
        and EvaluatedParameters.hasKey("winString") and EvaluatedParameters.hasKey("winText")))
	return {exception: x_lang("Unexpected error")}

    ; set parameters for winexist() call
	SetTitleMatchMode, % EvaluatedParameters.TitleMatchMode
	DetectHiddenWindows, % EvaluatedParameters.findhiddenwindow
	DetectHiddenText, % EvaluatedParameters.findhiddentext
	
	; check whether window exists. If so get the window ID
	windowID := winexist(EvaluatedParameters.winString, EvaluatedParameters.winText, EvaluatedParameters.ExcludeTitle, EvaluatedParameters.ExcludeText)
	if not windowID
    	return
    else
		return windowID
}

; finds the window ID 
; EvaluatedParameters must have the result of function windowFunctions_evaluateWindowParameters() 
; returns window ID if window was found and 0 if window was not found
; on error, returns an object with key "exception" which contains the exception message. Use it to call x_finish() or x_enabled()
windowFunctions_getWindowAndControlID(EvaluatedParameters)
{
    if (not (EvaluatedParameters.hasKey("IdentifyControlBy") and EvaluatedParameters.hasKey("ControlTextMatchMode") and EvaluatedParameters.hasKey("Control_identifier")
		and EvaluatedParameters.hasKey("TitleMatchMode") and EvaluatedParameters.hasKey("findhiddenwindow") and EvaluatedParameters.hasKey("findhiddentext")
        and EvaluatedParameters.hasKey("winString") and EvaluatedParameters.hasKey("winText")))
	return {exception: x_lang("Unexpected error")}

	if (EvaluatedParameters.IdentifyControlBy = "ID")
	{
		; get the control ID
		controlget, controlID, Hwnd,,, % "ahk_id " EvaluatedParameters.Control_identifier

		; if user specified the ID and the found control has not the ID, then the ID that was specified by the user is a window ID. So, the control does not exist and we return empty control ID
		if (controlID != EvaluatedParameters.Control_identifier)
		{
			controlID := ""
		}

		; window ID is empty, since we didn't retrieve any window ID
		windowID := ""
	}
	Else
	{
		; set parameters for winexist() call
		SetTitleMatchMode, % EvaluatedParameters.TitleMatchMode
		DetectHiddenWindows, % EvaluatedParameters.findhiddenwindow
		DetectHiddenText, % EvaluatedParameters.findhiddentext
		
		; check whether window exists. If so get the window ID
		windowID := winexist(EvaluatedParameters.winString, EvaluatedParameters.winText, EvaluatedParameters.ExcludeTitle, EvaluatedParameters.ExcludeText)

		if (windowID)
		{
			if (EvaluatedParameters.IdentifyControlBy = "name")
			{
				; user wants to identify the control by name. We use the specified title match mode
				SetTitleMatchMode, % EvaluatedParameters.ControlTextMatchMode
			}
			Else if (EvaluatedParameters.IdentifyControlBy = "class")
			{
				; user wants to identify the control by class ID. We use the exact title match mode to prevent that a control is found that starts with the class name.
				SetTitleMatchMode, 3 ;exact match
			}

			; get the control ID
			controlget, controlID, Hwnd,, % EvaluatedParameters.Control_identifier, ahk_id %windowID%
		}
		Else
		{
			windowID := ""
		}
	}
	return {windowID: windowID, controlID: controlID}
}

; opens window parameter assistant
windowFunctions_openAssistant()
{
    x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; opens window parameter assistant bug excludes the parameters excludeTitle and ExcludeText
windowFunctions_openAssistantNoExcludes()
{
    x_assistant_windowParameter({wintitle: "Wintitle", winText: "winText", FindHiddenText: "FindHiddenText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; opens window parameter assistant
windowFunctions_openAssistantWithControl()
{
    x_assistant_windowParameter({IdentifyControlBy: "IdentifyControlBy", ControlTextMatchMode: "ControlTextMatchMode", Control_identifier: "Control_identifier", wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

; opens window parameter assistant bug excludes the parameters excludeTitle and ExcludeText
windowFunctions_openAssistantWithControlNoExcludes()
{
    x_assistant_windowParameter({IdentifyControlBy: "IdentifyControlBy", ControlTextMatchMode: "ControlTextMatchMode", Control_identifier: "Control_identifier", wintitle: "Wintitle", winText: "winText", FindHiddenText: "FindHiddenText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}