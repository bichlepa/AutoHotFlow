#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1

#include lib\Objects\Objects.ahk



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

addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "ahk", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "html", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "png", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "ico", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "ini", true)
addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_Elements", "json", true)

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
    scriptContent .= "Source: """ oneFile """; DestDir: ""{app}" dirPath """; Flags: ignoreversion`n"
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

