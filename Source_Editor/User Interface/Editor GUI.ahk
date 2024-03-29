﻿global global_CurrentlyMainGuiIsDisabled
global global_CurrentlyActiveWindowHWND

; Create the main gui. Do not show yet
EditorGUIInit()
{
	global

	;We use this variable to indicate whether the main gui is disabled
	global_CurrentlyMainGuiIsDisabled:=false
	
	; Create the gui. It is empty, since the draw thread will paint the picture inside the gui
	gui,MainGUI:default
	gui,-dpiscale ; DPI Scaling would cause diffilcuties when calculating mouse coordinates
	; Add a status bar
	gui,add,StatusBar,hwnd_StatusbarHWND
	_setSharedProperty("hwnds.editGUIStatusbar" _FlowID, _StatusbarHWND)
	_setSharedProperty("hwnds.editGUIStatusbar" Global_ThisThreadID, _StatusbarHWND)

	; Add an hidden control, to avoid error sound when user presses keys while this window is open
	gui,add,hotkey,hidden hwnd_EditControlHWND
	_setSharedProperty("hwnds.editGUIEditControl" _FlowID, _EditControlHWND)
	_setSharedProperty("hwnds.editGUIEditControl" Global_ThisThreadID, _EditControlHWND)
	gui +resize

	;Store information which is needed by the draw thread
	gui,+Hwnd_EditorGuiHwnd
	_setSharedProperty("hwnds.editGUI" _FlowID, _EditorGuiHwnd)
	_setSharedProperty("hwnds.editGUI" Global_ThisThreadID, _EditorGuiHwnd)
	_setSharedProperty("hwnds.editGUIDC" _FlowID, GetDC(_EditorGuiHwnd))
	_setSharedProperty("hwnds.editGUIDC" Global_ThisThreadID, GetDC(_EditorGuiHwnd))
	
	; find out the height of the status bar, so we can calculate the available space for the rendered picture
	gui +lastfound
	ControlGetPos,,,,StatusBarHeight,,ahk_id %_StatusbarHWND%
	EditGUI_StatusBarHeight:=StatusBarHeight

	; Initialize the menu bar
	initializeMenuBar()
	ui_UpdateStatusbartext()
	
	;React on key
	OnMessage(0x100,"keyPressed",1)

	;React on mouse events
	OnMessage(0x203,"leftmousebuttondoubleclick",1)
	OnMessage(0x201,"leftmousebuttonclick",1)
	OnMessage(0x204,"rightmousebuttonclick",1)
	OnMessage(0x20A,"mousewheelmove",1)

	;the graphics need to be redrawn if window is moved. Expecially if the window was partially moved outside the screen.
	OnMessage(0x06,"WindowGetsActive",1)
	OnMessage(0x03,"WindowGetsMoved",1)
}


; show editor
EditGUIshow()
{
	global


	; show window
	flowName := _getFlowProperty(_FlowID, "Name")
	if (Editor_guiAlreadyShown=true)
	{
		 ;Added  w%widthofguipic% to trigger the guisize label
		gui, MainGUI:show, w%widthofguipic%,% "AutoHotFlow " lang("Editor") " - " flowName
	}
	else
	{
		; This is the first time we show the window

		; get the work area of the primary monitor
		local MonitorPrimary
		SysGet, MonitorPrimary, MonitorPrimary
		SysGet, MonitorWorkArea, MonitorWorkArea,%MonitorPrimary% 

		; Make window fill almost the whole screen
		local tempwidth:=round((MonitorWorkArearight - MonitorWorkArealeft)*0.9)
		local tempheight:=round((MonitorWorkAreabottom -MonitorWorkAreatop)*0.9)

		; show window
		gui, MainGUI:show,  w%tempwidth% h%tempheight%,% "AutoHotFlow " lang("Editor") " - " flowName
	}
	Editor_guiAlreadyShown:=true
}

EditGuiSetIcon(flowState)
{
	global

	; check whether icon has to be changed
	static oldFlowState
	if (oldFlowState != flowState)
	{
		oldFlowState := flowState
		
		; set the gui icon
		gui, MainGUI:+LastFound
		setGuiIcon(_ScriptDir "\icons\" flowState ".ico")
	}

}

; disable editor
EditGUIDisable()
{
	global
	; We don't disable the gui itself, but we will block user input now using this variable
	global_CurrentlyMainGuiIsDisabled:=true
}

; Enable editor
EditGUIEnable()
{
	global
	
	;Activate window if it is not hidden
	DetectHiddenWindows,off
	IfWinExist,% "ahk_id " _EditorGuiHwnd
	{
		DetectHiddenWindows,on
		WinActivate,% "ahk_id " _EditorGuiHwnd
	}
	DetectHiddenWindows,on
	global_CurrentlyMainGuiIsDisabled:=false
	
	; redraw picture
	API_Draw_Draw(_FlowID)
}


;Get the position of main gui
EditGUIGetPos()
{
	global
	local MainGUIX, MainGUIY, MainGUIWidth, MainGUIHeight
	WinGetPos, MainGUIX, MainGUIY, MainGUIWidth, MainGUIHeight, % "ahk_id " _EditorGuiHwnd
	return {x: MainGUIX, y: MainGUIY, w: MainGUIWidth, h: MainGUIHeight}
}

; react if window gets active
WindowGetsActive()
{
	; redraw the picture
	API_Draw_Draw(_FlowID)
}

; react if window gets moved
WindowGetsMoved()
{
	; redraw the picture
	API_Draw_Draw(_FlowID)
}

; user clicked with left mouse button
leftmousebuttonclick(wpar,lpar,msg,hwn)
{
	global 
	if (hwn!=_EditorGuiHwnd and hwn!=_StatusbarHWND)
	{
		; react only if user interacted with the main gui
		return
	}
	SetTimer, ui_leftmousebuttonclick,-1
}

; user clicked with right mouse button
rightmousebuttonclick(wpar,lpar,msg,hwn)
{
	global 
	if (hwn!=_EditorGuiHwnd and hwn!=_StatusbarHWND)
	{
		; react only if user interacted with the main gui
		return
	}
	SetTimer, ui_rightmousebuttonclick,-1
}

; user double clicked with left mouse button
leftmousebuttondoubleclick(wpar,lpar,msg,hwn)
{
	global
	if (hwn != _EditorGuiHwnd  and hwn != _StatusbarHWND)
	{
		; react only if user interacted with the main gui
		return
	}
	SetTimer, ui_leftmousebuttondoubleclick,-1
}

; react if user presses a key
keyPressed(wpar, lpar, msg, hwn)
{
	global
	
	if (hwn!=_EditControlHWND and hwn!=_StatusbarHWND and hwn!=_EditorGuiHwnd)
	{
		; react only if user interacted with the main gui
		return
	}
	
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}
	
	; wpar defines the hotkey
	if (wpar = GetKeyVK("a"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_a,-1
	}
	if (wpar = GetKeyVK("c"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_c,-1
	}
	if (wpar = GetKeyVK("s"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_s,-1
	}
	if (wpar = GetKeyVK("v"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_v,-1
	}
	if (wpar = GetKeyVK("x"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_x,-1
	}
	if (wpar = GetKeyVK("y"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_y,-1
	}
	if (wpar = GetKeyVK("z"))
	{
		if getkeystate("ctrl")
			SetTimer, key_ctrl_z,-1
	}
	if (wpar = GetKeyVK("DEL"))
	{
		SetTimer, key_del,-1
	}
}

; React on mouse wheel movement
mousewheelmove(wpar, lpar, msg, hwn)
{
	global
	
	if (hwn!=_EditControlHWND and hwn!=_StatusbarHWND and hwn!=_EditorGuiHwnd)
	{
		; react only if user interacted with the main gui
		return
	}
	
	if global_CurrentlyMainGuiIsDisabled ;If an other GUI is opened and some functions of the main gui are disabled
	{
		ui_ActionWhenMainGUIDisabled()
		return
	}

	if (hwn!=_EditControlHWND and hwn!=_StatusbarHWND and hwn!=_EditorGuiHwnd)
	{
		; react only if user interacted with the main gui
		return
	}
	if (wpar = 7864320 or wpar = 7864328)
		SetTimer, mouse_wheelup, -1 
	else if (wpar = 4287102976 or wpar = 4287102984)
		SetTimer, mouse_wheeldown, -1 
}

; When user tries to interact with disabled gui, enable the child gui
ui_ActionWhenMainGUIDisabled()
{
	SoundPlay,*16 ; Play the warn sound
	WinActivate,ahk_id %global_CurrentlyActiveWindowHWND%
}

; Update the status bar text
ui_UpdateStatusbartext(which="")
{
	global
	static elementtext

	if (which != "pos")
	{
		; update element text if not only the position needs to be updated
		selectedElements := _getFlowProperty(_FlowID, "selectedElements")
		if (selectedElements.count()=0)
		{
			elementtext:=lang("%1% elements", _getAllElementIds(_FlowID).count())
		}
		else if (selectedElements.count()=1)
		{
			elementtext:=lang("1 selected element: %1%",_getFlowProperty(_FlowID, "selectedElement"))
		}
		else
		{
			elementtext:=lang("%1% selected elements", selectedElements.count())
		}
	}
	; get position informations
	offsetx := _getFlowProperty(_FlowID, "flowSettings.offsetx")
	offsety := _getFlowProperty(_FlowID, "flowSettings.offsety")
	zoomFactor := _getFlowProperty(_FlowID, "flowSettings.zoomFactor")

	; update status bar text
	gui,maingui:default
	sb_SetText("Offset: x " Round(offsetx) " y " Round(offsety) "   |   Zoom: " Round(zoomFactor,2 )  "   |   " elementtext  ,1)
}

; Updates the localized labels TODO: it is not finished and is never called
ui_OnLanguageChange()
{
	global 
	local temp

	; Redraw the flow
	API_Draw_Draw(_FlowID)

	DetectHiddenWindows off
	WinGetTitle, temp, % "ahk_id " _EditorGuiHwnd
	
	flowName := _getFlowProperty(_FlowID, "Name")
	IfWinExist,% temp
		gui,MainGUI:show,,% "AutoHotFlow " lang("Editor") " - " flowName 
	else
		gui,MainGUI:show,hide,% "AutoHotFlow " lang("Editor") " - " flowName 
	
	;TODO Renamed the menus when the language changes.
	;~ initializeTrayBar()
	;~ initializeMenuBar()
}


 ;redraw the picture when GUI is resized
MainGUIguisize()
{
	global EditGUI_StatusBarHeight
	global heightofguipic
	global widthofguipic
	; adjust the status bar
	SB_SetParts(a_guiwidth)

	; calculate and share the available space for the picture 
	heightofguipic:=a_guiheight - EditGUI_StatusBarHeight
	widthofguipic:=a_guiwidth
	_setFlowProperty(_FlowID, "draw.heightofguipic", heightofguipic)
	_setFlowProperty(_FlowID, "draw.widthofguipic", widthofguipic)

	; Redraw the picture
	API_Draw_Draw(_FlowID)
}

; returns the gui client size
GetClientSize(hwnd, ByRef w, ByRef h)
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}


