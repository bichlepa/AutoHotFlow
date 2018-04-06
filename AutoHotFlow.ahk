#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ MsgBox '%1%' - %2% - %3% - %4% - %5%

;Handle a command line parameter if any
command=%1%
commandMessage=%2%
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

if not (a_iscompiled)
{
	;This is only executing while developing
	;Here, some source files are automatically modified
	
	;Those includes are needed by the elements
	;They will be inserted in main.ahk and from there in editor.ahk and execution.ahk
	Libincludes=
	(
	#include lib\7z wrapper\7z wrapper.ahk
	#include Lib\TTS\TTS by Learning One.ahk
	#include Lib\Eject by SKAN\Eject by SKAN.ahk
	#include Lib\Class_Monitor\Class_Monitor.ahk
	#include Lib\HTTP Request\HTTPRequest.ahk
	#include Lib\HTTP Request\Uriencode.ahk
	
	)
	Libincludes.= "global_elementInclusions = `n(`n" Libincludes "`n)`n"
	
	;Find all elements in folder Source_Elements to include them in main.ahk later
	elementInclusions := "`n"
	loop, files, %A_WorkingDir%\source_Elements\*.ahk, FR
	{
		if not (substr(A_LoopFileName,1,1)=="_")
			elementInclusions .= "#include " A_LoopFileFullPath "`n"
	}

	;Replace the includes in the file main.ahk
	FileRead,mainfilecontent,source_main\main.ahk

	StringGetPos,posstart,mainfilecontent,;Element_Includes_Start
	posstart+= strlen(";Element_Includes_Start") +1
	stringgetpos,posend,mainfilecontent,;Element_Includes_End
	posend-=1
	mainfilecontent:=substr(mainfilecontent,1,posstart) elementInclusions SubStr(mainfilecontent,posend)
	
	StringGetPos,posstart,mainfilecontent,;Lib_Includes_Start
	posstart+= strlen(";Lib_Includes_Start") +1
	stringgetpos,posend,mainfilecontent,;Lib_Includes_End
	posend-=1
	mainfilecontent:=substr(mainfilecontent,1,posstart) Libincludes SubStr(mainfilecontent,posend)

	FileDelete,source_main\main.ahk
	FileAppend,%mainfilecontent%,source_main\main.ahk

	;The element API functions are written three times for each of those threads: main, execution, editor
	;If a new API function is created for the thread execution,
	;this code automatically adds empty API functions for the other threads

	;Find all element API functions
	FileRead,apifileExecution,*t %A_WorkingDir%\source_Execution\api\Functions for elements.ahk
	
	allFUnctions:=Object()
	loop, parse, apifileExecution, `n
	{
		oneLine:=a_loopfield
		if (substr(oneLine,1,2) = "x_")
		{
			stringgetpos,pos1,oneLine,(
			StringLeft, funcname, oneLine, % pos1
			StringTrimLeft, pars, oneline, % pos1
			allFunctions.push({line: oneLine, Name: funcname, pars: pars})
		}
	}
	FileRead,apifileEditor,*t %A_WorkingDir%\source_Editor\api\api caller elements.ahk
	FileRead,apifileMain,*t %A_WorkingDir%\source_main\threads\api caller elements.ahk
	
	for oneIndex, oneFuncion in allFunctions
	{
		loop 2
		{
			if a_index = 1
				apiFile:=apifileEditor
			else if a_index=2
				apiFile:=apifileMain
			
			StringGetPos, posfunc, apifile, % oneFuncion.name
			if (posfunc = -1)
			{
				apifile.="`n`n" oneFuncion.name oneFuncion.pars "`n{`n}`n"
			}
			else
			{
				StringGetPos, posfuncend,apifile,`n,,%posfunc%
				function:=substr(apifile, posfunc +1, posfuncend-posfunc)
				stringgetpos, pospars, function, (
				stringleft,funcname, function, %pospars%
				StringTrimLeft,funcpars , function,%pospars%
				
				StringReplace, apifile, apifile,% function,% oneFuncion.name oneFuncion.pars
			}
			
			if a_index = 1
				apifileEditor:=apiFile
			else if a_index=2
				apifileMain:=apiFile
		}
	}
	
	;~ MsgBox %apifileEditor%
	Filedelete, %A_WorkingDir%\source_Editor\api\API Caller Elements.ahk
	Filedelete, %A_WorkingDir%\source_main\threads\API Caller Elements.ahk
	FileAppend,%apifileEditor%, %A_WorkingDir%\source_Editor\api\API Caller Elements.ahk, utf-8
	FileAppend,%apifileMain%, %A_WorkingDir%\source_main\threads\API Caller Elements.ahk, utf-8
	
}

;At last run main.ahk passing all command line parameters which were passed to this script
run,autohotkey\autohotkey_h.exe "%A_ScriptDir%\source_main\main.ahk" "%1%" "%2%" "%3%" "%4%" "%5%" "%6%" "%7%" "%8%" "%9%" "%10%"

;If there is a command which must be processed by AutoHotFlow, pass it after it has started
;TODO: Main.ahk should process the command itself.
if (command = "AHFCommand")
{
	DetectHiddenWindows,on
	WinWait,%A_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW,,30
	IfWinExist,%A_ScriptDir% AHF_HIDDEN_COMMAND_WINDOW
	{
		ControlSetText,Edit1,%commandMessage%
		ExitApp
	}
}