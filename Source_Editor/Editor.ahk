#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _WorkingDir := _getShared("_WorkingDir")
global _ScriptDir := _getShared("_ScriptDir")
SetWorkingDir %a_temp%  ; using working dir forbidden.

SetBatchLines -1
#SingleInstance off
CoordMode,mouse,client
;FileEncoding,UTF-8
;OnExit,Exi

;Following variables will be present (and some others)
;Global_ThisFlowID
;_ahkThreadID


#Include %A_ScriptDir%\..
#include language\language.ahk ;Must be very first
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_getSettings("UILanguage"))

#include lib\Object to file\String-object-file.ahk
#include lib\GDI+\GDIp.ahk
#include lib\objhasvalue\objhasvalue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk

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


;PlaceholderIncludesOfElements

parentAHKThread := AhkExported()



EditorGUIInit()
EditGUIshow()
initializeTrayBar()

SetTimer,queryTasks,100
return


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
				EditGUIshow()
			}
		}
		else
			break
	}
}




exit:
global _exiting := true
return