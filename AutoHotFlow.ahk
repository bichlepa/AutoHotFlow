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

;Create folder for global variables
FileCreateDir,Global variables
FileCreateDir,Saved Flows\Static variables


;Create a hidden window to recieve commands
com_CreateHiddenReceiverWindow()


#Include %a_scriptdir%
#Include manager\ini.ahk
#include language\language.ahk
#Include manager\functions of manager.ahk
#Include manager\settings of flows.ahk
#Include manager\tray.ahk
#Include manager\about.ahk
#Include manager\Main GUI.ahk
#Include manager\settings\s_language.ahk
#Include manager\settings\s_settings.ahk
#Include manager\communication\receive.ahk
#Include manager\communication\send.ahk
#Include manager\debug\d_logger.ahk
#include External Scripts\Object to file\String-object-file.ahk
;~ #include External Scripts\MailSlots\Server.ahk
;~ #include External Scripts\MailSlots\Client.ahk





gosub,CreateMainGUI

loadSavedFlows()
if 1!=AutomaticStartup
	gosub,ShowMainGUI





SetTimer,regularStatusUpdateOfFlows,5000
return




regularStatusUpdateOfFlows:

for tempRegCount, tempRegItem in allItems
{

	if (%tempRegItem%enabled="true" or  %tempRegItem%running="true")
	{
		com_SendCommand({function: "UpdateStatus"},%tempRegItem%name) ;Send the command to the Editor.
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
for count, tempItem in allItems
{
	com_SendCommand({function: "exit"},nameOf(tempItem)) ;Send the command to the Editor.
	
}
exitapp

BaseFrame_About:
return

/*
f10::
debug()
return
*/