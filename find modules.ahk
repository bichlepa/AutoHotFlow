#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ MsgBox '%1%' - %2% - %3% - %4% - %5%

FileEncoding utf-8

#include lib\Json\Jxon.ahk
#Include lib\ini\ini helper.ahk

; parse arguments
for n, param in A_Args
{
    if (param = "onlyDefaultPackage")
	{
		; if this parameter is present, we will only include the default package
		onlyDefaultPackage := true
	}
	Else
	{
		MsgBox, unknown parameter: %param%
	}
}

allElementTypes := ["actions", "conditions", "loops", "triggers"]
availableHelpFileLanguages := []

; find available help files
loop, files, Help\*, D
{
	availableHelpFileLanguages.push(A_LoopFileName)
}

; prepare translations merge
; read and copy all existing basic translations
allTranslations := []
allTranslationsMeta := []
loop, files, language\basic\*.ini
{
	if instr(a_loopfilename, "removed")
		continue

	oneLanguage := substr(a_loopfilename, 1, instr(a_loopfilename, ".") - 1)

	; read existing translations
	FileRead, iniFileContent, % a_loopfilepath
	newTranslations := importIni(iniFileContent)
	allTranslationsMeta[oneLanguage] := newTranslations.delete("language_info")
	allTranslations[oneLanguage] := []
	mergeTranslations(allTranslations[oneLanguage], newTranslations)
}

; prepare help menu index
for oneLanguageIndex, oneLanguage in availableHelpFileLanguages
{
	fileRead, helpFileMenuTemplate_%oneLanguage%, help\%oneLanguage%\Menu - template.html
	fileRead, helpFileMenuTemplateOneEntry_%oneLanguage%, help\%oneLanguage%\Menu - template of one entry.html
	for oneElementTypeIndex, oneElementType in allElementTypes
	{
		helpFileMenuEntries_%oneElementType%_%oneLanguage% := ""
	}
}

;This is only executing while developing
;Here, some source files are automatically modified
Libincludes := ""
elementInclusions := ""
helpFiles := ""
licenseInfo := []
loop, files, source_Elements\*, D
{
	packageName := A_LoopFileName
	packagePath := A_LoopFilePath
	if (onlyDefaultPackage)
	{
		; we want only default package.
		if (packageName != "Default")
		{
			; skip this package
			continue
		}
	}
	fileread,fileContent,% packagePath "\manifest.json"
	fileContent := Jxon_Load(fileContent)

	for oneLibraryIndex, oneLibrary in fileContent.libraries
	{
		Libincludes .= "#include " packagePath "\" oneLibrary "`n"
	}

	for oneElementTypeIndex, oneElementType in allElementTypes
	{
		for oneElementIndex, oneElement in fileContent[oneElementType]
		{
			elementInclusions .= "#include " packagePath "\" oneElementType "\" oneElement "`n"
		}
	}
	
	; Create the help file menu index and copy help files

	for oneLanguageIndex, oneLanguage in availableHelpFileLanguages
	{

		for oneElementTypeIndex, oneElementType in allElementTypes
		{
			FileCreateDir, help\%oneLanguage%\%oneElementType%

			for oneElementIndex, oneElement in fileContent[oneElementType]
			{
				oneElementWithoutExtension := substr(oneElement, 1, -4)
				helpFileName:= oneElementWithoutExtension ".html"
				helpFilePathDestination := "help\" oneLanguage "\" oneElementType "\" helpFileName
				helpFilePathSource := packagePath "\" helpFilePathDestination
				if (FileExist(helpFilePathSource))
				{
					FileCopy, % helpFilePathSource, % helpFilePathDestination , 1

					fileread, helpFile, % helpFilePathDestination
					startPos := instr(helpFile, "<h1")
					startPos := instr(helpFile, ">", ,startPos) + strlen(">")
					stopPos := instr(helpFile, "</h1>", ,startPos)
					oneElementName := trim(substr(helpFile, startPos, stopPos - startPos), "`r`n`t ")
					helpFileMenuOneEntry := helpFileMenuTemplateOneEntry_%oneLanguage%
					helpFileMenuOneEntry := StrReplace(helpFileMenuOneEntry, "%path%", oneElementType "\" helpFileName)
					helpFileMenuOneEntry := StrReplace(helpFileMenuOneEntry, "%name%", oneElementName)
					helpFileMenuEntries_%oneElementType%_%oneLanguage% .= helpFileMenuOneEntry
				}
			}

		}

	}
	

	; merge translations files
	loop, files, %packagePath%\language\*.ini
	{
		if instr(a_loopfilename, "removed")
			continue

		oneLanguage := substr(a_loopfilename, 1, instr(a_loopfilename, ".") - 1)
		
		; read existing translations
		FileRead, iniFileContent, % a_loopfilepath
		newTranslations := importIni(iniFileContent)
		newTranslations.delete("language_info")
		mergeTranslations(allTranslations[oneLanguage], newTranslations)
	}


	; read license informations
	licenseInfoEntry := []
	licenseInfoEntry.author := fileContent.author
	licenseInfoEntry.website := fileContent.website
	licenseInfoEntry.license := fileContent.license
	licenseInfoEntry.description := fileContent.description
	licenseInfoEntry.version := fileContent.version
	licenseInfo[packageName] := licenseInfoEntry
}

; write help menu index; prepare help menu index
for oneLanguageIndex, oneLanguage in availableHelpFileLanguages
{
	for oneElementTypeIndex, oneElementType in allElementTypes
	{
		helpFileMenuTemplate_%oneLanguage% := StrReplace(helpFileMenuTemplate_%oneLanguage%, "%" oneElementType "%", helpFileMenuEntries_%oneElementType%_%oneLanguage%)
	}
	Filedelete, help\%oneLanguage%\Menu.html
	FileAppend, % helpFileMenuTemplate_%oneLanguage%, help\%oneLanguage%\Menu.html
}


; save merged translations
for oneLanguage, oneLanguageData in allTranslations
{
	language_info := oneLanguageData.delete("language_info")
	iniFileContent := exportIni({language_info: allTranslationsMeta[oneLanguage]}) "`n`n" exportIni({translations: oneLanguageData})
	iniPath := "language\" oneLanguage ".ini"
	filedelete, % iniPath
	FileAppend, % iniFileContent, % iniPath, utf-16
}

;Those includes are needed by the elements
;They will be inserted in main.ahk and from there in editor.ahk and execution.ahk
Libincludes.= "`nglobal_libInclusionsForThreads = `n(`n" Libincludes "`n)`n"
elementInclusions.= "`nglobal_elementInclusionsForThreads = `n(`n" elementInclusions "`n)`n"

;Replace the includes in the file main.ahk
FileRead,mainfilecontent,source_main\main.ahk

StringGetPos,posstart,mainfilecontent,;Element_Includes_Start
posstart+= strlen(";Element_Includes_Start") +1
stringgetpos,posend,mainfilecontent,;Element_Includes_End
posend-=1
mainfilecontent:=substr(mainfilecontent,1,posstart) elementInclusions SubStr(mainfilecontent,posend)

StringGetPos,posstart,mainfilecontent,;Lib_Includes_Start
posstart+= strlen(";Lib_Includes_Start") +1
stringgetpos,posend,mainfilecontent,;Lib_Includes_End
posend-=1
mainfilecontent:=substr(mainfilecontent,1,posstart) Libincludes SubStr(mainfilecontent,posend)

FileDelete,source_main\main.ahk
FileAppend,%mainfilecontent%,source_main\main.ahk

; license text
; add license informations from modules
licenseInfoPackageText := ""
for onePackageName, onePackage in licenseInfo
{
	licenseInfoPackageText .= onePackageName "`n"
	licenseInfoPackageText .= "description: " onePackage.description "`n"
	licenseInfoPackageText .= "author: " onePackage.author "`n"
	licenseInfoPackageText .= "source: " onePackage.website "`n"
	licenseInfoPackageText .= "license: " onePackage.license "`n"
	licenseInfoPackageText .= "`n"
}


; find licenses in source code and create some readable text
licenseInfoText := ""
loop, files, *.ahk, FR
{
	if (onlyDefaultPackage)
	{
		; we want only default package.
		if (instr(a_loopfilePath,"\Source_Elements\"))
		{
			if (not instr(a_loopfilePath,"\Source_Elements\Default\"))
			{
				; skip this package
				continue
			}
		}
	}

	FileRead, fileContent, % a_loopfilePath
	if instr(fileContent, "license info" ":")
	{
		pos1 := instr(fileContent, "license info" ":")
		pos1 := instr(fileContent, "{", , pos1)
		pos2 := instr(fileContent, "}", , pos1)
		licenseInfo := substr(fileContent, pos1, pos2 - pos1 + 1)
		licenseInfo := Jxon_Load(licenseInfo)
		if (licenseInfo.name)
		{
			licenseInfoText .= licenseInfo.name "`n"
			licenseInfoText .= "author: " licenseInfo.author "`n"
			licenseInfoText .= "source: " licenseInfo.source "`n"
			licenseInfoText .= "license: " licenseInfo.license "`n"
			if (licenseInfo.licenselink)
				licenseInfoText .= "link to license text: " licenseInfo.licenselink "`n"
			licenseInfoText .= "`n"
		}
	}
}


; insert the text in the about.ahk file
aboutCodeFilePath := "Source_Manager\User interface\About.ahk"
FileRead, aboutCode, % aboutCodeFilePath

startpos := instr(aboutCode, "#aboutTextOtherCodeOverviewStart") + strlen("#aboutTextOtherCodeOverviewStart`n")
stopPos := instr(aboutCode, "#aboutTextOtherCodeOverviewStop")
codeBefore := substr(aboutCode, 1, startpos)
codeAfter := substr(aboutCode, stopPos)
aboutCode := codeBefore licenseInfoText codeAfter

StringReplace, aboutCode, aboutCode, `n, `r`n, all
StringReplace, aboutCode, aboutCode, `r`r`n, `r`n, all

startpos := instr(aboutCode, "#aboutTextPackagesStart") + strlen("#aboutTextPackagesStart`n")
stopPos := instr(aboutCode, "#aboutTextPackagesStop")
codeBefore := substr(aboutCode, 1, startpos)
codeAfter := substr(aboutCode, stopPos)
aboutCode := codeBefore licenseInfoPackageText codeAfter

StringReplace, aboutCode, aboutCode, `n, `r`n, all
StringReplace, aboutCode, aboutCode, `r`r`n, `r`n, all

filedelete, % aboutCodeFilePath
FileAppend, % aboutCode, % aboutCodeFilePath, utf-8


;The element API functions are written three times for each of those threads: main, execution, editor
;If a new API function is created for the thread execution,
;this code automatically adds empty API functions for the other threads

; ;Find all element API functions
; FileRead,apifileExecution,*t %A_WorkingDir%\source_Execution\api\Functions for elements.ahk

; allFUnctions:=Object()
; loop, parse, apifileExecution, `n
; {
; 	oneLine:=a_loopfield
; 	if (substr(oneLine,1,2) = "x_")
; 	{
; 		stringgetpos,pos1,oneLine,(
; 		StringLeft, funcname, oneLine, % pos1
; 		StringTrimLeft, pars, oneline, % pos1
; 		allFunctions.push({line: oneLine, Name: funcname, pars: pars})
; 	}
; }
; FileRead,apifileEditor,*t %A_WorkingDir%\source_Editor\api\api caller elements.ahk
; FileRead,apifileMain,*t %A_WorkingDir%\source_main\threads\api caller elements.ahk

; for oneIndex, oneFuncion in allFunctions
; {
; 	loop 2
; 	{
; 		if a_index = 1
; 			apiFile:=apifileEditor
; 		else if a_index=2
; 			apiFile:=apifileMain
		
; 		StringGetPos, posfunc, apifile, % oneFuncion.name
; 		if (posfunc = -1)
; 		{
; 			apifile.="`n`n" oneFuncion.name oneFuncion.pars "`n{`n}`n"
; 		}
; 		else
; 		{
; 			StringGetPos, posfuncend,apifile,`n,,%posfunc%
; 			function:=substr(apifile, posfunc +1, posfuncend-posfunc)
; 			stringgetpos, pospars, function, (
; 			stringleft,funcname, function, %pospars%
; 			StringTrimLeft,funcpars , function,%pospars%
			
; 			StringReplace, apifile, apifile,% function,% oneFuncion.name oneFuncion.pars
; 		}
		
; 		if a_index = 1
; 			apifileEditor:=apiFile
; 		else if a_index=2
; 			apifileMain:=apiFile
; 	}
; }

; ;~ MsgBox %apifileEditor%
; Filedelete, %A_WorkingDir%\source_Editor\api\API Caller Elements.ahk
; Filedelete, %A_WorkingDir%\source_main\threads\API Caller Elements.ahk
; FileAppend,%apifileEditor%, %A_WorkingDir%\source_Editor\api\API Caller Elements.ahk, utf-8
; FileAppend,%apifileMain%, %A_WorkingDir%\source_main\threads\API Caller Elements.ahk, utf-8

if not a_iscompiled
	SoundBeep, 300, 100

exitapp

mergeTranslations(allTranslations, newTranslations)
{
	for oneNewCategory, oneNewCategoryContent in newTranslations
	{
		for oneNewTranslationKey, oneNewTranslationValue in oneNewCategoryContent
		{
			if (not allTranslations.hasKey(oneNewTranslationKey))
			{
				allTranslations[oneNewTranslationKey] := oneNewTranslationValue
			}
		}
	}

	return
}