
ui_MakeNewHelp()
{
	global
	
	Gui, Help:Destroy
	Gui, Help:+HwndGUIHelpHWND
	
	
	
	
}


ui_showHelp()
{
	
	
	Gui, Help:Show, w720 h490,% lang("Help")
	Gui, Help:+HwndGUIHelpHWND
}

;~ ui_showHelp(helpFile)
;~ {
	;~ global
	;~ local helpfilepath
	
	
	;~ helpfilepath=Help\%UILang%\%helpFile%.html
	;~ IfNotExist, Help\%UILang%\%helpFile%.html
	;~ {
		;~ IfNotExist, Help\en\%helpFile%.html
		;~ {
			;~ MsgBox, 16, % lang("Error"),% lang("No help file was found")
			;~ Return
		;~ }
		;~ helpfilepath=Help\%UILang%\%helpFile%.html
	;~ }
	;~ Gui, Help:Add, ActiveX, x0 y0 w720 h490 vHB, Shell.Explorer
	;~ HB.Navigate(A_ScriptDir . "\Help\" UILang "\Index.html")
	;~ Gui, Help:+ToolWindow +LabelHelp
	;~ Gui, Help:Color, FFFFFF
	;~ Gui, Help:Show, w720 h490,% lang("Help")
	;~ Gui, Help:+HwndGUIHelpHWND
	;~ Return
;~ }

ui_closeHelp()
{
	global
	Gui, Help:Destroy
}






