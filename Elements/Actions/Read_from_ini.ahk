iniAllActions.="Read_from_ini|" ;Add this action to list of all actions on initialisation

runActionRead_from_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVarName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local tempText
	
	if tempVarName=
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	
	
	
	if %ElementID%Action=1 ;Read a key
	{
		if %ElementID%WhenError=1
		{
			IniRead,tempText,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file),% v_replaceVariables(InstanceID,ThreadID,%ElementID%section),% v_replaceVariables(InstanceID,ThreadID,%ElementID%key),% v_replaceVariables(InstanceID,ThreadID,%ElementID%default)
		}
		else
		{
			IniRead,tempText,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file),% v_replaceVariables(InstanceID,ThreadID,%ElementID%section),% v_replaceVariables(InstanceID,ThreadID,%ElementID%key),E?R ROR
			if tempText=E?R ROR
			{
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
				return
			}
		}
		
		v_SetVariable(InstanceID,ThreadID,tempVarName,tempText)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	else ;Get section list
	{
		IniRead,tempText,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
		v_setVariable(InstanceID,ThreadID,tempVarName,v_importVariable(tempText,"list","`n"),"list")
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}

	
	
	
	return
}
getNameActionRead_from_ini()
{
	return lang("Read_from_ini")
}
getCategoryActionRead_from_ini()
{
	return lang("Files")
}

getParametersActionRead_from_ini()
{
	global
	
	parametersToEdit:=["Label|" lang("Variable name"),"VariableName|value|varname","Label|" lang("Select an .ini file"),"File||file|" lang("Select an .ini file") "|8|(*.ini)","Label|" lang("Action"),"Radio|1|Action|" lang("Read a key") ";" lang("Read the section names"),"Label|" lang("Section"),"Text|section|Section","Label|" lang("Key"),"Text|key|Key","Label|" lang("Behaviour on error"),"Radio|1|WhenError|" lang("Insert default value in the variable") ";" lang("Throw exception"),"Label|" lang("Default value on failure"),"Text|ERROR|Default" ]
	return parametersToEdit
}

GenerateNameActionRead_from_ini(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	if GUISettingsOfElement%ID%Action1
		return lang("Read_from_ini") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section " - " GUISettingsOfElement%ID%key
	else
		return lang("Read_from_ini") " " lang("Read the section names")
	
}

CheckSettingsActionRead_from_ini(ID)
{
	if (GUISettingsOfElement%ID%Action1 != 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Section
		GuiControl,Disable,GUISettingsOfElement%ID%Key
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError1
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError2
		GuiControl,Disable,GUISettingsOfElement%ID%Default
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Section
		GuiControl,Enable,GUISettingsOfElement%ID%Key
		GuiControl,Enable,GUISettingsOfElement%ID%WhenError1
		GuiControl,Enable,GUISettingsOfElement%ID%WhenError2
		if GUISettingsOfElement%ID%WhenError1=1
			GuiControl,Enable,GUISettingsOfElement%ID%Default
		else
			GuiControl,Disable,GUISettingsOfElement%ID%Default
	}
	
	
}
