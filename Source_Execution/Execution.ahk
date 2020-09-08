#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _WorkingDir := _share._WorkingDir
global _ScriptDir := _share._ScriptDir
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
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_settings.UILanguage)

#include Lib\Object to file\String-object-file.ahk
#include Lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk
#include Lib\gdi+\gdip.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk

;~ #include Source_Draw\API\API receiver execution.ahk

;~ #include Source_Common\Flows\Manage Flows.ahk
;~ #include Source_Common\Elements\Manage Elements.ahk
#include Source_Common\Flows\Save.ahk
#include Source_Common\Flows\load.ahk
#include Source_Common\Flows\Compatibility.ahk
#include Source_Common\Flows\Manage Flows.ahk
;~ #include Source_Common\Flows\Flow actions.ahk
#include Source_Common\Flows\states.ahk
#include Source_Common\Elements\Manage Elements.ahk
#include source_Common\Elements\Elements.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include Source_Common\settings\Default values.ahk
#include source_Common\variables\Global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\Variables\code tokenizer.ahk
#include source_Common\Variables\code evaluator.ahk
#include source_Common\Variables\expression evaluator.ahk
#include source_Common\Other\Other.ahk

#include Source_Execution\execution task\execution task.ahk
#include Source_Execution\API\API for elements.ahk
#include Source_Execution\execution task\instances and threads.ahk
#include Source_Execution\Variables\Variables.ahk
#include Source_Execution\Trigger\Trigger.ahk

#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

;PlaceholderIncludesOfElements

parentAHKThread := AhkExported()

menu,tray, tip, Execution

SetTimer,executionTask,10

SetTimer,queryTasks,100
return

queryTasks()
{
	global
	Loop
	{
		oneTask := _getTask("execution")
		if (oneTask)
		{
			name:=oneTask.name
			
			if (name = "startFlow")
			{
				startFlow(oneTask.FlowID, oneTask.TriggerID, oneTask.params)
			}
			else if (name = "enableTriggers")
			{
				enableTriggers(oneTask.FlowID)
			}
			if (name = "StopFlow")
			{
				StopFlow(oneTask.FlowID)
			}
			if (name = "ExecuteToggleFlow")
			{
				ExecuteToggleFlow(oneTask.FlowID)
			}
			if (name = "DisableTriggers")
			{
				DisableTriggers(oneTask.FlowID)
			}
			if (name = "enableOneTrigger")
			{
				enableOneTrigger(oneTask.FlowID, oneTask.TriggerID)
			}
			if (name = "disableOneTrigger")
			{
				disableOneTrigger(oneTask.FlowID, oneTask.TriggerID)
			}
			if (name = "externalFlowFinish")
			{
				ExecuteInNewAHKThread_finishedExecution(oneTask.UniqueID)
			}
			if (name = "externalTrigger")
			{
				ExecuteInNewAHKThread_trigger(oneTask.UniqueID)
			}
			
			;~ if (isfunc(name))
			;~ {
				;~ if (oneTask.HasKey(par1))
				;~ {
					;~ if (oneTask.HasKey(par2))
					;~ {
						;~ %name%(par1)
						;~ if (oneTask.HasKey(par3))
						;~ {
							;~ if (oneTask.HasKey(par4))
							;~ {
								;~ %name%(par1, par2, par3, par4)
							;~ }
							;~ else
								;~ %name%(par1, par2, par3)
						;~ }
						;~ else
							;~ %name%(par1, par2)
					;~ }
					;~ else
						;~ %name%(par1)
				;~ }
				;~ else
					;~ %name%()
			;~ }
			
			if (name="abc")
			{
				MsgBox "abc"
			}
		}
		else
			break
	}
	
}




exit_all()
{
	global
	API_Main_Thread_Stopped(_ahkThreadID) 
}


exit:
if (exiting != true)
exit_all()
exiting := true
exitapp
return