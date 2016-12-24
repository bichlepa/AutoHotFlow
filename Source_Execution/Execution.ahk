#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
my_WorkingDir = %A_WorkingDir%
SetWorkingDir %a_temp%  ; using working dir forbidden.

#Persistent
SetBatchLines -1
#SingleInstance off

#NoTrayIcon

OnExit,Exit
#Include %A_ScriptDir%\..
#include language\language.ahk ;Must be very first
;initialize languages
lang_Init(my_WorkingDir "\language", my_WorkingDir)

#include Lib\Object to file\String-object-file.ahk
#include Lib\ObjFullyClone\ObjFullyClone.ahk

;~ #include Source_Draw\API\API receiver execution.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include Source_Common\Defaults\Default values.ahk
#include source_Common\Multithreading\API Caller Main.ahk

#include Source_Execution\execution task\execution task.ahk
#include Source_Execution\API\functions for elements.ahk
#include Source_Execution\execution task\instances and threads.ahk
#include Source_Execution\API\API receiver Execution.ahk
#include Source_Execution\Variables\Variables.ahk
#include Source_Execution\Variables\Expression.ahk
#include Source_Execution\Trigger\Trigger.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()

;PlaceholderIncludesOfElements

parentAHKThread := AhkExported()

menu,tray, tip, Execution

SetTimer,executionTask,10

hotkey, ^NumpadMult, d_showAnyVariable
return




exit_all()
{
	global
	API_Main_Thread_Stopped(Global_ThisThreadID "") 
}


exit:
if (exiting != true)
exit_all()
exiting := true
exitapp
return