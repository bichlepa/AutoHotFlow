#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
my_ScriptDir = %A_WorkingDir%

;if portable installation, the script dir is the working dir. 
;If installed in programs folder, it is a dir which is writable without admin rights
my_WorkingDir = %A_WorkingDir%
IfInString, my_WorkingDir, %A_ProgramFiles%
{
	my_WorkingDir = %A_AppData%\AutoHotFlow
	if not fileexist(my_WorkingDir)
		FileCreateDir, %my_WorkingDir%
}

; using working dir forbidden.
;The reason is that while any thread uses the command FileSelectFile, the working directory of the working directory of the whole process is changed to the path which is shown in the dialog.
SetWorkingDir %a_temp%  
;~ MsgBox %my_WorkingDir%

;~ MsgBox %1% - %2% - %3% - %4% - %5%
OnExit,exit

Global_ThisThreadID:="Main"
#Include %A_ScriptDir%\..

#include language\language.ahk
lang_Init(my_ScriptDir "\language", my_WorkingDir)

#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk

;Lib_includes_Start#include lib\7z wrapper\7z wrapper.ahk
global_elementInclusions = 
(
#include lib\7z wrapper\7z wrapper.ahk

)

;Lib_Includes_End

#include Source_Main\Tray\Tray.ahk
#include Source_Main\Globals\Global Variables.ahk
#include Source_Main\Threads\Threads.ahk
#include Source_Main\Threads\API Caller to Manager.ahk
#include Source_Main\Threads\API Caller to Draw.ahk
#include Source_Main\Threads\API Caller to Editor.ahk
#include Source_Main\Threads\API Caller to Execution.ahk
#include Source_Main\Threads\API Caller Elements.ahk
#include Source_Main\Threads\API Receiver Main.ahk

#include Source_Main\Flows\Save.ahk
#include Source_Main\Flows\load.ahk
#include Source_Main\Flows\Compatibility.ahk
#include Source_Main\Flows\Manage Flows.ahk
#include Source_Main\Flows\Manage Elements.ahk
#include Source_Main\Flows\Flow actions.ahk
#include Source_Main\Flows\states.ahk

#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Defaults\Default values.ahk
#include source_Common\variables\global variables.ahk
#include source_Common\variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()


;Element_Includes_Start
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Beep.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Compress files.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Execute_Flow.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Extract files.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\New_List.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\New_Variable.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Script.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Select_file.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Set_Flow_Status.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Sleep.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Stop_Flow.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Tooltip.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Trace_Point.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Actions\Trace_Point_Check.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Debug_dialog.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Expression.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Flow_Enabled.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Conditions\Flow_Running.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Loops\SimpleLoop.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Loops\Work_through_a_list.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Triggers\Hotkey.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow\source_Elements\Default\Triggers\Manual.ahk

;Element_Includes_End



init_GlobalVars()


Thread_StartManager()
Thread_StartDraw()
Thread_StartExecution()

;Find flows and activate some triggers
FindFlows()
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
	
	i_SaveUnsavedFlows()
	
	Thread_StoppAll()
}
ExitApp
