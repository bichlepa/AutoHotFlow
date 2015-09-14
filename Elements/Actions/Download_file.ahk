iniAllActions.="Download_file|" ;Add this action to list of all actions on initialisation

runActionDownload_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if tempPath=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File path not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File path")))
		return
	}
	if DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	

	local tempURL
	
	

	if %ElementID%IsExpression=1
		tempURL:=%ElementID%URL
	else if %ElementID%IsExpression=2
		tempURL:=v_replaceVariables(InstanceID,ThreadID,%ElementID%URL)
	else if %ElementID%IsExpression=3
		tempURL:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%URL)
	
	URLDownloadToFile,%tempURL%,%tempPath%
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File not downloaded.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Couldn't download file"))
		return
	}
	v_SetVariable(InstanceID,ThreadID,tempVarName,temp)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionDownload_file()
{
	return lang("Download_file")
}
getCategoryActionDownload_file()
{
	return lang("Internet")
}

getParametersActionDownload_file()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("URL")})
	parametersToEdit.push({type: "Radio", id: "IsExpression", default: 1, choices: [lang("This is a Link. It does not contain variables"), lang("This is a Link. It contains variables enclosed in percentage signs"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "URL", default: "http://www.example.com", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("File path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select file")})

	return parametersToEdit
}

GenerateNameActionDownload_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Download_file") " " GUISettingsOfElement%ID%file ": " GUISettingsOfElement%ID%URL 
	
}

CheckSettingsActionDownload_file(ID)
{
	
	
}
