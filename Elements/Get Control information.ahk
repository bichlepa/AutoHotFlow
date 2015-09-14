goto,jumpOverFunctionsFunctionsForElementGetControlInformation

FunctionsForElementGetControlInformation:
ui_disableElementSettingsWindow()
FunctionsForElementGetWindowInformationGetControlInformationAfterwards:=true
goto,FunctionsForElementGetWindowInformation2

FunctionsForElementGetControlInformation2:




gui,SettingsOfElement:default
gui,submit,nohide




winget,tempPar,ControlList,ahk_id %FunctionsForElementGetControlInformationWinID% ;Get all controls in the window
;~ MsgBox,%tempPar%
gui, FunctionsForElementGetControlInformation:Default

gui,add,text,w400 ,% lang("Select_a_control_text_which_you_want_to_import")
gui,add,listbox,w400 h500 AltSubmit vFunctionsForElementGetControlInformationListBoxOfContolTexts gFunctionsForElementGetControlInformationListBoxOfContolTexts
if (GUISettingsOfElement%setElementID%IdentifyControlBy1=1)
{
	gui,add,radio,w400 checked vFunctionsForElementGetControlInformationRadioImportControlText,% lang("Import_Text_in_control")
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlClassNN,%  lang("Import Classname and instance number of the control")
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlHWND,%  lang("Import unique control ID of the control")
}
else if (GUISettingsOfElement%setElementID%IdentifyControlBy2=1)
{
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlText,% lang("Import_Text_in_control")
	gui,add,radio,w400 checked vFunctionsForElementGetControlInformationRadioImportControlClassNN,%  lang("Import Classname and instance number of the control")
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlHWND,%  lang("Import unique control ID of the control")
}
else if (GUISettingsOfElement%setElementID%IdentifyControlBy3=1)
{
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlText,% lang("Import_Text_in_control")
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlClassNN,%  lang("Import Classname and instance number of the control")
	gui,add,radio,w400 checked vFunctionsForElementGetControlInformationRadioImportControlHWND,%  lang("Import unique control ID of the control")
}
gui,add,button,w400 h30 default gFunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn,% lang("OK")
tempCountOfControlsInWindow=0

loop,parse,tempPar,`n
{
	ControlGetText,tempparText,%a_loopfield%,ahk_id %FunctionsForElementGetControlInformationWinID%
	ControlGet,tempparControlID,hwnd,,%a_loopfield%,ahk_id %FunctionsForElementGetControlInformationWinID%
	
	tempParControlClassNN%a_index%:=a_loopfield
	tempParControlID%a_index%:=tempparControlID
	tempParText%a_index%:=tempparText
	
	StringReplace,tempparText,tempparText,`r
	StringReplace,tempparText,tempparText,`n,¶
	StringReplace,tempparText,tempparText,|,_
	;~ stringleft,tempparText,tempparText,100
	guicontrol,,FunctionsForElementGetControlInformationListBoxOfContolTexts,%a_loopfield% ► %tempparText%
	
	tempCountOfControlsInWindow++
	
	
}
if tempCountOfControlsInWindow>0
{
	DetectHiddenWindows on
	gui,+hwndFunctionsForElementGetControlInformationHWND
	gui,show,hide
	wingetpos,tempParentX,tempParentY,tempParentW,tempParentH,ahk_id %SettingsGUIHWND%
	
	wingetpos,,,tempWidth,tempHeight,ahk_id %FunctionsForElementGetControlInformationHWND%
	tempXpos:=round(tempParentX+tempParentW/2- tempWidth/2)
	tempYpos:=round(tempParentY+tempParentH/2- tempHeight/2)
	;~ MsgBox %tempWidth% %FunctionsForElementGetControlInformationHWND%
	gui,show,x%tempXpos% y%tempYpos%,% lang("Window assistant")
	
	SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,100
	return
}
else
{
	MsgBox,16,% lang("Error"),% lang("This window seems not to have controls")
	goto,FunctionsForElementGetControlInformationGuiClose
	
}



FunctionsForElementGetControlInformationListBoxOfContolTexts:
if a_guievent=doubleclick
	goto,FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn
gui,submit,NoHide
;ToolTip,%FunctionsForElementGetControlInformationListBoxOfContolTexts%


ControlGetPos, tempx,tempy,tempw,temph,,% "ahk_id " tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%
;ToolTip("FunctionsForElementGetControlInformationListBoxOfContolTexts " FunctionsForElementGetControlInformationListBoxOfContolTexts "`tempParControlID " tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts% "`ntempwinstring " tempwinstring "`n`ntempx " tempx "`ntempy " tempy "`ntempw " tempw "`ntemph " temph)
WinGetPos,tempwinx,tempwiny,tempwinw,tempwinh,ahk_id %FunctionsForElementGetControlInformationWinID%

ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,tempx,tempy,tempw,temph)
SetTimer,FunctionsForElementGetControlInformationRemoveShape,-2000

return
FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn:

SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()

gui, FunctionsForElementGetControlInformation:Default
gui,submit
gui,destroy




gui,SettingsOfElement:default


;guicontrol,,GUISettingsOfElement%setElementID%winText,% tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%  ;thrown out
if (FunctionsForElementGetControlInformationRadioImportControlText=1) ;if selected that the name will be imported
{
	guicontrol,,GUISettingsOfElement%setElementID%Control_identifier,% tempParText%FunctionsForElementGetControlInformationListBoxOfContolTexts%
	guicontrol,,GUISettingsOfElement%setElementID%IdentifyControlBy1,1
	guicontrol,,GUISettingsOfElement%setElementID%ControlTextMatchMode3,1
}
else if (FunctionsForElementGetControlInformationRadioImportControlClassNN=1)
{
	guicontrol,,GUISettingsOfElement%setElementID%Control_identifier,% tempParControlClassNN%FunctionsForElementGetControlInformationListBoxOfContolTexts%
	guicontrol,,GUISettingsOfElement%setElementID%IdentifyControlBy2,1
}
else if (FunctionsForElementGetControlInformationRadioImportControlHWND=1)
{
	guicontrol,,GUISettingsOfElement%setElementID%Control_identifier,% tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%
	guicontrol,,GUISettingsOfElement%setElementID%IdentifyControlBy3,1
}


ui_EnableElementSettingsWindow()
return
FunctionsForElementGetControlInformationEscape:
gui,destroy
SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()
return

FunctionsForElementGetControlInformationGuiClose:
gui,destroy
SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()

return


FunctionsForElementGetControlInformationRemoveShape:
ui_DeleteShapeOnScreen()
return

FunctionsForElementGetControlInformationGetControlCoveredByMouse:
;get the mouse position and the control that is covered by the mouse
MouseGetPos,tempmousex,tempmousey,tempwinidundermouse,tempcontrol,2
;~ ToolTip,%tempwinidundermouse% - %FunctionsForElementGetControlInformationWinID% - %tempcontrol%
if (tempwinidundermouse=FunctionsForElementGetControlInformationWinID and tempcontrol!="") ;Check whether the mouse is over the right window and coveres a control
{
	
	if (tempmousex!=tempmouseOldx or tempmousey!=tempmouseOldy) ;Prevent to adapt the control while mouse is moving
	{
		tempmouseOldx:=tempmousex
		tempmouseOldy:=tempmousey
	}
	else
	{
		;Select the control that is covered by mouse
		Loop,%tempCountOfControlsInWindow%
		{
			;~ MsgBox % tempcontrol " --- " tempParControlID%a_index%
			
			if (tempcontrol=tempParControlID%a_index%)
			{
				;~ ToolTip("tempwinidundermouse: " tempwinidundermouse " tempcontrol:" tempcontrol " tempParControlID%a_index%: " tempParControlID%a_index% " a_index: " a_index)
				guicontrol,FunctionsForElementGetControlInformation:choose,FunctionsForElementGetControlInformationListBoxOfContolTexts,|%a_index%
				
			}
			
		}
	}
}

;additionally check whether the window has been moved

return

jumpOverFunctionsFunctionsForElementGetControlInformation:
temp:=temp