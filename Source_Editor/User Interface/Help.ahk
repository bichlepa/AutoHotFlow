
;~ ui_MakeNewHelp()
;~ {
	;~ global
	
	;~ Gui, Help:Destroy
	;~ Gui, Help:+HwndGUIHelpHWND
	
	
	
	
;~ }


;~ ui_showHelp()
;~ {
	
	
	;~ Gui, Help:Show, w720 h490,% lang("Help")
	;~ Gui, Help:+HwndGUIHelpHWND
;~ }

ui_showHelp(helpFile)
{
	global
	local helpfilepath
	local tempx
	local tempy
	local tempw
	local temph
	local helpx
	local helpy
	local helpw
	local helph
	local VirtualWidth
	local VirtualHeight
	
	Gui, Help:Destroy
	MsgBox %helpFile%
	gui,Help:-dpiscale
	helpfilepath=Help\%UILang%\%helpFile%.html
	;~ MsgBox %helpfilepath%
	IfNotExist, Help\%UILang%\%helpFile%.html
	{
		IfNotExist, Help\en\%helpFile%.html
		{
			MsgBox, 16, % lang("Error"),% lang("No help file was found")
			Return
		}
		helpfilepath=Help\en\%helpFile%.html
	}
	Gui, Help:Add, ActiveX, x0 y0 w720 h490 vHB, Shell.Explorer
	HB.Navigate(A_WorkingDir . "\" helpfilepath)
	Gui, Help: +ToolWindow 
	Gui, Help:Color, FFFFFF
	Gui, Help: +resize
	
	WinGetPos,tempx,tempy,tempw,temph,% "ahk_id " SG2.hwnd
	
	helpx:=tempw+tempx
	helph:=temph
	helpy:=tempy
	helpw:=720
	;~ MsgBox %A_ScreenWidth% - %helpw% - %tempw% 
	SysGet, VirtualWidth, 78
	;~ SysGet, VirtualHeight, 79
	
	if ((VirtualWidth-helpx)<helpw)
	{
		tempx:= VirtualWidth - helpw - tempw -10
		;~ MsgBox %A_ScreenWidth% - %widthhelp% - %tempw% 
		WinMove,% "ahk_id " SG1.hwnd,,%tempx%
		helpx:=VirtualWidth - helpw -10
	}
	
	Gui, Help:Show, x%helpx% y%helpy% w%helpw% h%helph%,% lang("Help")
	Gui, Help:+HwndGUIHelpHWND
	Return
	
	Helpguiclose:
	;~ SoundBeep
	Gui, Help:Destroy
	return
	
	helpguisize:
	guicontrol, move, HB ,w%A_GuiWidth% h%A_GuiHeight%
	return
	
}

ui_closeHelp()
{
	global
	Gui, Help:Destroy
}





