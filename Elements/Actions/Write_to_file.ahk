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
	
	parametersToEdit:=["Label|" lang("Text_to_write"),"MultiLineText||text","Label|" lang("File path"),"File||file|" lang("Select a file") "|8","Label|" lang("Encoding"),"Radio|2|Encoding|" "ANSI" ";" "Unicode UTF-8" ";" "Unicode UTF-16","Label|" lang("Append or overwrite"),"Radio|1|Overwrite|" lang("Append") ";" lang("Overwrite"),"Label|" lang("Linefeed"),"Radio|2|Linefeed|" lang("Only a linefeed") ";" lang("Carriage return and linefeed")]
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
