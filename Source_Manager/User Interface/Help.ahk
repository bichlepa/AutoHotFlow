
; Show help file for AHF.
ui_showHelp()
{
	global
	
	; if a previous help gui is shown, destry it
	Gui, Help:Destroy
	
	; disable DPI for this gui
	gui,Help:-dpiscale

	; Find the help file
	local uiLang := _getSettings("UILanguage")
	local helpfilepath := _scriptDir "\Help\" UILang "\index.html"
	If not fileexist(helpfilepath)
	{
		helpfilepath := _scriptDir "\Help\en\index.html"
		If not fileexist(helpfilepath)
		{
			MsgBox, 16, % lang("Error"),% lang("No help file was found")
			Return
		}
	}

	; show a browser in the gui
	Gui, Help:Add, ActiveX, x0 y0 w720 h490 vHelpGuiBrowser, Shell.Explorer
	HelpGuiBrowser.Navigate(helpfilepath)

	; adjust gui appearance
	Gui, Help: +ToolWindow 
	Gui, Help:Color, FFFFFF
	Gui, Help: +resize
	
	; Find the perfect gui size
	SysGet, MonitorWorkArea, MonitorWorkArea 
	local helpx := MonitorWorkArealeft + 50
	local helpy := MonitorWorkAreatop + 50
	local helph := MonitorWorkAreabottom - MonitorWorkAreatop - 100
	local helpw := MonitorWorkArearight - MonitorWorkArealeft - 100
	
	; Show the help gui
	Gui, Help:Show, x%helpx% y%helpy% w%helpw% h%helph%,% lang("Help")
	Return
	
	; user closes help gui
	Helpguiclose:
	; destroy the gui
	Gui, Help:Destroy
	return
	
	; user resizes the help gui
	helpguisize:
	; move the browser control
	guicontrol, move, HelpGuiBrowser ,w%A_GuiWidth% h%A_GuiHeight%
	return
}
