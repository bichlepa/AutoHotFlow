goto,jumpoverMouseTracker

MouseTracker(settingsobject)
{
	global
	local temp
	loop 3
		MouseTrackerCoordMode%a_index%=
	;~ MsgBox % strobj(settingsobject)
	if settingsobject.HasKey("ParCoordMode")
	{
		MouseTrackerParCoordMode:=settingsobject.ParCoordMode
		if GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%1
			MouseTrackerCoordMode1=checked
		if GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%2
			MouseTrackerCoordMode2=checked
		if GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%3
			MouseTrackerCoordMode3=checked
	}
	else
	{
		if settingsobject.HasKey("CoordMode")
			MouseTrackerCoordMode:=settingsobject.CoordMode
	}
	
	loop 3
		MouseTrackerRadioMethod%a_index%=
	if settingsobject.HasKey("ParGetPixelColorMethod")
	{
		MouseTrackerParGetPixelColorMethod:=settingsobject.ParGetPixelColorMethod
		if GUISettingsOfElement%setElementID%%MouseTrackerParGetPixelColorMethod%1
			MouseTrackerRadioMethod1=checked
		if GUISettingsOfElement%setElementID%%MouseTrackerParGetPixelColorMethod%2
			MouseTrackerRadioMethod2=checked
		if GUISettingsOfElement%setElementID%%MouseTrackerParGetPixelColorMethod%3
			MouseTrackerRadioMethod3=checked
	}
	else
		MouseTrackerRadioMethod1=checked
	
	if settingsobject.haskey("ImportMousePos")
		MouseTrackerImportMousePos:=settingsobject.ImportMousePos
	else
		MouseTrackerImportMousePos=
	if settingsobject.haskey("ParColor")
		MouseTrackerParColor:=settingsobject.ParColor
	else
		MouseTrackerParColor=
	if settingsobject.haskey("ImportColor")
		MouseTrackerImportColor:=settingsobject.ImportColor
	else
		MouseTrackerImportColor=
	if settingsobject.haskey("SelectParMousePos")
		MouseTrackerSelectParMousePos:=settingsobject.SelectParMousePos
	else
		MouseTrackerSelectParMousePos=
	if settingsobject.haskey("SelectParMousePosLabelPos1")
		MouseTrackerSelectParMousePosLabelPos1:=settingsobject.SelectParMousePosLabelPos1
	else
		MouseTrackerSelectParMousePosLabelPos1=
	if settingsobject.haskey("SelectParMousePosLabelPos2")
		MouseTrackerSelectParMousePosLabelPos2:=settingsobject.SelectParMousePosLabelPos2
	else
		MouseTrackerSelectParMousePosLabelPos2=
	if settingsobject.haskey("ParMousePosX")
		MouseTrackerParMousePosX:=settingsobject.ParMousePosX
	else
		MouseTrackerParMousePosX=
	if settingsobject.haskey("ParMousePosY")
		MouseTrackerParMousePosY:=settingsobject.ParMousePosY
	else
		MouseTrackerParMousePosY=
	if settingsobject.haskey("ParMousePosX2")
		MouseTrackerParMousePosX2:=settingsobject.ParMousePosX2
	else
		MouseTrackerParMousePosX2=
	if settingsobject.haskey("ParMousePosY2")
		MouseTrackerParMousePosY2:=settingsobject.ParMousePosY2
	else
		MouseTrackerParMousePosY2=
	
	SetTimer,MouseTrackerCreateGUI,-1
}

MouseTrackerCreateGUI:

if GUISettingsOfElement%setElementID%CoordMode1
	MouseTrackerCoordMode1=checked
if GUISettingsOfElement%setElementID%CoordMode2
	MouseTrackerCoordMode2=checked
if GUISettingsOfElement%setElementID%CoordMode3
	MouseTrackerCoordMode3=checked

gui, MouseTracker:Default

if (MouseTrackerImportColor="yes")
	gui,add,ListView,h200 w200 vMouseTrackerColor
gui,add,text,w200,% lang("Hold control key down and use keyboard cursors to move mouse by one pixel.")
gui,font,wbold
gui,add,text,x10,% lang("Mouse position")
gui,font,wnorm
if settingsobject.HasKey("ParCoordMode")
{
	gui,add,radio,vMouseTrackerCoordMode1 gMouseTrackerRadioCoordMode %MouseTrackerCoordMode1%,%  lang("Relative to screen")
	gui,add,radio,vMouseTrackerCoordMode2 gMouseTrackerRadioCoordMode %MouseTrackerCoordMode2%,% lang("Relative to active window position")
	gui,add,radio,vMouseTrackerCoordMode3 gMouseTrackerRadioCoordMode %MouseTrackerCoordMode3%,% lang("Relative to active window client position")
}
gui,add,edit,vMouseTrackerColorTextMouse readonly r2
gui,font,wbold
gui,add,text,,% lang("Color ID")
gui,font,wnorm
gui,add,edit,vMouseTrackerColorText readonly w100
if not (MouseTrackerImportColor="yes")
	gui,add,ListView,yp x+10 w90 h20 vMouseTrackerColor

if (MouseTrackerImportColor="yes")
{
	gui,font,wbold
	gui,add,text,,% lang("Method")
	gui,font,wnorm
	gui,add,radio,vMouseTrackerMethod1 gMouseTrackerRadioMethod %MouseTrackerRadioMethod1%,% lang("Default method")
	gui,add,radio,vMouseTrackerMethod2 gMouseTrackerRadioMethod %MouseTrackerRadioMethod2%,% lang("Alternative method")
	gui,add,radio,vMouseTrackerMethod3 gMouseTrackerRadioMethod %MouseTrackerRadioMethod3%,% lang("Slow method")
}

if (MouseTrackerImportMousePos="optional" or MouseTrackerSelectParMousePos="yes")
{
	gui,font,wbold
	gui,add,text,x10,% lang("Import")
	gui,font,wnorm
}
if (MouseTrackerImportMousePos="optional")
	gui,add,checkbox,x10  w200  vMouseTrackerCheckBoxImportMousePos,% lang("Import mouse position")
if (MouseTrackerSelectParMousePos="yes")
{
	gui,add,radio,x10  w200 group checked vMouseTrackerRadioSelectParMousePosLabelPos1,% MouseTrackerSelectParMousePosLabelPos1
	gui,add,radio,x10  w200  vMouseTrackerRadioSelectParMousePosLabelPos2,% MouseTrackerSelectParMousePosLabelPos2
}
gui,add,Button,x10  w200  vMouseTrackerButtonOK gMouseTrackerbuttonOK,% lang("OK")
gui,add,Button,x10  w200  vMouseTrackerButtonCancel gMouseTrackerbuttonCancel,% lang("Cancel")
gui,+hwndMouseTrackerHWND
gui,+alwaysontop

;Put the window in the center of the main window
gui,show,hide
wingetpos,tempParentX,tempParentY,tempParentW,tempParentH,ahk_id %SettingsGUIHWND%
;~ MsgBox %tempParentX%
wingetpos,,,tempWidth,tempHeight,ahk_id %MouseTrackerHWND%
tempXpos:=round(tempParentX+tempParentW/2- tempWidth/2)
tempYpos:=round(tempParentY+tempParentH/2- tempHeight/2)

gui,show,x%tempXpos% y%tempYpos%,% lang("Mouse tracker")

hotkey,ifwinactive
hotkey,ifwinexist
hotkey,^right,MouseTrackerRight,on
hotkey,^left,MouseTrackerLeft,on
hotkey,^up,MouseTrackerup,on
hotkey,^down,MouseTrackerDown,on
gosub, MouseTrackerRadioCoordMode
gosub, MouseTrackerRadioMethod
SetTimer,MouseTrackerGetColorCoveredByMouse,100
return


MouseTrackerbuttonOK:
gui,MouseTracker:submit
gui,SettingsOfElement:default
if (MouseTrackerImportColor="yes")
{
	guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerParColor%,%MouseTrackerColorText%
}

if (MouseTrackerImportMousePos="yes" or( MouseTrackerImportMousePos="optional" and MouseTrackerCheckBoxImportMousePos=1))
{
	if (MouseTrackerSelectParMousePos="yes")
	{
		if MouseTrackerRadioSelectParMousePosLabelPos1=1
		{
			MouseTrackerThisParMousePosX:=MouseTrackerParMousePosX
			MouseTrackerThisParMousePosY:=MouseTrackerParMousePosY
		}
		else
		{
			MouseTrackerThisParMousePosX:=MouseTrackerParMousePosX2
			MouseTrackerThisParMousePosY:=MouseTrackerParMousePosY2
		}
	}
	else
	{
		MouseTrackerThisParMousePosX:=MouseTrackerParMousePosX
		MouseTrackerThisParMousePosY:=MouseTrackerParMousePosY
	}
	
	if MouseTrackerParMousePosX!=
		guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerThisParMousePosX%,%MouseTrackerMouseFoundX%
	if MouseTrackerParMousePosY!=
		guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerThisParMousePosY%,%MouseTrackerMouseFoundY%
	if MouseTrackerParCoordMode!=
	{
		guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%1,%MouseTrackerCoordMode1%
		guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%2,%MouseTrackerCoordMode2%
		guicontrol,,GUISettingsOfElement%setElementID%%MouseTrackerParCoordMode%3,%MouseTrackerCoordMode3%
	}
}

goto,MouseTrackerbuttonCancel
MouseTrackerbuttonCancel:
gui,MouseTracker:destroy
gui,SettingsOfElement:default
hotkey,right,MouseTrackerRight,off
hotkey,left,MouseTrackerLeft,off
hotkey,up,MouseTrackerup,off
hotkey,down,MouseTrackerDown,off
MouseTrackerMouseFoundX=
MouseTrackerMouseFoundY=
SetTimer,MouseTrackerGetColorCoveredByMouse,off
return

MouseTrackerGetColorCoveredByMouse:

IfWinNotExist,ahk_id %settingsguiHWND%
	goto,MouseTrackerbuttonCancel
;get the mouse position
CoordMode,mouse,%MouseTrackerCoordMode%
CoordMode,pixel,%MouseTrackerCoordMode%
MouseGetPos,MouseTrackerMouseX,MouseTrackerMouseY,tempwinidundermouse,tempcontrol

if (tempwinidundermouse=MouseTrackerHWND)
	return

if (MouseTrackerMouseX!=MouseTrackerMouseOldX or MouseTrackerMouseY!=MouseTrackerMouseOldY) ;Prevent to adapt the control while mouse is moving
{
	
	MouseTrackerMouseOldX:=MouseTrackerMouseX
	MouseTrackerMouseOldY:=MouseTrackerMouseY
	tempMovedMouse:=true
}
else if (tempMovedMouse=true)
{
	MouseTrackerMouseFoundX:=MouseTrackerMouseX
	MouseTrackerMouseFoundY:=MouseTrackerMouseY
	gui,MouseTracker:submit,nohide
	PixelGetColor,tempcolor,%MouseTrackerMouseX%,%MouseTrackerMouseY%,rgb %MouseTrackerMethod%
	guicontrol,MouseTracker:,MouseTrackerColorText,%tempcolor%
	guicontrol,MouseTracker:,MouseTrackerColorTextMouse,x: %MouseTrackerMouseFoundX%`ny: %MouseTrackerMouseFoundY%
	
	guicontrol,MouseTracker: +background%tempcolor%,MouseTrackerColor
	tempMovedMouse:=false
	return
	
	
}

return


MouseTrackerRadioMethod:
gui,MouseTracker:submit,nohide
if MouseTrackerMethod1
	MouseTrackerMethod=
if MouseTrackerMethod2
	MouseTrackerMethod=alt
if MouseTrackerMethod3
	MouseTrackerMethod=slow
return
MouseTrackerRadioCoordMode:
gui,MouseTracker:submit,nohide
if MouseTrackerCoordMode1
	MouseTrackerCoordMode=Screen
if MouseTrackerCoordMode2
	MouseTrackerCoordMode=window
if MouseTrackerCoordMode3
	MouseTrackerCoordMode=client
return

MouseTrackerRight:
SendMode,event
MouseMove,1,0,0,r
return
MouseTrackerLeft:
SendMode,event
MouseMove,-1,0,0,r
return
MouseTrackerup:
SendMode,event
MouseMove,0,-1,0,r
return
MouseTrackerDown:
SendMode,event
MouseMove,0,1,0,r
return

jumpoverMouseTracker:
temp=

	
