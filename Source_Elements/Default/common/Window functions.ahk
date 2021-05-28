; this file contains some functions which are used for elements which interact with a window
; warning! Those functions are not ment to be used by elements from other packages. Incompatible changes are likely in future. If you want to use them, then make a copy of this file and add it to your package.

; adds all required fields for a window identification
windowFunctions_addWindowIdentificationParametrization(parametersToEdit, options = "")
{
	parametersToEdit.push({type: "Label", label: x_lang("Window identification")})

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

	parametersToEdit.push({type: "Label", label: x_lang("Import window identification"), size: "small"})
    if (not options.noExcludes)
	    parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistant", label: x_lang("Import window identification")})
    else
	    parametersToEdit.push({type: "button", goto: "windowFunctions_openAssistantNoExcludes", label: x_lang("Import window identification")})
}

; generates a string based on the configuration for the element name
windowFunctions_generateWindowIdentificationName(ElementParameters, options = "")
{
    nameString := ""
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode = 1)
			nameString := nameString "`n" x_lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 2)
			nameString := nameString "`n" x_lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode = 3)
			nameString := nameString "`n" x_lang("Title is exatly") ": " ElementParameters.Wintitle
	}
    if (not options.noExcludes)
    {
        if (ElementParameters.excludeTitle)
            nameString := nameString "`n" x_lang("Exclude_title") ": " ElementParameters.excludeTitle
    }
	if (ElementParameters.winText)
		nameString := nameString "`n" x_lang("Control_text") ": " ElementParameters.winText
    if (not options.noExcludes)
    {
        if (ElementParameters.ExcludeText)
            nameString := nameString "`n" x_lang("Exclude_control_text") ": " ElementParameters.ExcludeText
    }
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
	if (tempwinstring = "" and EvaluatedParameters.winText = "")
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
    returnValue.winString := tempwinstring
    returnValue.findhiddentext := findhiddentext
    returnValue.findhiddenwindow := findhiddenwindow
    returnValue.TitleMatchMode := EvaluatedParameters.TitleMatchMode
    returnValue.winText := EvaluatedParameters.winText
    returnValue.ExcludeTitle := EvaluatedParameters.ExcludeTitle
    returnValue.ExcludeText := EvaluatedParameters.ExcludeText
    return returnValue
}

; finds the window ID 
; EvaluatedParameters must have the result of function windowFunctions_evaluateWindowParameters() 
; returns window ID if window was found and 0 if window was not found
; on error, returns an object with key "exception" which contains the exception message. Use it to call x_finish() or x_enabled()
windowFunctions_getWindowID(EvaluatedParameters)
{
    if (not (EvaluatedParameters.hasKey("TitleMatchMode") and EvaluatedParameters.hasKey("findhiddenwindow") and EvaluatedParameters.hasKey("findhiddentext")
        and EvaluatedParameters.hasKey("winString") and EvaluatedParameters.hasKey("winText") and EvaluatedParameters.hasKey("ExcludeTitle") and EvaluatedParameters.hasKey("ExcludeText")))
	return {exception: x_lang("Unexpected error")}

    ; set parameters for winexist() call
	SetTitleMatchMode, % EvaluatedParameters.TitleMatchMode
	DetectHiddenWindows, % EvaluatedParameters.findhiddenwindow
	DetectHiddenText, % EvaluatedParameters.findhiddentext
	
	; check whether window exists. If so get the window ID
	windowID := winexist(EvaluatedParameters.winString, EvaluatedParameters.winText, EvaluatedParameters.ExcludeTitle, EvaluatedParameters.ExcludeText)
    return windowID
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