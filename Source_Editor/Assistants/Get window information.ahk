#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

assistant_GetWindowInformation(neededInfo)
{
	global
	assistant_GetWindowInformation_NeededInfo:=neededInfo
	ui_disableElementSettingsWindow()
	
	
	;Build the GUI to select a window
	gui, assistant_GetWindowInformation:Default

	gui,add,text,x10 w400 ,% lang("Select_a_window_which_you_want_to_import")
	gui,add,text,X+10 ,% lang("Optinally select some text of a control in window")
	gui,add,checkbox,x10 w400 vassistant_GetWindowInformation_CheckBoxFindHiddenWindows gassistant_GetWindowInformation_UpdateWindowlist,% lang("Detect hidden window")
	gui,add,checkbox,X+10 w400 vassistant_GetWindowInformation_CheckBoxFindHiddenText gassistant_GetWindowInformation_ListBoxTitles checked,% lang("Detect hidden text")
	gui,add,button,x10 w400 h30 gassistant_GetWindowInformation_UpdateWindowlist,% lang("Update window list")
	gui,add,listbox,x10 w400 h500 AltSubmit vassistant_GetWindowInformation_ListBoxTitles gassistant_GetWindowInformation_ListBoxTitles
	gui,add,listbox,w400 h500 X+10 vassistant_GetWindowInformation_ListBoxControlTexts
	gui,add,checkbox,w400 vassistant_GetWindowInformation_CheckBoxImportUniqueIDs,% lang("Also_import_unique_IDs")

	gui,add,button,w400 h30 default gassistant_GetWindowInformation_ButtonOK,% lang("OK")
	
	if (assistant_GetWindowInformation_NeededInfo.findhiddenwindow)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.findhiddenwindow)
		guicontrol,,assistant_GetWindowInformation_CheckBoxFindHiddenWindows,%tempValue%
	}
	if (assistant_GetWindowInformation_NeededInfo.findhiddentext)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.findhiddentext)
		guicontrol,,assistant_GetWindowInformation_CheckBoxFindHiddenText,%tempValue%
	}
	
	
	assistant_GetWindowInformation_UpdateWindowlist()
	DetectHiddenWindows,on
	if tempCountOfWindows>0
	{
		gui,+hwndassistant_GetWindowInformation_HWND
		;Put the window in the center of the main window
		gui,show,hide
		wingetpos,tempParentX,tempParentY,tempParentW,tempParentH,ahk_id %SettingsGUIHWND%
		
		wingetpos,,,tempWidth,tempHeight,ahk_id %assistant_GetWindowInformation_HWND%
		tempXpos:=round(tempParentX+tempParentW/2- tempWidth/2)
		tempYpos:=round(tempParentY+tempParentH/2- tempHeight/2)
		;~ MsgBox %tempWidth% %assistant_GetWindowInformation_HWND%
		gui,show,x%tempXpos% y%tempYpos%,% lang("Window assistant")
		
		SetTimer,assistant_GetWindowInformation_GetWindowCoveredByMouse,100
		return
	}
	else
	{
		gui, assistant_GetWindowInformation:destroy
		MsgBox,0,% lang("Error"), lang("No windows found.")
		;~ FunctionsForElementGetControlInformationListBoxOfContolTextsButtonGoOn()
		
		ui_enableElementSettingsWindow()
	}

	
}


;user selects a new window
assistant_GetWindowInformation_ListBoxTitles()
{
	global
	gui,submit,NoHide
	tempWinID:=tempParWinID%assistant_GetWindowInformation_ListBoxTitles%
	WinGetPos,tempwinx,tempwiny,tempwinw,tempwinh,% "ahk_id " tempWinID

	ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,0,0,tempwinw,tempwinh)

	;Get all controls of window
	winget,tempControlList,ControlListHwnd,% "ahk_id " tempWinID
	;~ ToolTip %tempControlList%
	guicontrol,,assistant_GetWindowInformation_ListBoxControlTexts,|
	loop,parse,tempControlList,`n
	{
		if not assistant_GetWindowInformation_CheckBoxFindHiddenText
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
		guicontrol,,assistant_GetWindowInformation_ListBoxControlTexts,%tempparText%

		
		
	}

	SetTimer,ui_DeleteShapeOnScreen,-2000
	return
}

;User clicks on OK. The selected window will be imported
assistant_GetWindowInformation_ButtonOK()
{
	global
	SetTimer,assistant_GetWindowInformation_GetWindowCoveredByMouse,off

	gui,submit
	gui,destroy
	gui,SettingsOfElement:default
	tempWinID:=tempParWinID%assistant_GetWindowInformation_ListBoxTitles%
	WinGetTitle,temp,ahk_id %tempWinID%
	if (assistant_GetWindowInformation_NeededInfo.Wintitle)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Wintitle,temp)
	WinGetclass,temp,ahk_id %tempWinID%
	if (assistant_GetWindowInformation_NeededInfo.ahk_class)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_class,temp)
	WinGet,temp,processName,ahk_id %tempWinID%
	if (assistant_GetWindowInformation_NeededInfo.ahk_exe)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_exe,temp)

	if (assistant_GetWindowInformation_NeededInfo.excludeTitle)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.excludeTitle,"")
	if (assistant_GetWindowInformation_NeededInfo.ExcludeText)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ExcludeText,"")
	
	if (assistant_GetWindowInformation_NeededInfo.winText)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.winText,assistant_GetWindowInformation_ListBoxControlTexts)

	if (assistant_GetWindowInformation_NeededInfo.findhiddenwindow)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.findhiddenwindow,assistant_GetWindowInformation_CheckBoxFindHiddenWindows)
	if (assistant_GetWindowInformation_NeededInfo.findhiddentext)
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.findhiddentext,assistant_GetWindowInformation_CheckBoxFindHiddenText)

	if assistant_GetWindowInformation_CheckBoxImportUniqueIDs=1
	{
		WinGet,temp,pid,ahk_id %tempWinID%
		
		if (assistant_GetWindowInformation_NeededInfo.ahk_pid)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,temp)
		if (assistant_GetWindowInformation_NeededInfo.ahk_id)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,tempWinID)
	}
	else
	{
		if (assistant_GetWindowInformation_NeededInfo.ahk_pid)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,"")
		if (assistant_GetWindowInformation_NeededInfo.ahk_id)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,"")
		
	}
	ui_DeleteShapeOnScreen()

	;~ if assistant_GetWindowInformation_GetControlInformationAfterwards
	;~ {
		;~ FunctionsForElementGetControlInformationWinID:=tempWinID
		;~ goto,FunctionsForElementGetControlInformation2
	;~ }
	;~ else
		ui_EnableElementSettingsWindow()
	return
}







assistant_GetWindowInformationGuiEscape()
{
	assistant_GetWindowInformationGuiClose()
}

assistant_GetWindowInformationGuiClose()
{
	global
	gui,destroy
	SetTimer,assistant_GetWindowInformation_GetWindowCoveredByMouse,off
	ui_DeleteShapeOnScreen()
	ui_EnableElementSettingsWindow()
	return
}

assistant_GetWindowInformation_UpdateWindowlist()
{
	global
	gui,submit,nohide
	;~ ToolTip update
	if assistant_GetWindowInformation_CheckBoxFindHiddenWindows
		DetectHiddenWindows,on
	else
		DetectHiddenWindows,off
	if assistant_GetWindowInformation_CheckBoxFindHiddenText
		DetectHiddentext,on
	else
		DetectHiddentext,off
	WinGet,winlist,List
	tempCountOfWindows=0
	completelist=
	;~ guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,|
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
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,% completelist
	return
}


assistant_GetWindowInformation_GetWindowCoveredByMouse()
{
	global
	
	;get the mouse position and the control that is covered by the mouse
	MouseGetPos,tempmousex,tempmousey,tempwinidundermouse,tempcontrol

	if (tempwinidundermouse!="") ;Check whether the mouse is over the right window and coveres a control
	{
		if (tempmousex!=tempmouseOldx or tempmousey!=tempmouseOldy) ;Prevent to adapt the control while mouse is moving
		{
			
			tempmouseOldx:=tempmousex
			tempmouseOldy:=tempmousey
			
			if (tempLastChoosenWin!=tempwinidundermouse)
				tempLastChoosenWin := ""
		}
		else
		{
			if (tempLastChoosenWin!=tempwinidundermouse and assistant_GetWindowInformation_HWND!=tempwinidundermouse)
			{
				;Select the control that is covered by mouse
				found:=false
				Loop,%tempCountOfWindows%
				{
				
					if (tempwinidundermouse=tempParWinID%a_index%)
					{
						;ToolTip("tempwinidundermouse: " tempwinidundermouse " tempcontrol:" tempcontrol " tempParControlID%a_index%: " tempParControlID%a_index% " a_index: " a_index)
						guicontrol,assistant_GetWindowInformation:choose,assistant_GetWindowInformation_ListBoxTitles,|%a_index%
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
					guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,% classe " ► " title 

					guicontrol,assistant_GetWindowInformation:choose,assistant_GetWindowInformation_ListBoxTitles,|%tempCountOfWindows%
				}
			}
		}
	}

	;additionally check whether the window has been moved

	return
}
