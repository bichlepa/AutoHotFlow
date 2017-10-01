;Always add this element class name to the global list
AllElementClasses.push("Trigger_Hotkey")

Element_getPackage_Trigger_Hotkey()
{
	return "default"
}

Element_getElementType_Trigger_Hotkey()
{
	return "trigger"
}

Element_getElementLevel_Trigger_Hotkey()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Trigger_Hotkey()
{
	return lang("Hotkey")
}

Element_getIconPath_Trigger_Hotkey()
{
	return "Source_elements\default\icons\keyboard.png"
}

Element_getCategory_Trigger_Hotkey()
{
	return lang("User_interaction")
}

Element_getParameters_Trigger_Hotkey()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "hotkey"})
	parametersToEdit.push({id: "BlockKey"})
	parametersToEdit.push({id: "Wildcard"})
	parametersToEdit.push({id: "WhenRelease"})
	parametersToEdit.push({id: "UseWindow"})
	
	parametersToEdit.push({id: "TitleMatchMode"})
	parametersToEdit.push({id: "Wintitle"})
	parametersToEdit.push({id: "winText"})
	parametersToEdit.push({id: "FindHiddenText"})
	parametersToEdit.push({id: "ahk_class"})
	parametersToEdit.push({id: "ahk_exe"})
	parametersToEdit.push({id: "ahk_id"})
	parametersToEdit.push({id: "ahk_pid"})
	parametersToEdit.push({id: "FindHiddenWindow"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Trigger_Hotkey(Environment)
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Hotkey")})
	parametersToEdit.push({type: "Hotkey", id: "hotkey"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "BlockKey", default: 1, label: lang("Block_key")})
	parametersToEdit.push({type: "Checkbox", id: "Wildcard", default: 0, label: lang("Trigger even if other keys are already held down")})
	parametersToEdit.push({type: "Checkbox", id: "WhenRelease", default: 0, label: lang("Trigger on release rather than press")})
	parametersToEdit.push({type: "Label", label: lang("Window")})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Where should the hotkey be active?")})
	parametersToEdit.push({type: "Radio", id: "UseWindow", default: 1, result: "enum", choices: [lang("Everywhere"), lang("Only active when the specified window is active"), lang("Only active whe the specified window exists")], enum: ["Everywhere", "WindowIsActive", "WindowExists"]})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Window_Class")})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Process_Name")})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Unique_window_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Unique_Process_ID")})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Hidden window")})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", size: "small", label: lang("Get_parameters")})
	parametersToEdit.push({type: "button", id: "GetWindowInformation", goto: "Trigger_Window_Opens_GetWindowParameters", label: lang("Get_Parameters")})

	
	return parametersToEdit
}

Element_GenerateName_Trigger_Hotkey(Environment, ElementParameters)
{
	global
	return % lang("Hotkey") " - " ElementParameters.Hotkey 
	
}

Element_CheckSettings_Trigger_Hotkey(Environment, ElementParameters)
{
	x_Par_Disable("WhenRelease", ElementParameters.BlockKey)
	x_Par_Disable("BlockKey", ElementParameters.WhenRelease)
	
	showWindowPars:=ElementParameters.UseWindow ="WindowIsActive" or ElementParameters.UseWindow="WindowExists"
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

Element_enable_Trigger_Hotkey(Environment, ElementParameters)
{
	
	global
	
	local success:=false
	local functionObject
	
	local temphotkey:=ElementParameters.hotkey
	if temphotkey=
	{
		x_finish(Environment, "exception", lang("The_Hotkey_is_not_set!"))
		return
	}
	if (ElementParameters.BlockKey=False)
		temphotkey=~%temphotkey%
	if (ElementParameters.WhenRelease=True)
		temphotkey=%temphotkey% UP
	if (ElementParameters.Wildcard=True)
		temphotkey=*%temphotkey%
	
	
	if (ElementParameters.UseWindow ="WindowIsActive" or ElementParameters.UseWindow ="WindowExists")
	{
		local tempWinTitle:=x_replaceVariables(Environment, ElementParameters.Wintitle) 
		local tempWinText:=x_replaceVariables(Environment, ElementParameters.winText)
		local tempTitleMatchMode :=ElementParameters.TitleMatchMode
		local tempahk_class:=x_replaceVariables(Environment, ElementParameters.ahk_class)
		local tempahk_exe:=x_replaceVariables(Environment, ElementParameters.ahk_exe)
		local tempahk_id:=x_replaceVariables(Environment, ElementParameters.ahk_id)
		local tempahk_pid:=x_replaceVariables(Environment, ElementParameters.ahk_pid)
		
		;If no window specified, error
		if (tempwinstring="" and tempWinText="")
		{
			x_enabled(Environment, "exception", lang("The hotkey %1% cannot be set!",temphotkey) " " lang("No window specified"))
			return
		}
		
		tempwinstring=%tempWinTitle%
		if tempahk_class<>
			tempwinstring=%tempwinstring% ahk_class %tempahk_class%
		if tempahk_id<>
			tempwinstring=%tempwinstring% ahk_id %tempahk_id%
		if tempahk_pid<>
			tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
		if tempahk_exe<>
			tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
		
		SetTitleMatchMode,%tempTitleMatchMode%
		
		if (ElementParameters.findhiddenwindow=False)
			DetectHiddenWindows off
		else
			DetectHiddenWindows on
		if (ElementParameters.findhiddentext=False)
			DetectHiddenText off
		else
			DetectHiddenText on
	}


	
	if (ElementParameters.UseWindow ="WindowIsActive")
		hotkey,IfWinActive,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	else if (ElementParameters.UseWindow ="WindowExists")
		hotkey,IfWinExist,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	else
		hotkey,IfWinActive
	
	
	
	functionObject:= x_NewExecutionFunctionObject(environment, "Element_trigger_Trigger_Hotkey", ElementParameters)
	x_SetExecutionValue(Environment, "hotkey", temphotkey)

	hotkey,%temphotkey%,% functionObject, UseErrorLevel on
	if ErrorLevel
	{
		x_enabled(Environment, "exception", lang("The hotkey %1% cannot be set!",temphotkey))
	}

	
	x_enabled(Environment, "normal", lang("The hotkey %1% was set.",temphotkey))

	
	
}

Element_trigger_Trigger_Hotkey(Environment, ElementParameters)
{
	x_trigger(Environment)
}

Element_postTrigger_Trigger_Hotkey(Environment, ElementParameters)
{
	x_SetVariable(Environment, "A_Hotkey", ElementParameters.hotkey,"thread")
}


Element_disable_Trigger_Hotkey(Environment, ElementParameters)
{
	temphotkey:=x_getExecutionValue(Environment, "hotkey")
	hotkey,%temphotkey%,off
	x_disabled(Environment, "normal",  lang("The hotkey %1% was unset.",temphotkey))

}