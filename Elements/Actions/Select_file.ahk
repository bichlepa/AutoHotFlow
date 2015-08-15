iniAllActions.="Select_file|" ;Add this action to list of all actions on initialisation
ActionSelect_fileToStart:=Object()
runActionSelect_file(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
		
	tempInstanceString:="Instance_" InstanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance
	ActionSelect_fileToStart.insert(tempInstanceString)
	
	SetTimer,ActionSelect_file_StartNextQuestion,10,-10 ;lower priority
	
	
	return
	
	

	ActionSelect_file_StartNextQuestion:
	Select_fileStarted:=false
	for count, tempcSelect_fileidToStart in ActionSelect_fileToStart ;get the first element
	{
		Select_fileStarted:=true
		
		StringSplit,tempElement,tempcSelect_fileidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = thread id
		; tempElement4 = element id
		; tempElement5 = element id in the instance
		ActionSelect_fileToStart_Element_ID:=tempElement4
		ActionSelect_fileToStart_Element_IDInInstance:=tempElement5
		ActionSelect_fileStart_CurrentInstanceID:=tempElement2
		ActionSelect_fileStart_CurrentThreadID:=tempElement3
		
		;gui,%tempcSelect_fileidToStart%:default
		
		;gui,10:-SysMenu 
		
		ActionSelect_fileStart_CurrentVarname:=v_replaceVariables(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,%ActionSelect_fileToStart_Element_ID%Varname)
		if not v_CheckVariableName(ActionSelect_fileStart_CurrentVarname)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" ActionSelect_fileStart_CurrentVarname "' is not valid")
			MarkThatElementHasFinishedRunning(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,ActionSelect_fileToStart_Element_ID,ActionSelect_fileToStart_Element_IDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",ActionSelect_fileStart_CurrentVarname)) )
			continue
		}
		
		tempActionSelectFileOptions=0
		if %ActionSelect_fileToStart_Element_ID%fileMustExist
			tempActionSelectFileOptions+=1
		if %ActionSelect_fileToStart_Element_ID%PathMustExist
			tempActionSelectFileOptions+=2
		if %ActionSelect_fileToStart_Element_ID%PromptNewFile
			tempActionSelectFileOptions+=8
		if %ActionSelect_fileToStart_Element_ID%PromptOverwriteFile
			tempActionSelectFileOptions+=16
		if %ActionSelect_fileToStart_Element_ID%NoShortcutTarget
			tempActionSelectFileOptions+=32
		if %ActionSelect_fileToStart_Element_ID%SaveButton
			tempActionSelectFileOptions=S%tempActionSelectFileOptions%
		if %ActionSelect_fileToStart_Element_ID%MultiSelect
			tempActionSelectFileOptions=M%tempActionSelectFileOptions%
		
		
		tempActionSelectFilePath:=v_replaceVariables(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,%ActionSelect_fileToStart_Element_ID%folder)
		if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempActionSelectFilePath)
			tempActionSelectFilePath:=SettingWorkingDir "\" tempActionSelectFilePath
		;MsgBox %tempActionSelectFileOptions%
		
		FileSelectFile,tempActionSelectFilefile,%tempActionSelectFileOptions%,%tempActionSelectFilePath%,% v_replaceVariables(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,%ActionSelect_fileToStart_Element_ID%title),% v_replaceVariables(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,%ActionSelect_fileToStart_Element_ID%filter)
		;MsgBox %ActionSelect_fileToStart_Element_ID% %tempActionSelectFilefile% %errorlevel%
		
		if errorlevel
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! User dismissed the dialog without selecting a file or system refused to show the dialog.")
			MarkThatElementHasFinishedRunning(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,ActionSelect_fileToStart_Element_ID,ActionSelect_fileToStart_Element_IDInInstance,"exception",lang("User dismissed the dialog without selecting a file or system refused to show the dialog."))
			continue
		}
		else
		{
			if %ActionSelect_fileToStart_Element_ID%MultiSelect ;If multiselect, make a list
			{
				tempActionSelectFilefilelist=
				Loop,parse,tempActionSelectFilefile,`n
				{
					if a_index=1
						tempActionSelectFiledir:=A_LoopField
					else
						tempActionSelectFilefilelist.=tempActionSelectFiledir "\" A_LoopField "▬"
					
				}
				StringTrimRight,tempActionSelectFilefilelist,tempActionSelectFilefilelist,1
				;~ MsgBox %tempActionSelectFilefilelist%
				;MsgBox % v_importVariable(tempActionSelectFilefilelist,"list","▬")
				v_setVariable(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,ActionSelect_fileStart_CurrentVarname,v_importVariable(tempActionSelectFilefilelist,"list","▬"),"list")
			}
			else
				v_setVariable(ActionSelect_fileStart_CurrentInstanceID,ActionSelect_fileStart_CurrentThreadID,ActionSelect_fileStart_CurrentVarname,tempActionSelectFilefile)
			
			
			MarkThatElementHasFinishedRunningOneVar(tempcSelect_fileidToStart,"normal")
		}
		
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
	ActionSelect_fileToStart:=Object()

}



getParametersActionSelect_file()
{
	
	parametersToEdit:=["Label|" lang("Output variable_name"),"VariableName|selectedFiles|Varname","Label|" lang("Prompt"),"text|" lang("Select a file")" |title","Label|" lang("Root directory"),"folder||folder","Label|" lang("Filter"),"Text|" lang("Any files") " (*.*)|filter","Label|" lang("Options"), "checkbox|0|MultiSelect|" lang("Allow to select multiple files"),"checkbox|0|SaveButton|" lang("'Save' button instead of an 'Open' button"),"checkbox|0|fileMustExist|" lang("File must exist"),"checkbox|0|PathMustExist|" lang("Path must exist"),"checkbox|0|PromptNewFile|" lang("Prompt to create new file"),"checkbox|0|PromptOverwriteFile|" lang("Prompt to overwrite file"),"checkbox|0|NoShortcutTarget|" lang("Don't resolve shortcuts to their targets")]
	
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