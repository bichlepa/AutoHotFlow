#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _WorkingDir := _share._WorkingDir
global _ScriptDir := _share._ScriptDir
SetWorkingDir %a_temp%  ; using working dir forbidden.

SetBatchLines -1
#SingleInstance off
CoordMode,mouse,client
;FileEncoding,UTF-8
OnExit,Exit

;Following variables will be present (and some others)
;Global_ThisFlowID
;_ahkThreadID


#Include %A_ScriptDir%\..
#include language\language.ahk ;Must be very first
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_settings.UILanguage)

#include lib\Object to file\String-object-file.ahk
#include lib\GDI+\GDIp.ahk
#include lib\objhasvalue\objhasvalue.ahk
#include lib\ObjFullyClone\ObjFullyClone.ahk
#include lib\Random Word List\Random Word List.ahk

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
#include Source_Editor\API\API receiver Editor.ahk
#include Source_Editor\API\API Caller Elements.ahk
#include Source_Editor\Assistants\Get window information.ahk

#include source_Common\Multithreading\API Caller Main.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\settings\Default values.ahk
#include source_Common\settings\settings.ahk
#include source_Common\Variables\global variables.ahk
#include source_Common\Variables\code parser.ahk
#include source_Common\variables\code evaluator.ahk
#include source_Common\variables\code tokenizer.ahk
#include source_Common\variables\expression evaluator.ahk
#include source_Common\flows\flows.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()
;PlaceholderIncludesOfElements

parentAHKThread := AhkExported()



EditorGUIInit()
EditGUIshow()
initializeTrayBar()


FlowObj := _flows[FlowID]

return


exit_all()
{
	global
	API_Main_Thread_Stopped(_ahkThreadID)
	deinitializeTrayBar()
}


exit:
if (exiting != true)
exit_all()
exiting := true
exitapp
return