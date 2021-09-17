#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..\..  ; Ensures a consistent starting directory.


; this script parses the source code and writes all text that is passed to lang() to the translation files


;parameters
mainlanguagecode:="en"
mainlanguagename:="English"


#Include %A_ScriptDir%\..\..
#Include lib\json\jxon.ahk
#Include lib\ini\ini helper.ahk

allStrings := object()

; at first we will search for lang() calls in source code of AHF. We will search in packages later
folders := ["Source_Common", "Source_Main", "Source_Manager", "Source_Editor", "Source_Execution", "Source_Draw"]

; the tranlations of source code are in the folder "basic"
iniPath := "language\basic\en.ini"

; read existing translations
FileRead, iniFileContent, % iniPath
iniContent := importIni(iniFileContent)
iniContentLanguageInfo := iniContent.language_info

for oneFolderIndex, oneFolder in folders
{
	allStringsValue := oneFolder
	if (oneFolder = "Source_Common" or oneFolder = "Source_Main")
		allStringsValue := "common"
	searchLangCallsInCode(oneFolder, allStrings, allStringsValue, "common")
}

iniContent := mergeStringsInIniContent(iniContent, allStrings)

iniFileContent := exportIni({language_info: iniContentLanguageInfo}) "`n`n" exportIni(iniContent)
filedelete, % iniPath
FileAppend, % iniFileContent, % iniPath


; now we will search in packages
loop, files, source_elements\*, D
{
	iniPath := A_LoopFilePath "\language\en.ini"
	
	FileRead, iniFileContent, % iniPath
	iniContent := importIni(iniFileContent)

	allStringsValue := A_LoopFileName
	allNewStrings := searchLangCallsInCode(A_LoopFilePath, allStrings, "fileName", "_common")
	
	iniContent := mergeStringsInIniContent(iniContent, allNewStrings)
	iniFileContent := exportIni({language_info: iniContentLanguageInfo}) "`n`n" exportIni(iniContent)
	filedelete, % iniPath
	FileAppend, % iniFileContent, % iniPath, utf-16
}



SoundBeep, 200, 100
ExitApp

searchLangCallsInCode(folder, allStrings, allStringsValue, allStringsValueIfOtherOccurences = "")
{
	allNewStrings := []

	if (allStringsValue = "filename")
		useFileNameAsStringsValue := true

	;Search for all ahk files and search for lang() calls
	loop %folder%\*.ahk,1,1
	{
		if (useFileNameAsStringsValue)
			allStringsValue := A_LoopFileName
	
		currentfile := A_LoopFileFullPath
		FileRead, ahkFileContent, %currentfile%
		
		tempFoundPos := 1
		Loop
		{
			;search for a lang() call and get the string out of it. (It was hard to implement maybe I will need to rewrite it)
			tempFoundPos := RegExMatch(ahkFileContent, "U)lang\(""(.+"")", tempVariablesToReplace, tempFoundPos + 1)
			if (tempFoundPos = 0)
				break
			
			langvar := tempVariablesToReplace1
			
			StringGetPos, pos, langvar, "
			if pos
				StringLeft, langvar, langvar, %pos%
			else
			{
				MsgBox, unexpected error in file %currentfile%
				exitapp
			}
			
			stringreplace, langvar, langvar, _, %a_space%, all
			if not allStrings.haskey(langvar)
			{
				allStrings[langvar] := allStringsValue
				allNewStrings[langvar] := allStringsValue
			}
			Else if (allStrings[langvar] != allStringsValue and allStringsValueIfOtherOccurences)
			{
				allStrings[langvar] := allStringsValueIfOtherOccurences
				allNewStrings[langvar] := allStringsValueIfOtherOccurences
			}
		}
	}

	return allNewStrings
}


; search for missing entries in ini file
mergeStringsInIniContent(iniContent, allStrings)
{
	newIniContent := []

	for oneString, oneCategory in allStrings
	{
		if not newIniContent[oneCategory]
			newIniContent[oneCategory] := []
		newIniContent[oneCategory][oneString] := getKeyFromIniContent(iniContent, oneString)
	}

	return newIniContent
}

getKeyFromIniContent(iniContent, string)
{
	for oneIndex, oneCategory in iniContent
	{
		if (oneCategory[string])
		{
			return oneCategory[string]
		}
	}

	pos := instr(string, "#")
	if pos
		string := trim(substr(string, 1, pos-1))
	return string
}



