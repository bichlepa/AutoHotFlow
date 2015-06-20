iniAllActions.="Set_lock_key|" ;Add this action to list of all actions on initialisation

runActionSet_lock_key(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if %ElementID%WhichKey=1 ;Caps lock
	{
		if %ElementID%Status=1
			SetCapsLockState,On
		else if %ElementID%Status=2
			SetCapsLockState,Off
		else if %ElementID%Status=3
		{
			SetStoreCapslockMode, Off 
			send {CapsLock}
			SetStoreCapslockMode, On
		}
		else if %ElementID%Status=4
			SetCapsLockState,AlwaysOn
		else if %ElementID%Status=5
			SetCapsLockState,AlwaysOff
		
	}
	else if %ElementID%WhichKey=2 ;Num lock
	{
		if %ElementID%Status=1
			SetNumLockState,On
		else if %ElementID%Status=2
			SetNumLockState,Off
		else if %ElementID%Status=3
			send {NumLock}
		else if %ElementID%Status=4
			SetNumLockState,AlwaysOn
		else if %ElementID%Status=5
			SetNumLockState,AlwaysOff
		
	}
	else if %ElementID%WhichKey=3 ;Scroll Lock
	{
		if %ElementID%Status=1
			SetScrollLockState,On
		else if %ElementID%Status=2
			SetScrollLockState,Off
		else if %ElementID%Status=3
			send {ScrollLock}
		else if %ElementID%Status=4
			SetScrollLockState,AlwaysOn
		else if %ElementID%Status=5
			SetScrollLockState,AlwaysOff
		
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionSet_lock_key()
{
	return lang("Set_lock_key")
}
getCategoryActionSet_lock_key()
{
	return lang("User_simulation")
}

getParametersActionSet_lock_key()
{
	global
	parametersToEdit:=["Label|" lang("Which lock key"),"Radio|1|WhichKey|" lang("Caps lock") ";" lang("Num lock") ";" lang("Scroll lock"),"Label|" lang("Status to set"),"Radio|1|Status|" lang("On") ";" lang("Off") ";" lang("Toggle") ";" lang("Always on") ";" lang("Always off") ]
	;,"Label|" lang("Insert_a_keystroke"), "Hotkey||HotkeyToInsert,"Button|customSettingButtonOfActionSet_lock_keyHotkeyToInsert||" lang("Insert")
	return parametersToEdit
}



GenerateNameActionSet_lock_key(ID)
{
	global
	local statusstring
	
	if GUISettingsOfElement%ID%Status1=1
		statusstring:= lang("On")
	else if GUISettingsOfElement%ID%Status2=1
		statusstring:= lang("Off")
	else if GUISettingsOfElement%ID%Status3=1
		statusstring:= lang("Toggle")
	else if GUISettingsOfElement%ID%Status4=1
		statusstring:= lang("Always on")
	else if GUISettingsOfElement%ID%Status5=1
		statusstring:= lang("Always off")
	
	if GUISettingsOfElement%ID%WhichKey1=1 ;Caps lock
		return % lang("Set caps lock state") ": " statusstring
	else if GUISettingsOfElement%ID%WhichKey2=1 ;Num lock
		return % lang("Set num lock state") ": " statusstring
	else if GUISettingsOfElement%ID%WhichKey3=1 ;Num lock
		return % lang("Set scroll lock state") ": " statusstring
		
	
}