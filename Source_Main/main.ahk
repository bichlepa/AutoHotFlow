#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..  ; Ensures a consistent starting directory.
;~ MsgBox %1% - %2% - %3% - %4% - %5%
OnExit,exit

Global_ThisThreadID:="Main"



#Include %A_ScriptDir%\..
#include language\language.ahk
lang_Init()

#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk

#include Source_Main\Globals\Global Variables.ahk
#include Source_Main\Threads\Threads.ahk
#include Source_Main\Threads\API Caller to Manager.ahk
#include Source_Main\Threads\API Caller to Draw.ahk
#include Source_Main\Threads\API Caller to Editor.ahk
#include Source_Main\Threads\API Caller to Execution.ahk
#include Source_Main\Threads\API Receiver Main.ahk

#include Source_Main\Flows\Save.ahk
#include Source_Main\Flows\load.ahk
#include Source_Main\Flows\Compatibility.ahk
#include Source_Main\Flows\Manage Flows.ahk
#include Source_Main\Flows\Manage Elements.ahk
#include Source_Main\Flows\Flow actions.ahk
#include Source_Main\Flows\states.ahk

#include source_Common\Elements API\API Caller Elements.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Defaults\Default values.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()


;Element_Includes_Start
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Execute_Flow.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\New_Variable.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Set_Flow_Status.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Sleep.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Tooltip.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Debug_dialog.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Expression.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Flow_Enabled.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Flow_Running.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Triggers\Hotkey.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Triggers\Manual.ahk

;Element_Includes_End



init_GlobalVars()

Thread_StartManager()
Thread_StartDraw()
Thread_StartExecution()

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
