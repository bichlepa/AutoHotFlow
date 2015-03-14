goto,jumpOverFunctionsFunctionsForElementGetControlInformation

FunctionsForElementGetControlInformation:
ui_disableElementSettingsWindow()
hotkey,ifwinactive
hotkey,f12,FunctionsForElementGetControlInformationf12,on
hotkey,esc,FunctionsForElementGetControlInformationEscape,on
ToolTip(lang("Get_parameters.") "`n`n" lang("Activate_a_Window_and_press_F12.") "`n`n" lang("If you want to cancel, press Escape"),100000)
return

FunctionsForElementGetControlInformationf12:

ToolTip()
hotkey,f12,FunctionsForElementGetControlInformationf12,off
hotkey,esc,FunctionsForElementGetControlInformationEscape,off

gui,2:default
gui,submit,nohide

WinGetActiveTitle,tempParWintitle


WinGetClass,tempParahk_class,A


winget,tempParPID,PID,A

winget,tempParID,ID,A

winget,tempParProcessName,ProcessName,A


winget,tempPar,ControlList,A
;~ MsgBox,%tempPar%
gui, FunctionsForElementGetControlInformation:Default

gui,add,text,w400 ,% lang("Select_a_control_text_whitch_you_want_to_import")
gui,add,listbox,w400 h500 AltSubmit vFunctionsForElementGetControlInformationListBoxOfContolTexts gFunctionsForElementGetControlInformationListBoxOfContolTexts
gui,add,checkbox,w400 vFunctionsForElementGetControlInformationCheckBoxImportUniqueIDs,% lang("Also_import_unique_IDs")
if (GUISettingsOfElement%setElementID%IdentifyControlBy1=1)
{
	gui,add,radio,w400 checked vFunctionsForElementGetControlInformationRadioImportControlText,% lang("Import_Text_in_control")
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlClassNN,%  lang("Import Classname and instance number of the control")
}
else
{
	gui,add,radio,w400 vFunctionsForElementGetControlInformationRadioImportControlText,% lang("Import_Text_in_control")
	gui,add,radio,w400 checked vFunctionsForElementGetControlInformationRadioImportControlClassNN,%  lang("Import Classname and instance number of the control")
}
gui,add,button,w400 h30 default gFunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn,% lang("OK")
tempCountOfControlsInWindow=0
loop,parse,tempPar,`n
{
	ControlGetText,tempparText,%a_loopfield%,A
	
	tempParControlID%a_index%:=a_loopfield
	tempParText%a_index%:=tempparText
	
	StringReplace,tempparText,tempparText,`r
	StringReplace,tempparText,tempparText,`n,¶
	stringleft,tempparText,tempparText,100
	guicontrol,,FunctionsForElementGetControlInformationListBoxOfContolTexts,%a_loopfield% ► %tempparText%
	
	tempCountOfControlsInWindow++
	
	
}
if tempCountOfControlsInWindow>0
{
	
	gui,show
	SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,100
	return
}
else
{
	MsgBox,0,% lang("Error"), lang("This window seems not to have controls")
	goto,FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn
	
}



FunctionsForElementGetControlInformationListBoxOfContolTexts:
if a_guievent=doubleclick
	goto,FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn
gui,submit,NoHide
;ToolTip,%FunctionsForElementGetControlInformationListBoxOfContolTexts%

tempwinstring=%tempParWintitle%
	if tempParahk_class<>
		tempwinstring=%tempwinstring% ahk_class %tempParahk_class%
	if tempParControlID<>
		tempwinstring=%tempwinstring% ahk_id %tempParControlID%
	if tempParPID<>
		tempwinstring=%tempwinstring% ahk_pid %tempParPID%

ControlGetPos, tempx,tempy,tempw,temph,% tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%,%tempwinstring%
;ToolTip("FunctionsForElementGetControlInformationListBoxOfContolTexts " FunctionsForElementGetControlInformationListBoxOfContolTexts "`tempParControlID " tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts% "`ntempwinstring " tempwinstring "`n`ntempx " tempx "`ntempy " tempy "`ntempw " tempw "`ntemph " temph)
WinGetPos,tempwinx,tempwiny,tempwinw,tempwinh,%tempwinstring%

ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,tempx,tempy,tempw,temph)
SetTimer,FunctionsForElementGetControlInformationRemoveShape,-2000

return
FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn:

SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()

gui, FunctionsForElementGetControlInformation:Default
gui,submit
gui,destroy




gui,2:default

if FunctionsForElementGetControlInformationCheckBoxImportUniqueIDs=1
{
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id,%tempParID%
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid,%tempParPID%
}
else
{
	
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid
}

;guicontrol,,GUISettingsOfElement%setElementID%winText,% tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%  ;thrown out
if (FunctionsForElementGetControlInformationRadioImportControlText=1) ;if selected that the name will be imported
{
	guicontrol,,GUISettingsOfElement%setElementID%Control_identifier,% tempParText%FunctionsForElementGetControlInformationListBoxOfContolTexts%
	guicontrol,,GUISettingsOfElement%setElementID%IdentifyControlBy1,1
	guicontrol,,GUISettingsOfElement%setElementID%ControlTextMatchMode3,1
}
else
{
	guicontrol,,GUISettingsOfElement%setElementID%Control_identifier,% tempParControlID%FunctionsForElementGetControlInformationListBoxOfContolTexts%
	guicontrol,,GUISettingsOfElement%setElementID%IdentifyControlBy2,1
}

guicontrol,,GUISettingsOfElement%setElementID%ahk_exe,%tempParProcessName%
guicontrol,,GUISettingsOfElement%setElementID%ahk_class,%tempParahk_class%
guicontrol,,GUISettingsOfElement%setElementID%Wintitle,%tempParWintitle%

ui_EnableElementSettingsWindow()
return
FunctionsForElementGetControlInformationEscape:
ToolTip()
hotkey,esc,FunctionsForElementGetControlInformationEscape,off
hotkey,f12,FunctionsForElementGetControlInformationf12,off
SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()
return

FunctionsForElementGetControlInformationGuiClose:
gui,destroy
hotkey,esc,FunctionsForElementGetControlInformationEscape,off
hotkey,f12,FunctionsForElementGetControlInformationf12,off
SetTimer,FunctionsForElementGetControlInformationGetControlCoveredByMouse,Off
ui_DeleteShapeOnScreen()
ui_EnableElementSettingsWindow()

return


FunctionsForElementGetControlInformationRemoveShape:
ui_DeleteShapeOnScreen()
return

FunctionsForElementGetControlInformationGetControlCoveredByMouse:
;get the mouse position and the control that is covered by the mouse
MouseGetPos,tempmousex,tempmousey,tempwinidundermouse,tempcontrol

if (tempwinidundermouse=tempParID and tempcontrol!="") ;Check whether the mouse is over the right window and coveres a control
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
		
			if (tempcontrol=tempParControlID%a_index%)
			{
				;ToolTip("tempwinidundermouse: " tempwinidundermouse " tempcontrol:" tempcontrol " tempParControlID%a_index%: " tempParControlID%a_index% " a_index: " a_index)
				guicontrol,FunctionsForElementGetControlInformation:choose,FunctionsForElementGetControlInformationListBoxOfContolTexts,|%a_index%
					
			}
			
		}
	}
}

;additionally check whether the window has been moved

return

jumpOverFunctionsFunctionsForElementGetControlInformation:
temp:=temp