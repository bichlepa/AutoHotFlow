#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..  ; Ensures a consistent starting directory.


;parameters
mainlanguagecode:="en"
mainlanguagename:="English"


#Include language.ahk

allStrings:=object()
allLangs:=Object()
stringalllangs=`n

_language:=Object()
_language.lang:=mainlanguagecode
_language.fallbacklang:=mainlanguagecode
_language.dir:=A_ScriptDir
_language.readAll:=True
_language.MakeAdditionalCategoryOfTranslationObject:=true


lang_Init()

;Search for all ahk files and search for lang() calls
loop %A_WorkingDir%\*.ahk,1,1
{
	;MsgBox %A_LoopFileFullPath%
	if A_LoopFileName=language.ahk
		continue
	
	ToolTip, Scanning %A_LoopFileFullPath%
	currentfile:=A_LoopFileFullPath
	FileRead,ahkFileContent,%A_LoopFileFullPath%
	tempFoundPos=1
	Loop
	{
		;search for a lang() call and get the string out of it. (It was hard to implement maybe I will need to rewrite it)
		tempFoundPos:=RegExMatch(ahkFileContent, "U)lang\(""(.+"")", tempVariablesToReplace,tempFoundPos +1)
		if tempFoundPos=0
			break
		langvar:=tempVariablesToReplace1
		;~ ToolTip, %A_LoopFileFullPath% %tempFoundPos%
		StringGetPos,pos,langvar,"
		if pos
			StringLeft,langvar,langvar,%pos%
		else
		{
			MsgBox, unexpected error!
		}
		
		SetTimer,langremovetooltip,-5000
		;~ StringReplace,langvar_no_spaces,langvar,%a_space%,_,all
		if not allStrings.haskey(langvar)
			allStrings[langvar]:=1
		
		lang(langvar)
		if (_language.success != 1)
		{
			;~ StringReplace,langvar_spaces,langvar,_,%A_Space%,all
			;~ MsgBox %currentfile%
			InputBox,newtrans,How is this in %mainlanguagename%?,%currentfile%`n`n%langvar%,,,,,,,,%langvar%
			
			;try to correct common errors
			loop,9
			{
				StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
				StringReplace,newtrans,newtrans,$%a_index%,`%1`%,all
				StringReplace,newtrans,newtrans,$%a_index%$,`%1`%,all
				StringReplace,newtrans,newtrans,`%%a_index%$,`%1`%,all
				StringReplace,newtrans,newtrans,$%a_index%`%,`%1`%,all
			}
			iniwrite,% newtrans,%A_ScriptDir%\%mainlanguagecode%.ini,translations,%langvar%
		}
		
	}
}

;Search for entries in ini which are not used
for, tempString, tempTransl in _language.cache
{
	if not allStrings.HasKey(tempString)
	{
		tempCategory:=langCategoryOfTranslation[tempString]
		MsgBox, 4,Unused translation,%tempString% `n`nin category '%tempCategory%' is not used. Delete?
		IfMsgBox yes
			IniDelete,%A_ScriptDir%\%mainlanguagecode%.ini,%tempCategory%,%tempString%
	}
	else
		tooltip  %tempString%
	
}

MsgBox Everything is translated! :-)
ExitApp

langremovetooltip:
ToolTip
return