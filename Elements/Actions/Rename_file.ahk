iniAllActions.="Rename_file|" ;Add this action to list of all actions on initialisation

runActionRename_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temperror
	local tempdir
	local tempfilename
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
	if tempPath=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File path not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File path")))
		return
	}
	
	
	SplitPath,tempPath,tempfilename,tempdir
	
	if (tempfilename="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File name not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File name")))
		return
		
	}
	if (tempdir="")
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File directory not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("File directory")))
		return
	}
	
	
	FileMove,%tempdir%\%tempfilename%,% tempdir "\" v_replaceVariables(InstanceID,ThreadID,%ElementID%newName),% %ElementID%Overwrite
	
	temperror:=errorlevel
	
	if a_lasterror
	{
		;~ MsgBox % a_lasterror 
		if temperror
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! " temperror " files not renamed.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% files not renamed",temperror))
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No files renamed.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No files renamed"))
		}
		return
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")

	return
}
getNameActionRename_file()
{
	return lang("Rename_file")
}
getCategoryActionRename_file()
{
	return lang("Files")
}

getParametersActionRename_file()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("File")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file")})
	parametersToEdit.push({type: "Label", label: lang("New name")})
	parametersToEdit.push({type: "Edit", id: "newName", default: lang("Renamed") ".txt", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Overwrite")})
	parametersToEdit.push({type: "Checkbox", id: "Overwrite", default: 0, label: lang("Overwrite existing files")})
	
	return parametersToEdit
}

GenerateNameActionRename_file(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Rename_file") " " GUISettingsOfElement%ID%file " " lang("To") " " GUISettingsOfElement%ID%newName 
	
}

CheckSettingsActionRename_file(ID)
{
	
	
}
