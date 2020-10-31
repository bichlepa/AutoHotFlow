;Always add this element class name to the global list
x_RegisterElementClass("Action_Show_Window")

;Element type of the element
Element_getElementType_Action_Show_Window()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Show_Window()
{
	return x_lang("Show_Window")
}

;Category of the element
Element_getCategory_Action_Show_Window()
{
	return x_lang("Window")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Show_Window()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Show_Window()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Show_Window()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Show_Window()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Show_Window(Environment)
{
	parametersToEdit:=Object()
	
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Window identification")})
	parametersToEdit.push({type: "Label", label: x_lang("Title_of_Window"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [x_lang("Start_with"), x_lang("Contain_anywhere"), x_lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Exclude_title"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: x_lang("Text_of_a_control_in_Window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: x_lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: x_lang("Exclude_text_of_a_control_in_window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
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
	parametersToEdit.push({type: "button", goto: "Action_Show_Window_ButtonWindowAssistant", label: x_lang("Import window identification")})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Show_Window(Environment, ElementParameters)
{
	
	local tempNameString
	if (ElementParameters.Wintitle)
	{
		if (ElementParameters.TitleMatchMode=1)
			tempNameString:=tempNameString "`n" x_lang("Title begins with") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=2)
			tempNameString:=tempNameString "`n" x_lang("Title includes") ": " ElementParameters.Wintitle
		else if (ElementParameters.TitleMatchMode=3)
			tempNameString:=tempNameString "`n" x_lang("Title is exatly") ": " ElementParameters.Wintitle
	}
	if (ElementParameters.excludeTitle)
		tempNameString:=tempNameString "`n" x_lang("Exclude_title") ": " ElementParameters.excludeTitle
	if (ElementParameters.winText)
		tempNameString:=tempNameString "`n" x_lang("Control_text") ": " ElementParameters.winText
	if (ElementParameters.ExcludeText)
		tempNameString:=tempNameString "`n" x_lang("Exclude_control_text") ": " ElementParameters.ExcludeText
	if (ElementParameters.ahk_class)
		tempNameString:=tempNameString "`n" x_lang("Window_Class") ": " ElementParameters.ahk_class
	if (ElementParameters.ahk_exe)
		tempNameString:=tempNameString "`n" x_lang("Process") ": " ElementParameters.ahk_exe
	if (ElementParameters.ahk_id)
		tempNameString:=tempNameString "`n" x_lang("Window_ID") ": " ElementParameters.ahk_id
	if (ElementParameters.ahk_pid)
		tempNameString:=tempNameString "`n" x_lang("Process_ID") ": " ElementParameters.ahk_pid
	
	return x_lang("Show_Window") ": " tempNameString
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Show_Window(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Show_Window(Environment, ElementParameters)
{


	tempWinTitle:=x_replaceVariables(Environment, ElementParameters.Wintitle) 
	tempWinText:=x_replaceVariables(Environment, ElementParameters.winText)
	tempExcludeTitle:=EvaluatedParameters.ExcludeTitle
	tempExcludeText:=EvaluatedParameters.ExcludeText
	tempTitleMatchMode :=ElementParameters.TitleMatchMode
	tempahk_class:=x_replaceVariables(Environment, ElementParameters.ahk_class)
	tempahk_exe:=x_replaceVariables(Environment, ElementParameters.ahk_exe)
	tempahk_id:=x_replaceVariables(Environment, ElementParameters.ahk_id)
	tempahk_pid:=x_replaceVariables(Environment, ElementParameters.ahk_pid)
	
	tempwinstring:=tempWinTitle
	if tempahk_class
		tempwinstring:=tempwinstring " ahk_class " tempahk_class
	if tempahk_id
		tempwinstring:=tempwinstring " ahk_id " tempahk_id
	if tempahk_pid
		tempwinstring:=tempwinstring " ahk_pid " tempahk_pid
	if tempahk_exe
		tempwinstring:=tempwinstring " ahk_exe " tempahk_exe
	
	;If no window specified, error
	if (tempwinstring="" and tempWinText="")
	{
		x_enabled(Environment, "exception", x_lang("No window specified"))
		return
	}
	
	if ElementParameters.findhiddenwindow=0
		tempFindHiddenWindows = off
	else
		tempFindHiddenWindows = on
	if ElementParameters.findhiddentext=0
		tempfindhiddentext = off
	else
		tempfindhiddentext = on

	SetTitleMatchMode,%tempTitleMatchMode%
	DetectHiddenWindows,%tempFindHiddenWindows%
	DetectHiddenText,%tempfindhiddentext%
	
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText) ;Example code. Remove it
	if tempWinid
	{
		x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread")
		WinShow,ahk_id %tempWinid%
		x_finish(Environment, "normal")
		return
	}
	else
	{
		x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
		return
	}

	

	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Show_Window(Environment, ElementParameters)
{
	
}


; opens the assistant for getting window information
Action_Show_Window_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}
