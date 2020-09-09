
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
	settingsdefinitions.push({section: "appearance", key: "ShowElementsLevel", default: "Beginner"})
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
		_setSettings(onesetting.key, temp)
	}
	;~ d(_settings)
}

;Write settings into settings file. Should be called whenever some settings are changed
write_settings()
{
	global settingsdefinitions, filepathsettings
	for oneindex, onesetting in settingsdefinitions
	{
		Iniwrite, % _getSettings(onesetting.key), %filepathsettings%, % onesetting.section, % onesetting.key
	}
}

checkNewWorkingDir(PreviousWorkingDir, NewWorkingDir)
{
	if (NewWorkingDir = "")
	{
		MsgBox, 17, AutoHotFlow, % lang("The specified folder is empty!") "`n" lang("If you press '%1%', previous path will remain.",lang("OK"))
		IfMsgBox cancel
			return
		else
			return PreviousWorkingDir
	}
	if DllCall("Shlwapi.dll\PathIsRelative","Str",NewWorkingDir) ;if user did not enter an absolute path
	{
		if NewWorkingDir!=  ;If user left it blank, he don't want to change it. if not...
		{
			MsgBox, 17, AutoHotFlow, % lang("The specified folder is not an absolute path!") "`n" lang("If you press '%1%', previous path will remain.",lang("OK"))
			IfMsgBox cancel
				return
			else
				return PreviousWorkingDir
		}
	}
	else
	{
		fileattr := FileExist(NewWorkingDir)
		if not fileattr
		{
			MsgBox, 36, AutoHotFlow, % lang("The specified folder does not exist. Should it be created?") "`n" lang("Press '%1%', if you want to correct it.",lang("No"))
			IfMsgBox Yes
			{
				FileCreateDir,%NewWorkingDir%
				if errorlevel
				{
					MsgBox, 16, AutoHotFlow, % lang("The specified folder could not be created!")
					return
				}
				
			}
			else
				return
		}
		else if not instr(fileattr,"D")
		{
			MsgBox, 17, AutoHotFlow, % lang("The specified path exists but it is a file. It must be a folder!") "`n" lang("Press '%1%', if you want to correct it.",lang("Cancel"))
			IfMsgBox Yes
			{
				FileCreateDir,%NewWorkingDir%
				if errorlevel
				{
					MsgBox, 16, AutoHotFlow, % lang("The specified folder could not be created!")
					return
				}
				
			}
			else
				return
		}
	}
	
	return NewWorkingDir
}