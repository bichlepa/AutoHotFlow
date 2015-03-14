iniAllActions.="Select_folder|" ;Add this action to list of all actions on initialisation

runActionSelect_folder(InstanceID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSelect_folderToStart))
		ActionSelect_folderToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ElementID "_" ElementIDInInstance
	ActionSelect_folderToStart.insert(tempInstanceString)
	
	SetTimer,ActionSelect_folder_StartNextQuestion,10,-10 ;lower priority
	
	
	return
	
	

	ActionSelect_folder_StartNextQuestion:
	Select_folderStarted:=false
	for count, tempcSelect_folderidToStart in ActionSelect_folderToStart ;get the first element
	{
		StringSplit,tempElement,tempcSelect_folderidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = element id
		; tempElement4 = element id in the instance
		ActionSelect_folderToStart_Element_ID:=tempElement3
		ActionSelect_folderStart_CurrentInstanceID:=tempElement2
		
		;gui,%tempcSelect_folderidToStart%:default
		
		;gui,10:-SysMenu 
		
		tempActionSelectFolderOptions=0
		tempActionSelectFolderRoot:=v_replaceVariables(InstanceID,%ActionSelect_folderToStart_Element_ID%folder)
		if %ActionSelect_folderToStart_Element_ID%ButtonNewFolder
			tempActionSelectFolderOptions+=1
		if %ActionSelect_folderToStart_Element_ID%EditField
			tempActionSelectFolderOptions+=2
		
		if %ActionSelect_folderToStart_Element_ID%AllowUpward
			tempActionSelectFolderRoot:="*" tempActionSelectFolderRoot
		
		;MsgBox %tempActionSelectFileOptions%
		FileSelectFolder,tempActionSelectFolderFolder,% tempActionSelectFolderRoot ,%tempActionSelectFolderOptions%,% v_replaceVariables(InstanceID,%ActionSelect_folderToStart_Element_ID%title)
		;MsgBox %ActionSelect_folderToStart_Element_ID% %tempActionSelectFilefile% %errorlevel%
		
		if errorlevel
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_folderidToStart,"exception")
		else
		{
			v_setVariable(ActionSelect_folderStart_CurrentInstanceID,%ActionSelect_folderToStart_Element_ID%Varname,tempActionSelectFolderFolder)
			
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_folderidToStart,"normal")
		}
		Select_folderStarted:=true
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
	
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|selectedFolder|Varname","Label|" lang("Prompt"),"text|" lang("Select a folder")" |title","Label|" lang("Starting folder"),"folder||folder","Label|" lang("Options"), "checkbox|1|AllowUpward|" lang("Permit to navigate upward"),"checkbox|0|ButtonNewFolder|" lang("Show a button to create a new folder"),"checkbox|0|EditField|" lang("Show an edit field to type in the folder name")]
	
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