goto,jumpOverFunctionsFunctionsForElementGetWindowInformation

FunctionsForElementGetWindowInformation:
FunctionsForElementGetWindowInformationGetControlInformationAfterwards:=false
ui_disableElementSettingsWindow()
FunctionsForElementGetWindowInformation2:
gui,2:default
gui,submit,nohide

DetectHiddenWindows,off

;~ winWholelist=
;~ loop %winlist%
;~ {
	;~ WinGetTitle,title,% "ahk_id " winlist%a_index%
	;~ winWholelist.=winlist%a_index% "|"
	
;~ }
;~ MsgBox %winWholelist%


gui, FunctionsForElementGetWindowInformation:Default

gui,add,text,x10 w400 ,% lang("Select_a_window_which_you_want_to_import")
gui,add,text,X+10 ,% lang("Optinally select some text of a control in window")
gui,add,checkbox,x10 w400 vFunctionsForElementGetWindowInformationCheckBoxFindHiddenWindows gFunctionsForElementGetWindowInformationUpdateWindowlist,% lang("Find hidden windows")
gui,add,checkbox,X+10 w400 vFunctionsForElementGetWindowInformationCheckBoxFindHiddenText gFunctionsForElementGetWindowInformationListBoxTitles checked,% lang("Find hidden text")
gui,add,button,x10 w400 h30 gFunctionsForElementGetWindowInformationUpdateWindowlist,% lang("Update window list")
gui,add,listbox,x10 w400 h500 AltSubmit vFunctionsForElementGetWindowInformationListBoxTitles gFunctionsForElementGetWindowInformationListBoxTitles
gui,add,listbox,w400 h500 X+10 vFunctionsForElementGetWindowInformationListBoxControlTexts
gui,add,checkbox,w400 vFunctionsForElementGetWindowInformationCheckBoxImportUniqueIDs,% lang("Also_import_unique_IDs")

gui,add,button,w400 h30 default gFunctionsForElementGetWindowInformationButtonOK,% lang("OK")
gosub FunctionsForElementGetWindowInformationUpdateWindowlist
if tempCountOfWindows>0
{
	gui,+hwndFunctionsForElementGetWindowInformationHWND
	gui,show
	SetTimer,FunctionsForElementGetWindowInformationGetWindowCoveredByMouse,100
	return
}
else
{
	MsgBox,0,% lang("Error"), lang("No windows found.")
	goto,FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn
	
}


return

;user selects a new window
FunctionsForElementGetWindowInformationListBoxTitles:
gui,submit,NoHide
tempWinID:=tempParWinID%FunctionsForElementGetWindowInformationListBoxTitles%
WinGetPos,tempwinx,tempwiny,tempwinw,tempwinh,% "ahk_id " tempWinID

ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,0,0,tempwinw,tempwinh)

;Get all controls of window
winget,tempControlList,ControlListHwnd,% "ahk_id " tempWinID
;~ ToolTip %tempControlList%
guicontrol,,FunctionsForElementGetWindowInformationListBoxControlTexts,|
loop,parse,tempControlList,`n
{
	if not FunctionsForElementGetWindowInformationCheckBoxFindHiddenText
	{
		controlget,tempVisible,visible,,,ahk_id %a_loopfield%
		if tempVisible
			continue
	}
	
	ControlGetText,tempparText,,ahk_id %a_loopfield%
	
	if tempparText= ;Skip controls that have no text
		continue
	
	
	;~ stringleft,tempparText,tempparText,100
	
	StringReplace,tempparText,tempparText,`r
	StringReplace,tempparText,tempparText,`n,¶
	StringReplace,tempparText,tempparText,|,_
	guicontrol,,FunctionsForElementGetWindowInformationListBoxControlTexts,%tempparText%

	
	
}

SetTimer,FunctionsForElementGetControlInformationRemoveShape,-2000
return

;User clicks on OK. The selected window will be imported
FunctionsForElementGetWindowInformationButtonOK:
SetTimer,FunctionsForElementGetWindowInformationGetWindowCoveredByMouse,off

gui,submit
gui,destroy
gui,2:default
tempWinID:=tempParWinID%FunctionsForElementGetWindowInformationListBoxTitles%
WinGetTitle,temp,ahk_id %tempWinID%
guicontrol,,GUISettingsOfElement%setElementID%Wintitle,%temp%
WinGetclass,temp,ahk_id %tempWinID%
guicontrol,,GUISettingsOfElement%setElementID%ahk_class,%temp%
WinGet,temp,processName,ahk_id %tempWinID%
guicontrol,,GUISettingsOfElement%setElementID%ahk_exe,%temp%

guicontrol,,GUISettingsOfElement%setElementID%excludeTitle,
guicontrol,,GUISettingsOfElement%setElementID%ExcludeText,

guicontrol,,GUISettingsOfElement%setElementID%winText,%FunctionsForElementGetWindowInformationListBoxControlTexts%


guicontrol,,GUISettingsOfElement%setElementID%findhiddenwindow,%FunctionsForElementGetWindowInformationCheckBoxFindHiddenWindows%
guicontrol,,GUISettingsOfElement%setElementID%findhiddentext,%FunctionsForElementGetWindowInformationCheckBoxFindHiddenText%

if FunctionsForElementGetWindowInformationCheckBoxImportUniqueIDs=1
{
	WinGet,temp,pid,ahk_id %tempWinID%
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid,%temp%
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id,%tempWinID%
}
else
{
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid,
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id,
	
}

if FunctionsForElementGetWindowInformationGetControlInformationAfterwards
{
	FunctionsForElementGetControlInformationWinID:=tempWinID
	goto,FunctionsForElementGetControlInformation2
}
else
	ui_EnableElementSettingsWindow()
return








FunctionsForElementGetWindowInformationEscape:
gui,destroy
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()
return

FunctionsForElementGetWindowInformationGuiClose:
gui,destroy
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()
return

FunctionsForElementGetWindowInformationUpdateWindowlist:
gui,submit,nohide
;~ ToolTip update
if FunctionsForElementGetWindowInformationCheckBoxFindHiddenWindows
	DetectHiddenWindows,on
else
	DetectHiddenWindows,off
if FunctionsForElementGetWindowInformationCheckBoxFindHiddenText
	DetectHiddentext,on
else
	DetectHiddentext,off
WinGet,winlist,List
tempCountOfWindows=0
completelist=
;~ guicontrol,FunctionsForElementGetWindowInformation:,FunctionsForElementGetWindowInformationListBoxTitles,|
loop %winlist%
{
	
	;~ winWholelist.=winlist%a_index%"|"
	
	tempParWinID%a_index%:=winlist%a_index%
	
	WinGetTitle,title,% "ahk_id " winlist%a_index%
	WinGetclass,classe,% "ahk_id " winlist%a_index%
	tempParWinTitle%a_index%:=title
	tempParWinclass%a_index%:=classe
	
	completelist.="|"classe " ► " title 
	
	
	
	tempCountOfWindows++
	
	
}
guicontrol,FunctionsForElementGetWindowInformation:,FunctionsForElementGetWindowInformationListBoxTitles,% completelist
return


FunctionsForElementGetWindowInformationGetWindowCoveredByMouse:
;get the mouse position and the control that is covered by the mouse
MouseGetPos,tempmousex,tempmousey,tempwinidundermouse,tempcontrol

if (tempwinidundermouse!="") ;Check whether the mouse is over the right window and coveres a control
{
	if (tempmousex!=tempmouseOldx or tempmousey!=tempmouseOldy) ;Prevent to adapt the control while mouse is moving
	{
		
		tempmouseOldx:=tempmousex
		tempmouseOldy:=tempmousey
		tempLastChoosenWin=
	}
	else
	{
		if (tempLastChoosenWin!=tempwinidundermouse and FunctionsForElementGetWindowInformationHWND!=tempwinidundermouse)
		{
			;Select the control that is covered by mouse
			found:=false
			Loop,%tempCountOfWindows%
			{
			
				if (tempwinidundermouse=tempParWinID%a_index%)
				{
					;ToolTip("tempwinidundermouse: " tempwinidundermouse " tempcontrol:" tempcontrol " tempParControlID%a_index%: " tempParControlID%a_index% " a_index: " a_index)
					guicontrol,FunctionsForElementGetWindowInformation:choose,FunctionsForElementGetWindowInformationListBoxTitles,|%a_index%
					tempLastChoosenWin:=tempwinidundermouse
					found:=true
					break
				}
				
			}
			if not found
			{
				tempCountOfWindows++
				WinGetTitle,title,% "ahk_id " tempwinidundermouse
				WinGetclass,classe,% "ahk_id " tempwinidundermouse
				tempParWinTitle%tempCountOfWindows%:=title
				tempParWinclass%tempCountOfWindows%:=classe
				tempParWinID%tempCountOfWindows%:=tempwinidundermouse
				guicontrol,FunctionsForElementGetWindowInformation:,FunctionsForElementGetWindowInformationListBoxTitles,% classe " ► " title 

				guicontrol,FunctionsForElementGetWindowInformation:choose,FunctionsForElementGetWindowInformationListBoxTitles,|%tempCountOfWindows%
			}
		}
	}
}

;additionally check whether the window has been moved

return


jumpOverFunctionsFunctionsForElementGetWindowInformation:
temp:=temp