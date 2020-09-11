#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _WorkingDir := _getShared("_WorkingDir")
global _ScriptDir := _getShared("_ScriptDir")
SetWorkingDir %a_temp%  ; using working dir forbidden.

;~ MsgBox %_WorkingDir%
#NoTrayIcon

parentAHKThread := AhkExported()
global _ahkThreadID

OnExit,Exit
_exiting := false

#Include %A_ScriptDir%\..
#include lib\Object to file\String-object-file.ahk
#include lib\Robert - Ini library\Robert - Ini library.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\ObjHasValue\ObjHasValue.ahk
#include lib\Random Word List\Random Word List.ahk
#include lib\GDI+\GDIp.ahk

#include language\language.ahk
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()

lang_setLanguage(_getSettings("UILanguage"))

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

#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\API Caller to Draw.ahk
#include Source_Common\Multithreading\API Caller to Editor.ahk
#include Source_Common\Multithreading\API Caller to Execution.ahk
#include Source_Common\Multithreading\API Caller to Manager.ahk
#include Source_Common\Multithreading\API for Elements.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

;PlaceholderIncludesOfElements

menu,tray, tip, Manager
init_Manager_GUI()
Show_Manager_GUI()

SetTimer,queryTasks,100
return

queryTasks()
{
	global
	Loop
	{
		oneTask:=_getTask("manager")
		if (oneTask)
		{
			name:=oneTask.name
			if (name="TreeView_Refill")
			{
				TreeView_manager_Refill()
			}
			if (name="TreeView_AddEntry")
			{
				TreeView_manager_AddEntry(oneTask.type, oneTask.id)
			}
			if (name="TreeView_Select")
			{
				TreeView_manager_Select(oneTask.type, oneTask.id, oneTask.options)
			}
			if (name="ShowWindow")
			{
				Show_Manager_GUI()
			}
		}
		else
			break
	}
}

exit:
global _exiting := true
return