; Create the main gui. Do not show yet
EditorGUIInit()
{
	global

	;We use this variable to indicate whether the main gui is disabled
	CurrentlyMainGuiIsDisabled:=false
	
	; Create the gui. It is empty, since the draw thread will paint the picture inside the gui
	gui,MainGUI:default
	gui,-dpiscale ; DPI Scaling would cause diffilcuties when calculating mouse coordinates
	; Add a statsu bar
	gui,add,StatusBar,hwnd_StatusbarHWND
	_setSharedProperty("hwnds.editGUIStatusbar" FlowID, _StatusbarHWND)
	_setSharedProperty("hwnds.editGUIStatusbar" Global_ThisThreadID, _StatusbarHWND)

	; Add an hidden control, to avoid error sound when user presses keys while this window is open
	gui,add,hotkey,hidden hwnd_EditControlHWND
	_setSharedProperty("hwnds.editGUIEditControl" FlowID, _EditControlHWND)
	_setSharedProperty("hwnds.editGUIEditControl" Global_ThisThreadID, _EditControlHWND)
	gui +resize

	;Store information which is needed by the draw thread
	gui,+Hwnd_EditorGuiHwnd
	_setSharedProperty("hwnds.editGUI" FlowID, _EditorGuiHwnd)
	_setSharedProperty("hwnds.editGUI" Global_ThisThreadID, _EditorGuiHwnd)
	_setSharedProperty("hwnds.editGUIDC" FlowID, GetDC(_EditorGuiHwnd))
	_setSharedProperty("hwnds.editGUIDC" Global_ThisThreadID, GetDC(_EditorGuiHwnd))
	
	; find out the height of the status bar, so we can calculate the available space for the rendered picture
	gui +lastfound
	ControlGetPos,,,,StatusBarHeight,,ahk_id %_StatusbarHWND%
	EditGUI_StatusBarHeight:=StatusBarHeight
	
	; Initialize the menu bar
	initializeMenuBar()
	ui_UpdateStatusbartext()
	
	;Set some hotkeys that are needed in editor gui
	hotkey,IfWinActive,% "ahk_id " _EditorGuiHwnd
	
	hotkey,^c,ctrl_c
	hotkey,^v,ctrl_v
	hotkey,^s,ctrl_s
	hotkey,^z,ctrl_z
	hotkey,^y,ctrl_y
	hotkey,^a,ctrl_a
	
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

; Show editor.
; this function is called from file a common module, which is also used by the manager thread.
; For Manager thread this function is defined in the "API Caller to Editor". The editor thread does not need to use the api.
API_Editor_EditGUIshow(FlowID) ;Api function which is used in common code
{
	EditGUIshow()
}

; show editor
EditGUIshow()
{
	global


	; show window
	flowName := _getFlowProperty(FlowID, "Name")
	if (Editor_guiAlreadyShown=true)
	{
		 ;Added  w%widthofguipic% to trigger the guisize label
		gui, MainGUI:show, w%widthofguipic%,% "·AutoHotFlow· " lang("Editor") " - " flowName
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
		gui, MainGUI:show,  w%tempwidth% h%tempheight%,% "·AutoHotFlow· " lang("Editor") " - " flowName
	}
	Editor_guiAlreadyShown:=true
}

; disable editor
EditGUIDisable()
{
	global
	; We don't disable the gui itself, but we will block user input now using this variable
	CurrentlyMainGuiIsDisabled:=true
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
	CurrentlyMainGuiIsDisabled:=false
	
	; redraw picture
	API_Draw_Draw(FlowID)
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
	API_Draw_Draw(FlowID)
}

; react if window gets moved
WindowGetsMoved()
{
	; redraw the picture
	API_Draw_Draw(FlowID)
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

; react if user presses a key TODO, do we actually use this or the hotkeys?
keyPressed(wpar, lpar, msg, hwn)
{
	global
	
	if (hwn!=_EditControlHWND and hwn!=_StatusbarHWND and hwn!=_EditorGuiHwnd)
	{
		; react only if user interacted with the main gui
		return
	}
	wpar2:=wpar
	
	if (wpar=0x53)
	{
		if getkeystate("ctrl")
			SetTimer, ctrl_s,-1
	}
	if (wpar=0x43)
	{
		if getkeystate("ctrl")
			SetTimer, ctrl_c,-1
	}
	if (wpar=0x56)
	{
		if getkeystate("ctrl")
			SetTimer, ctrl_v,-1
	}
	if (wpar=0x1b)
	{
		SetTimer, esc,-1
	}
	if (wpar=0x2e)
	{
		SetTimer, del,-1
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
	if (wpar = 7864328)
		SetTimer, ctrl_wheelup, -1 
	else if (wpar = 4287102984)
		SetTimer, ctrl_wheeldown, -1 
}

; When user tries to interact with disabled gui, enable the child gui
ui_ActionWhenMainGUIDisabled()
{
	global
	SoundPlay,*16 ; Play the warn sound
	WinActivate,ahk_id %CurrentlyActiveWindowHWND%
}

; Update the status bar text
ui_UpdateStatusbartext(which="")
{
	global
	static elementtext
	if (which!="pos")
	{
		; update element text if not only the position needs to be updated
		selectedElements := _getFlowProperty(FlowID, "selectedElements")
		if (selectedElements.count()=0)
		{
			elementtext:=lang("%1% elements", _getAllElementIds(FlowID).count())
		}
		else if (selectedElements.count()=1)
		{
			elementtext:=lang("1 marked element: %1%",_getFlowProperty(FlowID, "selectedElement"))
		}
		else
		{
			elementtext:=lang("%1% marked elements", selectedElements.count())
		}
	}
	; get position informations
	offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx")
	offsety := _getFlowProperty(FlowID, "flowSettings.offsety")
	zoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomFactor")

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
	API_Draw_Draw(FlowID)

	DetectHiddenWindows off
	WinGetTitle, temp, % "ahk_id " _EditorGuiHwnd
	
	flowName := _getFlowProperty(FlowID, "Name")
	IfWinExist,% temp
		gui,MainGUI:show,,% "·AutoHotFlow· " lang("Editor") " - " flowName 
	else
		gui,MainGUI:show,hide,% "·AutoHotFlow· " lang("Editor") " - " flowName 
	
	;TODO Renamed the menus when the language changes.
	;~ initializeTrayBar()
	;~ initializeMenuBar()
}


 ;redraw the picture when GUI is resized
MainGUIguisize()
{
	global EditGUI_StatusBarHeight
	; adjust the status bar
	SB_SetParts(a_guiwidth)

	; calculate and share the available space for the picture 
	heightofguipic:=a_guiheight - EditGUI_StatusBarHeight
	widthofguipic:=a_guiwidth
	_setFlowProperty(FlowID, "draw.heightofguipic", heightofguipic)
	_setFlowProperty(FlowID, "draw.widthofguipic", widthofguipic)

	; Redraw the picture
	API_Draw_Draw(FlowID)
}

; returns the gui client size
GetClientSize(hwnd, ByRef w, ByRef h)
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}


