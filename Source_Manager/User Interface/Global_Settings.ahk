
globalSettings_GUI()
{
	global
	
	Disable_Manager_GUI()
	
	IfExist, %A_Startup%\AutoHotFlow.lnk 
		GuiSettingAutostart=1
	else
		GuiSettingAutostart=0

	gui,GlobalSettings:default
	gui,GlobalSettings:add,text,,% lang("Startup") 
	gui,GlobalSettings:add,Checkbox,w200 checked%GuiSettingAutostart% vGuiSettingAutostart ,% lang("Start with windows") 
	gui,GlobalSettings:add,Button,w120 gGuiSettingsChooseOK vGuiSettingsChooseOK default,% lang("OK")
	gui,GlobalSettings:add,Button,w70 X+10 yp gGuiSettingsChooseCancel,% lang("Cancel")
	gui,GlobalSettings:show
	return
	
	GlobalSettingsguiclose:
	GuiSettingsChooseCancel:
	Enable_Manager_GUI()
	gui,GlobalSettings:destroy
	return

	GuiSettingsChooseOK:
	gui,GlobalSettings:Submit,nohide

	if GuiSettingAutostart
	{
		FileCreateShortcut,%A_ScriptFullPath%,%A_Startup%\AutoHotFlow.lnk ,,AutomaticStartup
	}
	else
		FileDelete,%A_Startup%\AutoHotFlow.lnk 

	gui,GlobalSettings:destroy
	Enable_Manager_GUI()

}