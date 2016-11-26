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

Element_getName_Trigger_Hotkey()
{
	return lang("Hotkey")
}

Element_getCategory_Trigger_Hotkey()
{
	return lang("User_interaction")
}

Element_getParameters_Trigger_Hotkey()
{
	return ["hotkey", "BlockKey", "Wildcard", "WhenRelease", "UseWindow", "TitleMatchMode", "Wintitle", "winText", "FindHiddenText", "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"]
}

Element_getParametrizationDetails_Trigger_Hotkey()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Hotkey")})
	parametersToEdit.push({type: "Hotkey", id: "hotkey"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "BlockKey", default: 1, label: lang("Block_key")})
	parametersToEdit.push({type: "Checkbox", id: "Wildcard", default: 0, label: lang("Trigger even if other keys are already held down")})
	parametersToEdit.push({type: "Checkbox", id: "WhenRelease", default: 0, label: lang("Trigger on release rather than press")})
	parametersToEdit.push({type: "Label", label: lang("Window")})
	parametersToEdit.push({type: "Radio", id: "UseWindow", default: 1, choices: [lang("Always active"), lang("Only active when the specified window is active"), lang("Only active whe the specified window exists")]})
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window")})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window")})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
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
	parametersToEdit.push({type: "button", id: "GetWindowInformation", goto: "FunctionsForElementGetWindowInformation", label: lang("Get_Parameters")})

	
	return parametersToEdit
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
	if (ElementParameters.BlockKey=0)
		temphotkey=~%temphotkey%
	if (ElementParameters.WhenRelease=1)
		temphotkey=%temphotkey% UP
	if (ElementParameters.Wildcard=1)
		temphotkey=*%temphotkey%
	
	
	;~ if (ElementParameters.UseWindow =2 or ElementParameters.UseWindow =3)
	;~ {
		;~ local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.Wintitle)
		;~ local tempWinText:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.winText)
		;~ local tempTitleMatchMode :=ElementParameters.TitleMatchMode
		;~ local tempahk_class:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.ahk_class)
		;~ local tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.ahk_exe)
		;~ local tempahk_id:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.ahk_id)
		;~ local tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,ElementParameters.ahk_pid)
		
		;~ ;If no window specified, error
		;~ if (tempwinstring="" and tempWinText="")
		;~ {
			;~ logger("f0",%ElementID%type " '" %ElementID%name "': Error! No window specified")
			;~ MsgBox,16,% lang("Error"),% lang("The hotkey %1% cannot be set!",temphotkey) " " lang("No window specified")
			;~ return
		;~ }
		
		;~ tempwinstring=%tempWinTitle%
		;~ if tempahk_class<>
			;~ tempwinstring=%tempwinstring% ahk_class %tempahk_class%
		;~ if tempahk_id<>
			;~ tempwinstring=%tempwinstring% ahk_id %tempahk_id%
		;~ if tempahk_pid<>
			;~ tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
		;~ if tempahk_exe<>
			;~ tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
		
		;~ SetTitleMatchMode,%tempTitleMatchMode%
		
		;~ if %ElementID%findhiddenwindow=0
			;~ DetectHiddenWindows off
		;~ else
			;~ DetectHiddenWindows on
		;~ if %ElementID%findhiddentext=0
			;~ DetectHiddenText off
		;~ else
			;~ DetectHiddenText on
	;~ }


	
	;~ if (%ElementID%UseWindow =2)
		;~ hotkey,IfWinActive,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	;~ else if (%ElementID%UseWindow =3)
		;~ hotkey,IfWinExist,%tempwinstring%,%tempWinText% ;,%tempExcludeTitle%,%tempExcludeText%
	;~ else
		;~ hotkey,IfWinActive
	
	
	
	local uniqueID:=x_NewUniqueExecutionID(Environment)
	functionObject:=x_NewExecutionFunctionObject(environment, uniqueID, "Element_trigger_Trigger_Hotkey")
	x_SetExecutionValue(uniqueID, "hotkey", temphotkey)

	hotkey,%temphotkey%,% functionObject, UseErrorLevel on
	if ErrorLevel
	{
		x_finish(Environment, "exception", lang("The hotkey %1% cannot be set!",temphotkey))
	}

	

	x_finish(Environment, "normal", lang("The hotkey %1% was set.",temphotkey))

	
	
}

Element_trigger_Trigger_Hotkey(Environment, ElementParameters)
{
	x_trigger(Environment)
}


Element_disable_Trigger_Hotkey(Environment, ElementParameters)
{
	uniqueID:=x_GetMyUniqueExecutionID(Environment)
	temphotkey:=x_getExecutionValue(uniqueID, "hotkey")
	hotkey,%temphotkey%,off
}

Element_GenerateName_Trigger_Hotkey(ElementParameters)
{
	global
	return % lang("Hotkey") " - " ElementParameters.Hotkey 
	
}

Element_CheckSettings_Trigger_Hotkey(Environment, ElementParameters)
{
	;~ ElementSettings.enable(ElementParameters.BlockKey,"WhenRelease")
}