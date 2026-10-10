#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetBatchLines -1
#SingleInstance, force

#include lib\Objects\Objects.ahk

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

gui, add, text,,Select package
gui, add, DropDownList, w200 vpackageName choose1, % allPackages
gui, add, button, w200 gpackageSelected default, OK
gui,show
return

packageSelected:
gui, submit
gui, destroy

; read version number from manifest file
manifestFilePath := "Source_elements\" packageName "\manifest.json"
FileRead, manifestFile, % manifestFilePath

PackageVersion := readFromJson(manifestFile, "version")
PackageAuthor := readFromJson(manifestFile, "author")
Packagewebsite := readFromJson(manifestFile, "website")
Packagelicense := readFromJson(manifestFile, "license")
oldPackageVersion := PackageVersion

InputBox, PackageVersion, Version number, Check version number, , , , , , , , %PackageVersion%
if errorlevel
    ExitApp

; check version number. It must have three numbers with dots.
valid := true
loop, parse, PackageVersion, .
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
    MsgBox, Version number "%PackageVersion%" is invalid!
    ExitApp
}

; write new versio number to source file
StringReplace, manifestFile, manifestFile, % """" oldPackageVersion """", % """" PackageVersion """"
if (errorlevel)
{
    MsgBox, could not write new version number to manifest file
    ExitApp
}
FileDelete, % manifestFilePath
FileAppend, % manifestFile, % manifestFilePath

; create file list
AppDirList := []
AppFileList := []


addFilesInFolderWithExtension(AppDirList, AppFileList, "Source_elements\" packageName , "*", true)


; write the innoSetupFile

; write all informations into the inno Setup script
innoSetupScriptPath := "innoSetupScript - Extension Package.iss"
innoSetupScriptTemplatePath := "innoSetupScript - Extension Package template.iss"
FileRead, scriptContent, % innoSetupScriptTemplatePath

fileList := 
for oneIndex, oneFile in AppFileList
{
    SplitPath, oneFile, oneFileName, dirPath
    if dirPath
        dirPath := "\" dirPath
    fileList .= "Source: """ oneFile """; DestDir: ""{app}" dirPath """; Flags: ignoreversion`r`n"
}

scriptContent := StrReplace(scriptContent, "&packageName&", packageName)
scriptContent := StrReplace(scriptContent, "&author&", PackageAuthor)
scriptContent := StrReplace(scriptContent, "&version&", PackageVersion)
scriptContent := StrReplace(scriptContent, "&website&", Packagewebsite)
scriptContent := StrReplace(scriptContent, "&license&", Packagelicense)
scriptContent := StrReplace(scriptContent, "&files&", fileList)

FileDelete, % innoSetupScriptPath
FileAppend, % scriptContent,  % innoSetupScriptPath


SoundBeep, 200, 100

exitapp

readFromJson(content, key)
{
    value := content
    value := substr(value, instr(value, """" key """:") +  strlen("""" key """:"))
    value := substr(value, instr(value, """") + 1)
    value := substr(value, 1, instr(value, """") - 1)
    return value
}

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

