iniAllTriggers.="Clipboard_Changes|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerClipboard_Changes(ElementID)
{
	global
	
	TriggerClipboard_Changes_Enabled:=true
	
	
}

getParametersTriggerClipboard_Changes()
{
	
	parametersToEdit:=[]
	
	
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



DisableTriggerClipboard_Changes(ID)
{
	global
	TriggerClipboard_Changes_Enabled:=false
	
	
}

GenerateNameTriggerClipboard_Changes(ID)
{
	return lang("Clipboard_Changes") 
	
}

goto,JumpOverTriggerClipboard_Changes

OnClipboardChange:
if (TriggerClipboard_Changes_Enabled=true)
	goto,r_startRun
return

JumpOverTriggerClipboard_Changes:
temp= ;Do nothing