#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ MsgBox '%1%' - %2% - %3% - %4% - %5%

if not fileexist("language\en.ini")
{
	runwait, "find modules.ahk"
}


FileEncoding utf-8

;Handle a command line parameter if any
command = %1%
commandMessage = %2%
if (command = "AHFCommand")
{
	DetectHiddenWindows,on
	
	;If an instance of AutoHotFlow already exists, pass the command to the hidden window of AutoHotFlow
	IfWinExist,%A_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW
	{
		ControlSetText,Edit1,%commandMessage%,%A_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW
		ExitApp
	}
}


;At last run main.ahk passing all command line parameters which were passed to this script
run,autohotkey\autohotkey.exe "%A_ScriptDir%\source_main\main.ahk" "%1%" "%2%" "%3%" "%4%" "%5%" "%6%" "%7%" "%8%" "%9%" "%10%"
