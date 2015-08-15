iniAllActions.="Read_from_file|" ;Add this action to list of all actions on initialisation

runActionRead_from_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local tempText
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}

	if %ElementID%Encoding=2 ;UTF-8
		tempOptions.="*P65001 "
	else if %ElementID%Encoding=3 ;UTF-16
		tempOptions.="*P1200 "
		
	if %ElementID%Linefeed=1 ;Remove carriage returns
	{
		tempOptions.="*t "
	}
	

	
	FileRead,tempText,% tempPath
	if ErrorLevel
	{
		if not fileexist(tempPath)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' could not be read")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' could not be read",tempPath))
			return
		}
	}
	
	v_SetVariable(InstanceID,ThreadID,varname,tempText)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionRead_from_file()
{
	return lang("Read_from_file")
}
getCategoryActionRead_from_file()
{
	return lang("Files")
}

getParametersActionRead_from_file()
{
	global
	
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|FileText|varname","Label|" lang("File path"),"File||file|" lang("Select a file") "|8","Label|" lang("Encoding"),"Radio|2|Encoding|" "ANSI" ";" "Unicode UTF-8" ";" "Unicode UTF-16","Label|" lang("Linefeed"),"Checkbox|1|Linefeed|" lang("Replace Carriage return and linefeed with single linefeeds") ]
	return parametersToEdit
}

GenerateNameActionRead_from_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Read_from_file") " " GUISettingsOfElement%ID%file 
	
}

CheckSettingsActionRead_from_file(ID)
{
	
	
}
