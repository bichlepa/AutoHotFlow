#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
_WorkingDir := _share._WorkingDir
_ScriptDir := _share._ScriptDir
SetWorkingDir %a_temp%  ; using working dir forbidden.

;~ MsgBox %_WorkingDir%
#NoTrayIcon

parentAHKThread := AhkExported()
onexit exit
#Include %A_ScriptDir%\..
#include lib\Object to file\String-object-file.ahk
#include lib\7z wrapper\7z wrapper.ahk

#include language\language.ahk
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()

lang_setLanguage(_settings.UILanguage)

#include Source_Manager\User Interface\manager gui.ahk
#include Source_Manager\User Interface\help.ahk
#include Source_Manager\User Interface\Change Category GUI.ahk
#include Source_Manager\User Interface\Global_Settings.ahk
#include Source_Manager\User Interface\import and export.ahk
#include Source_Manager\API\API receiver manager.ahk

#include source_Common\variables\global variables.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Multithreading\API Caller Main.ahk
#include source_Common\flows\flows.ahk
#include source_Common\settings\settings.ahk


menu,tray, tip, Manager
init_Manager_GUI()
Show_Manager_GUI()


return

exit_all()
{
	global
	API_Main_Exit()
}

exit:
if (exiting != true)
exit_all()
exiting := true
exitapp
return