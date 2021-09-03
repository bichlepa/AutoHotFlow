﻿
assistant_GetWindowInformation(neededInfo)
{
	global
	assistant_GetWindowInformation_NeededInfo:=neededInfo
	ui_disableElementSettingsWindow()
	
	
	;Build the GUI to select a window
	gui, assistant_GetWindowInformation:Default

	gui,add,text,xm ym w400 ,% lang("Select_a_window_which_you_want_to_import")
	if (assistant_GetWindowInformation_NeededInfo.winText)
	{
		gui,add,text,X+10 yp w400,% lang("Optinally select some text of a control in window")
	}
	if (assistant_GetWindowInformation_NeededInfo.Control_identifier)
	{
		gui,add,text,X+30 yp w400,% lang("Select a control which you want to import")
	}
	if (assistant_GetWindowInformation_NeededInfo.findhiddenwindow)
	{
		gui,add,checkbox,Y+10 xm w400 section vassistant_GetWindowInformation_CheckBoxFindHiddenWindows gassistant_GetWindowInformation_UpdateWindowlist,% lang("Detect hidden window")
	}
	gui,add,button,xm Y+10 w400 h30 gassistant_GetWindowInformation_UpdateWindowlist,% lang("Update window list")
	if (assistant_GetWindowInformation_NeededInfo.winText and assistant_GetWindowInformation_NeededInfo.FindHiddenText)
	{
		gui,add,checkbox,ys X+10 w400 vassistant_GetWindowInformation_CheckBoxFindHiddenText gassistant_GetWindowInformation_ListBoxTitles checked,% lang("Detect hidden text")
	}
	if (assistant_GetWindowInformation_NeededInfo.Control_identifier and assistant_GetWindowInformation_NeededInfo.IdentifyControlBy)
	{
		gui,add,radio,ys X+30 w400 vassistant_GetWindowInformation_RadioIdentifyControlByText,% lang("Text in conrol")
		gui,add,radio,Y+5 xp w400 vassistant_GetWindowInformation_RadioIdentifyControlByClass,% lang("Classname and instance number of the control")
		gui,add,radio,Y+5 xp w400 vassistant_GetWindowInformation_RadioIdentifyControlByID,% lang("Unique control ID")
	}
	gui,add,listbox,x10 ys+70 w400 h500 AltSubmit vassistant_GetWindowInformation_ListBoxTitles gassistant_GetWindowInformation_ListBoxTitles
	if (assistant_GetWindowInformation_NeededInfo.winText)
	{
		gui,add,listbox, X+10 yp w400 h500 vassistant_GetWindowInformation_ListBoxControlTexts
	}
	if (assistant_GetWindowInformation_NeededInfo.Control_identifier)
	{
		gui,add,listbox, X+30 yp w400 h500 AltSubmit vassistant_GetWindowInformation_ListBoxControlIdentifications gassistant_GetWindowInformation_ListBoxControlIdentifications 
	}
	
	gui,add,text,w1 Y+10 xm,
	if (assistant_GetWindowInformation_NeededInfo.Xpos)
	{
		gui,add,text,X+10 yp,% lang("X #coordinate")
		gui,add,edit,X+10 yp w50 vassistant_GetWindowInformation_EditXPos
	}
	if (assistant_GetWindowInformation_NeededInfo.Ypos)
	{
		gui,add,text,X+10 yp ,% lang("Y #coordinate")
		gui,add,edit,X+10 yp w50 vassistant_GetWindowInformation_EditYPos
	}
	if (assistant_GetWindowInformation_NeededInfo.Width)
	{
		gui,add,text,X+10 yp ,% lang("Width")
		gui,add,edit,X+10 yp w50 vassistant_GetWindowInformation_EditWidth
	}
	if (assistant_GetWindowInformation_NeededInfo.Height)
	{
		gui,add,text,X+10 yp ,% lang("Height")
		gui,add,edit,X+10 yp w50 vassistant_GetWindowInformation_EditHeight
	}
	
	if (assistant_GetWindowInformation_NeededInfo.ahk_id or assistant_GetWindowInformation_NeededInfo.ahk_pid)
	{
		gui,add,checkbox,xm Y+20 w400 vassistant_GetWindowInformation_CheckBoxImportUniqueIDs,% lang("Import unique window ID and process ID")
	}
	gui,add,button, xm Y+10 w400 h30 default gassistant_GetWindowInformation_ButtonOK,% lang("OK")
	
	
	;Fill values
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
	if (assistant_GetWindowInformation_NeededInfo.Xpos)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.Xpos)
		guicontrol,,assistant_GetWindowInformation_EditPosX,%tempValue%
	}
	if (assistant_GetWindowInformation_NeededInfo.Ypos)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.Ypos)
		guicontrol,,assistant_GetWindowInformation_EditPosY,%tempValue%
	}
	if (assistant_GetWindowInformation_NeededInfo.Width)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.Width)
		guicontrol,,assistant_GetWindowInformation_EditWidth,%tempValue%
	}
	if (assistant_GetWindowInformation_NeededInfo.Height)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.Height)
		guicontrol,,assistant_GetWindowInformation_EditHeight,%tempValue%
	}
	if (assistant_GetWindowInformation_NeededInfo.IdentifyControlBy)
	{
		tempValue:=x_Par_GetValue(assistant_GetWindowInformation_NeededInfo.IdentifyControlBy)
		guicontrol,,assistant_GetWindowInformation_RadioIdentifyControlBy%tempValue%,1
	}
	
	
	assistant_GetWindowInformation_UpdateWindowlist()
	DetectHiddenWindows,on
	if (assistant_GetWindowInformation_AllWinIDs.MaxIndex() > 0)
	{
		gui,+hwndassistant_GetWindowInformation_HWND
		
		;Put the window in the center of the element settings window
		gui,show,hide
		ui_GetElementSettingsGUIPos()
		DetectHiddenWindows,on
		wingetpos,,,tempWidth,tempHeight,ahk_id %assistant_GetWindowInformation_HWND%
		tempXpos:=round(ElementSettingsGUIX+ElementSettingsGUIWidth/2- tempWidth/2)
		tempYpos:=round(ElementSettingsGUIY+ElementSettingsGUIHeight/2- tempHeight/2)
	
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

;Update the list with all windows
assistant_GetWindowInformation_UpdateWindowlist()
{
	global
	local winlist, completelist, title, classe
	gui,assistant_GetWindowInformation:submit,nohide
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
	completelist=
	;~ guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,|
	
	assistant_GetWindowInformation_AllWinIDs:=Object()
	assistant_GetWindowInformation_AllWinTitles:=Object()
	assistant_GetWindowInformation_AllWinClasses:=Object()
	
	loop %winlist%
	{
		assistant_GetWindowInformation_AllWinIDs[a_index]:=winlist%a_index%
		
		WinGetTitle,title,% "ahk_id " winlist%a_index%
		WinGetclass,classe,% "ahk_id " winlist%a_index%
		assistant_GetWindowInformation_AllWinTitles[a_index]:=title
		assistant_GetWindowInformation_AllWinClasses[a_index]:=classe
		
		completelist.="|"classe " ► " title 
	}
	
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,% completelist
	assistant_GetWindowInformation_ListBoxTitles()
	return
}



;user selects a new window. The control list will be updated and the window highlighted.
assistant_GetWindowInformation_ListBoxTitles()
{
	global
	local tempwinx, tempwiny, tempwinw, tempwinh
	local tempWinID, tempControlHwndList, tempControlClassList, tempHwndToClassMap
	local tempparText, tempVisible, 
	
	gui,assistant_GetWindowInformation:submit,NoHide
	tempWinID:=assistant_GetWindowInformation_AllWinIDs[assistant_GetWindowInformation_ListBoxTitles]
	WinGetPos,tempwinx,tempwiny,tempwinw,tempwinh,% "ahk_id " tempWinID

	ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,0,0,tempwinw,tempwinh)
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_EditXPos, % tempwinx
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_EditYPos, % tempwiny
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_EditWidth, % tempwinw
	guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_EditHeight, % tempwinh
	
	
	if (assistant_GetWindowInformation_NeededInfo.winText or assistant_GetWindowInformation_NeededInfo.Control_identifier)
	{
		;Get all controls of window
		winget,tempControlHwndList,ControlListHwnd,% "ahk_id " tempWinID
		winget,tempControlClassList,ControlList,% "ahk_id " tempWinID
		
		;create a map in order to know which controls and hwnd's are of same control
		tempHwndToClassMap:=Object()
		loop,parse,tempControlClassList,`n
		{
			ControlGet, tempHwnd, hwnd,,%A_LoopField%,% "ahk_id " tempWinID
			tempHwndToClassMap[tempHwnd]:=A_LoopField
		}
		
		;~ ToolTip %tempControlHwndList%
		guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxControlTexts,|
		guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxControlIdentifications,|
		
		assistant_GetWindowInformation_AllControlIDs:=Object()
		assistant_GetWindowInformation_AllControlClasses:=Object()
		assistant_GetWindowInformation_AllControlTexsts:=Object()
		loop,parse,tempControlHwndList,`n
		{
			assistant_GetWindowInformation_AllControlIDs.push(a_loopfield)
			assistant_GetWindowInformation_AllControlClasses.push(tempHwndToClassMap[a_loopfield])
			
			controlget,tempVisible,visible,,,ahk_id %a_loopfield%
			
			ControlGetText,tempparText,,ahk_id %a_loopfield%
			StringLeft,tempparText,tempparText,100 ;Trim the text if it is very long
			StringReplace,tempparText,tempparText,`r,,all
			StringReplace,tempparText,tempparText,`n,¶, all
			StringReplace,tempparText,tempparText,|,_, all
			assistant_GetWindowInformation_AllControlTexsts.push(tempparText)
			
			if (assistant_GetWindowInformation_NeededInfo.winText)
			{
				if (assistant_GetWindowInformation_CheckBoxFindHiddenText or tempVisible)
				{
					if tempparText		;Skip controls that have no text
					{
						guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxControlTexts,%tempparText%
					}
				}
			}
			
			if (assistant_GetWindowInformation_NeededInfo.Control_identifier)
			{
				guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxControlIdentifications,% tempHwndToClassMap[a_loopfield] " ► " tempparText
			}
		}
	}

	SetTimer,ui_DeleteShapeOnScreen,-2000
	return
}

;user has selected a new control. Highlight it
assistant_GetWindowInformation_ListBoxControlIdentifications()
{
	global
	local tempx, tempy, tempw, temph, tempwinx, tempwiny
	local tempWinID, tempControlID
	
	gui,assistant_GetWindowInformation:submit,NoHide
	
	tempWinID:=assistant_GetWindowInformation_AllWinIDs[assistant_GetWindowInformation_ListBoxTitles]
	WinGetPos,tempwinx,tempwiny,,,% "ahk_id " tempWinID
	
	tempControlID:=assistant_GetWindowInformation_AllControlIDs[assistant_GetWindowInformation_ListBoxControlIdentifications]
	
	ControlGetPos, tempx, tempy, tempw, temph,,ahk_id %tempControlID%
	ui_DrawShapeOnScreen(tempwinx + tempx,tempwiny + tempy, tempw, temph,0,0, tempw, temph)
	
	SetTimer,ui_DeleteShapeOnScreen,-2000
}

;User clicks on OK. The selected window will be imported
assistant_GetWindowInformation_ButtonOK()
{
	global
	SetTimer,assistant_GetWindowInformation_GetWindowCoveredByMouse,off

	gui,assistant_GetWindowInformation:submit
	gui,assistant_GetWindowInformation:destroy
	gui,GUISettingsOfElement:default
	tempWinID:=assistant_GetWindowInformation_AllWinIDs[assistant_GetWindowInformation_ListBoxTitles]
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
	
	if (assistant_GetWindowInformation_NeededInfo.Xpos)
	{
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Xpos,assistant_GetWindowInformation_EditXpos)
	}
	if (assistant_GetWindowInformation_NeededInfo.Ypos)
	{
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Ypos,assistant_GetWindowInformation_EditYpos)
	}
	if (assistant_GetWindowInformation_NeededInfo.Width)
	{
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Width,assistant_GetWindowInformation_EditWidth)
	}
	if (assistant_GetWindowInformation_NeededInfo.Height)
	{
		x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Height,assistant_GetWindowInformation_EditHeight)
	}
	
	if (assistant_GetWindowInformation_NeededInfo.Control_identifier)
	{
		if (assistant_GetWindowInformation_RadioIdentifyControlByText)
		{
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.IdentifyControlBy,"Text")
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Control_identifier,assistant_GetWindowInformation_AllControlTexsts[assistant_GetWindowInformation_ListBoxControlIdentifications])
		}
		else if (assistant_GetWindowInformation_RadioIdentifyControlByClass)
		{
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.IdentifyControlBy,"Class")
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Control_identifier,assistant_GetWindowInformation_AllControlClasses[assistant_GetWindowInformation_ListBoxControlIdentifications])
		}
		else if (assistant_GetWindowInformation_RadioIdentifyControlByID)
		{
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.IdentifyControlBy,"ID")
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.Control_identifier,assistant_GetWindowInformation_AllControlIDs[assistant_GetWindowInformation_ListBoxControlIdentifications])
		}
	}
	
	if assistant_GetWindowInformation_CheckBoxImportUniqueIDs
	{
		WinGet,temp,pid,ahk_id %tempWinID%
		
		if (assistant_GetWindowInformation_NeededInfo.ahk_pid)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,temp)
		if (assistant_GetWindowInformation_NeededInfo.ahk_id)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_id,tempWinID)
	}
	else
	{
		if (assistant_GetWindowInformation_NeededInfo.ahk_pid)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_pid,"")
		if (assistant_GetWindowInformation_NeededInfo.ahk_id)
			x_Par_SetValue(assistant_GetWindowInformation_NeededInfo.ahk_id,"")
		
	}
	ui_DeleteShapeOnScreen()

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
	gui,assistant_GetWindowInformation:destroy
	SetTimer,assistant_GetWindowInformation_GetWindowCoveredByMouse,off
	ui_DeleteShapeOnScreen()
	ui_EnableElementSettingsWindow()
	return
}

assistant_GetWindowInformation_GetWindowCoveredByMouse()
{
	global
	static tempmouseOldx, tempmouseOldy, tempLastChoosenWin, tempLastChoosenControl, timeMouseNotMoving
	
	local tempmousex, tempmousey, tempwinidundermouse, tempcontrolUnderMouse, found, title, classe
	local newWindowSelected, newindex
	
	IfWinNotExist,ahk_id %global_SettingWindowHWND%
	{
		assistant_GetWindowInformationGuiClose()
	}
	
	;get the mouse position and the control that is covered by the mouse
	MouseGetPos,tempmousex,tempmousey,tempwinidundermouse,tempcontrolUnderMouse,2

	if (tempwinidundermouse!="") ;Check whether the mouse is over the right window and coveres a control
	{
		if (tempmousex!=tempmouseOldx or tempmousey!=tempmouseOldy) ;Prevent to adapt the control while mouse is moving
		{
			tempmouseOldx:=tempmousex
			tempmouseOldy:=tempmousey
			timeMouseNotMoving:=0
			
			if (tempLastChoosenWin!=tempwinidundermouse)
			{
				tempLastChoosenWin := ""
			}
		}
		else
		{
			if (timeMouseNotMoving < 3)
			{
				timeMouseNotMoving++
			}
			else
			{
				if (assistant_GetWindowInformation_HWND!=tempwinidundermouse)
				{
					if (tempLastChoosenWin!=tempwinidundermouse)
					{
						;Select the window that is covered by mouse
						found:=false
						Loop,% assistant_GetWindowInformation_AllWinIDs.maxindex()
						{
							;Seek the window that is covered by the mouse in the list and select it
							if (tempwinidundermouse = assistant_GetWindowInformation_AllWinIDs[a_index])
							{
								tempLastChoosenWin:=tempwinidundermouse
								found:=true
								
								guicontrol,assistant_GetWindowInformation:choose,assistant_GetWindowInformation_ListBoxTitles,%a_index%
								assistant_GetWindowInformation_ListBoxTitles()
								break
							}
						}
						if not found
						{
							;The window that is covered by the mouse was not found in the list (because the window appeared after the windows list was generated).
							;Add the missing entry and select it.
							WinGetTitle,title,% "ahk_id " tempwinidundermouse
							WinGetclass,classe,% "ahk_id " tempwinidundermouse
							assistant_GetWindowInformation_AllWinTitles.push(title)
							assistant_GetWindowInformation_AllWinclasses.push(classe) 
							assistant_GetWindowInformation_AllWinIDs.push(tempwinidundermouse)
							guicontrol,assistant_GetWindowInformation:,assistant_GetWindowInformation_ListBoxTitles,% classe " ► " title 

							guicontrol,assistant_GetWindowInformation:choose,assistant_GetWindowInformation_ListBoxTitles,% assistant_GetWindowInformation_AllWinIDs.MaxIndex()
							assistant_GetWindowInformation_ListBoxTitles()
						}
						
						tempLastChoosenControl:=""
						newWindowSelected:=True
					}
					
					;If user needs to select a control
					if (assistant_GetWindowInformation_NeededInfo.Control_identifier and (newWindowSelected or tempLastChoosenControl != tempcontrolUnderMouse))
					{
						if (tempcontrolUnderMouse)
						{
							;select the control which is covered by the mouse
							
							found:=false
							loop 2 ;Make two iterations. In the first iteration we will try to find the control which is covered by the mouse in the control list. If it fails, we will update the control list and then find the
							{
								Loop,% assistant_GetWindowInformation_AllControlIDs.maxindex()
								{
									;Seek the control that is covered by the mouse in the list and select it
									if (tempcontrolUnderMouse = assistant_GetWindowInformation_AllControlIDs[a_index])
									{
										tempLastChoosenControl:=tempwinidundermouse
										found:=true
										
										guicontrol, assistant_GetWindowInformation:choose, assistant_GetWindowInformation_ListBoxControlIdentifications, %a_index%
										assistant_GetWindowInformation_ListBoxControlIdentifications()
										break
									}
								}
								
								if (found)
									break ;The control was found. Leave the loop
								else if (a_index = 1)
								{
									tooltip tiöhaih
									assistant_GetWindowInformation_ListBoxTitles() ;Update control list and proceed with the second iteration
								}
							}
							
							newControlSelected:=True
						}
						tempLastChoosenControl:=tempcontrolUnderMouse
					}
				}
			}
		}
	}

	;additionally check whether the window has been moved

	return
}
