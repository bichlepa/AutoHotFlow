iniAllTriggers.="Clipboard_Changes|" ;Add this trigger to list of all triggers on initialisation



EnableTriggerClipboard_Changes(ElementID)
{
	global
	
	TriggerClipboard_Changes_Enabled:=true
	OnClipboardChange("TriggerTriggerClipboard_Changes")
	TriggerClipboard_Changes_SettingOnlyText:=%ElementID%OnlyText
	TriggerClipboard_Changes_SettingWhenEmpty:=%ElementID%WhenEmpty
	
}

TriggerTriggerClipboard_Changes(contenttype)
{
	global
	local temppars
	
	if (TriggerClipboard_Changes_Enabled=true)
	{
		if ((TriggerClipboard_Changes_SettingOnlyText=0  and contenttype!=0) or (TriggerClipboard_Changes_SettingOnlyText=1 and contenttype=1) or (TriggerClipboard_Changes_SettingWhenEmpty=1 and contenttype=0))
		{
			logger("f1",%ElementID%type " '" %ElementID%name "': Trigger executes")
			
			temppars:=Object()
			temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_Clipboard",Clipboard)
			temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_ContentType",contenttype)
			r_Trigger(ElementID,temppars)
		}
	}
	
}

DisableTriggerClipboard_Changes(ID)
{
	global
	TriggerClipboard_Changes_Enabled:=false
	
}


getParametersTriggerClipboard_Changes()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "OnlyText", default: 1, label: lang("Trigger only if the clipboard contains some text.")})
	parametersToEdit.push({type: "Checkbox", id: "WhenEmpty", default: 0, label: lang("Trigger if clipboard is empty.")})

	
	return parametersToEdit
}

getNameTriggerClipboard_Changes()
{
	return lang("Clipboard_Changes")
}
getCategoryTriggerClipboard_Changes()
{
	return lang("User_interaction")
}





GenerateNameTriggerClipboard_Changes(ID)
{
	return lang("Clipboard_Changes") 
	
}

