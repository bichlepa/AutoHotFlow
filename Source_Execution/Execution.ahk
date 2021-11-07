#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; do not warn if a continuable exception occurs (it happens often when AHF is closing)
#WarnContinuableException off

; faster execution
SetBatchLines -1

; The execution thread should not have an own tray icon
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

; some triggeers need keyboard and mouse hooks.
; Install them at the beginning for consistent behaviour
; it also affects the A_TimeIdlePhysical variable
#InstallMouseHook
#InstallKeybdHook

; set default file encoding
FileEncoding utf-8

; Include libraries
#Include %A_ScriptDir%\..
#include Lib\Objects\Objects.ahk
#include lib\Random Word List\Random Word List.ahk
#include Lib\gdi+\gdip.ahk
#include lib\Json\Jxon.ahk
#include lib\7z wrapper\7z wrapper.ahk

; include language module
#include language\language.ahk ;Must be very first



; include all the other source code
#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
#include Source_Common\Flows\states.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\variables\Global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\Variables\code tokenizer.ahk
#include source_Common\Variables\code evaluator.ahk
#include source_Common\Variables\expression evaluator.ahk
#include source_Common\Other\Other.ahk
#include source_Common\Other\Design.ahk

#include Source_Execution\execution task\execution task.ahk
#include Source_Execution\API\API for elements.ahk
#include Source_Execution\execution task\instances and threads.ahk
#include Source_Execution\Variables\Variables.ahk
#include Source_Execution\Trigger\Trigger.ahk

#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

; Include the source code of the elements. The includes will be pasted here by the main thread.
;PlaceholderIncludesOfElements

; the api function x_isAHFStartup checks this variable to find out whether a trigger is triggered during startup
global global_EnablingDuringStartup := false

; check regularly for new tasks which we get through shared variable
SetTimer, queryTasks, 10

; start executing elements
executionTask()
return

; Checks for new tasks which can be sent to this AHK thread by writing the task instructions in a shared variable
queryTasks()
{
	global
	Loop
	{
		oneTask := _getTask("execution")
		if (oneTask)
		{
			name:=oneTask.name
			
			if (name = "ExecuteFlow")
			{
				; a flow should be started
				ExecuteFlow(oneTask.FlowID, oneTask.TriggerID, oneTask.instanceVars, oneTask.instanceProperties)
			}
			else if (name = "enableTriggers")
			{
				; all triggers of a flow should be enabled
				enableTriggers(oneTask.FlowID)
			}
			if (name = "StopFlow")
			{
				; a flow should be stopped
				StopFlow(oneTask.FlowID)
			}
			if (name = "ExecuteToggleFlow")
			{
				; a flow should be started or stopped
				ExecuteToggleFlow(oneTask.FlowID)
			}
			if (name = "DisableTriggers")
			{
				; all triggers of a flow should be disabled
				DisableTriggers(oneTask.FlowID)
			}
			if (name = "enableOneTrigger")
			{
				; a single trigger of a flow should be enabled
				global_EnablingDuringStartup := oneTask.startup
				enableOneTrigger(oneTask.FlowID, oneTask.TriggerID, oneTask.save)
				global_EnablingDuringStartup := false
			}
			if (name = "disableOneTrigger")
			{
				; a single trigger of a flow should be disabled
				disableOneTrigger(oneTask.FlowID, oneTask.TriggerID, oneTask.save)
			}
			if (name = "externalElementFinish")
			{
				; an element which was executed in a separate ahk thread has finished
				ExecuteInNewAHKThread_finishedExecution(oneTask.UniqueID)
			}
			if (name = "externalTrigger")
			{
				; an external trigger which is executing in a separate ahk thread has triggered
				ExecuteInNewAHKThread_trigger(oneTask.UniqueID, oneTask.iteration)
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