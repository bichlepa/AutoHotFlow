iniAllActions.="Run|" ;Add this action to list of all actions on initialisation

runActionRun(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempPath
	local tempPathRelative
	local ActionRuntempPid
	
	
	if ( %ElementID%ReplaceVariables)
	{
		tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%ToRun)
		
		
		
	}		
	else
	{
		tempPath:=% %ElementID%ToRun
		
	}
	
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
	{
		tempPathRelative:=tempPath
		tempPath:=SettingWorkingDir "\" tempPath
		
	}
	
	
	run, % tempPath,% SettingWorkingDir, UseErrorLevel,ActionRuntempPid ;Try to run it in the working direction
	if (ErrorLevel)
	{
		
		run, % tempPathRelative,% SettingWorkingDir, UseErrorLevel,ActionRuntempPid ;Try tu run it without the working direction (relative path)
		if (ErrorLevel)
		{
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
		}
		else
		{
			v_setVariable(InstanceID,ThreadID,"a_pid",ActionRuntempPid,,true)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
	}
	else
	{
		
		v_setVariable(InstanceID,ThreadID,"a_pid",ActionRuntempPid,,true)
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	}
	
	
	
	return
}
getNameActionRun()
{
	return lang("Run")
}
getCategoryActionRun()
{
	return lang("Process")
}

getParametersActionRun()
{
	global
	
	parametersToEdit:=["Label|" lang("Target"),"Text||ToRun","Label| " lang("Value"),"Checkbox|0|ReplaceVariables|" lang("Replace variables")]
	return parametersToEdit
}

GenerateNameActionRun(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	return lang("Run") ": "  GUISettingsOfElement%ID%ToRun
	
}