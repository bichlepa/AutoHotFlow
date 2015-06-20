#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#Include language.ahk


allLangs:=Object()
stringalllangs=`n
Loop,%A_WorkingDir%\*.ini
{
	StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
	
	IniRead,%filenameNoExt%enlangname,%filenameNoExt%.ini,general,enname
	IniRead,%filenameNoExt%langname,%filenameNoExt%.ini,general,name
	if %filenameNoExt%enlangname!=Error
	{
		allLangs.insert(filenameNoExt)
		
	}
	stringalllangs:=stringalllangs filenameNoExt " (" %filenameNoExt%enlangname " - "  %filenameNoExt%langname ")`n"
	;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
}



InputBox,translationto,Select Language,To which language do you want to translate?`nEnter a new short code or one of following codes:`n%stringalllangs%,,,% A_ScreenHeight*0.9

IfnotInString,stringalllangs,`n%translationto% (
{
	
	MsgBox,4,Question, %translationto% does not exist yet. Do you want to add a new language?
	allLangs.insert(translationto)
	IfMsgBox,yes
	{
		InputBox,%translationto%enlangname,Enter language name,What is the English name of the new language?
		if errorlevel
			ExitApp
		InputBox,%translationto%langname,Enter language name,% "What is the name of the new language in " %translationto%enlangname "?"
		if errorlevel
			ExitApp
		IniWrite,% %translationto%enlangname,%translationto%.ini,general,enname
		IniWrite,% %translationto%langname,%translationto%.ini,general,name
	}
	else
		ExitApp
	
}

UILang:=translationto
developing=yes

StringReplace,newWorkingDir,a_Scriptdir,\language
SetWorkingDir,%newWorkingDir%
Comma=,
loop %A_WorkingDir%\*.ahk,1,1
{
	;MsgBox %A_LoopFileFullPath%
	if A_LoopFileName=language.ahk
		continue
	
	FileRead,ahkFileContent,%A_LoopFileFullPath%
	tempFoundPos=1
	Loop
	{
		tempFoundPos:=RegExMatch(ahkFileContent, "U)lang\(""(.+"")", tempVariablesToReplace,tempFoundPos +1)
		if tempFoundPos=0
			break
		currentfile:=A_LoopFileFullPath
		ToolTip, %A_LoopFileFullPath% %tempFoundPos%
		StringGetPos,pos,tempVariablesToReplace1,"
		if pos
			StringLeft,tempVariablesToReplace1,tempVariablesToReplace1,%pos%
		else
		{
			MsgBox, error! could not exract the
			
		}
		
		ToolTip, %A_LoopFileFullPath% %tempFoundPos% %tempVariablesToReplace1%
		SetTimer,langremovetooltip,-5000
		lang(tempVariablesToReplace1)
		
	}
}
MsgBox Everything is translated! :-)
ExitApp

langremovetooltip:
ToolTip
return