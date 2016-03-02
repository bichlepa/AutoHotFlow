iniAllActions.="Select_folder|" ;Add this action to list of all actions on initialisation

runActionSelect_folder(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSelect_folderToStart))
		ActionSelect_folderToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance
	ActionSelect_folderToStart.insert(tempInstanceString)
	
	SetTimer,ActionSelect_folder_StartNextQuestion,10,-10 ;lower priority
	
	;~ MsgBox
	return
	
	

	ActionSelect_folder_StartNextQuestion:
	Select_folderStarted:=false
	for count, tempcSelect_folderidToStart in ActionSelect_folderToStart ;get the first element
	{
		
		Select_folderStarted:=true
		StringSplit,tempElement,tempcSelect_folderidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = thread id
		; tempElement4 = element id
		; tempElement5 = element id in the instance
		ActionSelect_folderToStart_Element_ID:=tempElement4
		ActionSelect_folderToStart_Element_IDInInstance:=tempElement5
		ActionSelect_folderStart_CurrentThread_ID:=tempElement3
		ActionSelect_folderStart_CurrentInstanceID:=tempElement2
		
		;gui,%tempcSelect_folderidToStart%:default
		
		;gui,10:-SysMenu 
		
		ActionSelect_folderStart_CurrentVarname:=v_replaceVariables(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThreadID,%ActionSelect_folderToStart_Element_ID%Varname)
		;~ MsgBox % tempcSelect_folderidToStart "--" ActionSelect_folderStart_CurrentVarname
		if not v_CheckVariableName(ActionSelect_folderStart_CurrentVarname)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" ActionSelect_folderStart_CurrentVarname "' is not valid")
			MarkThatElementHasFinishedRunning(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThread_ID,ActionSelect_folderToStart_Element_ID,ActionSelect_folderToStart_Element_IDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",ActionSelect_folderStart_CurrentVarname)) )
			break
		}
		
		
		tempActionSelectFolderOptions=0

		tempActionSelectFolderRoot:=v_replaceVariables(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThread_ID,%ActionSelect_folderToStart_Element_ID%folder)
		if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempActionSelectFolderRoot)
			tempActionSelectFolderRoot:=flowSettings.WorkingDir "\" tempActionSelectFolderRoot
		
		if %ActionSelect_folderToStart_Element_ID%ButtonNewFolder
			tempActionSelectFolderOptions+=1
		if %ActionSelect_folderToStart_Element_ID%EditField
			tempActionSelectFolderOptions+=2
		
		if %ActionSelect_folderToStart_Element_ID%AllowUpward
			tempActionSelectFolderRoot:="*" tempActionSelectFolderRoot
		
		
		
		;~ MsgBox %tempActionSelectFileOptions%
		FileSelectFolder,tempActionSelectFolderFolder,% tempActionSelectFolderRoot ,%tempActionSelectFolderOptions%,% v_replaceVariables(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThread_ID,%ActionSelect_folderToStart_Element_ID%title)
		;MsgBox %ActionSelect_folderToStart_Element_ID% %tempActionSelectFilefile% %errorlevel%
		
		if errorlevel
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! User dismissed the dialog without selecting a folder or system refused to show the dialog.")
			MarkThatElementHasFinishedRunning(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThread_ID,ActionSelect_folderToStart_Element_ID,ActionSelect_folderToStart_Element_IDInInstance,"exception",lang("User dismissed the dialog without selecting a folder or system refused to show the dialog."))
			break
		}
		else
		{
			v_setVariable(ActionSelect_folderStart_CurrentInstanceID,ActionSelect_folderStart_CurrentThread_ID,ActionSelect_folderStart_CurrentVarname,tempActionSelectFolderFolder)
			
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_folderidToStart,"normal")
		}
		
		break
		
	}
	
	if (Select_folderStarted)
		ActionSelect_folderToStart.remove(1) ;Remove the shown question
	else
		SetTimer,ActionSelect_folder_StartNextQuestion,off
	
	return
	
	
}

stopActionSelect_folder(ID)
{
	
	
}



getParametersActionSelect_folder()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "selectedFolder", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Prompt")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Select a folder"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Root directory")})
	parametersToEdit.push({type: "folder", id: "folder"})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "checkbox", id: "AllowUpward", default: 1, label: lang("Permit to navigate upward")})
	parametersToEdit.push({type: "checkbox", id: "ButtonNewFolder", default: 0, label: lang("Show a button to create a new folder")})
	parametersToEdit.push({type: "checkbox", id: "EditField", default: 0, label: lang("Show an edit field to type in the folder name")})

	return parametersToEdit
}

getNameActionSelect_folder()
{
	return lang("Select_folder")
}
getCategoryActionSelect_folder()
{
	return lang("User_interaction") "|" lang("files")
}

GenerateNameActionSelect_folder(ID)
{
	return lang("Select_folder") ". " lang("Starting folder") ": " GUISettingsOfElement%ID%folder
	
}

CheckSettingsActionSelect_folder(ID)
{
	if (GUISettingsOfElement%ID%MultiSelect = 1)
	{
		
		GuiControl,Disable,GUISettingsOfElement%ID%SaveButton
		GuiControl,,GUISettingsOfElement%ID%SaveButton,0
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%SaveButton
	}
	if (GUISettingsOfElement%ID%SaveButton = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%fileMustExist
		GuiControl,,GUISettingsOfElement%ID%fileMustExist,0
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%fileMustExist
	}
	
	
}