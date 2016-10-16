
SelectLanguage_GUI()
{
	global
	local stringalllangs
	Disable_Manager_GUI()
	
	stringalllangs=`n
	for count, oneLang in allLangs
	{
		stringalllangs.= oneLang " (" %oneLang%enlangname " - "  %oneLang%langname ")|"
		
	}
	
	gui, language:add, text, , % lang("Select_Language.")
	gui, language:add, ListBox, w200 h300 AltSubmit vGuiLanguageChoose gGuiLanguageChoose, %stringalllangs%
	gui, language:add, Button, w120 gGuiLanguageChooseOK vGuiLanguageChooseOK default Disabled, % lang("OK")
	gui, language:add, Button, w70 X+10 yp gGuiLanguageChooseCancel,% lang("Cancel")
	gui, language:show
	return
	
	
	languageguiclose:
	GuiLanguageChooseCancel:
	Enable_Manager_GUI()
	gui, language:destroy
	return
	
	GuiLanguageChoose:
	gui, language:submit, nohide
	
	if A_GuiEvent = DoubleClick 
	{
		if GuiLanguageChoose>0	
			goto GuiLanguageChooseOK
	}
	
	if GuiLanguageChoose > 0	
		GuiControl, language:enable, GuiLanguageChooseOK
	else
		GuiControl, language:disable, GuiLanguageChooseOK
	return
	
	GuiLanguageChooseOK:
	gui, language:Submit, nohide

	IniWrite, % allLangs[GuiLanguageChoose], settings.ini, common, UILanguage
	iniread, UILang, settings.ini, common, UILanguage
	lang_LoadCurrentLanguage()

	gui, language:destroy

	Enable_Manager_GUI()

	Refresh_Manager_GUI()
	return
}



