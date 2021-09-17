#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; do not warn if a continuable exception occurs (it happens often when AHF is closing)
#WarnContinuableException off

; faster execution
SetBatchLines -1

; The manager should not have an own tray icon
#NoTrayIcon

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
#include lib\Objects\Objects.ahk
#include lib\Random Word List\Random Word List.ahk
#include lib\GDI+\GDIp.ahk
#include lib\Json\Jxon.ahk
#include lib\7z wrapper\7z wrapper.ahk

; include language module
#include language\language.ahk


; include all the other source code
#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
#include Source_Common\Flows\Flow actions.ahk
#include Source_Common\Flows\states.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk
#include Source_Manager\User Interface\manager gui.ahk
#include Source_Manager\User Interface\help.ahk
#include Source_Manager\User Interface\Change Category GUI.ahk
#include Source_Manager\User Interface\Global_Settings.ahk
#include Source_Manager\User Interface\import and export.ahk
#include Source_Manager\User Interface\about.ahk
#include Source_Manager\Api\API for Elements.ahk

#include source_Common\variables\global variables.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\settings\settings.ahk
#include source_Common\Other\Other.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include source_Common\Other\Design.ahk

#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

; Include the source code of the elements. The includes will be pasted here by the main thread.
;PlaceholderIncludesOfElements

; Create and show manager gui
init_Manager_GUI()
if (not _getShared("WindowsStartup"))
	Show_Manager_GUI()

; check regularly for new tasks which we get through shared variable
SetTimer,queryTasks,100
return

; Checks for new tasks which can be sent to this AHK thread by writing the task instructions in a shared variable
queryTasks()
{
	global
	Loop
	{
		oneTask := _getTask("manager")
		if (oneTask)
		{
			name := oneTask.name
			if (name = "TreeView_Refill")
			{
				; the treeview needs to be refilled
				TreeView_manager_Refill()
			}
			if (name = "ShowWindow")
			{
				; the manager gui needs to be shown
				Show_Manager_GUI()
			}
		}
		else
		{
			; There is no task in shared memory. We can now return and save the cpu time until next timer event
			break
		}
	}
}

; Start the exit routine
exit:
global _exiting := true
return

FinallyExit:
ExitApp