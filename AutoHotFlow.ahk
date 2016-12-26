#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ MsgBox %1% - %2% - %3% - %4% - %5%

if not (a_iscompiled)
{
	;This is only executing while developing
	
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

	;~ MsgBox %mainfilecontent%
	FileDelete,source_main\main.ahk
	FileAppend,%mainfilecontent%,source_main\main.ahk

}

;At last run main.ahk
run,autohotkey\autohotkey_h.exe source_main\main.ahk "%1%" "%2%" "%3%" "%4%" "%5%" "%6%" "%7%" "%8%" "%9%" "%10%"