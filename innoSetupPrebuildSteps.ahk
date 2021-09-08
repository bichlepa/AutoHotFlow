#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1

#include lib\Objects\Objects.ahk


; read version number from source file
mainFilePath := "source_main\main.ahk"
FileRead, mainFile, % mainFilePath

versionNumber := mainFile
versionNumber := substr(versionNumber, instr(versionNumber, "_AHF_VERSION") +  strlen("_AHF_VERSION"))
versionNumber := substr(versionNumber, instr(versionNumber, """") + 1)
versionNumber := substr(versionNumber, 1, instr(versionNumber, """") - 1)
oldVersionNumber := versionNumber

InputBox, versionNumber, Version number, Check version number, , , , , , , , %versionNumber%
if errorlevel
    ExitApp

; check version number. It must have three numbers with dots.
valid := true
loop, parse, versionNumber, .
{
    ; major version must be 1. When version 2 comes, this code will be changed.
    if (a_index = 1)
    {
        if (a_loopfield != 1)
        {
            valid := false
        }
    }
    ; minor and patch version can be between 0 and 100
    if (not (a_loopfield >= 0 and a_loopfield <= 100))
    {
        valid := false
    }
    ; a number might be written differently (like 0x1 or 01). We convert it to a string. On right side we perform a mathematical operation and round it to make sure it is a normal integer.
    if (a_loopfield "a" != round(a_loopfield + 0) "a")
    {
        valid := false
    }

    lastindex := a_index
}
if (lastindex != 3 or not valid)
{
    MsgBox, Version number "%versionNumber%" is invalid!
    ExitApp
}
; write new versio number to source file
StringReplace, mainFile, mainFile, % """" oldVersionNumber """", % """" versionNumber """"
if (errorlevel)
{
    MsgBox, could not write new version number to main.ahk file
    ExitApp
}
FileDelete, % mainFilePath
FileAppend, % mainFile, % mainFilePath

; build some executables
buildFile("AutoHotFlow", "Icons/MainIcon.ico")
buildFile("find modules")

buildFile(path, icon = "")
{
    SplitPath, A_AhkPath,, AhkRoot
    if (icon)
        RunWait, "%AhkRoot%\Compiler\Ahk2Exe.exe" /in "%A_WorkingDir%\%path%.ahk" /out "%A_WorkingDir%\%path%.exe" /icon "%A_WorkingDir%\%icon%"
    else 
        RunWait, "%AhkRoot%\Compiler\Ahk2Exe.exe" /in "%A_WorkingDir%\%path%.ahk" /out "%A_WorkingDir%\%path%.exe"
}


; run find Modules
run, "find modules.exe"

; create file list
AppDirList := []
AppFileList := []


addFilesInFolderWithExtension(AppDirList, AppFileList, "AutoHotKey", "*", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "bin", "*", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Icons", "ico", true)

addFile(AppDirList, AppFileList, "language\language.ahk")
addFile(AppDirList, AppFileList, "language\en.ini")

addFilesInFolderWithExtension(AppDirList, AppFileList, "Saved Flows\demo flows", "json", false)

addFilesInFolderWithExtension(AppDirList, AppFileList, "Help", "css", false)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Help\en", "html", false)

addFilesInFolderWithExtension(AppDirList, AppFileList, "Lib", "ahk", true)
removeFolder(AppDirList, AppFileList, "Lib\Yunit")

addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Common", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Draw", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Editor", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Execution", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Main", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Manager", "ahk", true)

addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "html", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "png", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "ico", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "ini", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements\Default", "json", true)

addFile(AppDirList, AppFileList, "find modules.exe")
addFile(AppDirList, AppFileList, "AutoHotFlow.exe")



; write file list into the inno Setup script
FileRead, scriptContent, innoSetupScript.iss
pos := instr(scriptContent, "[Files]")
scriptContent := substr(scriptContent, 1, pos + strlen("[Files]") + 1)

for oneIndex, oneFile in AppFileList
{
    SplitPath, oneFile, oneFileName, dirPath
    if dirPath
        dirPath := "\" dirPath
    scriptContent .= "Source: """ oneFile """; DestDir: ""{app}" dirPath """; Flags: ignoreversion`r`n"
}

; write new version number to inno setup file
StringReplace, scriptContent, scriptContent, % "MyAppVersion """ oldVersionNumber """", % "MyAppVersion """ versionNumber """"
if (errorlevel)
{
    MsgBox, could not write new version number to Inno Setup file
    ExitApp
}


FileDelete, innoSetupScript.iss
FileAppend, % scriptContent, innoSetupScript.iss


SoundBeep, 200, 100

exitapp

addFile(dirList, fileList, filepath)
{
    SplitPath, filepath, oneFileName, dirPath
    
    if (not ObjHasValue(fileList, filepath))
    {
        fileList.push(filepath)
    }

    if (not ObjHasValue(dirList, dirPath))
    {
        dirList.push(dirPath)
    }
}

addFilesInFolderWithExtension(dirList, fileList, path, extension, recursive = false)
{
    if (recursive)
    {
        recursiveOption := "R"
    }
    loop, files, %path%\*.%extension%, % recursiveOption
    {
        addFile(dirList, fileList, a_loopfilePath)
    }
}

removeFile(dirList, fileList, filepath)
{
    for oneIndex, oneFile in fileList
    {
        if (oneFile = filepath)
        {
            fileList.removeAt(oneIndex)
            break
        }
    }

    removeUnusedDirs(dirList, fileList)
}

removeFolder(dirList, fileList, path)
{
    toRemoveList := []

    for oneIndex, oneFile in fileList
    {
        if (substr(oneFile, 1, strlen(path) + 1) = path "\")
        {
            toRemoveList.push(oneFile)
        }
    }

    for oneIndex, oneFile in toRemoveList
    {
        removeFile(dirList, fileList, oneFile)
    }
}


removeUnusedDirs(dirList, fileList)
{
    Loop
    {
        someThingDeleted := false

        for toCheckIndex, toCheckDir in dirList
        {
            found := false
            
            for oneIndex, oneDir in dirList
            {
                SplitPath, oneDir, oneFileName, dirPath
                {
                    if (dirPath = toCheckDir)
                    {
                        found := true
                        break
                    }
                }
            }
            
            if found
                continue

            for oneIndex, oneFile in fileList
            {
                SplitPath, oneFile, oneFileName, dirPath
                {
                    if (dirPath = toCheckDir)
                    {
                        found := true
                        break
                    }
                }
            }

            if not found
            {
                dirList.removeAt(toCheckIndex)
                someThingDeleted := true
                break
            }
        }

        if not someThingDeleted
            break
    }
}

