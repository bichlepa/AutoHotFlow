#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
my_WorkingDir := _share.my_WorkingDir
my_ScriptDir := _share.my_ScriptDir
SetWorkingDir %a_temp%  ; using working dir forbidden.

#Persistent
SetBatchLines -1
#SingleInstance off

#NoTrayIcon

OnExit,Exit
#Include %A_ScriptDir%\..
#include language\language.ahk ;Must be very first
;initialize languages
_language:=Object()
_language.dir:=my_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_settings.UILanguage)

#include Lib\Object to file\String-object-file.ahk
#include Lib\ObjFullyClone\ObjFullyClone.ahk

;~ #include Source_Draw\API\API receiver execution.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include Source_Common\settings\Default values.ahk
#include source_Common\variables\Global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\Variables\code tokenizer.ahk
#include source_Common\Variables\code evaluator.ahk
#include source_Common\Variables\expression evaluator.ahk
#include source_Common\Multithreading\API Caller Main.ahk
#include source_Common\flows\flows.ahk
#include lib\Random Word List\Random Word List.ahk

#include Source_Execution\execution task\execution task.ahk
#include Source_Execution\API\functions for elements.ahk
#include Source_Execution\execution task\instances and threads.ahk
#include Source_Execution\API\API receiver Execution.ahk
#include Source_Execution\Variables\Variables.ahk
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