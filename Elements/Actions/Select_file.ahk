iniAllActions.="Select_file|" ;Add this action to list of all actions on initialisation

runActionSelect_file(InstanceID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionSelect_fileToStart))
		ActionSelect_fileToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ElementID "_" ElementIDInInstance
	ActionSelect_fileToStart.insert(tempInstanceString)
	
	SetTimer,ActionSelect_file_StartNextQuestion,10,-10 ;lower priority
	
	
	return
	
	

	ActionSelect_file_StartNextQuestion:
	Select_fileStarted:=false
	for count, tempcSelect_fileidToStart in ActionSelect_fileToStart ;get the first element
	{
		StringSplit,tempElement,tempcSelect_fileidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = element id
		; tempElement4 = element id in the instance
		ActionSelect_fileToStart_Element_ID:=tempElement3
		ActionSelect_fileStart_CurrentInstanceID:=tempElement2
		
		;gui,%tempcSelect_fileidToStart%:default
		
		;gui,10:-SysMenu 
		
		tempActionSelectFileOptions=0
		if %ActionSelect_fileToStart_Element_ID%fileMustExist
			tempActionSelectFileOptions+=1
		if %ActionSelect_fileToStart_Element_ID%PathMustExist
			tempActionSelectFileOptions+=2
		if %ActionSelect_fileToStart_Element_ID%PromptNewFile
			tempActionSelectFileOptions+=8
		if %ActionSelect_fileToStart_Element_ID%PromptOverwriteFile
			tempActionSelectFileOptions+=16
		if %ActionSelect_fileToStart_Element_ID%SaveButton
			tempActionSelectFileOptions=S%tempActionSelectFileOptions%
		if %ActionSelect_fileToStart_Element_ID%MultiSelect
			tempActionSelectFileOptions=M%tempActionSelectFileOptions%
		;MsgBox %tempActionSelectFileOptions%
		FileSelectFile,tempActionSelectFilefile,%tempActionSelectFileOptions%,% v_replaceVariables(InstanceID,%ActionSelect_fileToStart_Element_ID%folder),% v_replaceVariables(InstanceID,%ActionSelect_fileToStart_Element_ID%title),% v_replaceVariables(InstanceID,%ActionSelect_fileToStart_Element_ID%filter)
		;MsgBox %ActionSelect_fileToStart_Element_ID% %tempActionSelectFilefile% %errorlevel%
		
		if errorlevel
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_fileidToStart,"exception")
		else
		{
			if %ActionSelect_fileToStart_Element_ID%MultiSelect
			{
				Loop,parse,tempActionSelectFilefile,`n
				{
					if a_index=1
						tempActionSelectFiledir:=A_LoopField
					else
						tempActionSelectFilefilelist.=tempActionSelectFiledir "\" A_LoopField "▬"
					
				}
				StringTrimRight,tempActionSelectFilefilelist,tempActionSelectFilefilelist,1
				;MsgBox %tempActionSelectFilefilelist%
				;MsgBox % v_importVariable(tempActionSelectFilefilelist,"list","▬")
				v_setVariable(ActionSelect_fileStart_CurrentInstanceID,%ActionSelect_fileToStart_Element_ID%Varname,v_importVariable(tempActionSelectFilefilelist,"list","▬"),"list")
			}
			else
				v_setVariable(ActionSelect_fileStart_CurrentInstanceID,%ActionSelect_fileToStart_Element_ID%Varname,tempActionSelectFilefile)
			
			
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_fileidToStart,"normal")
		}
		Select_fileStarted:=true
		break
		
	}
	
	if (Select_fileStarted)
		ActionSelect_fileToStart.remove(1) ;Remove the shown question
	else
		SetTimer,ActionSelect_file_StartNextQuestion,off
	
	return
	
	
}

stopActionSelect_file(ID)
{
	

}



getParametersActionSelect_file()
{
	
	parametersToEdit:=["Label|" lang("Variable_name"),"VariableName|selectedFiles|Varname","Label|" lang("Prompt"),"text|" lang("Select a file")" |title","Label|" lang("Starting folder or file"),"folder||folder","Label|" lang("Filter"),"Text|" lang("Any files") " (*.*)|filter","Label|" lang("Options"), "checkbox|0|MultiSelect|" lang("Allow to select multiple files"),"checkbox|0|SaveButton|" lang("'Save' button instead of an 'Open' button"),"checkbox|0|fileMustExist|" lang("File must exist"),"checkbox|0|PathMustExist|" lang("Path must exist"),"checkbox|0|PromptNewFile|" lang("Prompt to create new file"),"checkbox|0|PromptOverwriteFile|" lang("Prompt to overwrite file")]
	
	return parametersToEdit
}

getNameActionSelect_file()
{
	return lang("Select_file")
}
getCategoryActionSelect_file()
{
	return lang("User_interaction") "|" lang("files")
}

GenerateNameActionSelect_file(ID)
{
	return lang("Select_file") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%text
	
}

CheckSettingsActionSelect_file(ID)
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