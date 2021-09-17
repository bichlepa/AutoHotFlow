#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1

; this script renames test flows and adds the prefix "Test "
; this way we can set a .gitignore filter to ignore all flows but test flows
; if you add a new test flow, call the function to rename it
; it detects whether it is a test flow by its category.

testCategories := []
testCategories.push("Automatic tests")
testCategories.push("Manual tests")

filedelete, .gitignore
fileappend, % "/*.json`n", .gitignore

loop, files, *.json
{
    FileRead, fileContent, % a_loopfilepath
    isTestFlow := false

    for oneCategoryIndex, oneCategory in testCategories
    {
        if instr(fileContent, """category"": """ oneCategory """,")
            isTestFlow := true
    }
    
    if (isTestFlow)
    {
        fileappend, % "!/" a_loopfilename "`n", .gitignore
    }
}

