iniAllActions.="Read_from_file|" ;Add this action to list of all actions on initialisation

runActionRead_from_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local tempVarName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local tempText
	
	if tempVarName=
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")

	if %ElementID%Encoding=2
		tempOptions.="*P65001 "
	else if %ElementID%Encoding=3
		tempOptions.="*P1200 "
		
	if %ElementID%Linefeed=1
	{
		tempOptions.="*t "
	}
	

	
	FileRead,tempText,% tempOptions v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
	{
		v_SetVariable(InstanceID,ThreadID,tempVarName,tempText)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
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
	
	parametersToEdit:=["Label|" lang("Variable name"),"VariableName|FileText|varname","Label|" lang("Select file"),"File||file|" lang("Select a file") "|8","Label|" lang("Encoding"),"Radio|2|Encoding|" "ANSI" ";" "Unicode UTF-8" ";" "Unicode UTF-16","Label|" lang("Linefeed"),"Checkbox|1|Linefeed|" lang("Replace Carriage return and linefeed with single linefeeds") ]
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
