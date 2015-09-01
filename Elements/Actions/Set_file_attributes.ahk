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
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath
	
	FileSetAttrib,%tempattr%,% tempPath,%operateon%,%recurse%
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
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
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
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Select file")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("Attributes")})
	parametersToEdit.push({type: "CheckBox", id: "ReadOnly", default: -1, label: lang("Read only"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Archive", default: -1, label: lang("Archive"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "System", default: -1, label: lang("System"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Hidden", default: -1, label: lang("Hidden"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Offline", default: -1, label: lang("Offline"), gray: true})
	parametersToEdit.push({type: "CheckBox", id: "Temporary", default: -1, label: lang("Temporary"), gray: true})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Radio", id: "OperateOnWhat", default: 1, choices: [lang("Operate on files"), lang("Operate on files and folders"), lang("Operate on folders")]})
	parametersToEdit.push({type: "Checkbox", id: "Recurse", default: 0, label: lang("Recurse subfolders into")})


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
