;Always add this element class name to the global list
x_RegisterElementClass("Condition_Window_Active")

;Element type of the element
Element_getElementType_Condition_Window_Active()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_Window_Active()
{
	return lang("Window_Active")
}

;Category of the element
Element_getCategory_Condition_Window_Active()
{
	return lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_Window_Active()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_Window_Active()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_Window_Active()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_Window_Active()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_Window_Active(Environment)
{
	parametersToEdit:=Object()
	
	
	
	parametersToEdit.push({type: "Label", label: lang("Window identification")})
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Import window identification"), size: "small"})
	parametersToEdit.push({type: "button", goto: "Condition_Window_Active_ButtonWindowAssistant", label: lang("Import window identification")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_Window_Active(Environment, ElementParameters)
{
	
	local tempNameString
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode=1)
			tempNameString:=tempNameString "`n" lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=2)
			tempNameString:=tempNameString "`n" lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=3)
			tempNameString:=tempNameString "`n" lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString:=tempNameString "`n" lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString:=tempNameString "`n" lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString:=tempNameString "`n" lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString:=tempNameString "`n" lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString:=tempNameString "`n" lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString:=tempNameString "`n" lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString:=tempNameString "`n" lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return lang("Window_Active") ": " tempNameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_Window_Active(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_Window_Active(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	tempWinTitle:=EvaluatedParameters.Wintitle
	tempWinText:=EvaluatedParameters.winText
	tempTitleMatchMode :=EvaluatedParameters.TitleMatchMode
	tempahk_class:=EvaluatedParameters.ahk_class
	tempahk_exe:=EvaluatedParameters.ahk_exe
	tempahk_id:= EvaluatedParameters.ahk_id
	tempahk_pid:= EvaluatedParameters.ahk_pid
	
	tempwinstring:=EvaluatedParameters.Wintitle
	if (EvaluatedParameters.ahk_class)
		tempwinstring:=tempwinstring " ahk_class " EvaluatedParameters.ahk_class
	if (EvaluatedParameters.ahk_id)
		tempwinstring:=tempwinstring " ahk_id " EvaluatedParameters.ahk_id
	if (EvaluatedParameters.ahk_pid)
		tempwinstring:=tempwinstring " ahk_pid " EvaluatedParameters.ahk_pid
	if (EvaluatedParameters.ahk_exe)
		tempwinstring:=tempwinstring " ahk_exe " EvaluatedParameters.ahk_exe
	
	;If no window specified, error
	if (tempwinstring="" and EvaluatedParameters.winText="")
	{
		x_finish(Environment, "exception", lang("No window specified"))
		return
	}
	
	if (ElementParameters.findhiddenwindow=0)
		tempFindHiddenWindows = off
	else
		tempFindHiddenWindows = on
	if (ElementParameters.findhiddentext=0)
		tempfindhiddentext = off
	else
		tempfindhiddentext = on

	SetTitleMatchMode,% EvaluatedParameters.TitleMatchMode
	DetectHiddenWindows,%tempFindHiddenWindows%
	DetectHiddenText,%tempfindhiddentext%
	
	tempWinid:=winexist(tempwinstring,EvaluatedParameters.winText,EvaluatedParameters.ExcludeTitle,EvaluatedParameters.ExcludeText) ;Example code. Remove it
	if not tempWinid
	{
		x_finish(Environment, "exception", lang("Seeked window does not exist") )
		return
	}
	
	x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread")
	
	if winactive("ahk_id " tempWinid)
	{
		x_finish(Environment, "yes")
	}
	else
	{
		x_finish(Environment, "no")
	}
	
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_Window_Active(Environment, ElementParameters)
{
}






Condition_Window_Active_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}
