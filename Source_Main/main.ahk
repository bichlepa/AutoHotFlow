#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

global _ScriptDir, _WorkingDir
global _ahkThreadID:="Main"

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _ScriptDir := A_WorkingDir

;if portable installation, the script dir is the working dir. 
;If installed in programs folder, it is a dir which is writable without admin rights
global _WorkingDir := A_WorkingDir
IfInString, _WorkingDir, %A_ProgramFiles%
{
	_WorkingDir = %A_AppData%\AutoHotFlow
	if not fileexist(_WorkingDir)
		FileCreateDir, %_WorkingDir%
}

;First of all initialize global variables and load the settings
gosub, init_GlobalVars
load_settings()
logger("a1", "startup")

; using working dir forbidden.
;The reason is that while any thread uses the command FileSelectFile, the working directory of the working directory of the whole process is changed to the path which is shown in the dialog.
SetWorkingDir %a_temp%  
;~ MsgBox %_WorkingDir%

;~ MsgBox %1% - %2% - %3% - %4% - %5%
OnExit,exit

#Include %A_ScriptDir%\..

#include language\language.ahk
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_settings.UILanguage)

initLog()

;if setting run as admin active
if (_settings.runAsAdmin and not A_IsAdmin)
{
	FileRead,triedtostart,%a_temp%\autoHotflowTryToStartAsAdmin.txt
	IfInString, triedtostart, 111
	{
		MsgBox, 52, , % lang("Several tries to start as administrator failed. Do you want to disable it?")
		IfMsgBox yes
		{
			_settings.runAsAdmin:=false
			write_settings()
			skipstartAsAdmin :=true
		}
	}
	if not skipstartAsAdmin
	{
		FileAppend,1,%a_temp%\autoHotflowTryToStartAsAdmin.txt
		try Run *RunAs "%A_ScriptFullPath%" 
		ExitApp
	}
	
	;~ RunAsAdmin()
}
FileDelete,%a_temp%\autoHotflowTryToStartAsAdmin.txt


#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk

;Include libraries which may be used by the elements. This code is generated.
;Lib_includes_Start
#include lib\7z wrapper\7z wrapper.ahk
global_elementInclusions = 
(
#include lib\7z wrapper\7z wrapper.ahk

)

;Lib_Includes_End

;Include sourcecode
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
#include Source_Main\settings\settings.ahk

#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Settings\Default values.ahk
#include source_Common\Settings\Settings.ahk
#include source_Common\variables\global variables.ahk
#include source_Common\variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include source_Common\flows\flows.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()

;Includ elements. This code is generated
;The elements must be included before the other treads are started
;Element_Includes_Start
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\activate_Window.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Beep.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Compress files.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Execute_Flow.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Extract files.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\New_List.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\New_Variable.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Script.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Select_file.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Set_Flow_Status.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Sleep.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Stop_Flow.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Tooltip.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Trace_Point.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Actions\Trace_Point_Check.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Conditions\Debug_dialog.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Conditions\Expression.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Conditions\Flow_Enabled.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Conditions\Flow_Running.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Loops\SimpleLoop.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Loops\Work_through_a_list.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Triggers\Hotkey.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Triggers\Manual.ahk
#include C:\Users\Paul\Documents\GitHub\AutoHotFlow v1\source_Elements\Default\Triggers\Window_opens.ahk

;Element_Includes_End




;Start other threads
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
global _exitingNow

if (_exitingNow!=true)
{
	_exitingNow:=true
	
	i_SaveUnsavedFlows()
	
	Thread_StoppAll()
}
ExitApp
