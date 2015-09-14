iniAllTriggers.="File_Observer|" ;Add this trigger to list of all triggers on initialisation
TriggerFile_Observer_AllActiveTriggerObj:=Object()
TriggerFile_Observer_MaxAmount:=20


EnableTriggerFile_Observer(ElementID)
{
	global
	
	local path :=v_replaceVariables(0,0,%ElementID%folder) 
	;~ local FileNameStart :=v_replaceVariables(0,0,%ElementID%FileNameStart) 
	;~ local FileNameEnd :=v_replaceVariables(0,0,%ElementID%FileNameEnd) 
	local WhatNotify:=""
	local result
	;Check whether value is not empty
	if path=
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! Path is empty!")
		MsgBox,16,% lang("Error"),% lang("Path is empty!")
		return
	}
	
	if %ElementID%IncludeSubfolders
	{
		path=%path%*
	}
	
	;~ if FileNameEnd
	;~ {
		;~ path.="|" FileNameEnd "\"
	;~ }
	;~ if FileNameStart
	;~ {
		;~ path.="|\" FileNameStart
	;~ }
	
	
	if %ElementID%FILE_NOTIFY_CHANGE_FILE_NAME
	{
		WhatNotify.="0x1|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_DIR_NAME
	{
		WhatNotify.="0x2|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_ATTRIBUTES
	{
		WhatNotify.="0x4|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_SIZE
	{
		WhatNotify.="0x8|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_LAST_WRITE
	{
		WhatNotify.="0x10|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_LAST_ACCESS
	{
		WhatNotify.="0x20|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_CREATION
	{
		WhatNotify.="0x40|"
	}
	if %ElementID%FILE_NOTIFY_CHANGE_SECURITY
	{
		WhatNotify.="0x100|"
	}
	StringTrimRight,WhatNotify,WhatNotify,1
	
	if WhatNotify=
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! No event type selected!")
		MsgBox,16,% lang("Error"),% lang("No event type selected")
		return
	}
	
	loop %TriggerFile_Observer_MaxAmount%
	{
		if TriggerFile_Observer_AllActiveTriggerObj.HasKey("Index" A_Index)
			continue
		else
		{
			local tempObject:=Object()
			tempObject.ElementID:=ElementID
			tempObject.Path:=Path
			
			
			TriggerHotkey_AllActiveTriggerObj["Index" A_Index]:=tempObject
			result:=WatchDirectory(path,"TriggerFile_ObserverWatch" A_Index,WhatNotify)
			;~ ToolTip %result%
			if (result<=0)
			{
				logger("f0",%ElementID%type " '" %ElementID%name "': Error! The folder " path " cannot be observed!")
				MsgBox,16,% lang("Error"),% lang("The path %1% cannot be observed!",path)
			}
			%ElementID%enabledFile_Observer:=tempFile_Observer
			success:=true
			break
		}
	}
	;~ MsgBox,,, % "FileCreateFile_Observer," A_ScriptFullPath "," %id%File_ObserverPath ",,RunFlow " ThisFlowFolder "\" ThisFlowFilename
	if not success
	{
		logger("f0",%ElementID%type " '" %ElementID%name "': Error! The file observer cannot be set! The maximum amount is reached.")
		MsgBox,16,% lang("Error"),% lang("The file observer cannot be set!") " " lang("The maximum amount is reached.") 
		return
	}
	
}


TriggerFile_ObserverWatch(FileFrom,FileTo,Index)
{
	global 
	local elementID:=TriggerFile_Observer_AllActiveTriggerObj["index" index]["elementID"]
	local temppars:=Object()
	
	if (FileFrom="" and FileTo!="")
		temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangeType","ADDED")
	if (FileFrom!="" and FileTo="")
		temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangeType","REMOVED")
	if (FileFrom!="" and FileTo!="" and FileFrom!=FileTo)
		temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangeType","RENAMED")
	if (FileFrom!="" and FileTo!="" and FileFrom=FileTo)
		temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangeType","MODIFIED")
	
	temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangedFrom",FileFrom)
	temppars["threadVariables"]:=v_AppendAVariableToString(temppars["threadVariables"],"A_FileChangedTo",FileTo)
	
	r_Trigger(ElementID,temppars)
}


DisableTriggerFile_Observer(ElementID)
{
	global
	WatchDirectory("")
	
	
}

getParametersTriggerFile_Observer()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Path to observe")})
	parametersToEdit.push({type: "Folder", id: "folder", default: "%A_Desktop%" , label: lang("Path to observe")})
	parametersToEdit.push({type: "Label", label: lang("Subfolders"), size: "small"})
	parametersToEdit.push({type: "CheckBox", id: "IncludeSubfolders", default: 1, label: lang("Include subfolders")})
	
	;~ parametersToEdit.push({type: "Label", label: lang("Filter")})
	;~ parametersToEdit.push({type: "Label", label: lang("Beginning of filename"), size: "small"})
	;~ parametersToEdit.push({type: "edit", id: "FileNameStart", content: "String"})
	;~ parametersToEdit.push({type: "Label", label: lang("End of filename"), size: "small"})
	;~ parametersToEdit.push({type: "edit", id: "FileNameEnd", content: "String"})
	
	
	parametersToEdit.push({type: "Label", label: lang("Event types")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_CREATION", default: 0, label: lang("File created")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_LAST_ACCESS", default: 0, label: lang("File accessed")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_LAST_WRITE", default: 1, label: lang("Written to file")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_SIZE", default: 0, label: lang("File size changed")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_FILE_NAME", default: 0, label: lang("File name changed")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_DIR_NAME", default: 0, label: lang("Folder name changed")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_ATTRIBUTES", default: 0, label: lang("Attributes changed")})
	parametersToEdit.push({type: "CheckBox", id: "FILE_NOTIFY_CHANGE_SECURITY", default: 0, label: lang("Security changed")})


	
	return parametersToEdit
}

getNameTriggerFile_Observer()
{
	return lang("File_Observer")
}
getCategoryTriggerFile_Observer()
{
	return lang("Files")
}



GenerateNameTriggerFile_Observer(ID)
{
	return lang("File_Observer") ": " GUISettingsOfElement%ID%Folder
	
}


TriggerFile_ObserverWatch1(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,1)
}
TriggerFile_ObserverWatch2(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,2)
}
TriggerFile_ObserverWatch3(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,3)
}
TriggerFile_ObserverWatch4(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,4)
}
TriggerFile_ObserverWatch5(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,5)
}
TriggerFile_ObserverWatch6(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,6)
}
TriggerFile_ObserverWatch7(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,7)
}
TriggerFile_ObserverWatch8(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,8)
}
TriggerFile_ObserverWatch9(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,9)
}
TriggerFile_ObserverWatch10(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,10)
}
TriggerFile_ObserverWatch11(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,11)
}
TriggerFile_ObserverWatch12(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,12)
}
TriggerFile_ObserverWatch13(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,13)
}
TriggerFile_ObserverWatch14(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,14)
}
TriggerFile_ObserverWatch15(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,15)
}
TriggerFile_ObserverWatch16(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,16)
}
TriggerFile_ObserverWatch17(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,17)
}
TriggerFile_ObserverWatch18(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,18)
}
TriggerFile_ObserverWatch19(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,19)
}
TriggerFile_ObserverWatch20(FileFrom,FileTo) {
	TriggerFile_ObserverWatch(FileFrom,FileTo,20)
}