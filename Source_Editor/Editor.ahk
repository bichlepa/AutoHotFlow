#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; faster execution
SetBatchLines -1

; Get working dir for AutoHotFlow from shared variable.
; It is the directory where the flows and global variables are saved
; (not to be confused with the working dir in the settings of AutoHotFlow)
global _WorkingDir := _getShared("_WorkingDir")
; Get script dir for AutoHotFlow from shared variable.
global _ScriptDir := _getShared("_ScriptDir")
; using working dir forbidden, because in other parts of the code we use the commands FileSelectFolder and FileSelectFile
; While any thread uses those commands, the working directory of the whole process is changed to the path which is shown in the dialog.
SetWorkingDir %a_temp%

; Set the default coord mode for mouse interactions
CoordMode,mouse,client

; Make the variable _ahkThreadID super global. This variable will be set by the main thread after this thread is created.
global _ahkThreadID

; On call of ExitApp, we will start the exit routine
OnExit,Exit
global _exiting := false

;initialize logger
init_logger()

; Include libraries
#Include %A_ScriptDir%\..
#include lib\Object to file\String-object-file.ahk
#include lib\GDI+\GDIp.ahk
#include lib\objhasvalue\objhasvalue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk

; include language module
#include language\language.ahk ;Must be very first
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_getSettings("UILanguage"))

; include all the other source code
#include Source_Editor\User Interface\Editor GUI.ahk
#include Source_Editor\User Interface\Editor GUI user input.ahk
#include Source_Editor\User Interface\Editor GUI menu bar.ahk
#include Source_Editor\User Interface\Element settings.ahk
#include Source_Editor\User Interface\Element settings other.ahk
#include Source_Editor\User Interface\Flow settings.ahk
#include Source_Editor\User Interface\GDI+.ahk
#include Source_Editor\User Interface\Tooltip.ahk
#include Source_Editor\User Interface\Help.ahk
#include Source_Editor\User Interface\Tray.ahk
#include Source_Editor\Elements\Mark elements.ahk
#include Source_Editor\Elements\Clipboard.ahk
#include Source_Editor\Assistants\Get window information.ahk
#include Source_Editor\Assistants\Mouse Tracker.ahk
#include Source_Editor\Assistants\Choose color.ahk
#include Source_Editor\Api\API for Elements.ahk

#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
#include Source_Common\Flows\Flow actions.ahk
#include Source_Common\Flows\states.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\settings\Default values.ahk
#include source_Common\settings\settings.ahk
#include source_Common\Variables\global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include source_Common\Other\Other.ahk

#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

; Include the source code of the elements. The includes will be pasted here by the main thread.
;PlaceholderIncludesOfElements

; initialize and show the editor gui
EditorGUIInit()
EditGUIshow()
initializeTrayBar()

; check regularly for new tasks which we get through shared variable
SetTimer,queryTasks,100
return

; Checks for new tasks which can be sent to this AHK thread by writing the task instructions in a shared variable
queryTasks()
{
	global
	Loop
	{
		oneTask:=_getTask("editor" FlowID)
		if (oneTask)
		{
			name:=oneTask.name
			if (name="EditGUIshow")
			{
				; the editor gui should be shown
				EditGUIshow()
			}
			if (name="exit")
			{
				ToolTip, % "exit " flowID
				; the editor gui should be closed. We close the thread
				ExitApp
			}
		}
		else
		{
			; There is no task in shared memory. We can now return and save the cpu time until next timer event
			break
		}
	}
}

; Functions which are defined in api Caller to Editor.
API_Editor_EditGUIshow(FlowID) ;Api function which is used in common code
{
	EditGUIshow()
}
API_Editor_Exit(par_flowID)
{
	ExitApp
}


; Start the exit routine
exit:
global _exiting := true
return

FinallyExit:
ExitApp