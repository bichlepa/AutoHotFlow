ui_CreateMainGui()
{
	global
	;Create tha main gui
	gui,1:default
	gui,add,picture,vPicFlow hwndPicFlowHWND x0 y0 0xE gclickOnPicture
	gui,add,StatusBar
	
	gui +resize

	;This is needed by GDI+
	gui +lastfound
	gui,+HwndMainGuihwnd
	ControlGetPos,,,,StatusBarHeight,msctls_statusbar321,ahk_id %MainGuihwnd%
	
	;Set some hotkeys that are needed in main window
	hotkey,IfWinActive,ahk_id %MainGuihwnd%
	;~ hotkey,^x,ctrl_x
	hotkey,^c,ctrl_c
	hotkey,^v,ctrl_v
	hotkey,^s,ctrl_s
	hotkey,esc,esc
	hotkey,del,del
	hotkey,^wheelup,ctrl_wheelup
	hotkey,^wheeldown,ctrl_wheeldown
	hotkey,~rbutton,rightmousebuttonclick
}


ui_DisableMainGUI()
{
	global
	gui,1:+disabled
	
}
ui_EnableMainGUI()
{
	global
	gui,1:-disabled
	
	WinActivate,ahk_id %MainGuihwnd%
}

ui_showgui()
{
	global
	SysGet, MonitorPrimary, MonitorPrimary
	SysGet,MonitorWorkArea,MonitorWorkArea,%MonitorPrimary% 
	
	
	tempwidth:=round((MonitorWorkArearight - MonitorWorkArealeft)*0.9)
	tempheight:=round((MonitorWorkAreabottom -MonitorWorkAreatop)*0.9)

	if guiAlreadyShowed=true
		gui,1:show, w%widthofguipic%,% "·AutoHotFlow· " lang("Editor") " - " flowName ;Added  w%widthofguipic% to trigger the guisize label
	else
		gui,1:show,  w%tempwidth% h%tempheight%,% "·AutoHotFlow· " lang("Editor") " - " flowName
	sleep 10
	
	ui_Draw()
	ui_UpdateStatusbartext()
	
	
	
}

ui_UpdateStatusbartext(which="")
{
	global
	if (which="pos" or which ="")
	{
		sb_SetText("Offset: x " Round(offsetx) " y " Round(offsety) "   |   Zoom: " Round(zoomFactor,2 ),1)
	}
}

goto,jumpOverGUIJumpLabels





guisize: ;resize the picture when GUI is resized

;MsgBox w%A_guiwidth%  %a_guiheight%
GuiControl,move,PicFlow,w%A_guiwidth%  h%a_guiheight%
heightofguipic:=a_guiheight - StatusBarHeight



widthofguipic:=a_guiwidth
guicontrolget,guipic,pos,PicFlow ;get the picture position. -> gx, gy

;SB_SetParts(a_guiwidth*0.2,a_guiwidth*0.5,a_guiwidth*0.3)
SB_SetParts(a_guiwidth)


ui_draw()
return




jumpOverGUIJumpLabels: