global global_GUIHelpHWND

; show help near the current settings window
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
	
	; destroy help gui (if present)
	Gui, Help: Destroy
	gui, Help: -dpiscale

	; copy some information to local variables
	local elementType := _getElementProperty(_FlowID, elementID, "type")
	local elementClass := _getElementProperty(_FlowID, elementID, "Class")
	local elementHelpFilepath := elementType "s\" StrReplace(elementClass, elementType "_")
	local uiLang := _getSettings("UILanguage")

	; calculate help file path
	helpfilepath := _ScriptDir "\Help\" UILang "\" elementHelpFilepath ".html"
	IfNotExist, %helpfilepath%
	{
		; help file path in current language does not exist. Try to find english help file
		helpfilepath := _ScriptDir "\Help\en\" elementHelpFilepath ".html"
		IfNotExist, %helpfilepath%
		{
			; no help file found.
			MsgBox, 16, % lang("Error"), % lang("No help file was found")
			Return
		}
	}
	
	; create gui with a browser window inside
	Gui, Help: Add, ActiveX, x0 y0 w720 h490 vHB, Shell.Explorer
	HB.Navigate(helpfilepath)
	Gui, Help: +ToolWindow 
	Gui, Help: Color, FFFFFF
	Gui, Help: +resize
	
	;find out whether the settings window is opened
	IfWinExist, % "ahk_id " global_SettingWindowParentHWND
	{
		; Settings window exists

		; Position the window right to the settings window
		WinGetPos, tempx, tempy, tempw, temph, % "ahk_id " global_SettingWindowParentHWND
		
		helpx := tempw + tempx
		helph := temph
		helpy := tempy
		helpw := 720
		
		;Check whether the settings window is on the righthand side and needs to be moved
		SysGet, VirtualWidth, 78
		if ((VirtualWidth - helpx) < helpw)
		{
			; settings window needs to be moved
			tempx := VirtualWidth - helpw - tempw - 10
			
			WinMove, % "ahk_id " global_SettingWindowParentHWND, , %tempx%
			helpx := VirtualWidth - helpw - 10
		}
		
		;show gui
		Gui, Help: Show, x%helpx% y%helpy% w%helpw% h%helph%, % lang("Help #noun")
	}
	else
	{
		; Settings window does not exist. Show it in the middle of the screen
		Gui, Help: Show, w720, % lang("Help #noun")
	}
	
	Gui, Help: +Hwndglobal_GUIHelpHWND
	Return
	
	; react if user closes the help window
	Helpguiclose:
	; destroy help window
	Gui, Help: Destroy
	return
	
	; react if user resizes the help window
	helpguisize:
	; adjust the size of the built in browser
	guicontrol, move, HB, w%A_GuiWidth% h%A_GuiHeight%
	return
	
}

; closes the help gui
ui_closeHelp()
{
	global
	; destroy help window
	Gui, Help: Destroy
}





