#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..  ; Ensures a consistent starting directory.
;~ MsgBox %1% - %2% - %3% - %4% - %5%
OnExit,exit

Global_ThisThreadID:="Main"
#Include %A_ScriptDir%\..
#include language\language.ahk
#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk

#include Source_Main\Globals\Global Variables.ahk
#include Source_Main\Threads\Threads.ahk
#include Source_Main\Threads\API Caller to Manager.ahk
#include Source_Main\Threads\API Caller to Draw.ahk
#include Source_Main\Threads\API Caller to Editor.ahk
#include Source_Main\Threads\API Receiver Main.ahk

#include Source_Main\Flows\Save.ahk
#include Source_Main\Flows\load.ahk
#include Source_Main\Flows\Compatibility.ahk
#include Source_Main\Flows\Manage Flows.ahk
#include Source_Main\Flows\Manage Elements.ahk
#include Source_Main\Flows\Flow actions.ahk

#include source_Common\Elements API\API Caller Elements.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Defaults\Default values.ahk

AllElementClasses:=Object()
;Element_Includes_Start
#include C:\GitHub\AutoHotFlow\source_Elements\Default\Actions\New_Variable.ahk
#include C:\GitHub\AutoHotFlow\source_Elements\Default\Actions\Tooltip.ahk
#include C:\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Expression.ahk

;Element_Includes_End


init_GlobalVars()
lang_Init()

Thread_StartManager()
Thread_StartDraw()


return



ExitApp

;Beendet AutoHotFlow. Kann von allen Threads aufgerufen werden
exit()
{
	SetTimer,exitt,10
}

exitt:
ExitApp
return

exit:
global exitingNow
if (exitingNow!=true)
{
	exitingNow:=true
	Thread_StoppAll()
}
ExitApp
