iniAllActions.="Write_to_ini|" ;Add this action to list of all actions on initialisation

runActionWrite_to_ini(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	
	local tempSection
	local tempKey
	local tempText
	local tempValue
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	
	tempSection:=v_replaceVariables(InstanceID,ThreadID,%ElementID%section)
	tempKey:=v_replaceVariables(InstanceID,ThreadID,%ElementID%key)
	tempValue:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Value)
	
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
	if tempValue=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! Value is not specified.")
	}
	
	IniWrite,% tempValue,% tempPath,% tempSection,% tempKey
	
	if ErrorLevel
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' could not be written")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' could not be read",tempPath))
		return
		
	}
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	
	return
}
getNameActionWrite_to_ini()
{
	return lang("Write_to_ini")
}
getCategoryActionWrite_to_ini()
{
	return lang("Files")
}

getParametersActionWrite_to_ini()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Value")})
	parametersToEdit.push({type: "Edit", id: "Value", default: "value", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionWrite_to_ini(ID)
{
	global
	;MsgBox % %ID%text_to_show
	

	return lang("Write_to_ini") " " GUISettingsOfElement%ID%Value ": " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%Section " - " GUISettingsOfElement%ID%key

	
}

CheckSettingsActionWrite_to_ini(ID)
{
	
	
	
}
