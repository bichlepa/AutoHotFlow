
globalSettings_GUI()
{
	global
	local lnk_target
	local stringalllangs
	local needtorefreshflowtreeview
	
	Disable_Manager_GUI()
	
	;first gather some information
	
	;Find out whether autostart is active by searching for the link
	GuiSettingAutostart=0
	local lnk_target=0
	IfExist, %A_Startup%\AutoHotFlow.lnk 
	{
		FileGetShortcut, %A_Startup%\AutoHotFlow.lnk , lnk_target
		if (lnk_target = A_ScriptFullPath)
			GuiSettingAutostart=1
	}
	
	;Prepare data for language dropdown
	stringalllangs=`n
	for onecode, oneLang in _language.allLangs
	{
		stringalllangs.=  oneLang.enlangname " - "  oneLang.langname "|"
		if (onecode = _language.lang)
			GuiLanguageChoose:=A_Index
	}
	
	;Prepare other settings
	GuiSettingRunAsAdmin:=(!!_settings.RunAsAdmin)
	GuiFlowSettingsParallel:=(_settings.FlowExecutionPolicy = "parallel")
	GuiFlowSettingsskip:=(_settings.FlowExecutionPolicy = "skip")
	GuiFlowSettingsWait:=(_settings.FlowExecutionPolicy = "Wait")
	GuiFlowSettingsStop:=(_settings.FlowExecutionPolicy = "Stop")
	GuiSettingsHideDemoFlows:=(!!_settings.HideDemoFlows)
	
	;build the gui
	gui,GlobalSettings:default
	gui,add, tab3,vglobalsettingtab,% lang("General") "|" lang("Flow settings") "|" lang("Appearance")
	globalsetting_tab_General:=1
	globalsetting_tab_FlowSettings:=2
	globalsetting_tab_Appearance:=3
	
	gui,tab, %globalsetting_tab_General%
	gui,font,s10 cnavy wbold
	gui,add, text, X+10 Y+10 w300 section, % lang("Select_Language.")
	gui,font,s8 cDefault wnorm
	gui,add, DropDownList, xs Y+10 w300 AltSubmit vGuiLanguageChoose choose%GuiLanguageChoose%, %stringalllangs%
	gui,font,s10 cnavy wbold
	gui,add,text, xs Y+20 w300, % lang("General") 
	gui,font,s8 cDefault wnorm
	gui,add,Checkbox,xs Y+10 w300 checked%GuiSettingAutostart% vGuiSettingAutostart ,% lang("Start with windows") 
	gui,add,Checkbox,xs Y+10 w300 checked%GuiSettingRunAsAdmin% vGuiSettingRunAsAdmin ,% lang("Run as admin") 
	
	gui,tab, %globalsetting_tab_FlowSettings%
	gui,font,s10 cnavy wbold
	gui,add,text,xs ys+10 w300,% lang("Flow_execution_policy")
	gui,font,s8 cDefault wnorm
	gui,add,radio,xs Y+10 w300 vGuiFlowSettingsParallel checked%GuiFlowSettingsParallel%,% lang("Parallel_execution_of_multiple_instances")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsSkip checked%GuiFlowSettingsskip% ,% lang("Skip_execution_when_an_instance_is_already_executing")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsWait  checked%GuiFlowSettingsWait%,% lang("Wait_until_the_currently_executing_instance_has_finished")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsStop  checked%GuiFlowSettingsStop%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	
	gui,font,s10 cnavy wbold
	gui,add,text,xs Y+20  w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	gui,add,Edit,xs Y+10 w300 vGuiFlowSettingsWorkingDir,% _settings.FlowWorkingDir
	
	gui,tab, %globalsetting_tab_Appearance%
	gui,font,s10 cnavy wbold
	gui,add,text,xs ys+10 w300,% lang("Shown flows")
	gui,font,s8 cDefault wnorm
	gui,add,Checkbox,xs Y+10 w300 checked%GuiSettingsHideDemoFlows% vGuiSettingsHideDemoFlows ,% lang("Hide demonstration flows") 
	
	gui,tab
	gui,add,Button,xs y300 w140 gGuiSettingsChooseOK vGuiSettingsChooseOK default,% lang("OK")
	gui,add,Button,X+10 yp w140 gGuiSettingsChooseCancel,% lang("Cancel")
	
	gui,show,,% lang("Settings")
	return
	
	GlobalSettingsguiclose:
	GuiSettingsChooseCancel:
	Enable_Manager_GUI()
	gui,GlobalSettings:destroy
	return

	GuiSettingsChooseOK:
	gui,GlobalSettings:Submit,nohide

	;Check working directory
	newworkingdir:=checkNewWorkingDir(_settings.FlowWorkingDir, GuiFlowSettingsWorkingDir)
	if not (newworkingdir)
	{
		guicontrol, choose, globalsettingtab, %globalsetting_tab_FlowSettings%
		guicontrol, focus, GuiFlowSettingsWorkingDir
		return
	}
	_settings.FlowWorkingDir :=newworkingdir

	;handle language setting
	lang_setLanguage(GuiLanguageChoose)
	if (_settings.UILanguage != _language.lang)
	{
		_settings.UILanguage := _language.lang
		Refresh_Manager_GUI()
		needtorefreshflowtreeview:=true
	}

	;handle autostart setting
	if GuiSettingAutostart
	{
		FileCreateShortcut,%A_ScriptFullPath%,%A_Startup%\AutoHotFlow.lnk ,,AutomaticStartup
	}
	else
	{
		FileDelete,%A_Startup%\AutoHotFlow.lnk 
	}
	
	;handle "hide demo flows" setting
	if (_settings.HideDemoFlows != GuiSettingsHideDemoFlows)
	{
		needtorefreshflowtreeview:=true
		_settings.HideDemoFlows := GuiSettingsHideDemoFlows
	}
	
	;handle other settings
	_settings.RunAsAdmin:=GuiSettingRunAsAdmin
	
	GuiFlowSettingsParallel ? _settings.FlowExecutionPolicy := "parallel"
	GuiFlowSettingsskip ? _settings.FlowExecutionPolicy := "skip"
	GuiFlowSettingsWait ? _settings.FlowExecutionPolicy := "Wait"
	GuiFlowSettingsStop ? _settings.FlowExecutionPolicy := "Stop"
	

	;Write current settings to file
	API_Main_write_settings()
	
	;if user has selected "run as admin"
	if (_settings.runAsAdmin and not A_IsAdmin)
	{
		MsgBox, 36, , % lang("You have selected ""%1%"" do you want to restart in order to enable this setting?", lang("Run as admin") )
		IfMsgBox yes
		{
			try Run *RunAs "%A_ScriptFullPath%" 
			ExitApp
		}
	}
	
	;if Flow treeview needs to be refreshed
	if needtorefreshflowtreeview
	{
		TreeView_manager_Refill()
	}
	
	gui,GlobalSettings:destroy
	Enable_Manager_GUI()
	return
}