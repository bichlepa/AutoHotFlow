iniAllTriggers.="Process_starts|" ;Add this trigger to list of all triggers on initialisation

EnableTriggerProcess_starts(ID)
{
	global
	
	tempProcessName:=v_replaceVariables(0,0,%ID%ProcessName)
	
	
	FileDelete,Generated Scripts\TriggerProcess_starts%ID%.ahk
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
		
		
		ControlSetText,Edit1,Run|a_pid=`%errorlevel`%,CommandWindowOfEditor,Ѻ%flowname%Ѻ
		process,waitclose,%tempProcessName%
	}
	
	CommandForTrigger:
	gui,submit
	if CommandForTrigger=exit
	{
		exitapp
	}
	),Generated Scripts\TriggerProcess_starts%ID%.ahk
	run,Generated Scripts\AutoHotkey.exe "Generated Scripts\TriggerProcess_starts%ID%.ahk"
	
}
getParametersTriggerProcess_starts()
{
	
	parametersToEdit:=["Label|" lang("Process name"),"text||ProcessName"]
	
	
	return parametersToEdit
}

getNameTriggerProcess_starts()
{
	return lang("Process_starts")
}
getCategoryTriggerProcess_starts()
{
	return lang("Process")
}



DisableTriggerProcess_starts(ID)
{
	DetectHiddenWindows, On
	ControlSetText,Edit1,exit,CommandWindowFor%ID%
	
}

GenerateNameTriggerProcess_starts(ID)
{
	return lang("Process_starts") " " GUISettingsOfElement%ID%ProcessName
	
}

