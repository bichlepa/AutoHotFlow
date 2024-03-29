﻿#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; do not warn if a continuable exception occurs (it happens often when AHF is closing)
#WarnContinuableException off

; faster execution
SetBatchLines -1

; Set the default coord mode for mouse interactions
CoordMode,mouse,client

; Make the variable _ahkThreadID super global. This variable will be set by the main thread after this thread is created.
global _ahkThreadID

; On call of ExitApp, we will start the exit routine
OnExit,Exit
global _exiting := false

; Get working dir for AutoHotFlow from shared variable.
; It is the directory where the flows and global variables are saved
; (not to be confused with the working dir in the settings of AutoHotFlow)
global _WorkingDir := _getShared("_WorkingDir")
; Get script dir for AutoHotFlow from shared variable.
global _ScriptDir := _getShared("_ScriptDir")
; using working dir forbidden, because in other parts of the code we use the commands FileSelectFolder and FileSelectFile
; While any thread uses those commands, the working directory of the whole process is changed to the path which is shown in the dialog.
; SetWorkingDir %a_temp% working dir is only set in main thread. Otherwise it causes errors if another thread is currently including files

; set default file encoding
FileEncoding utf-8

; speed up gui and changes dramatically
SetWinDelay, 0

;initialize logger
init_logger()

; Include libraries
#Include %A_ScriptDir%\..
#include lib\GDI+\GDIp.ahk
#include lib\Objects\Objects.ahk
#include lib\Random Word List\Random Word List.ahk
#include lib\Json\Jxon.ahk
#include lib\7z wrapper\7z wrapper.ahk

; include language module
#include language\language.ahk ;Must be very first


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
#include Source_Editor\Elements\Select elements.ahk
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
#include source_Common\settings\settings.ahk
#include source_Common\Variables\global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include source_Common\Other\Other.ahk
#include source_Common\Other\Design.ahk

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
		; check whether flow is active or running
		if xx_isFlowExecuting(_FlowID)
		{
			; change icon to "running"
			EditGuiSetIcon("running")
			tray_setIcon("running")
		}
		Else
		{
			if xx_isFlowEnabled(_FlowID)
			{
				EditGuiSetIcon("enabled")
				tray_setIcon("enabled")
			}
			Else
			{
				EditGuiSetIcon("disabled")
				tray_setIcon("disabled")
			}
		}
		
		; check whether there is a new task from another ahk thread
		oneTask:=_getTask("editor" _FlowID)
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
				ToolTip, % "exit " _FlowID
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
API_Editor_EditGUIshow(p_FlowID) ;Api function which is used in common code
{
	EditGUIshow()
}
API_Editor_Exit(p_FlowID)
{
	ExitApp
}


; Start the exit routine
exit:
logger("t1", "editor thread for " _flowID " is going to exit")
global _exiting := true
return

FinallyExit:
ExitApp