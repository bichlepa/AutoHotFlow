iniAllActions.="Set_file_attributes|" ;Add this action to list of all actions on initialisation

runActionSet_file_attributes(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempattr
	local operateon
	local recurse
	if %ElementID%ReadOnly=1
		tempattr.="+R"
	else if %ElementID%ReadOnly=0
		tempattr.="-R"
	if %ElementID%Archive=1
		tempattr.="+A"
	else if %ElementID%Archive=0
		tempattr.="-A"
	if %ElementID%System=1
		tempattr.="+S"
	else if %ElementID%System=0
		tempattr.="-S"
	if %ElementID%Hidden=1
		tempattr.="+H"
	else if %ElementID%Hidden=0
		tempattr.="-H"
	if %ElementID%Offline=1
		tempattr.="+O"
	else if %ElementID%Offline=0
		tempattr.="-O"
	if %ElementID%Temporary=1
		tempattr.="+T"
	else if %ElementID%Temporary=0
		tempattr.="-T"
	
	if tempattr= ;If nothing deselected, it is normal
		tempattr=+N
	
	if %ElementID%OperateOnWhat=1
		operateon=0
	else if %ElementID%OperateOnWhat=2
		operateon=1
	else if %ElementID%OperateOnWhat=3
		operateon=2
	
	if %ElementID%Recurse=1
		recurse=0
	else if %ElementID%Recurse=2
		recurse=1
	
	
	FileSetAttrib,%tempattr%,% v_replaceVariables(InstanceID,ThreadID,%ElementID%file),%operateon%,%recurse%
	if ErrorLevel
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	else
	{
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	}
	return
}
getNameActionSet_file_attributes()
{
	return lang("Set_file_attributes")
}
getCategoryActionSet_file_attributes()
{
	return lang("Files")
}

getParametersActionSet_file_attributes()
{
	global
	
	parametersToEdit:=["Label|" lang("Select file"),"File||file|" lang("Select a file") "|","Label|" lang("Attributes"),"CheckboxWithGray|-1|ReadOnly|" ("Read only") ,"CheckboxWithGray|-1|Archive|" lang("Archive") ,"CheckboxWithGray|-1|System|" lang("System"),"CheckboxWithGray|-1|Hidden|" lang("Hidden") ,"CheckboxWithGray|-1|Offline|" lang("Offline") ,"CheckboxWithGray|-1|Temporary|" lang("Temporary"),"Label|" lang("Options"),"Radio|1|OperateOnWhat|" lang("Operate on files") ";" lang("Operate on files and folders") ";" lang("Operate on folders"),"Checkbox|0|Recurse|" lang("Recurse subfolders into")]
	return parametersToEdit
}

GenerateNameActionSet_file_attributes(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Set_file_attributes") " " GUISettingsOfElement%ID%file
	
}

CheckSettingsActionSet_file_attributes(ID)
{
	
	
}
