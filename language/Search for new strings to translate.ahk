#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..  ; Ensures a consistent starting directory.

#Include language.ahk
#include strobj.ahk

allStrings:=object()
allLangs:=Object()
stringalllangs=`n
lang_Init()

_language.UILang:="en"
;~ MsgBox % _language.UILang

developing=yes
langMakeAdditionalCategoryOfTranslationObject:=true


lang_ReadAllTranslations()
;~ MsgBox % strobj(langAllTranslations)
Comma=,
loop %A_WorkingDir%\*.ahk,1,1
{
	;MsgBox %A_LoopFileFullPath%
	if A_LoopFileName=language.ahk
		continue
	
	FileRead,ahkFileContent,%A_LoopFileFullPath%
	tempFoundPos=1
	ToolTip, %A_LoopFileFullPath%
	Loop
	{
		tempFoundPos:=RegExMatch(ahkFileContent, "U)lang\(""(.+"")", tempVariablesToReplace,tempFoundPos +1)
		if tempFoundPos=0
			break
		currentfile:=A_LoopFileFullPath
		;~ ToolTip, %A_LoopFileFullPath% %tempFoundPos%
		StringGetPos,pos,tempVariablesToReplace1,"
		if pos
			StringLeft,tempVariablesToReplace1,tempVariablesToReplace1,%pos%
		else
		{
			MsgBox, unexpected error!
			
		}
		
		;~ ToolTip, %A_LoopFileFullPath% %tempFoundPos% %tempVariablesToReplace1%
		SetTimer,langremovetooltip,-5000
		StringReplace,tempVariablesToReplaceNoSpaces,tempVariablesToReplace1,%a_space%,_,all
		if not allStrings.haskey(tempVariablesToReplaceNoSpaces)
			allStrings[tempVariablesToReplaceNoSpaces]:=1
		lang(tempVariablesToReplace1)
		
	}
}

;Search for entries in ini which are not used
;~ MsgBox % strobj(langAllTranslations)
;~ MsgBox % strobj(allStrings)
;~ MsgBox % strobj(langCategoryOfTranslation)
for, tempString, tempTransl in langAllTranslations
{
	;~ MsgBox % tempString "`n`n" strobj(langAllTranslations)
	if not allStrings.HasKey(tempString)
	{
		tempCategory:=langCategoryOfTranslation[tempString]
		MsgBox, 4,Unused translation,%tempString% `n`nin category '%tempCategory%' is not used. Delete?
		IfMsgBox yes
			IniDelete,%A_ScriptDir%\%UILang%.ini,%tempCategory%,%tempString%
	}
	else
		tooltip  %tempString%
	
}

MsgBox Everything is translated! :-)
ExitApp

langremovetooltip:
ToolTip
return