#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1

;get root AHF path
ahf_path := a_scriptDir
Loop
{
	ahf_pathOld := ahf_path
	ahf_path := substr(ahf_path,1, instr(ahf_path, "\", ,0) - 1)
	if (ahf_pathOld = ahf_path)
	{
		MsgBox, Error. Cant find root folder of AHF
		ExitApp
	}
	if fileexist(ahf_path "\AutoHotFlow.ahk")
		break
}

; let user enter the package name
InputBox, packageName, Create new package, Enter name of the new package
if not packageName
    exitapp

; check whether package exists
packagePath := ahf_path "\source_elements\" packageName
if fileexist(packagePath)
{
    MsgBox, Error. Package already exists
    ExitApp
}

; create folder structure
FileCreateDir, % packagePath
FileCreateDir, % packagePath "\Actions"
FileCreateDir, % packagePath "\Conditions"
FileCreateDir, % packagePath "\help"
FileCreateDir, % packagePath "\help\en"
FileCreateDir, % packagePath "\help\en\Actions"
FileCreateDir, % packagePath "\help\en\Conditions"
FileCreateDir, % packagePath "\help\en\Loops"
FileCreateDir, % packagePath "\help\en\Triggers"
FileCreateDir, % packagePath "\Icons"
FileCreateDir, % packagePath "\language"
FileCreateDir, % packagePath "\lib"
FileCreateDir, % packagePath "\Loops"
FileCreateDir, % packagePath "\Triggers"

; create initial language file
IniWrite, % "English", % packagePath "\language\en.ini", language_info, enname
IniWrite, % "English", % packagePath "\language\en.ini", language_info, name

jsonfile = 
(
{
    "name": "&packageName&",
    "description": "&packageName& extension",
    "author": "",
    "website": "",
    "license": "",
    "libraries": [
    ],
    "actions": [

    ],
    "conditions": [
        
    ],
    "loops": [
        
    ],
    "triggers": [
       
    ]
}
)

StringReplace, jsonfile, jsonfile, &packageName& , %packageName%, All

fileappend, % jsonfile, % packagePath "\manifest.json"

MsgBox, Package %packageName% was created. Please open the manifest.json and fill out missing data.

run, %packagePath%