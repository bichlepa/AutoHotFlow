
globalSettings_GUI()
{
	global
	
	Disable_Manager_GUI()
	
	GuiSettingAutostart=0
	local lnk_target=0
	IfExist, %A_Startup%\AutoHotFlow.lnk 
	{
		FileGetShortcut, %A_Startup%\AutoHotFlow.lnk , lnk_target
		if (lnk_target = A_ScriptFullPath)
			GuiSettingAutostart=1
	}

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
	return
}