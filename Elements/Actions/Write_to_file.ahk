iniAllActions.="Write_to_file|" ;Add this action to list of all actions on initialisation

runActionWrite_to_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempEncoding
	local tempOverwrite
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text)
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath

		
	if %ElementID%Encoding=1
		tempEncoding=%A_Space%
	else if %ElementID%Encoding=2
		tempEncoding=UTF-8
	else if %ElementID%Encoding=3
		tempEncoding=UTF-16
		
	if %ElementID%Overwrite=2
		FileDelete,% tempPath
		
		
	if %ElementID%Linefeed=1
	{
		StringReplace,tempText,tempText,`r`n,`n,all
		FileAppend,% tempText,*%tempPath%,%tempEncoding%
	}
	else if %ElementID%Linefeed=2
	{
		StringReplace,tempText,tempText,`r`n,`n,all
		StringReplace,tempText,tempText,`n,`r`n,all
		FileAppend,% tempText,% tempPath,%tempEncoding%
	}

	
	
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' could not be written")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' could not be read",tempPath))
		return
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionWrite_to_file()
{
	return lang("Write_to_file")
}
getCategoryActionWrite_to_file()
{
	return lang("Files")
}

getParametersActionWrite_to_file()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Text_to_write")})
	parametersToEdit.push({type: "Edit", id: "text", multiline: true, content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8})
	parametersToEdit.push({type: "Label", label: lang("Encoding")})
	parametersToEdit.push({type: "Radio", id: "Encoding", default: 2, choices: [ANSI, Unicode UTF-8, Unicode UTF-16]})
	parametersToEdit.push({type: "Label", label: lang("Append or overwrite")})
	parametersToEdit.push({type: "Radio", id: "Overwrite", default: 1, choices: [lang("Append"), lang("Overwrite")]})
	parametersToEdit.push({type: "Label", label: lang("Linefeed")})
	parametersToEdit.push({type: "Radio", id: "Linefeed", default: 2, choices: [lang("Only a linefeed"), lang("Carriage return and linefeed")]})

	return parametersToEdit
}

GenerateNameActionWrite_to_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Write_to_file") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%text
	
}

CheckSettingsActionWrite_to_file(ID)
{
	
	
}
