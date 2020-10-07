
ui_showHelp(elementID)
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
	gui,Help:-dpiscale
	local elementType:= _getElementProperty(FlowID, elementID, "type")
	local elementClass:= _getElementProperty(FlowID, elementID, "Class")
	local elementHelpFilepath := elementType "s\" StrReplace(elementClass, elementType "_")

	local uiLang := _getSettings("UILanguage")
	helpfilepath=%_ScriptDir%\Help\%UILang%\%elementHelpFilepath%.html
	ToolTip, % helpfilepath
	IfNotExist, %helpfilepath%
	{
		helpfilepath=%_ScriptDir%\Help\en\%elementHelpFilepath%.html
		IfNotExist, %helpfilepath%
		{
			MsgBox, 16, % lang("Error"),% lang("No help file was found")
			Return
		}
	}
	
	Gui, Help:Add, ActiveX, x0 y0 w720 h490 vHB, Shell.Explorer
	HB.Navigate(helpfilepath)
	Gui, Help: +ToolWindow 
	Gui, Help:Color, FFFFFF
	Gui, Help: +resize
	
	;find out whether the settings window is opened
	IfWinExist, % "ahk_id " global_SettingWindowParentHWND
	{
		;Position the window right to the settings window
		WinGetPos,tempx,tempy,tempw,temph,% "ahk_id " global_SettingWindowParentHWND
		
		helpx:=tempw+tempx
		helph:=temph
		helpy:=tempy
		helpw:=720
		;~ MsgBox %A_ScreenWidth% - %helpw% - %tempw% 
		
		;Check whether the settings window is on the righthand side and needs to be moved
		SysGet, VirtualWidth, 78
		if ((VirtualWidth-helpx)<helpw)
		{
			tempx:= VirtualWidth - helpw - tempw -10
			;~ MsgBox %A_ScreenWidth% - %widthhelp% - %tempw% 
			WinMove,% "ahk_id " global_SettingWindowParentHWND,,%tempx%
			helpx:=VirtualWidth - helpw -10
		}
		
		;show gui
		Gui, Help:Show, x%helpx% y%helpy% w%helpw% h%helph%,% lang("Help")
	}
	else
	{
		Gui, Help:Show, w720,% lang("Help")
	}
	
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





