#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1

if not instr(fileexist("Source_elements"), "D")
{
    MsgBox, Error! directory "Source_elements" does not exist.
    ExitApp
}

; test wheter rights are sufficient
FileAppend, test, Source_elements\WriteTest.txt
if errorlevel
{
    ; rights are not sufficient, run as admin
    if a_iscompiled
    {
        try Run *RunAs "%A_ScriptFullPath%" ;Run as admin. See https://autohotkey.com/docs/commands/Run.htm#RunAs
    }
    Else
    {
        try Run *RunAs "%a_ahkPath%" "%A_ScriptFullPath%" ;Run as admin. See https://autohotkey.com/docs/commands/Run.htm#RunAs
    }
    exitapp
}
FileDelete, Source_elements\WriteTest.txt


; find all packages
allPackages := ""
loop, files, Source_elements\*, D
{
	if (A_LoopFileName = "Default")
		continue
    if (allPackages != "")
	    allPackages .= "|"
	allPackages .= A_LoopFileName
}

if not allPackages
{
    MsgBox, No packages found!
    ExitApp
}

gui, add, text,,Which package do you want to uninstall?
gui, add, DropDownList, w200 vpackageName choose1, % allPackages
gui, add, button, w200 gpackageSelected default, OK
gui,show
return

packageSelected:
gui, submit

if not packageName
{
    MsgBox, Unknown error!
    ExitApp
}
FileRemoveDir, Source_elements\%packageName%, 1
if errorlevel
{
    MsgBox, Error! Package %packageName% could net be deleted.
}
Else
{
    run, "find modules.exe"
    MsgBox, Package %packageName% was successfully deleted.
    run, "autoHotFlow.exe"
}
ExitApp