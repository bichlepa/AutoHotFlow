#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#Include language.ahk
#include strobj.ahk


gui, add, TreeView ,gAction x10 y40 w250 h400

Gui, Add, ListView,gAction AltSubmit nosort grid yp X+10 w450 h100,Language|Text
gui,font,s12
gui, add, edit,gEditField vEditField xp Y+10 h290 w450 
gui,font,s8

;~ gui,add,button,gNewEntry x10 Y+10,New Entry
;~ gui,add,button,gEintragLöschen yp X+10,Delete Entry
;~ gui,add,button,gNeueKategorie yp X+10,New Category
;~ gui,add,button,gKategorieLöschen yp X+10,Delete Category

LV_Modify(2, "Select") ;Zweite Sprache auswählen
loadLanguageList()
updateTreeView()
;~ gui,+resize ;TODO
gui, show
return



loadLanguageList()
{
	global
	allLangs:=Object()
	
	Loop,%A_WorkingDir%\*.ini
	{
		StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
		
		IniRead,%filenameNoExt%enlangname,%filenameNoExt%.ini,general,enname
		IniRead,%filenameNoExt%langname,%filenameNoExt%.ini,general,name
		if %filenameNoExt%enlangname!=Error
		{
			
			allLangs[filenameNoExt]:={enlangname: %filenameNoExt%enlangname,langname: %filenameNoExt%langname}
			langNumber%a_index%:=filenameNoExt
		}
		stringalllangs:=stringalllangs filenameNoExt " (" %filenameNoExt%enlangname " - "  %filenameNoExt%langname ")`n"
		;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
		lv_add("",%filenameNoExt%langname,"")
	}
	
}


updateTreeView()
{
	global
	local temp
	local tempCategory
	local tempItemName
	TV_Delete()
	
	AllCategories:=object()
	AllItems:=object()
	
	loop,read,en.ini
	{
		
		ifinstring,a_loopreadline,[
			ifinstring,a_loopreadline,]
			{
				tempCategory:=trim(a_loopreadline,"[]")
				AllCategories[tempCategory]:={ID: TV_Add(tempCategory)} ;insert the id of the category
			}
		
		ifinstring,a_loopreadline,=
		{
			
			stringgetpos,pos,a_loopreadline,=
			stringleft,tempItemName,a_loopreadline,%pos%
			
			AllItems[tempItemName]:={ID: TV_Add(tempItemName,AllCategories[tempCategory]["id"])}
			
			;~ IDItem%ItemCounter%:=TV_Add(tempItemName,tempCategory)
			;~ if (neuname=Item%ItemCounter%) ;Für den Fall, dass man ein neues Item einfügt
			;~ {
				;~ neuname=nix
				;~ neuItemID:=IDItem%ItemCounter%
			;~ }
				
			
			
		}
		
	}
	;~ MsgBox % strobj(AllCategories)
	;~ MsgBox % strobj(AllItems)
}

Action:
SelectedItemID:=TV_GetSelection()
TV_GetText(SelectedItemText, SelectedItemID)
SelectedCategoryID:=TV_GetParent(SelectedItemID)
TV_GetText(SelectedCategoryText, SelectedCategoryID)

;~ MsgBox % SelectedItemID ": " SelectedItemText "`n" SelectedCategoryID ": " SelectedCategoryText


if SelectedCategoryID ;If an item is selected
{
	;~ MsgBox % strobj(allLangs)
	for templang, langobject in allLangs
	{
		
		iniread,tempText,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%,%a_space%
		;~ MsgBox %templang% - %SelectedCategoryText% - %SelectedItemText% - %tempText%
		LV_Modify(a_index,"",langobject.langname,tempText)
		
		
		
	}
	
	SelectedLangNr:=LV_Getnext(0) ;Which Row is selected
	if SelectedLangNr
	{
		SelectedLanguageID:=langNumber%SelectedLangNr%
		
		LV_Gettext(temptext,SelectedLangNr,2) 
		
		StringReplace,temptext,temptext,``n,`n,all
		guicontrol,,EditField,%temptext%
	}
	else
		guicontrol,,EditField,
	
	
}
else ;Wenn eine Kategorie gewählt ist
{
	for templang, langobject in allLangs
	{
		
		iniread,tempText,%templang%.ini,%SelectedCategoryText%,%SelectedItemText%,%a_space%
		
		LV_Modify(a_index,"",langobject.langname,tempText)
		
		
		
	}
	guicontrol,,EditField,
}



return
EditField:
if not ChosenLanguageID
	return
if not SelectedItemText
	return
if not SelectedCategoryText
	return
gui,submit,NoHide

stringreplace,EditFieldCorrected,EditField,`n,``n,all
iniwrite,%EditFieldCorrected%,%ChosenLanguageID%.ini,%SelectedCategoryText%,%SelectedItemText%
;~ LV_Modify(gewählteSpracheNr,"",SpracheGewählt%gewählteSpracheNr%,EditFeld)


return

allLangs:=Object()
stringalllangs=`n
Loop,%A_WorkingDir%\*.ini
{
	StringReplace,filenameNoExt,A_LoopFileName,.%A_LoopFileExt%
	
	IniRead,%filenameNoExt%enlangname,%filenameNoExt%.ini,general,enname
	IniRead,%filenameNoExt%langname,%filenameNoExt%.ini,general,name
	if %filenameNoExt%enlangname!=Error
	{
		allLangs.insert(filenameNoExt)
		
	}
	stringalllangs:=stringalllangs filenameNoExt " (" %filenameNoExt%enlangname " - "  %filenameNoExt%langname ")`n"
	;MsgBox %  filenameNoExt "|" %filenameNoExt%langname
}



InputBox,translationto,Select Language,To which language do you want to translate?`nEnter a new short code or one of following codes:`n%stringalllangs%,,,% A_ScreenHeight*0.9

IfnotInString,stringalllangs,`n%translationto% (
{
	
	MsgBox,4,Question, %translationto% does not exist yet. Do you want to add a new language?
	allLangs.insert(translationto)
	IfMsgBox,yes
	{
		InputBox,%translationto%enlangname,Enter language name,What is the English name of the new language?
		if errorlevel
			ExitApp
		InputBox,%translationto%langname,Enter language name,% "What is the name of the new language in " %translationto%enlangname "?"
		if errorlevel
			ExitApp
		IniWrite,% %translationto%enlangname,%translationto%.ini,general,enname
		IniWrite,% %translationto%langname,%translationto%.ini,general,name
	}
	else
		ExitApp
	
}

UILang:=translationto
developing=yes

StringReplace,newWorkingDir,a_Scriptdir,\language
SetWorkingDir,%newWorkingDir%
Comma=,
loop %A_WorkingDir%\*.ahk,1,1
{
	;MsgBox %A_LoopFileFullPath%
	if A_LoopFileName=language.ahk
		continue
	
	FileRead,ahkFileContent,%A_LoopFileFullPath%
	tempFoundPos=1
	Loop
	{
		tempFoundPos:=RegExMatch(ahkFileContent, "U)lang\(""(.+"")", tempVariablesToReplace,tempFoundPos +1)
		if tempFoundPos=0
			break
		currentfile:=A_LoopFileFullPath
		ToolTip, %A_LoopFileFullPath% %tempFoundPos%
		StringGetPos,pos,tempVariablesToReplace1,"
		if pos
			StringLeft,tempVariablesToReplace1,tempVariablesToReplace1,%pos%
		else
		{
			MsgBox, error! could not exract the
			
		}
		
		ToolTip, %A_LoopFileFullPath% %tempFoundPos% %tempVariablesToReplace1%
		SetTimer,langremovetooltip,-5000
		lang(tempVariablesToReplace1)
		
	}
}
MsgBox Everything is translated! :-)
ExitApp

langremovetooltip:
ToolTip
return