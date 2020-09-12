
; Show help file for AHF.
ui_showHelp()
{
	global
	
	Gui, Help:Destroy
	
	gui,Help:-dpiscale

	local uiLang := _getSettings("UILanguage")
	helpfilepath = %_scriptDir%\Help\%UILang%\index.html
	IfNotExist, %_scriptDir%\Help\%UILang%\index.html
	{
		IfNotExist, %_scriptDir%\Help\en\index.html
		{
			MsgBox, 16, % lang("Error"),% lang("No help file was found")
			Return
		}
		helpfilepath=%_scriptDir%\Help\en\index.html
	}
	Gui, Help:Add, ActiveX, x0 y0 w720 h490 vHB, Shell.Explorer
	HB.Navigate(helpfilepath)
	Gui, Help: +ToolWindow 
	Gui, Help:Color, FFFFFF
	Gui, Help: +resize
	
	SysGet,MonitorWorkArea ,MonitorWorkArea 
	helpx:=MonitorWorkArealeft+50
	helpy:=MonitorWorkAreatop+50
	helph:=MonitorWorkAreabottom-MonitorWorkAreatop-100
	helpw:=MonitorWorkArearight-MonitorWorkArealeft-100
	;~ MsgBox %A_ScreenWidth% - %helpw% - %tempw% 

	
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