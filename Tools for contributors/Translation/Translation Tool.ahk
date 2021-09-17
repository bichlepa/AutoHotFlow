#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%\..\..  ; Ensures a consistent starting directory.
#SingleInstance, force

;parameters
mainlanguagecode:="en"


; find all paths

; the first one is AHF language file
paths := "language\basic"

; search for language files in element packages
loop, files, % A_WorkingDir "\source_elements\*", D
{
	if fileexist(a_loopfilepath "\language")
	{
		paths .= "|" StrReplace(a_loopfilepath, A_WorkingDir "\") "\language"
	}
}

; show the gui
gui, selectPath: default
gui, add, text, w400, Please choose your working directory`nYou can either edit the translations of the base application or of an element package
gui, add, ListBox, w400 vguipathListbox choose1 r10, % paths
gui, add, button, w400 h30 gguiPathButtonOK, OK

gui,show
return

guiPathButtonOK:
gui, submit

; set the working directory to the selected path
SetWorkingDir, % A_WorkingDir "\" guipathListbox
gui, destroy



; create tanslation tool GUI
gui, main:default
gui, add, dropdownlist,vDropDownLanguage  x10 y10 w70

gui, add, button, gButtonFindUntranslated y10 X+20, Find untranslated entries

gui, add, Edit, vEditSearch gEditSearch y10 X+20, 
gui, add, button, gButtonSearch vButtonSearch y10 X+10, Search

gui, add, button, gButtonAddNewLanguage y10 X+50, Add new language

gui, add, TreeView ,gGuiListSelect x10 y40 w250 h500 hwndtreeViewHWND


Gui, Add, ListView,gGuiListSelect AltSubmit nosort grid yp X+10 w450 h200,Language|Text
gui,font,s12
gui, add, edit,gEditField vEditField xp Y+10 h290 w450 disabled
gui,font,s8
gui,+hwndMainGuiHWND

; super global variables with all data
global global_allLangs := []
global global_langInfo := []
global global_allTranslations := []
global global_TV_AllCategories := []
global global_TV_AllEntries := []

loadLanguages()
UpdateTreeView()

;~ gui,+resize ;TODO

gui, show

; set up some hotkeys
hotkey, IfWinActive, ahk_id %MainGuiHWND%
hotkey, pgdn, HotkeyNextEntry
hotkey, pgup, HotkeyNextEntry
return



loadLanguages()
{
	global mainlanguagecode
	; delete variable content (if any)
	global_langInfo := []
	global_allTranslations := []
	global_allLangs := []

	; read all ini files
	Loop,%A_WorkingDir%\*.ini
	{
		; skip ini file with removed entries
		if instr(a_loopfilename, "removed")
			continue

		; remove extension
		StringReplace, filenameNoExt, % A_LoopFileName, .%A_LoopFileExt%

		; read ini content
		fileread, fileContent, %A_LoopFileName%
		
		; parse all ini content
		global_allTranslations[filenameNoExt] := importIni(fileContent)
		if not isobject(global_allTranslations[filenameNoExt])
		{
			MsgBox, % "Error in " A_LoopFileName ": " global_allTranslations[filenameNoExt]
			ExitApp
		}

		; write language info to another variable and delete it from global_allTranslations
		global_langInfo[filenameNoExt] := global_allTranslations[filenameNoExt].delete("language_info")
		
		if not (global_langInfo[filenameNoExt].name and global_langInfo[filenameNoExt].enname)
		{
			MsgBox, Error in %A_LoopFileName%: language information is invalid
			ExitApp
		}

		; write all langauge IDs to list
		global_allLangs.push(filenameNoExt)

	}
	
	; correct the entries in languages other than the main language
	for oneIndex, oneLanguage in global_allLangs
	{
		if (oneLanguage = mainlanguagecode)
			continue
		
		; create new object, where we will copy the entries
		newObject := []

		; go through all entries in this language
		for oneSectionID, OneSection in global_allTranslations[oneLanguage]
		{
			for oneKeyID, OneValue in OneSection
			{
				; check whether entry is empty
				if (OneValue = "")
				{
					; delete empty entries
					IniDelete, %oneLanguage%.ini, %oneSectionID%, %oneKeyID%
				}
				Else
				{
					; search for the entry in the main language, in all sections
					keyfound := false
					for oneEnSectionID, OneEnSection in global_allTranslations[mainlanguagecode]
					{
						if (OneEnSection.hasKey(oneKeyID))
						{
							; we found the entry in the main language

							; check whether section is same
							if (oneSectionID != oneEnSectionID)
							{
								; the section in main language differs from the section in this language.
								; change section of this language
								IniDelete, %oneLanguage%.ini, %oneSectionID%, %oneKeyID%
								IniWrite, % OneValue, %oneLanguage%.ini, %oneEnSectionID%, %oneKeyID%
							}
							
							; add the entry to the new Object
							if (not newObject[oneEnSectionID])
							{
								newObject[oneEnSectionID] := []
							}
							newObject[oneEnSectionID][oneKeyID] := OneValue
							keyfound := true
						}
					}
					if not keyfound
					{
						; entry does not exist in the main language.
						; delete the entry from file and write it to a file with the postfix "_removed"
						inidelete, %oneLanguage%.ini, % oneSectionID, % oneKeyID
						IniWrite, % OneValue, %oneLanguage%_removed.ini, % oneSectionID, % oneKeyID
					}
				}
			}
		}
		; overwrite the object
		global_allTranslations[oneLanguage] := newObject
	}

	updateLanguageListInGUI()
}

; updates the language List in GUI
updateLanguageListInGUI()
{
	global
	gui,main:default
	lv_delete()

	LanguageListString := "|"
	for oneIndex, oneLang in global_allLangs
	{
		LanguageListString .= oneLang "|"
		lv_add("",global_langInfo[oneLang].name,"")
	}

	stringreplace,LanguageListString,LanguageListString,|en|,|en||
	guicontrol, ,DropDownLanguage,%LanguageListString%
}

; moves the unused entries from the translation files to another file
moveUnusedEntries()
{
	global global_allTranslations
	global mainlanguagecode

	; make list of all entries in english language
	allEnLanguageKeys := []
	for oneSection, oneSectionContent in global_allTranslations[mainlanguagecode]
	{
		for oneKey, oneValue in oneSectionContent
		{
			allEnLanguageKeys[oneKey] := oneValue
		}
	}

	; go through all languages (skip english)
	for oneLanguage, oneLanguageContent in global_allTranslations
	{
		if (oneLanguage = mainlanguagecode)
		{
			continue
		}

		; find all entries that exist in this language but not in english
		toDelete := []
		for oneSection, oneSectionContent in oneLanguageContent
		{
			for oneKey, oneValue in oneSectionContent
			{
				if (allEnLanguageKeys.HasKey(oneKey) and oneValue != "")
				{
					
				}
				Else
				{
					toDelete[oneSection] := oneKey
				}
			}
		}

		; write entries to an other file and delete them from the original file
		for oneSection, oneKey in toDelete
		{
			if (oneKey != "")
				IniWrite, % oneLanguageContent[oneSection][oneKey], %oneLanguage%_removed.ini, % oneSection, % oneKey
			inidelete, %oneLanguage%.ini, % oneSection, % oneKey
			oneLanguageContent[oneSection].Delete(oneKey)
			if (oneLanguageContent[oneSection].Length = 0)
			{
				oneLanguageContent.delete(oneSection)
			}
		}
	}
}

; updates the list of translatable strings in the treeview
UpdateTreeView()
{
	global
	gui,main:default
	TV_Delete()
	
	global_TV_AllCategories:=object()
	global_TV_AllEntries:=object()

	for oneSection, oneSectionContent in global_allTranslations[mainlanguagecode]
	{
		global_TV_AllCategories[oneSection]:={ID: TV_Add(oneSection)}
		for oneKey, oneValue in oneSectionContent
		{
			global_TV_AllEntries[oneKey]:={ID: TV_Add(oneKey, global_TV_AllCategories[oneSection].id), Category: oneSection}
		}
	}
}

; react if user either selects an item in treeview or changes the language in listview
GuiListSelect()
{
	global
	gui, main: default

	if (A_GuiEvent = "i" or A_GuiEvent = "c")
		return

	; get text of selected item in TV
	SelectedKey_TV_ID := TV_GetSelection()
	if not SelectedKey_TV_ID
		return
	
	TV_GetText(SelectedItemText, SelectedKey_TV_ID)
	SelectedSection_TV_ID := TV_GetParent(SelectedKey_TV_ID)
	TV_GetText(SelectedCategoryText, SelectedSection_TV_ID)

	if SelectedSection_TV_ID ;If an item is selected (otherwise SelectedSection_TV_ID is empty)
	{
		; write all translations of that element in the listview
		for oneIndex, oneLang in global_allLangs
		{
			LV_Modify(a_index, "", global_langInfo[oneLang].name, global_allTranslations[oneLang][SelectedCategoryText][SelectedItemText])
		}
		
		; get selected language in LV
		SelectedLanguageNr := LV_Getnext(0) ;Which Row is selected
		if SelectedLanguageNr
		{
			; get value from LV
			SelectedLanguageID := global_allLangs[SelectedLanguageNr]
			LV_Gettext(temptext, SelectedLanguageNr, 2) 
			
			; replace linefeeds
			StringReplace, temptext, temptext, ``n, `n, all

			; enable the edit field and set the text
			guicontrol, Enable, EditField
			guicontrol,, EditField, %temptext%
		}
		else
		{
			; disable and empty the edit field
			guicontrol, disable, EditField
			guicontrol,, EditField,
		}
		
		
	}
	else ;If a category is selected
	{
		for oneIndex, oneLang in global_allLangs
		{
			LV_Modify(a_index, "", global_langInfo[oneLang].name, "")
		}
		guicontrol,disable,EditField
		guicontrol,,EditField,
	}
}

; user changed something in the edit field
EditField()
{
	global
	gui, main:default
	
	if not SelectedLanguageID
	{
		MsgBox,  unexpected error 1.
		return
	}
	if not SelectedItemText
	{
		MsgBox,  unexpected error 2.
		return
	}
	if not SelectedCategoryText
	{
		MsgBox,  unexpected error 3.
		return
	}
	gui, submit, NoHide
	
	; replace the linefeeds
	stringreplace, EditFieldCorrected, EditField, `n, ``n, all

	; update entry in variable.
	if not (global_allTranslations[SelectedLanguageID][SelectedCategoryText])
		global_allTranslations[SelectedLanguageID][SelectedCategoryText] := []
	global_allTranslations[SelectedLanguageID][SelectedCategoryText][SelectedItemText] := EditFieldCorrected

	; write entry to the ini file. Delete if field is empty
	if EditFieldCorrected=
		IniDelete, %SelectedLanguageID%.ini, %SelectedCategoryText%, %SelectedItemText%
	else
		iniwrite, %EditFieldCorrected%, %SelectedLanguageID%.ini, %SelectedCategoryText%, %SelectedItemText%
	if errorlevel
		MsgBox, % "Error writing to " SelectedLanguageID ".ini"


	; change value in LV
	LV_Modify(SelectedLanguageNr, "", global_langInfo[SelectedLanguageID].name, EditFieldCorrected)
}
return


;Select all elements which are complete

ButtonFindUntranslated()
{
	global
	gui, main: default
	gui, submit, nohide

	for tempCategoryName, tempCategoryObject in global_TV_AllCategories
	{
		global_TV_AllCategories[tempCategoryName].isComplete:=true
	}

	for oneEntryKey, OneEntryObject in global_TV_AllEntries
	{
		if (not global_allTranslations[DropDownLanguage][OneEntryObject.category][oneEntryKey])
		{
			TV_Modify(OneEntryObject.id ,"bold")
			global_TV_AllCategories[OneEntryObject.category]["isComplete"] := false
		}
		else
		{
			TV_Modify(OneEntryObject.id ,"-bold")
		}
		
		
	}
	for OneCategoryKey, OneCategoryObject in global_TV_AllCategories
	{
		if (OneCategoryObject.isComplete = true)
			TV_Modify(OneCategoryObject.id, "-bold")
		else
			TV_Modify(OneCategoryObject.id, "bold")
	}
}

ButtonSearch()
{
	global
	gui, main: default
	gui, submit, nohide

	for tempCategoryName, tempCategoryObject in global_TV_AllCategories
	{
		global_TV_AllCategories[tempCategoryName].isComplete:=true
	}

	for oneEntryKey, OneEntryObject in global_TV_AllEntries
	{
		if (instr(global_allTranslations[DropDownLanguage][OneEntryObject.category][oneEntryKey], Editsearch))
		{
			TV_Modify(OneEntryObject.id ,"bold")
			global_TV_AllCategories[OneEntryObject.category]["isComplete"] := false
		}
		else
		{
			TV_Modify(OneEntryObject.id ,"-bold")
		}
		
		
	}
	for OneCategoryKey, OneCategoryObject in global_TV_AllCategories
	{
		if (OneCategoryObject.isComplete = true)
			TV_Modify(OneCategoryObject.id, "-bold")
		else
			TV_Modify(OneCategoryObject.id, "bold")
	}
}

; if user enters something in the button
EditSearch()
{
	gui, main:default
	guicontrol,+default,buttonsearch
}

HotkeyNextEntry()
{
	global treeViewHWND
	
	if a_thishotkey = pgup
		controlsend,, {up}, ahk_id %treeViewHWND%
	else
		controlsend,, {down}, ahk_id %treeViewHWND%
}
return


mainguiclose:
exitapp



ButtonAddNewLanguage:
gui,2:destroy
gui,2:add,text,w200, Language ID consisting of two letters
gui,2:add,edit,w200 vNewLangId
gui,2:add,text,w200, Name of language in English
gui,2:add,edit,w200 vNewLangEnName
gui,2:add,text,w200, Name of language in the new language
gui,2:add,edit,w200 vNewLangName
gui,2:add,button,w95 default gNewLangOK,OK
gui,2:add,button,X+10 yp w95 gNewLangCancel,Cancel
gui,2:show,,New language
return

NewLangOK:
gui,2:submit,nohide
if NewLangId=
{
	MsgBox,0,Error,Please enter language ID
	return
}
if strlen(NewLangId)!=2
{
	MsgBox,0,Error,Language ID must consist of two letters
	return
}
if NewLangName=
{
	MsgBox,0,Error,Please enter language Name
	return
}
if NewLangEnName=
{
	MsgBox,0,Error,Please enter language Name
	return
}
IniWrite, % NewLangEnName, %NewLangId%.ini, language_info, enname
iniWrite, % NewLangName, %NewLangId%.ini, language_info, name
loadLanguages()

gui,2:destroy
return

NewLangCancel:
gui,2:destroy
return


; written by Paul Bichler
; license: WTFPL

; reads ini content from string
; returns a 2-dimensional array
importIni(fileContent)
{
    iniContent := []

	StringReplace, fileContent, fileContent, `r, `n, all

	loop, parse, fileContent, `n, % a_space a_tab
	{
		oneLine := A_LoopField
		if not oneLine
			continue
		
		if (substr(oneLine, 1, 1) = "[" and substr(oneLine, 0, 1) = "]")
		{
			currentSection := substr(oneLine, 2, -1)
			iniContent[currentSection] := []
			continue
		}

		onePos := instr(oneLine, "=")
		if (not onePos)
		{
			return "Line " a_index " has no euqal sign: " oneLine
		}
		oneKey := trim(substr(oneLine, 1, onePos - 1))
		oneValue := trim(substr(oneLine, onePos + 1))

		if (currentSection = "" and not iniContent[currentSection])
			iniContent[currentSection] := []
		
		iniContent[currentSection][oneKey] := oneValue
	}
    return iniContent
}

; writes ini content to string
exportIni(iniContent)
{
	fileContent := []

	for oneSection, oneSectionContent in iniContent
	{
		fileContent .= "[" oneSection "]`n"
		for oneKey, oneValue in oneSectionContent
		{
			fileContent .= oneKey "=" oneValue "`n"
		}
	}

	return fileContent
}