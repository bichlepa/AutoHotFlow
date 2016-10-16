
EditorGUIInit()
{
	global
	local MainGuihwnd, StatusbarHWND

	;Create the main gui
	CurrentlyMainGuiIsDisabled:=false
	
	gui,MainGUI:default
	gui,-dpiscale
	;~ gui,add,picture,vPicFlow hwndPicFlowHWND x0 y0 0xE hidden gclickOnPicture ;No picture needed anymore
	gui,add,StatusBar,hwndStatusbarHWND
	_share.hwnds["editGUIStatusbar" FlowID] := StatusbarHWND
	_share.hwnds["editGUIStatusbar" Global_ThisThreadID] := StatusbarHWND
	gui,add,hotkey,hidden hwndEditControlHWND ;To avoid error sound when user presses keys while this window is open
	_share.hwnds["editGUIEditControl" FlowID] := EditControlHWND
	_share.hwnds["editGUIEditControl" Global_ThisThreadID] := EditControlHWND
	gui +resize

	;This is needed by GDI+
	gui +lastfound
	gui,+HwndMainGuihwnd
	_share.hwnds["editGUI" FlowID]:=MainGuihwnd
	_share.hwnds["editGUI" Global_ThisThreadID]:=MainGuihwnd
	
	_share.hwnds["editGUIDC" FlowID] := GetDC(MainGuihwnd)
	_share.hwnds["editGUIDC" Global_ThisThreadID] := GetDC(MainGuihwnd)
	
	ControlGetPos,,,,StatusBarHeight,,ahk_id %StatusbarHWND%
	EditGUI_StatusBarHeight:=StatusBarHeight
	
	
	initializeMenuBar()
	
	;~ MsgBox %StatusBarHeight%
	
	;Set some hotkeys that are needed in main window 
	hotkey,IfWinActive,% "ahk_id " _share.hwnds["editGUI" FlowID]
	;~ hotkey,^x,ctrl_x
	
	hotkey,^c,ctrl_c
	hotkey,^v,ctrl_v
	hotkey,^s,ctrl_s
	hotkey,^z,ctrl_z
	hotkey,^y,ctrl_y
	hotkey,^a,ctrl_a
	
	;~ hotkey,esc,esc
	;~ hotkey,del,del
	
	;React on user input
	OnMessage(0x100,"keyPressed",1)
	OnMessage(0x203,"leftmousebuttondoubleclick",1)
	OnMessage(0x201,"leftmousebuttonclick",1)
	OnMessage(0x204,"rightmousebuttonclick",1)
	OnMessage(0x20A,"mousewheelmove",1)

	;the graphics need to be redrawn if window is moved. Expecially if the window was partially moved outside the screen.
	OnMessage(0x06,"WindowGetsActive",1)
	OnMessage(0x03,"WindowGetsMoved",1)
}
	
EditGUIshow()
{
	global
	local tempwidth, tempheight, MonitorPrimary
	SysGet, MonitorPrimary, MonitorPrimary
	SysGet, MonitorWorkArea, MonitorWorkArea,%MonitorPrimary% 
	tempwidth:=round((MonitorWorkArearight - MonitorWorkArealeft)*0.9)
	tempheight:=round((MonitorWorkAreabottom -MonitorWorkAreatop)*0.9)
	if (Editor_guiAlreadyShown=true)
	{
		gui, MainGUI:show, w%widthofguipic%,% "·AutoHotFlow· " lang("Editor") " - " _flows[FlowID].Name ;Added  w%widthofguipic% to trigger the guisize label
	}
	else
	{
		gui, MainGUI:show,  w%tempwidth% h%tempheight%,% "·AutoHotFlow· " lang("Editor") " - " _flows[FlowID].Name
	}
	Editor_guiAlreadyShown:=true
	;sleep 10
	;MsgBox % hwn " - "   this.hwnd	" -  " this.test
	;~ settimer,API_Main_Draw,-20
	;~ ui_UpdateStatusbartext()
}

EditGUIDisable()
{
	global
	;~ gui,MainGUI:+disabled
	CurrentlyMainGuiIsDisabled:=true
}

EditGUIEnable()
{
	global
	;~ gui,MainGUI:-disabled
	
	;Activate window if it is not hidden
	DetectHiddenWindows,off
	IfWinExist,% "ahk_id " _share.hwnds["editGUI" FlowID]
	{
		DetectHiddenWindows,on
		WinActivate,% "ahk_id " _share.hwnds["editGUI" FlowID]
	}
	DetectHiddenWindows,on
	CurrentlyMainGuiIsDisabled:=false
	
	API_Main_Draw()
}


;Get the position of main gui and store it into global variables
EditGUIGetPos()
{
	global
	WinGetPos,MainGUIX,MainGUIY,MainGUIWidth,MainGUIHeight,% "ahk_id " _share.hwnds["editGUI" FlowID]
	return {x: MainGUIX, y: MainGUIY, w: MainGUIWidth, h: MainGUIHeight}
}

WindowGetsActive()
{
SetTimer,API_Main_Draw,-1

}

WindowGetsMoved()
{
SetTimer,API_Main_Draw,-1

}

leftmousebuttonclick(wpar,lpar,msg,hwn)
{
	global _share
	global flowID
	if (hwn!=_share.hwnds["editGUI" FlowID] and hwn!=_share.hwnds["editGUIStatusbar" FlowID])
	{
		return
	}
	SetTimer, ui_leftmousebuttonclick,-1
}

rightmousebuttonclick(wpar,lpar,msg,hwn)
{
	global _share
	global flowID
		;~ SoundBeep 3000
	if (hwn!=_share.hwnds["editGUI" FlowID] and hwn!=_share.hwnds["editGUIStatusbar" FlowID])
	{
		;~ SoundBeep 3000
		return
	}
	SetTimer, ui_rightmousebuttonclick,-1
}


leftmousebuttondoubleclick(wpar,lpar,msg,hwn)
{
	global _share
	global flowID
	;~ ToolTip  %hwn% d
	;~ MsgBox % wpar " - " lpar " - " msg " - " hwn " . " maingui.hwnd " . " maingui.statusbarhwnd
	if (hwn!=_share.hwnds["editGUI" FlowID] and hwn!=_share.hwnds["editGUIStatusbar" FlowID])
		return
	SetTimer, ui_leftmousebuttondoubleclick,-1
}



keyPressed(wpar,lpar,msg,hwn)
{
	global
	
	if (hwn!=_share.hwnds["editGUIEditControl" FlowID] and hwn!=_share.hwnds["editGUIStatusbar" FlowID] and hwn!=_share.hwnds["editGUI" FlowID])
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
	local wpar2
	;~ temp:=format("{1:#x}",hwn)
	;~ wingetpos,tempwinx,tempwiny,tempwinw,tempwinh,ahk_id %MainGuihwnd%
	;~ controlgetpos,tempx,tempy,tempw,temph,,ahk_id %hwn%
	;~ ToolTip %wpar% - %lpar% - %msg% - %hwn% : %StatusbarHWND% - %temp% - %MainGuihwnd% __ %tempx%- %tempy%- %tempw%- %temph% __ %tempwinx%-%tempwiny%-%tempwinw%-%tempwinh%
	;~ API_DrawShapeOnScreen(tempwinx,tempwiny,tempwinw,tempwinh,tempx,tempy,tempw,temph)
	if (hwn!=_share.hwnds["editGUIEditControl" FlowID] and hwn!=_share.hwnds["editGUIStatusbar" FlowID] and hwn!=_share.hwnds["editGUI" FlowID])
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



ui_ActionWhenMainGUIDisabled()
{
	global
	SoundPlay,*16
	;~ MsgBox % CurrentlyActiveWindowHWND
	if nowexiting
		WinActivate,ahk_id %ExitMessageBoxHWND%
	else
		WinActivate,ahk_id %CurrentlyActiveWindowHWND%
}


ui_UpdateStatusbartext(which="")
{
	global
	local elementtext
	if (which="pos" or which ="")
	{

		if (_flows[FlowID].markedElements.count()=0)
		{
			elementtext:=lang("%1% elements", _flows[FlowID].allElements.count())
		}
		else if (_flows[FlowID].markedElements.count()=1)
		{
			elementtext:=lang("1 marked element: %1%", _flows[FlowID].markedElement)
		}
		else
		{
			elementtext:=lang("%1% marked elements", _flows[FlowID].markedElements.count())
		}
		gui,maingui:default
		sb_SetText("Offset: x " Round(FlowObj.flowSettings.offsetx) " y " Round(FlowObj.flowSettings.offsety) "   |   Zoom: " Round(FlowObj.flowSettings.zoomFactor,2 )  "   |   " elementtext  ,1)
	}
}

;Get the position of main gui and store it into global variables
ui_GetMainGUIPos()
{
	global 
	WinGetPos,MainGUIX,MainGUIY,MainGUIWidth,MainGUIHeight,% "ahk_id " _share.hwnds["editGUI" FlowID]
}

ui_OnLanguageChange()
{
	global _share
	global _flows
	API_Main_Draw()
	DetectHiddenWindows off
	WinGetTitle,temp,% "ahk_id " _share.hwnds["editGUI" FlowID]
	IfWinExist,% temp
		gui,MainGUI:show,,% "·AutoHotFlow· " lang("Editor") " - " _flows[FlowID].Name 
	else
		gui,MainGUI:show,hide,% "·AutoHotFlow· " lang("Editor") " - " _flows[FlowID].Name 
	
	;Help! I want that the menus are renamed when the language changes.
	;~ initializeTrayBar()
	;~ initializeMenuBar()
}


goto,jumpOverGUIJumpLabels





MainGUIguisize: ;resize the picture when GUI is resized
;MsgBox w%A_guiwidth%  %a_guiheight%
GuiControl,move,PicFlow,w%A_guiwidth%  h%a_guiheight%
heightofguipic:=a_guiheight - EditGUI_StatusBarHeight

widthofguipic:=a_guiwidth
guicontrolget,guipic,pos,PicFlow ;get the picture position. -> gx, gy

;SB_SetParts(a_guiwidth*0.2,a_guiwidth*0.5,a_guiwidth*0.3)
SB_SetParts(a_guiwidth)

_flows[FlowID].draw.heightofguipic := heightofguipic
_flows[FlowID].draw.widthofguipic := widthofguipic
API_Main_Draw()
return

GetClientSize(hwnd, ByRef w, ByRef h)
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}


jumpOverGUIJumpLabels:
