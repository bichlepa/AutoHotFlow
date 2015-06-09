#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1
DetectHiddenWindows on
#SingleInstance force


if not a_iscompiled
	developing=yes

allGlobalVariableNames=|

IDCount2=1

allItems:=object()
globalVariables:=Object()

if a_iscompiled=1
	editorPath=Editor.exe
else
	editorPath=Editor.ahk

#Include %a_scriptdir%
#Include manager\ini.ahk
#include language\language.ahk
#Include manager\functions of manager.ahk
#Include manager\settings of flows.ahk
#Include manager\tray.ahk
#Include manager\Main GUI.ahk
#Include manager\settings\s_language.ahk
#Include manager\settings\s_settings.ahk




;Create folder for global variables
FileCreateDir,Global variables


;Create a hidden window to recieve commands
gui,45:default
gui,new,,CommandWindowOfManager
gui,add,edit,vCommandWindowRecieve gCommandWindowRecieve

gosub,CreateMainGUI

loadSavedFlows()

SetTimer,regularStatusUpdateOfFlows,5000
return

;React on commands from other ahks
CommandWindowRecieve:
Critical
gui,submit
StringSplit,CommandWindowRecieve,CommandWindowRecieve,| ;Split the command

if CommandWindowRecieve1=Running ;Show that a flow is running
{
	tempid:=IDOfName(CommandWindowRecieve2,"Flow")
	%tempid%running=true
	updateIcon(tempid)
	
	if (IDOF(tempSelectedID)=IDOF(tempid))
	{
		guicontrol,,ButtonRunFlow,% lang("Stop")
	}
	
}
else if CommandWindowRecieve1=Stopping ;Show that a flow is stopping
{
	tempid:=IDOfName(CommandWindowRecieve2,"Flow")
	%tempid%running=true
	updateIcon(tempid)
	if (IDOF(tempSelectedID)=IDOF(tempid))
		guicontrol,,ButtonRunFlow,% lang("Stopping")
	
}
else if CommandWindowRecieve1=stopped ;Show that a flow is running
{
	tempid:=IDOfName(CommandWindowRecieve2,"Flow")
	%tempid%running=false
	updateIcon(tempid)
	if (IDOF(tempSelectedID)=IDOF(tempid))
		guicontrol,,ButtonRunFlow,% lang("Run")
	
}
else if CommandWindowRecieve1=Enabled ;Show that a flow is enabled
{
	tempid:=IDOfName(CommandWindowRecieve2,"Flow")
	%tempid%enabled=true
	updateIcon(tempid)
	SaveFlow(tempid)
	
	if %tempSelectedID%enabled=true
		guicontrol,,ButtonEnableFlow,% lang("Disable")
	else
		guicontrol,,ButtonEnableFlow,% lang("Enable")
	
}
else if CommandWindowRecieve1=Disabled ;Show that a flow is disabled
{
	tempid:=IDOfName(CommandWindowRecieve2,"Flow")
	%tempid%enabled=false
	updateIcon(tempid)
	SaveFlow(tempid)
	
	if %tempSelectedID%enabled=true
		guicontrol,,ButtonEnableFlow,% lang("Disable")
	else
		guicontrol,,ButtonEnableFlow,% lang("Enable")
	
}
else if CommandWindowRecieve1=SetGlobalVariable 
{
	setGlobalVariable(CommandWindowRecieve2,CommandWindowRecieve3)
	
}
else if CommandWindowRecieve1=DeleteGlobalVariable 
{
	deleteGlobalVariable(CommandWindowRecieve2)
	
}
else if CommandWindowRecieve1=GetGlobalVariable 
{
	
	tempgetValue:=getGlobalVariable(CommandWindowRecieve2)
;MsgBox globale Variable %CommandWindowRecieve2% = %tempgetValue%  angefragt
	ControlSetText,edit1,ReturnGlobalVariable|%tempgetValue%| ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3 "Ѻ" ;Send the command to the Editor.
	
}
else if CommandWindowRecieve1=ExecuteFlow ;Run a flow
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow to execute
	;CommandWindowRecieve3=Calling flow
	;CommandWindowRecieve4=Variable List
	;CommandWindowRecieve5=Instance ID of the calling flow to tell when its finished
	;CommandWindowRecieve6=Element ID in Instance
	;CommandWindowRecieve7=return results
	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerExecuteFlow|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%enabled=true
		{
			;Run the flow
			ControlSetText,edit1,Run|%CommandWindowRecieve4%|%CommandWindowRecieve3%|%CommandWindowRecieve5%|%CommandWindowRecieve6%|%CommandWindowRecieve7% ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve2
			
			ControlSetText,edit1,AnswerExecuteFlow|%CommandWindowRecieve2% ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		}
		else
			ControlSetText,edit1,AnswerExecuteFlow|Dἰsḁbled ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else if CommandWindowRecieve1=EnableFlow 
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow to enable
	;CommandWindowRecieve3=Calling flow

	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerEnableFlow|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%enabled!=true
			enableFlow(tempid)
		ControlSetText,edit1,AnswerEnableFlow|%CommandWindowRecieve2% ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else if CommandWindowRecieve1=DisableFlow 
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow to disable
	;CommandWindowRecieve3=Calling flow

	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerDisableFlow|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%enabled!=false
			disableFlow(tempid)
		ControlSetText,edit1,AnswerDisableFlow|%CommandWindowRecieve2% ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else if CommandWindowRecieve1=StopFlow 
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow to stop
	;CommandWindowRecieve3=Calling flow

	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerStopFlow|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%running!=false
			ControlSetText,edit1,stop,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve2 "Ѻ" 
		ControlSetText,edit1,AnswerStopFlow|%CommandWindowRecieve2% ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else if CommandWindowRecieve1=FlowIsEnabled? 
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow name
	;CommandWindowRecieve3=Calling flow

	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerFlowIsEnabled|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%enabled=true
			ControlSetText,edit1,AnswerFlowIsEnabled?|enabled ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		else
			ControlSetText,edit1,AnswerFlowIsEnabled?|disabled ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else if CommandWindowRecieve1=FlowIsRunning? 
{
	;ToolTip(CommandWindowRecieve1 " " CommandWindowRecieve2)
	;CommandWindowRecieve2=Flow name
	;CommandWindowRecieve3=Calling flow

	
	tempid:=IDOfName(CommandWindowRecieve2,"flow")
	
	if tempid=
		ControlSetText,edit1,AnswerFlowIsRunning?|ǸoⱾuchȠaⱮe ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
	else
	{
		if %tempid%running=true
			ControlSetText,edit1,AnswerFlowIsRunning?|running ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		else
			ControlSetText,edit1,AnswerFlowIsRunning?|stopped ,CommandWindowOfEditor,% "Ѻ" CommandWindowRecieve3
		
	}
	
}
else
	MsgBox,Error! AutoHotFlow Manager got an unknown Command: %CommandWindowRecieve%

Critical off
return


regularStatusUpdateOfFlows:

for tempRegCount, tempRegItem in allItems
{

	if (%tempRegItem%enabled="true" or  %tempRegItem%running="true")
	{
		
		ControlSetText,edit1,UpdateStatus ,CommandWindowOfEditor,% "Ѻ" %tempRegItem%name "Ѻ" ;Send the command to the Editor.
		if errorlevel
		{
			
			%tempRegItem%enabled=false
			%tempRegItem%running=false
			if (IDOF(tempSelectedID)=IDOF(tempRegItem))
			{
				guicontrol,,ButtonRunFlow,% lang("Run")
				guicontrol,,ButtonEnableFlow,% lang("Enable")
			}
			updateIcon(tempRegItem)
		}
	
	}
}
return


exit:

shuttingDown=true
;~ for count, tempItem in allItems
;~ {
	
	;~ ControlSetText,edit1,exit,CommandWindowOfEditor,% "Ѻ" nameOf(tempselected) "Ѻ" ;Send the command to the Editor.
	
;~ }
exitapp

/*
f10::
debug()
return
*/