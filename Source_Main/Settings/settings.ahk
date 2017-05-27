
;load settings from settings file. must be called olny once
load_settings()
{
	global my_workingdir, _settings, settingsdefinitions
	
	filepathsettings:= my_workingdir "\settings.ini"
	
	settingsdefinitions:=Object()
	settingsdefinitions.push({section: "common", key: "developing", default: ""})
	settingsdefinitions.push({section: "common", key: "UILanguage", default: ""})
	for oneindex, onesetting in settingsdefinitions
	{
		IniRead, temp, %filepathsettings%, % onesetting.section, % onesetting.key, % onesetting.default
		_settings[onesetting.key]:=temp
	}
	;~ d(_settings)
}