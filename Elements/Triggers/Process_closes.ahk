iniAllTriggers.="Process_closes|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerProcess_closes(ID)
{
	global
	
	tempProcessName:=v_replaceVariables(0,%ID%ProcessName)
	
	
	FileDelete,Generated Scripts\TriggerProcess_closes%ID%.ahk
	FileAppend,
	(
	#SingleInstance force
	DetectHiddenWindows, On
	
	;open a window so the main program can stop it
	gui,45:default
	gui,new,,CommandWindowFor%ID%
	gui,add,edit,vcommandFortrigger gCommandForTrigger
	
	loop
	{
		process,wait,%tempProcessName%
		
		
		process,waitclose,%tempProcessName%
		ControlSetText,Edit1,Run,CommandWindowOfEditor,Ѻ%flowname%Ѻ
	}
	
	CommandForTrigger:
	gui,submit
	if CommandForTrigger=exit
	{
		exitapp
	}
	),Generated Scripts\TriggerProcess_closes%ID%.ahk
	run,Generated Scripts\AutoHotkey.exe "Generated Scripts\TriggerProcess_closes%ID%.ahk"
	
}
getParametersTriggerProcess_closes()
{
	
	parametersToEdit:=["Label|" lang("Process name"),"text||ProcessName"]
	
	
	return parametersToEdit
}

getNameTriggerProcess_closes()
{
	return lang("Process_closes")
}
getCategoryTriggerProcess_closes()
{
	return lang("Process")
}



DisableTriggerProcess_closes(ID)
{
	DetectHiddenWindows, On
	ControlSetText,Edit1,exit,CommandWindowFor%ID%
	
}

GenerateNameTriggerProcess_closes(ID)
{
	
	
	return lang("Process_closes") " " GUISettingsOfElement%ID%ProcessName
	
}

