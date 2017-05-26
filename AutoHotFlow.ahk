#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ MsgBox %1% - %2% - %3% - %4% - %5%

if not (a_iscompiled)
{
	;This is only executing while developing
	
	Libincludes=
	(
	#include lib\7z wrapper\7z wrapper.ahk
	
	)
	Libincludes.= "global_elementInclusions = `n(`n" Libincludes "`n)`n"
	
	;Find all elements in folder Source_Elements
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
	;~ MsgBox % posend "-" SubStr(mainfilecontent,posend,100000)
	mainfilecontent:=substr(mainfilecontent,1,posstart) elementInclusions SubStr(mainfilecontent,posend,100000)
	
	StringGetPos,posstart,mainfilecontent,;Lib_Includes_Start
	posstart+= strlen(";Lib_Includes_Start") +1
	stringgetpos,posend,mainfilecontent,;Lib_Includes_End
	posend-=1
	;~ MsgBox % posend "-" SubStr(mainfilecontent,posend,100000)
	mainfilecontent:=substr(mainfilecontent,1,posstart) Libincludes SubStr(mainfilecontent,posend,100000)

	;~ MsgBox %mainfilecontent%
	FileDelete,source_main\main.ahk
	FileAppend,%mainfilecontent%,source_main\main.ahk


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

;At last run main.ahk
run,autohotkey\autohotkey_h.exe source_main\main.ahk "%1%" "%2%" "%3%" "%4%" "%5%" "%6%" "%7%" "%8%" "%9%" "%10%"