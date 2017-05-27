#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
my_WorkingDir := _share.my_WorkingDir
my_ScriptDir := _share.my_ScriptDir
SetWorkingDir %a_temp%  ; using working dir forbidden.

;~ MsgBox %my_WorkingDir%
#NoTrayIcon

parentAHKThread := AhkExported()
onexit exit
#Include %A_ScriptDir%\..
#include lib\Object to file\String-object-file.ahk
#include lib\7z wrapper\7z wrapper.ahk

#include language\language.ahk
;initialize languages
_language:=Object()
_language.dir:=my_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()

lang_setLanguage(_settings.UILanguage)

#include Source_Manager\User Interface\manager gui.ahk
#include Source_Manager\User Interface\help.ahk
#include Source_Manager\User Interface\Change Category GUI.ahk
#include Source_Manager\User Interface\Select language.ahk
#include Source_Manager\User Interface\Global_Settings.ahk
#include Source_Manager\User Interface\import and export.ahk
#include Source_Manager\API\API receiver manager.ahk

#include source_Common\variables\global variables.ahk
#include source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Multithreading\API Caller Main.ahk
#include source_Common\flows\flows.ahk


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