goto,jumpOverFunctionsFunctionsForElementGetWindowInformation

FunctionsForElementGetWindowInformation:
ui_disableElementSettingsWindow()
hotkey,ifwinactive
hotkey,f12,FunctionsForElementGetWindowInformationf12,on
hotkey,esc,FunctionsForElementGetWindowInformationEscape,on
ToolTip(lang("Get_parameters.") "`n`n" lang("Activate_a_Window_and_press_F12.") "`n`n" lang("If you want to cancel, press Escape"),100000)
return

FunctionsForElementGetWindowInformationf12:

ToolTip()
hotkey,f12,FunctionsForElementGetWindowInformationf12,off
hotkey,esc,FunctionsForElementGetWindowInformationEscape,off

gui,2:default
gui,submit,nohide

WinGetActiveTitle,tempPar
guicontrol,,GUISettingsOfElement%setElementID%Wintitle,%tempPar%

WinGetClass,tempPar,A
guicontrol,,GUISettingsOfElement%setElementID%ahk_class,%tempPar%

winget,tempParPID,PID,A

winget,tempParID,ID,A

winget,tempPar,ProcessName,A
guicontrol,,GUISettingsOfElement%setElementID%ahk_exe,%tempPar%

winget,tempPar,ControlList,A
;~ MsgBox,%tempPar%
gui, FunctionsForElementGetWindowInformation:Default
gui,add,text,w400 ,% lang("Select_a_control_text_whitch_you_want_to_import")
gui,add,listbox,w400 h500 vFunctionsForElementGetWindowInformationListBoxOfContolTexts gFunctionsForElementGetWindowInformationListBoxOfContolTexts
gui,add,checkbox,w400 vFunctionsForElementGetWindowInformationCheckBoxImportUniqueIDs,% lang("Also_import_unique_IDs")
gui,add,button,w400 h30 default gFunctionsForElementGetWindowInformationListBoxOfContolTextsButtonGoOn,% lang("OK")
tempThereAreControlTexts=false
loop,parse,tempPar,`n
{
	ControlGetText,tempparText,%a_loopfield%,A
	if tempparText<>
	{
		guicontrol,,FunctionsForElementGetWindowInformationListBoxOfContolTexts,%tempparText%
		tempThereAreControlTexts=true
	}
	
}
if tempThereAreControlTexts=true
{
	gui,show
	return
}
else
	goto,FunctionsForElementGetWindowInformationListBoxOfContolTextsButtonGoOn

FunctionsForElementGetWindowInformationListBoxOfContolTexts:
if a_guievent=doubleclick
	goto,FunctionsForElementGetWindowInformationListBoxOfContolTextsButtonGoOn
return
FunctionsForElementGetWindowInformationListBoxOfContolTextsButtonGoOn:
gui, FunctionsForElementGetWindowInformation:Default
gui,submit
gui,destroy

gui,2:default

if FunctionsForElementGetWindowInformationCheckBoxImportUniqueIDs=1
{
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id,%tempParID%
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid,%tempParPID%
}
else
{
	
	guicontrol,,GUISettingsOfElement%setElementID%ahk_id
	guicontrol,,GUISettingsOfElement%setElementID%ahk_pid
}

guicontrol,,GUISettingsOfElement%setElementID%winText,%FunctionsForElementGetWindowInformationListBoxOfContolTexts%

ui_EnableElementSettingsWindow()
return
FunctionsForElementGetWindowInformationEscape:
ToolTip()
hotkey,esc,FunctionsForElementGetWindowInformationEscape,off
hotkey,f12,FunctionsForElementGetWindowInformationf12,off
ui_EnableElementSettingsWindow()
return

FunctionsForElementGetWindowInformationGuiClose:
gui,destroy
ui_EnableElementSettingsWindow()
return

jumpOverFunctionsFunctionsForElementGetWindowInformation:
temp:=temp