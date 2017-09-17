;Always add this element class name to the global list
AllElementClasses.push("Action_Activate_Window")

Element_getPackage_Action_Activate_Window()
{
	return "default"
}

Element_getElementType_Action_Activate_Window()
{
	return "action"
}

Element_getElementLevel_Action_Activate_Window()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Activate_Window()
{
	return lang("Activate_Window")
}

Element_getIconPath_Action_Activate_Window()
{
	;~ return "Source_elements\default\icons\Bullhorn.png"
}

Element_getCategory_Action_Activate_Window()
{
	return lang("Window")
}

Element_getParameters_Action_Activate_Window()
{
	return ["TitleMatchMode", "Wintitle", "excludeTitle", "winText", "FindHiddenText", "ExcludeText", "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"]
}

Element_getParametrizationDetails_Action_Activate_Window(Environment)
{	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title")})
	parametersToEdit.push({type: "edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window")})
	parametersToEdit.push({type: "edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class")})
	parametersToEdit.push({type: "edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name")})
	parametersToEdit.push({type: "edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID")})
	parametersToEdit.push({type: "edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID")})
	parametersToEdit.push({type: "edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Get_parameters")})
	parametersToEdit.push({type: "button", goto: "x_assistant_windowParameter", label: lang("Get_Parameters")})
	
	return parametersToEdit
}

Element_GenerateName_Action_Activate_Window(Environment, ElementParameters)
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
	
	return lang("Activate_Window") ": " tempNameString
	
}

Element_run_Action_Activate_Window(Environment, ElementParameters)
{
	local tempWinid
	
	local tempWinTitle:=x_replaceVariables(Environment,ElementParameters.Wintitle)
	local tempWinText:=x_replaceVariables(Environment,ElementParameters.winText)
	local tempExcludeTitle:=x_replaceVariables(Environment,ElementParameters.excludeTitle)
	local tempExcludeText:=x_replaceVariables(Environment,ElementParameters.ExcludeText)
	local tempTitleMatchMode :=ElementParameters.TitleMatchMode
	local tempahk_class:=x_replaceVariables(Environment,ElementParameters.ahk_class)
	local tempahk_exe:=x_replaceVariables(Environment,ElementParameters.ahk_exe)
	local tempahk_id:=x_replaceVariables(Environment,ElementParameters.ahk_id)
	local tempahk_pid:=x_replaceVariables(Environment,ElementParameters.ahk_pid)
	
	local tempwinstring:=tempWinTitle
	if tempahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempahk_class%
	if tempahk_id<>
		tempwinstring=%tempwinstring% ahk_id %tempahk_id%
	if tempahk_pid<>
		tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
	if tempahk_exe<>
		tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
	if (tempwinstring="" and tempWinText="" and tempExcludeTitle = "" and tempExcludeText ="")
	{
		x_finish(Environment, "exception", lang("Error! No window specified")) 
		return
	}
	
	SetTitleMatchMode,%tempTitleMatchMode%
	
	if (ElementParameters.findhiddenwindow=0)
		DetectHiddenWindows off
	else
		DetectHiddenWindows on
	if (ElementParameters.findhiddentext=0)
		DetectHiddenText off
	else
		DetectHiddenText on
	
	tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText)
	if tempWinid
	{
		x_SetVariable(Environment,"A_WindowID",tempWinid,"Thread")
		WinActivate,ahk_id %tempWinid%
		x_finish(Environment, "normal")
		return
	}
	else
	{
		x_finish(Environment, "exception", lang("Error! Seeked window does not exist")) 
		return
	}
}
