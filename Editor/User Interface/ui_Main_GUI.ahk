ui_CreateMainGui()
{
	global
	;Create tha main gui
	gui,MainGUI:default
	;~ gui,add,picture,vPicFlow hwndPicFlowHWND x0 y0 0xE hidden gclickOnPicture ;No picture needed anymore
	gui,add,StatusBar,hwndStatusbarHWND
	gui,add,hotkey,hidden hwndEditHWND ;To avoid error sound when user presses keys while this window is open
	gui +resize

	;This is needed by GDI+
	gui +lastfound
	gui,+HwndMainGuihwnd
	MainGuiHwnddc := GetDC(MainGuihwnd)
	ControlGetPos,,,,StatusBarHeight,msctls_statusbar321,ahk_id %MainGuihwnd%
	
	

	
	;Set some hotkeys that are needed in main window
	;~ hotkey,IfWinActive,ahk_id %MainGuihwnd%
	;~ hotkey,^x,ctrl_x
	;~ hotkey,^c,ctrl_c
	;~ hotkey,^v,ctrl_v
	;~ hotkey,^s,ctrl_s
	;~ hotkey,esc,esc
	;~ hotkey,del,del

	OnMessage(0x100,"keyPressed",1)
	OnMessage(0x203,"leftmousebuttondoubleclick",1)
	OnMessage(0x201,"leftmousebuttonclick",1)
	OnMessage(0x204,"rightmousebuttonclick",1)
	OnMessage(0x20A,"mousewheelmove",1)

	;the graphics need to be redrawn if window is moved. Expecially if the window was partially moved outside the screen.
	OnMessage(0x06,"WindowGetsActive",1)
	OnMessage(0x03,"WindowGetsMoved",1)
	
	
}

WindowGetsActive()
{
SetTimer,ui_Draw,-1

}

WindowGetsMoved()
{
SetTimer,ui_Draw,-1

}

leftmousebuttonclick(wpar,lpar,msg,hwn)
{
	global
	if (hwn!=MainGuihwnd and hwn!=StatusbarHWND)
		return
	SetTimer, leftmousebuttonclick,-1
}
rightmousebuttonclick(wpar,lpar,msg,hwn)
{
	global
	if (hwn!=MainGuihwnd and hwn!=StatusbarHWND)
		return
	SetTimer, rightmousebuttonclick,-1
}

leftmousebuttondoubleclick(wpar,lpar,msg,hwn)
{
	global
	;~ ToolTip  %hwn% d
	if (hwn!=MainGuihwnd and hwn!=StatusbarHWND)
		return
	SetTimer, leftmousebuttondoubleclick,-1
}



keyPressed(wpar,lpar,msg,hwn)
{
	global
	
	if (hwn!=MainGuihwnd and hwn!=StatusbarHWND and hwn!=EditHWND)
		return
	;~ ToolTip %wpar% - %lpar% - %msg% - %hwn%
	wpar2:=wpar
	;~ ToolTip % format("{1:#X} - {2:#X} - ",wpar2,lpar)
	
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

mousewheelmove(wpar,lpar,msg,hwn)
{
	global
	;~ temp:=format("{1:#x}",hwn)
	;~ wingetpos,tempwinx,tempwiny,tempwinw,tempwinh,ahk_id %MainGuihwnd%
	;~ controlgetpos,tempx,tempy,tempw,temph,,ahk_id %hwn%
	;~ ToolTip %wpar% - %lpar% - %msg% - %hwn% : %StatusbarHWND% - %temp% - %MainGuihwnd% __ %tempx%- %tempy%- %tempw%- %temph% __ %tempwinx%-%tempwiny%-%tempwinw%-%tempwinh%
	;~ ui_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,tempx,tempy,tempw,temph)
	if (hwn!=MainGuihwnd and hwn!=StatusbarHWND and hwn!=EditHWND)
		return
	;~ ToolTip %wpar% - %lpar% - %msg% - %hwn%
	wpar2:=wpar
	;~ ToolTip % format("{1:#X}",wpar2)
	if wpar=7864328
		SetTimer, ctrl_wheelup,-1 
	else if wpar=4287102984
		SetTimer, ctrl_wheeldown,-1 
	;~ ToolTip %wpar% - %lpar% - %msg% - %hwn%
	;~ SetTimer, ctrl_wheelup,-1 
}



ui_DisableMainGUI()
{
	global
	gui,MainGUI:+disabled
	
}
ui_EnableMainGUI()
{
	global
	gui,MainGUI:-disabled
	
	;Activate window if it is not hidden
	DetectHiddenWindows,off
	IfWinExist,ahk_id %MainGuihwnd%
	{
		DetectHiddenWindows,on
		WinActivate,ahk_id %MainGuihwnd%
	}
	DetectHiddenWindows,on
}

ui_showgui()
{
	global
	SysGet, MonitorPrimary, MonitorPrimary
	SysGet,MonitorWorkArea,MonitorWorkArea,%MonitorPrimary% 
	
	
	tempwidth:=round((MonitorWorkArearight - MonitorWorkArealeft)*0.9)
	tempheight:=round((MonitorWorkAreabottom -MonitorWorkAreatop)*0.9)

	if guiAlreadyShowed=true
		gui,MainGUI:show, w%widthofguipic%,% "·AutoHotFlow· " lang("Editor") " - " flowName ;Added  w%widthofguipic% to trigger the guisize label
	else
		gui,MainGUI:show,  w%tempwidth% h%tempheight%,% "·AutoHotFlow· " lang("Editor") " - " flowName
	sleep 10
	
	ui_Draw()
	ui_UpdateStatusbartext()
	
	
	
}

ui_UpdateStatusbartext(which="")
{
	global
	if (which="pos" or which ="")
	{
		
		if not TheOnlyOneMarkedElement
			sb_SetText("Offset: x " Round(offsetx) " y " Round(offsety) "   |   Zoom: " Round(zoomFactor,2 ),1) 
		else
			sb_SetText("Offset: x " Round(offsetx) " y " Round(offsety) "   |   Zoom: " Round(zoomFactor,2 ) "   |   Marked Element: " TheOnlyOneMarkedElement ,1) 
	}
}

;Get the position of main gui and store it into global variables
ui_GetMainGUIPos()
{
	global 
	WinGetPos,MainGUIX,MainGUIY,MainGUIWidth,MainGUIHeight,ahk_id %MainGuihwnd%
}

ui_OnLanguageChange()
{
	global mainguihwnd
	global flowName
	ui_Draw()
	DetectHiddenWindows off
	WinGetTitle,temp,ahk_id %mainguihwnd%
	IfWinExist,% temp
		gui,MainGUI:show,,% "·AutoHotFlow· " lang("Editor") " - " flowName 
	else
		gui,MainGUI:show,hide,% "·AutoHotFlow· " lang("Editor") " - " flowName 
	
	;Help! I want that the menus are renamed when the language changes.
	;~ initializeTrayBar()
	;~ initializeMenuBar()
}


goto,jumpOverGUIJumpLabels





MainGUIguisize: ;resize the picture when GUI is resized


;MsgBox w%A_guiwidth%  %a_guiheight%
GuiControl,move,PicFlow,w%A_guiwidth%  h%a_guiheight%
heightofguipic:=a_guiheight - StatusBarHeight

widthofguipic:=a_guiwidth
guicontrolget,guipic,pos,PicFlow ;get the picture position. -> gx, gy

;SB_SetParts(a_guiwidth*0.2,a_guiwidth*0.5,a_guiwidth*0.3)
SB_SetParts(a_guiwidth)


ui_draw()
return

GetClientSize(hwnd, ByRef w, ByRef h)
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}


jumpOverGUIJumpLabels: