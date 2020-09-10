
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
	GuiSettingRunAsAdmin := (!!_getSettings("RunAsAdmin"))
	GuiFlowSettingsParallel := (_getSettings("FlowExecutionPolicy") = "parallel")
	GuiFlowSettingsskip := (_getSettings("FlowExecutionPolicy") = "skip")
	GuiFlowSettingsWait := (_getSettings("FlowExecutionPolicy") = "Wait")
	GuiFlowSettingsStop := (_getSettings("FlowExecutionPolicy") = "Stop")
	GuiShowElementsBeginner := (_getSettings("ShowElementsLevel") = "Beginner")
	GuiShowElementsAdvanced := (_getSettings("ShowElementsLevel") = "Advanced")
	GuiShowElementsProgrammer := (_getSettings("ShowElementsLevel") = "Programmer")
	;~ GuiShowElementsCustom:=(_getSettings("ShowElementsLevel") = "Custom") ;TODO
	GuiSettingsHideDemoFlows := (!!_getSettings("HideDemoFlows"))
	GUIloglevelFlow := _getSettings("LogLevelFlow")
	GUIloglevelApp := _getSettings("LogLevelApp")
	GUIloglevelThread := _getSettings("LogLevelThread")
	GUIlogToFile := (!!_getSettings("LogToFile"))
	
	;build the gui
	gui,GlobalSettings:default
	gui,add, tab3,vglobalsettingtab,% lang("General") "|" lang("Flow settings") "|" lang("Appearance") "|" lang("Debugging")
	globalsetting_tab_General:=1
	globalsetting_tab_FlowSettings:=2
	globalsetting_tab_Appearance:=3
	globalsetting_tab_Debugging:=4
	
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
	gui,add,text,xs ys w300,% lang("Flow_execution_policy")
	gui,font,s8 cDefault wnorm
	gui,add,radio,xs Y+10 w300 vGuiFlowSettingsParallel checked%GuiFlowSettingsParallel%,% lang("Parallel_execution_of_multiple_instances")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsSkip checked%GuiFlowSettingsskip% ,% lang("Skip_execution_when_an_instance_is_already_executing")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsWait  checked%GuiFlowSettingsWait%,% lang("Wait_until_the_currently_executing_instance_has_finished")
	gui,add,radio,xs Y+10 w300 Y+10 vGuiFlowSettingsStop  checked%GuiFlowSettingsStop%,% lang("Stop_the_currently_executing_instance_and_execute_afterwards")
	
	gui,font,s10 cnavy wbold
	gui,add,text,xs Y+20  w300 Y+15,% lang("Working directory")
	gui,font,s8 cDefault wnorm
	gui,add,Edit,xs Y+10 w300 vGuiFlowSettingsWorkingDir,% _getSettings("FlowWorkingDir")
	
	gui,tab, %globalsetting_tab_Appearance%
	gui,font,s10 cnavy wbold
	gui,add,text,xs ys w300,% lang("Shown flows")
	gui,font,s8 cDefault wnorm
	gui,add,Checkbox,xs Y+10 w300 checked%GuiSettingsHideDemoFlows% vGuiSettingsHideDemoFlows ,% lang("Hide demonstration flows") 
	gui,font,s10 cnavy wbold
	gui,add,text, xs Y+20 w300, % lang("Shown elements") 
	gui,font,s8 cDefault wnorm
	gui,add,radio,xs Y+10 w300 vGuiShowElementsBeginner checked%GuiShowElementsBeginner%,% lang("Beginner level")
	gui,add,radio,xs Y+10 w300 vGuiShowElementsAdvanced checked%GuiShowElementsAdvanced%,% lang("Advanced level")
	gui,add,radio,xs Y+10 w300 vGuiShowElementsProgrammer checked%GuiShowElementsProgrammer%,% lang("Programmer level")
	;~ gui,add,radio,xs Y+10 w300 vGuiShowElementsCustom checked%GuiShowElementsCustom%,% lang("Custom") ;TODO
		
	gui,tab, %globalsetting_tab_Debugging%
	gui,font,s10 cnavy wbold
	gui,add,text,xs ys w300,% lang("Logging")
	gui,font,s8 cDefault wnorm
	gui,add,text,xs Y+10 w100,% lang("Flow") 
	gui,add,slider,X+10 yp w60 range0-3 vGUIloglevelFlow gGuiSettingsupdatesomeinfo AltSubmit TickInterval1,%GUIloglevelFlow%
	gui,add,text,X+10 yp w100 vGUIloglevelFlowtext
	gui,add,text,xs Y+20 w100,% _getSettings("developing") ?  lang("App") : lang("Internal")  " 1"
	gui,add,slider,X+10 yp w60 range0-3 vGUIloglevelApp gGuiSettingsupdatesomeinfo AltSubmit TickInterval1,%GUIloglevelApp%
	gui,add,text,X+10 yp w100 vGUIloglevelApptext
	gui,add,text,xs Y+20 w100,% _getSettings("developing") ?  lang("Thread") : lang("Internal")  " 2"
	gui,add,slider,X+10 yp w60 range0-3 vGUIloglevelThread gGuiSettingsupdatesomeinfo AltSubmit TickInterval1,%GUIloglevelThread%
	gui,add,text,X+10 yp w100 vGUIloglevelThreadtext
	gui,add,Checkbox,xs Y+20 w300 checked%GUIlogToFile% vGUIlogToFile ,% lang("Log to file")
	
	gui,tab
	gui,add,Button,xs y300 w140 gGuiSettingsChooseOK vGuiSettingsChooseOK default,% lang("OK")
	gui,add,Button,X+10 yp w140 gGuiSettingsChooseCancel,% lang("Cancel")
	
	gui,show,,% lang("Settings")
	
	gosub,GuiSettingsupdatesomeinfo
	return
	
	GuiSettingsupdatesomeinfo:
	if (GUIloglevelFlow == 0)
		GuiControl,,GUIloglevelFlowText,% lang("Only errors")
	if (GUIloglevelFlow == 1)
		GuiControl,,GUIloglevelFlowText,% lang("Some logs")
	if (GUIloglevelFlow == 2)
		GuiControl,,GUIloglevelFlowText,% lang("Many logs")
	if (GUIloglevelFlow == 3)
		GuiControl,,GUIloglevelFlowText,% lang("All logs")
	if (GUIloglevelApp == 0)
		GuiControl,,GUIloglevelAppText,% lang("Only errors")
	if (GUIloglevelApp == 1)
		GuiControl,,GUIloglevelAppText,% lang("Some logs")
	if (GUIloglevelApp == 2)
		GuiControl,,GUIloglevelAppText,% lang("Many logs")
	if (GUIloglevelApp == 3)
		GuiControl,,GUIloglevelAppText,% lang("All logs")
	if (GUIloglevelThread == 0)
		GuiControl,,GUIloglevelThreadText,% lang("Only errors")
	if (GUIloglevelThread == 1)
		GuiControl,,GUIloglevelThreadText,% lang("Some logs")
	if (GUIloglevelThread == 2)
		GuiControl,,GUIloglevelThreadText,% lang("Many logs")
	if (GUIloglevelThread == 3)
		GuiControl,,GUIloglevelThreadText,% lang("All logs")
	
	return
	
	GlobalSettingsguiclose:
	GuiSettingsChooseCancel:
	Enable_Manager_GUI()
	gui,GlobalSettings:destroy
	return

	GuiSettingsChooseOK:
	gui,GlobalSettings:Submit,nohide

	;Check working directory
	newworkingdir:=checkNewWorkingDir(_getSettings("FlowWorkingDir"), GuiFlowSettingsWorkingDir)
	if not (newworkingdir)
	{
		guicontrol, choose, globalsettingtab, %globalsetting_tab_FlowSettings%
		guicontrol, focus, GuiFlowSettingsWorkingDir
		return
	}
	_setSettings("FlowWorkingDir", newworkingdir)

	;handle language setting
	lang_setLanguage(GuiLanguageChoose)
	if (_getSettings("UILanguage") != _language.lang)
	{
		_setSettings("UILanguage", _language.lang)
		Refresh_Manager_GUI()
		needtorefreshflowtreeview:=true
	}

	;handle autostart setting
	if GuiSettingAutostart
	{
		MsgBox % GetAhfPath()
		FileCreateShortcut,% GetAhfPath(),%A_Startup%\AutoHotFlow.lnk ,,WindowsStartup
	}
	else
	{
		FileDelete,%A_Startup%\AutoHotFlow.lnk 
	}
	
	;handle "hide demo flows" setting
	if (_getSettings("HideDemoFlows") != GuiSettingsHideDemoFlows)
	{
		needtorefreshflowtreeview:=true
		_setSettings("HideDemoFlows", GuiSettingsHideDemoFlows)
	}
	
	;handle other settings
	_setSettings("RunAsAdmin", GuiSettingRunAsAdmin)
	_setSettings("logtofile", GUIlogToFile)
	_setSettings("loglevelFlow", GUIloglevelFlow)
	_setSettings("loglevelApp", GUIloglevelApp)
	_setSettings("loglevelThread", GUIloglevelThread)
	_setSettings("logToFile", GUIlogToFile)
	
	GuiFlowSettingsParallel ? _setSettings("FlowExecutionPolicy", "parallel")
	GuiFlowSettingsskip ? _setSettings("FlowExecutionPolicy", "skip")
	GuiFlowSettingsWait ? _setSettings("FlowExecutionPolicy", "Wait")
	GuiFlowSettingsStop ? _setSettings("FlowExecutionPolicy", "Stop")
	
	GuiShowElementsBeginner ? _setSettings("ShowElementsLevel", "Beginner")
	GuiShowElementsAdvanced ? _setSettings("ShowElementsLevel", "Advanced")
	GuiShowElementsProgrammer ? _setSettings("ShowElementsLevel", "Programmer")
	;~ GuiShowElementsCustom ? _setSettings("ShowElementsLevel", "Custom") ;TODO
	

	;Write current settings to file
	write_settings()
	
	;if user has selected "run as admin"
	if (_getSettings("runAsAdmin") and not A_IsAdmin)
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