iniAllActions.="Read_from_ini|" ;Add this action to list of all actions on initialisation

runActionRead_from_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local tempText
	local tempSection
	local tempKey
	local tempDefault
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	
	if not fileexist(tempPath)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
		return
	}
	
	if %ElementID%Action=1 ;Read a key
	{
		tempSection:=v_replaceVariables(InstanceID,ThreadID,%ElementID%section)
		tempKey:=v_replaceVariables(InstanceID,ThreadID,%ElementID%key)
		
		if tempSection=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Section name is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Section name")))
			return
			
		}
		if tempKey=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Key name is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Key name")))
			return
			
		}
		
		if %ElementID%WhenError=1
		{
			tempDefault:=v_replaceVariables(InstanceID,ThreadID,%ElementID%default)
			
			IniRead,tempText,% tempPath,% tempSection,% tempKey,% tempDefault
			
		}
		else
		{
			IniRead,tempText,% tempPath,% tempSection,% tempKey,E?R ROR
			if tempText=E?R ROR
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Section '" tempSection "' and  key '" tempKey "' not found.")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Section '%1%' and key '%2%' not found.",tempSection,tempKey))
				
				return
			}
		}
		
		v_SetVariable(InstanceID,ThreadID,varname,tempText)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	else if %ElementID%Action=2 ;Read entire section
	{
		tempSection:=v_replaceVariables(InstanceID,ThreadID,%ElementID%section)
		if tempSection=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Section name is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Section name")))
			return
			
		}
		
		IniRead,tempText,% tempPath,tempSection
		v_SetVariable(InstanceID,ThreadID,varname,tempText)
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	else ;Get section list
	{
		IniRead,tempText,% tempPath
		v_setVariable(InstanceID,ThreadID,varname,v_importVariable(tempText,"list","`n"),"list")
		
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output Variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Path of .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", default: 1, choices: [lang("Read a key"), lang("Read the entire section"), lang("Read the section names")]})
	parametersToEdit.push({type: "Label", label: lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Behavior on error")})
	parametersToEdit.push({type: "Radio", id: "WhenError", default: 1, choices: [lang("Insert default value in the variable"), lang("Throw exception")]})
	parametersToEdit.push({type: "Label", label: lang("Default value on failure")})
	parametersToEdit.push({type: "Edit", id: "Default", default: "ERROR", content: "String"})

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
	if (GUISettingsOfElement%ID%Action1 = 1) ;Read key
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
	else if (GUISettingsOfElement%ID%Action2 = 1) ;Read section
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Section
		GuiControl,Disable,GUISettingsOfElement%ID%Key
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError1
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError2
		GuiControl,Disable,GUISettingsOfElement%ID%Default
	}
	else ;Read section names
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Section
		GuiControl,Disable,GUISettingsOfElement%ID%Key
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError1
		GuiControl,Disable,GUISettingsOfElement%ID%WhenError2
		GuiControl,Disable,GUISettingsOfElement%ID%Default
	}
	
	
}
