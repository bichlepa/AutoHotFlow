#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..  ; Ensures a consistent starting directory.
SetBatchLines -1
#SingleInstance off
CoordMode,mouse,client
;FileEncoding,UTF-8
OnExit,Exit

;Following variables will be present (and some others)
;Global_ThisFlowID
;Global_ThisThreadID


#include language\language.ahk
#include lib\Object to file\String-object-file.ahk
#include lib\GDI+\GDIp.ahk
#include lib\objhasvalue\objhasvalue.ahk

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

#include source_Common\Multithreading\API Caller Main.ahk
#include source_Common\Elements API\API Caller Elements.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Defaults\Default values.ahk

AllElementClasses:=Object()
AllTriggerClasses:=Object()
;PlaceholderIncludesOfElements

parentAHKThread := AhkExported()


lang_Init()

EditorGUIInit()
EditGUIshow()
initializeTrayBar()


FlowObj := _flows[FlowID]

return
;~ MsgBox %Global_ThisThreadID% %FlowID% fertig




exit_all()
{
	global
	API_Main_Thread_Stopped(Global_ThisThreadID)
	deinitializeTrayBar()
}


exit:
if (exiting != true)
exit_all()
exiting := true
exitapp
return