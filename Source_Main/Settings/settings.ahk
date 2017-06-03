
;load settings from settings file. Must be called olny once
load_settings()
{
	global settingsdefinitions, filepathsettings
	
	filepathsettings:= _WorkingDir "\settings.ini"
	
	settingsdefinitions:=Object()
	settingsdefinitions.push({section: "common", key: "developing", default: false})
	settingsdefinitions.push({section: "common", key: "UILanguage", default: ""})
	settingsdefinitions.push({section: "common", key: "runAsAdmin", default: false})
	settingsdefinitions.push({section: "flowSettings", key: "FlowExecutionPolicy", default: "parallel"})
	settingsdefinitions.push({section: "flowSettings", key: "FlowWorkingDir", default: A_MyDocuments "\AutoHotFlow default working directory"})
	settingsdefinitions.push({section: "appearance", key: "HideDemoFlows", default: False})
	settingsdefinitions.push({section: "debug", key: "LogLevelFlow", default: 0})
	settingsdefinitions.push({section: "debug", key: "LogLevelApp", default: 0})
	settingsdefinitions.push({section: "debug", key: "LogLevelThread", default: 0})
	settingsdefinitions.push({section: "debug", key: "LogToFile", default: False})
	for oneindex, onesetting in settingsdefinitions
	{
		default:=onesetting.default
		if default = 
			default := " "
		IniRead, temp, %filepathsettings%, % onesetting.section, % onesetting.key, % default
		_settings[onesetting.key]:=temp
	}
	;~ d(_settings)
}

;Write settings into settings file. Should be called whenever some settings are changed
write_settings()
{
	global settingsdefinitions, filepathsettings
	for oneindex, onesetting in settingsdefinitions
	{
		Iniwrite, % _settings[onesetting.key], %filepathsettings%, % onesetting.section, % onesetting.key
	}
}