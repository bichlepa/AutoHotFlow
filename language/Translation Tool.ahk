#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#Include language.ahk

;parameters
mainlanguagecode:="en"


gui,main:default
gui, add, dropdownlist,vDropDownLanguage  x10 y10 w70

gui, add, button, gButtonFindUntranslated y10 X+10, Find untranslated entries

gui, add, Edit, vEditSearch gEditSearch y10 X+30, 
gui, add, button, gButtonSearch vButtonSearch y10 X+10, Search

gui, add, button, gButtonAddNewLanguage y10 X+30, Add new language

;Only for developers. Translators will not need that
if not a_iscompiled
	gui, add, button, gButtonChangeCategory y10 X+10, Change category


gui, add, TreeView ,gAction x10 y40 w250 h500 hwndtreeViewHWND


Gui, Add, ListView,gAction AltSubmit nosort grid yp X+10 w450 h200,Language|Text
gui,font,s12
gui, add, edit,gEditField vEditField xp Y+10 h290 w450 disabled
gui,font,s8
gui,+hwndMainGuiHWND

LV_Modify(2, "Select") ;Zweite Sprache auswählen
loadLanguageList()
updateTreeView()
;~ gui,+resize ;TODO
gui, show
hotkey,IfWinActive,ahk_id %MainGuiHWND%
hotkey,pgdn,HotkeyNextEntry
hotkey,pgup,HotkeyNextEntry
return



loadLanguageList()
{
	global
	gui,main:default
	allLangs:=Object()
	local langname
	local enlangname
	local filenameNoExt
	lv_delete()
	LanguageListString=|
	Loop,%A_WorkingDir%\*.ini
	{
		StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
		
		IniRead,enlangname,%filenameNoExt%.ini,language_info,enname
		IniRead,langname,%filenameNoExt%.ini,language_info,name
		if enlangname!=Error
		{
			LanguageListString.=filenameNoExt "|"
			allLangs[filenameNoExt]:={enlangname: enlangname,langname: langname}
			langNumber%a_index%:=filenameNoExt
		}
		lv_add("",langname,"")
	}
	
	stringreplace,LanguageListString,LanguageListString,|en|,|en||
	;~ MsgBox %LanguageListString%
	guicontrol, ,DropDownLanguage,%LanguageListString%
}


updateTreeView()
{
	global
	gui,main:default
	local temp
	local tempCategory
	local tempItemName
	TV_Delete()
	
	AllCategories:=object()
	AllItems:=object()
	loop,read,%mainlanguagecode%.ini
	{
		
		ifinstring,a_loopreadline,[
			ifinstring,a_loopreadline,]
			{
				tempCategory:=trim(a_loopreadline)
				tempCategory:=trim(a_loopreadline,"[]")
				if tempCategory!=language_info
					AllCategories[tempCategory]:={ID: TV_Add(tempCategory)} ;insert the id of the category
			}
			
		if tempCategory=language_info
			continue
		
		ifinstring,a_loopreadline,=
		{
			stringgetpos,pos,a_loopreadline,=
			stringleft,tempItemName,a_loopreadline,%pos%
			
			AllItems[tempItemName]:={ID: TV_Add(tempItemName,AllCategories[tempCategory]["id"]),Category: tempCategory}
		}
		
	}
}

Action:
gui,main:default
if (A_GuiEvent = "i" or A_GuiEvent = "c")
	return

SelectedItemID:=TV_GetSelection()
if not SelectedItemID
	return
TV_GetText(SelectedItemText, SelectedItemID)
SelectedCategoryID:=TV_GetParent(SelectedItemID)
TV_GetText(SelectedCategoryText, SelectedCategoryID)

;~ MsgBox % SelectedItemID ": " SelectedItemText "`n" SelectedCategoryID ": " SelectedCategoryText


if SelectedCategoryID ;If an item is selected
{
	for templang, langobject in allLangs
	{
		
		iniread,tempText,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%,%a_space%
		
		if tempText=
		{
			IniRead,iniAllSections,%templang%.ini
			;~ MsgBox %iniAllSections%
			Loop,parse,iniAllSections,`n
			{
				
				IniRead,tempText,%templang%.ini,%a_loopfield%,%SelectedItemText%,%A_Space%
				if tempText
				{
					IniDelete,%templang%.ini,%a_loopfield%,%SelectedItemText%
					IniWrite,%tempText%,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%
					break
				}
			}
		}
		;~ MsgBox %templang% - %SelectedCategoryText% - %SelectedItemText% - %tempText%
		LV_Modify(a_index,"",langobject.langname,tempText)
		
		
		
	}
	
	SelectedLanguageNr:=LV_Getnext(0) ;Which Row is selected
	if SelectedLanguageNr
	{
		SelectedLanguageID:=langNumber%SelectedLanguageNr%
		
		LV_Gettext(temptext,SelectedLanguageNr,2) 
		
		StringReplace,temptext,temptext,``n,`n,all
		guicontrol,Enable,EditField
		guicontrol,,EditField,%temptext%
	}
	else
	{
		guicontrol,disable,EditField
		guicontrol,,EditField,
	}
	
	
}
else ;If a category is selected
{
	for templang, langobject in allLangs
	{
		
		LV_Modify(a_index,"",langobject.langname,"")
		
	}
	guicontrol,disable,EditField
	guicontrol,,EditField,
}

;~ guicontrol,focus,EditField

return

EditField:
gui,main:default
;~ MsgBox % SelectedLanguageID " - " SelectedItemText "-" SelectedCategoryText
if not SelectedLanguageID
	return
if not SelectedItemText
	return
if not SelectedCategoryText
	return
gui,submit,NoHide
;~ SoundBeep
stringreplace,EditFieldCorrected,EditField,`n,``n,all
if EditFieldCorrected=
	IniDelete,%SelectedLanguageID%.ini,%SelectedCategoryText%,%SelectedItemText%
else
	iniwrite,%EditFieldCorrected%,%SelectedLanguageID%.ini,%SelectedCategoryText%,%SelectedItemText%
LV_Modify(SelectedLanguageNr,"",allLangs[SelectedLanguageID].langname,EditFieldCorrected)
return

ButtonChangeCategory:
gui,main:default
if not SelectedItemText
	return
if not SelectedCategoryText
	return

try menu,MenuCategory,DeleteAll
for tempCategoryName, tempCategoryObject in AllCategories
{
	menu,MenuCategory,add,%tempCategoryName%,MenuChangeCategory
	if (tempCategoryName=SelectedCategoryText)
		menu,MenuCategory,check,%tempCategoryName%
}
menu,MenuCategory,add,--- New category ---,MenuChangeCategory
menu,menucategory,show
return
MenuChangeCategory:
gui,main:default
Critical
;~ MsgBox %A_ThisMenuItem% %SelectedLanguageID%
if (a_thismenuitem=SelectedCategoryText)
	return
if (a_thismenuitem="")
	return
if (a_thismenuitem="--- New category ---")
{
	InputBox,ToChangeCategory,New category,Enter new category name for item '%SelectedItemText%'
	if not ToChangeCategory
		return
	if ToChangeCategory = language_info
	{
		MsgBox category name "language_info" is forbidden
		return
	}
	if not AllCategories.haskey(ToChangeCategory)
		AllCategories[ToChangeCategory]:={ID: TV_Add(ToChangeCategory)} ;insert the id of the category
}
else
{
	ToChangeCategory:=a_thismenuitem
}

TV_Delete(SelectedItemID)

AllItems[SelectedItemText]:={ID: TV_Add(SelectedItemText,AllCategories[ToChangeCategory]["id"])}

for templang, langobject in allLangs
{
	iniRead,tempText,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%,%a_space%
	IniDelete,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%
	iniwrite,%tempText%,%templang%.ini,%ToChangeCategory%,%SelectedItemText%
}

return

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
IniWrite,% NewLangEnName,%NewLangId%.ini,language_info,enname
iniWrite,% NewLangName,%NewLangId%.ini,language_info,name
loadLanguageList()
updateTreeView()
gui,2:destroy
return

;Mark all elements which are complete

ButtonFindUntranslated:
gui,main:default
gui,submit,nohide
;~ MsgBox %DropDownLanguage%
for tempCategoryName, tempCategoryObject in AllCategories
{
	AllCategories[tempCategoryName].isComplete:=true
}
for DropDowntempItem, DropDowntempItemObject in AllItems
{
	
	
	iniread,DropDowntempText,%DropDownLanguage%.ini,% DropDowntempItemObject.category,% DropDowntempItem,%a_space%
	
	
	
	;~ ToolTip % DropDowntempItem " - " DropDowntempItemObject.id " - " DropDowntempItemObject.category "`n" DropDowntempText
	if DropDowntempText=
	{
		TV_Modify(DropDowntempItemObject.id ,"bold")
		;~ MsgBox % DropDowntempItemObject.category " - " AllCategories[DropDowntempItemObject.category]["isComplete"]
		AllCategories[DropDowntempItemObject.category]["isComplete"]:=false
		;~ MsgBox % AllCategories[DropDowntempItemObject.category]["isComplete"]
	}
	else
	{
		TV_Modify(DropDowntempItemObject.id ,"-bold")
	}
	
	
}
for tempCategoryName, tempCategoryObject in AllCategories
{
	if (tempCategoryObject.isComplete=true)
		TV_Modify(tempCategoryObject.id ,"-bold")
	else
		TV_Modify(tempCategoryObject.id ,"bold")
}
return

ButtonSearch:
gui,main:default
gui,submit,nohide
for tempCategoryName, tempCategoryObject in AllCategories
{
	AllCategories[tempCategoryName].isComplete:=true
}
for DropDowntempItem, DropDowntempItemObject in AllItems
{

	iniread,DropDowntempText,%DropDownLanguage%.ini,% DropDowntempItemObject.category,% DropDowntempItem,%a_space%
	

	
	;~ ToolTip % DropDowntempItem " - " DropDowntempItemObject.id " - " DropDowntempItemObject.category "`n" DropDowntempText
	ifinstring,DropDowntempText,%Editsearch%
	{
		TV_Modify(DropDowntempItemObject.id ,"bold")
		;~ MsgBox % DropDowntempItemObject.category " - " AllCategories[DropDowntempItemObject.category]["isComplete"]
		AllCategories[DropDowntempItemObject.category]["isComplete"]:=false
		;~ MsgBox % AllCategories[DropDowntempItemObject.category]["isComplete"]
	}
	else
	{
		TV_Modify(DropDowntempItemObject.id ,"-bold")
	}
	
	
}
for tempCategoryName, tempCategoryObject in AllCategories
{
	if (tempCategoryObject.isComplete=true)
		TV_Modify(tempCategoryObject.id ,"-bold")
	else
		TV_Modify(tempCategoryObject.id ,"bold")
}

return

EditSearch:
gui,main:default
guicontrol,+default,buttonsearch
return

HotkeyNextEntry:
gui,main:default
if a_thishotkey=pgup
	controlsend,,{up},ahk_id %treeViewHWND%
else
	controlsend,,{down},ahk_id %treeViewHWND%

return
NewLangCancel:
gui,2:destroy
return