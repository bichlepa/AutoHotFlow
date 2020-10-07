﻿
assistant_MouseTracker(neededInfo)
{
	global
	assistant_MouseTracker_NeededInfo:=neededInfo
	ui_disableElementSettingsWindow()
	
	gui, assistant_MouseTracker:Default

	gui,add,text,xm ym w200,% lang("Hold control key down and use keyboard cursors to move mouse by one pixel.")
	gui,font,wbold
	gui,add,text,xm Y+20 x10,% lang("Position reference")
	gui,font,wnorm
	
	if (assistant_MouseTracker_NeededInfo.HasKey("CoordMode"))
	{
		;Show GUI controls if the coord mode can be selected
		gui,add,radio,xm Y+10 group vassistant_MouseTracker_RadioCoordMode1 gassistant_MouseTracker_RadioCoordMode ,%  lang("Relative to screen")
		gui,add,radio,xm Y+10 vassistant_MouseTracker_RadioCoordMode2 gassistant_MouseTracker_RadioCoordMode ,% lang("Relative to active window position")
		gui,add,radio,xm Y+10 vassistant_MouseTracker_RadioCoordMode3 gassistant_MouseTracker_RadioCoordMode ,% lang("Relative to active window client position")
		
		assistant_MouseTracker_RadioCoordModeNames:=["Screen", "Window", "Client"]
		
		assistant_MouseTracker_RadioCoordMode := x_Par_GetValue(assistant_MouseTracker_NeededInfo.CoordMode)
		if not (assistant_MouseTracker_RadioCoordMode >=1 && assistant_MouseTracker_RadioCoordMode <= 3)
		{
			if (assistant_MouseTracker_RadioCoordMode=assistant_MouseTracker_RadioCoordModeNames[1])
				assistant_MouseTracker_RadioCoordMode := 1
			else if (assistant_MouseTracker_RadioCoordMode=assistant_MouseTracker_RadioCoordModeNames[2])
				assistant_MouseTracker_RadioCoordMode := 2
			else if (assistant_MouseTracker_RadioCoordMode=assistant_MouseTracker_RadioCoordModeNames[3])
				assistant_MouseTracker_RadioCoordMode := 3
			else 
				assistant_MouseTracker_RadioCoordMode := 1
		}
		guicontrol,,assistant_MouseTracker_RadioCoordMode%assistant_MouseTracker_RadioCoordMode%, 1
	}
	else
	{
		;Assume the coord mode to "sceen" if this parameter is not to be set
		assistant_MouseTracker_RadioCoordMode := 1
	}
	
	if (assistant_MouseTracker_NeededInfo.haskey("xpos") or assistant_MouseTracker_NeededInfo.haskey("ypos"))
	{
		
		;Show GUI controls if the mouse position can be selected
		gui,font,wbold
		gui,add,text,xm Y+20,% lang("Coordinates")
		gui,font,wnorm
		;~ if (assistant_MouseTracker_ImportMousePos="optional")
			;~ gui,add,checkbox,x10  w200  vassistant_MouseTracker_CheckBoxImportMousePos,% lang("Import mouse position")
		if (assistant_MouseTracker_NeededInfo.haskey("xpos2") or assistant_MouseTracker_NeededInfo.haskey("ypos2"))
		{
			gui,add,radio,Y+10 xm w200 vassistant_MouseTracker_WhichPosSelector1 checked,% lang("First position")
			gui,add,radio,Y+10 xm w200 vassistant_MouseTracker_WhichPosSelector2,% lang("Second position")
		}
			
		assistant_MouseTracker_EditPosX := x_Par_GetValue(assistant_MouseTracker_NeededInfo.xpos)
		assistant_MouseTracker_EditPosY := x_Par_GetValue(assistant_MouseTracker_NeededInfo.ypos)
		
		gui,add,text,xm Y+10, x
		gui,add,edit,yp X+10 w50 vassistant_MouseTracker_EditPosX , %assistant_MouseTracker_EditPosX%
		gui,add,text,yp X+20, y
		gui,add,edit,yp X+10 w50 vassistant_MouseTracker_EditPosY w100, %assistant_MouseTracker_EditPosY%
		
		if (assistant_MouseTracker_NeededInfo.haskey("xpos2") or assistant_MouseTracker_NeededInfo.haskey("ypos2"))
		{
			assistant_MouseTracker_EditPosX2 := x_Par_GetValue(assistant_MouseTracker_NeededInfo.xpos2)
			assistant_MouseTracker_EditPosY2 := x_Par_GetValue(assistant_MouseTracker_NeededInfo.ypos2)
			
			gui,add,text,xm Y+10, x2
			gui,add,edit,yp X+10 w50 vassistant_MouseTracker_EditPosX2 , %assistant_MouseTracker_EditPosX2%
			gui,add,text,yp X+20, y2
			gui,add,edit,yp X+10 w50 vassistant_MouseTracker_EditPosY2 w100, %assistant_MouseTracker_EditPosY2%
		}
		
	}

	if (assistant_MouseTracker_NeededInfo.haskey("color"))
	{
		;Show GUI controls if the color can be selected
		gui,font,wbold
		gui,add,text,xm Y+20,% lang("Color")
		gui,font,wnorm
		
		gui,add,edit,xm Y+10 vassistant_MouseTracker_ColorText readonly w100
		if not (assistant_MouseTracker_ImportColor="yes")
		;~ gui,add,ListView,yp x+10 w90 h20 vassistant_MouseTracker_Color
		;We use an empty listView and manipulate the background color.
		gui,add,ListView,h100 w200 vassistant_MouseTracker_ColorPreview
		
		if (assistant_MouseTracker_NeededInfo.haskey("colorGetMethod"))
		{
			gui,font,wbold
			gui,add,text,xm Y+20,% lang("Method for getting color")
			gui,font,wnorm
			gui,add,radio,xm Y+10 group vassistant_MouseTracker_RadioMethod1 gassistant_MouseTracker_RadioMethod,% lang("Default method")
			gui,add,radio,xm Y+10 vassistant_MouseTracker_RadioMethod2 gassistant_MouseTracker_RadioMethod ,% lang("Alternative method")
			gui,add,radio,xm Y+10 vassistant_MouseTracker_RadioMethod3 gassistant_MouseTracker_RadioMethod ,% lang("Slow method")
			
			assistant_MouseTracker_RadioMethodNames:=["default", "alt", "slow"]
			
			assistant_MouseTracker_RadioMethod := x_Par_GetValue(assistant_MouseTracker_NeededInfo.colorGetMethod)
			if not (assistant_MouseTracker_RadioMethod >=1 && assistant_MouseTracker_RadioMethod <= 3)
			{
				if (assistant_MouseTracker_RadioMethod=assistant_MouseTracker_RadioMethodNames[1])
					assistant_MouseTracker_RadioMethod := 1
				else if (assistant_MouseTracker_RadioMethod=assistant_MouseTracker_RadioMethodNames[2])
					assistant_MouseTracker_RadioMethod := 2
				else if (assistant_MouseTracker_RadioMethod=assistant_MouseTracker_RadioMethodNames[3])
					assistant_MouseTracker_RadioMethod := 3
				else 
					assistant_MouseTracker_RadioMethod := 1
			}
			guicontrol,,assistant_MouseTracker_RadioMethod%assistant_MouseTracker_RadioMethod%, 1
		}
	}
	
	
	gui,add,Button,xm Y+20 w95 h25 vassistant_MouseTracker_ButtonOK gassistant_MouseTracker_buttonOK default,% lang("OK")
	gui,add,Button,X+10 yp w95 h25 vassistant_MouseTracker_ButtonCancel gassistant_MouseTracker_buttonCancel,% lang("Cancel")
	gui,+hwndassistant_MouseTracker_HWND
	gui,+alwaysontop

	;Put the window in the center of the element settings window
	gui,show,hide
	ui_GetElementSettingsGUIPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %assistant_MouseTracker_HWND%
	tempXpos:=round(ElementSettingsGUIX+ElementSettingsGUIWidth/2- tempWidth/2)
	tempYpos:=round(ElementSettingsGUIY+ElementSettingsGUIHeight/2- tempHeight/2)

	gui,show,x%tempXpos% y%tempYpos%,% lang("Mouse tracker")

	;Activate hotkeys for moving the mouse by one pixel
	hotkey,ifwinactive
	hotkey,ifwinexist
	hotkey,^right,assistant_MouseTracker_Right,on
	hotkey,^left,assistant_MouseTracker_Left,on
	hotkey,^up,assistant_MouseTracker_up,on
	hotkey,^down,assistant_MouseTracker_Down,on
	
	;submit the settings
	assistant_MouseTracker_RadioCoordMode()
	assistant_MouseTracker_RadioMethod()
	
	;Set timer for catching the mouse position
	SetTimer,assistant_MouseTracker_Task,100
}


assistant_MouseTracker_buttonOK()
{
	global
	gui,assistant_MouseTracker:submit
	
	;Destry the window
	assistant_MouseTracker_buttonCancel()
	
	;Write the results to the element settings GUI
	if (assistant_MouseTracker_NeededInfo.haskey("xpos"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.xpos,assistant_MouseTracker_EditPosX)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("ypos"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.ypos,assistant_MouseTracker_EditPosY)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("xpos2"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.xpos2,assistant_MouseTracker_EditPosX2)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("ypos2"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.ypos2,assistant_MouseTracker_EditPosY2)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("color"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.color,assistant_MouseTracker_ColorText)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("CoordMode"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.CoordMode,assistant_MouseTracker_RadioCoordModeName)
	}
	if (assistant_MouseTracker_NeededInfo.haskey("colorGetMethod"))
	{
		x_Par_SetValue(assistant_MouseTracker_NeededInfo.colorGetMethod,assistant_MouseTracker_RadioMethodName)
	}

}

assistant_MouseTrackerGuiEscape()
{
	assistant_MouseTracker_buttonCancel()
}
assistant_MouseTrackerGuiClose()
{
	assistant_MouseTracker_buttonCancel()
}


assistant_MouseTracker_buttonCancel()
{
	global
	gui,assistant_MouseTracker:destroy
	ui_enableElementSettingsWindow()
	
	;Disable hotkeys
	hotkey,right,assistant_MouseTracker_Right,off
	hotkey,left,assistant_MouseTracker_Left,off
	hotkey,up,assistant_MouseTracker_up,off
	hotkey,down,assistant_MouseTracker_Down,off
	
	;Clean up
	assistant_MouseTracker_MouseFoundX=
	assistant_MouseTracker_MouseFoundY=
	
	;Stop timer
	SetTimer,assistant_MouseTracker_Task,off
}

assistant_MouseTracker_Task()
{
	global

	IfWinNotExist,ahk_id %global_SettingWindowHWND%
	{
		assistant_MouseTracker_buttonCancel()
	}
	
	;get the mouse position and the window which is covered by the mouse
	CoordMode,mouse,% assistant_MouseTracker_RadioCoordModeName
	CoordMode,pixel,% assistant_MouseTracker_RadioCoordModeName
	MouseGetPos,assistant_MouseTracker_MouseX,assistant_MouseTracker_MouseY,tempwinidundermouse,tempcontrol

	;If user points to the gui of the assistant, do nothing
	if (tempwinidundermouse=assistant_MouseTracker_HWND)
		return

	if (assistant_MouseTracker_MouseX!=assistant_MouseTracker_MouseOldX or assistant_MouseTracker_MouseY!=assistant_MouseTracker_MouseOldY) ;Prevent to adapt the control while mouse is moving
	{
		
		assistant_MouseTracker_MouseOldX:=assistant_MouseTracker_MouseX
		assistant_MouseTracker_MouseOldY:=assistant_MouseTracker_MouseY
		tempMovedMouse:=true
	}
	else if (tempMovedMouse=true)
	{
		;User has moved the mouse and ahs left it at the position for some time
		gui,assistant_MouseTracker:submit,nohide
		
		if (assistant_MouseTracker_WhichPosSelector2)
		{
			assistant_MouseTracker_MouseFoundX2:=assistant_MouseTracker_MouseX
			assistant_MouseTracker_MouseFoundY2:=assistant_MouseTracker_MouseY
		}
		else
		{
			assistant_MouseTracker_MouseFoundX:=assistant_MouseTracker_MouseX
			assistant_MouseTracker_MouseFoundY:=assistant_MouseTracker_MouseY
		}
		
		if (assistant_MouseTracker_NeededInfo.haskey("xpos") or assistant_MouseTracker_NeededInfo.haskey("ypos"))
		
		{
			if (assistant_MouseTracker_NeededInfo.haskey("xpos2") or assistant_MouseTracker_NeededInfo.haskey("ypos2"))
			{
				if (assistant_MouseTracker_WhichPosSelector1)
				{
					guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosX,%assistant_MouseTracker_MouseFoundX%
					guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosY,%assistant_MouseTracker_MouseFoundY%
				}
				else if (assistant_MouseTracker_WhichPosSelector2)
				{
					guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosX2,%assistant_MouseTracker_MouseFoundX2%
					guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosY2,%assistant_MouseTracker_MouseFoundY2%
				}
			}
			else
			{
				guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosX,%assistant_MouseTracker_MouseFoundX%
				guicontrol,assistant_MouseTracker:,assistant_MouseTracker_EditPosY,%assistant_MouseTracker_MouseFoundY%
			}
		}
		
		if (assistant_MouseTracker_NeededInfo.haskey("color"))
		{
			PixelGetColor,tempcolor,%assistant_MouseTracker_MouseX%,%assistant_MouseTracker_MouseY%,rgb %assistant_MouseTracker_RadioMethodName%
			guicontrol,assistant_MouseTracker:,assistant_MouseTracker_ColorText,%tempcolor%
			guicontrol,assistant_MouseTracker: +background%tempcolor%,assistant_MouseTracker_ColorPreview
		}
		
		tempMovedMouse:=false
	}
	return
}


assistant_MouseTracker_RadioMethod()
{
	global
	gui,assistant_MouseTracker:submit,nohide
	loop 3
	{
		if (assistant_MouseTracker_RadioMethod%a_index%)
			assistant_MouseTracker_RadioMethod := A_Index
	}
	
	assistant_MouseTracker_RadioMethodName :=assistant_MouseTracker_RadioMethodNames[assistant_MouseTracker_RadioMethod]
	return
}

assistant_MouseTracker_RadioCoordMode()
{
	global
	gui,assistant_MouseTracker:submit,nohide
	loop 3
	{
		if (assistant_MouseTracker_RadioCoordMode%a_index%)
			assistant_MouseTracker_RadioCoordMode := A_Index
	}
	assistant_MouseTracker_RadioCoordModeName :=assistant_MouseTracker_RadioCoordModeNames[assistant_MouseTracker_RadioCoordMode]
	return
}

assistant_MouseTracker_Right()
{
	global
	SendMode,event
	MouseMove,1,0,0,r
	return
}

assistant_MouseTracker_Left()
{
	global
	SendMode,event
	MouseMove,-1,0,0,r
	return
}

assistant_MouseTracker_up()
{
	global
	SendMode,event
	MouseMove,0,-1,0,r
	return
}

assistant_MouseTracker_Down()
{
	global
	SendMode,event
	MouseMove,0,1,0,r
	return
}

