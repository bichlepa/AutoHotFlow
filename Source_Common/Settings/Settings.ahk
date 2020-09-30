; returns file path of settings file
getSettingsFilePath()
{
	return _WorkingDir "\settings.json"
}

; returns default working directory of flows (during execution)
getDefaultSettings()
{
	; define default settings
	settings := {}
	settings.UILanguage := "en"
	settings.runAsAdmin := false
	settings.FlowExecutionPolicy := "parallel"
	settings.FlowWorkingDir := A_MyDocuments "\AutoHotFlow"
	settings.HideDemoFlows := False
	settings.ShowElementsLevel := "Beginner"
	settings.LogLevelFlow := 0
	settings.LogLevelApp := 0
	settings.LogLevelThread := 0
	settings.LogToFile := false

	return settings
}

;load settings from settings file. Must be called olny once
load_settings()
{
	; define default settings (if settings file does not exist or if some additional settings were added on recent update)
	settings := getDefaultSettings()

	; read settings and convert them to object
	FileRead, settingsFromFile, % getSettingsFilePath()
	settingsFromFile := Jxon_Load(settingsFromFile)

	; overwrite the default settings with the settings from file
	settings := ObjFullyMerge(settings, settingsFromFile)
	
	; set settings object
	_setAllSettings(settings)
}


;Write settings into settings file. Should be called whenever some settings are changed
write_settings()
{
	filedelete, % getSettingsFilePath()
	fileappend, % Jxon_Dump(_getAllSettings(), 2), % getSettingsFilePath()
}

; checks some settings
check_settings()
{
	; check working directory
	workingDir := _getSettings("FlowWorkingDir")
	if (not checkNewWorkingDir(workingDir, false))
	{
		; working directory is invalid. Try to set default working directory
		defaultSettings := getDefaultSettings()
		defaultValue := defaultSettings.FlowWorkingDir

		; check the default working directory
		if (checkNewWorkingDir(defaultValue, false))
		{
			; the default working directory is OK. Change the setting and show an alert to user
			_setSettings("FlowWorkingDir", defaultValue)
			write_settings()
			MsgBox, 17, AutoHotFlow, % lang("The default working directory was not found and cannot be created!") "`n" lang("It was changed to the default value") "`n" defaultValue
		}
		else
		{
			MsgBox, 17, AutoHotFlow, % lang("The default working directory cannot be created!") "`n" lang("Please check the settings")
		}
	}
}

; checks the default working directory of flows.
; if interactive is false, not alerts will be shown
; if valid, returns true
checkNewWorkingDir(NewWorkingDir, interactive = true)
{
	; check whether the working dir is empty
	if (NewWorkingDir = "")
	{
		if (interactive)
		{
			MsgBox, 16, AutoHotFlow, % lang("The specified folder is empty!")
		}
		return false
	}
	; check whether the working directory is relative
	if DllCall("Shlwapi.dll\PathIsRelative","Str",NewWorkingDir) ;if user did not enter an absolute path
	{
		if (interactive)
		{
			MsgBox, 16, AutoHotFlow, % lang("The specified folder is not an absolute path!")
		}
		return false	
	}

	; check whether the specified folder exists
	fileattr := FileExist(NewWorkingDir)
	if not fileattr
	{
		; the folder does not exist
		if (interactive)
		{
			; ask user whether he wants to create the not existing folder
			MsgBox, 36, AutoHotFlow, % lang("The specified folder does not exist. Should it be created?") "`n" lang("Press '%1%', if you want to correct it.", lang("Yes"))
			IfMsgBox Yes
			{
				FileCreateDir,%NewWorkingDir%
				if errorlevel
				{
					MsgBox, 16, AutoHotFlow, % lang("The specified folder could not be created!")
					return false
				}
			}
			else
				return false
		}
		else
		{
			; try to create the not existing folder
			FileCreateDir,%NewWorkingDir%
			if errorlevel
			{
				return false
			}
		}
	}
	else if not instr(fileattr,"D")
	{
		; the specified path is a file
		if (interactive)
		{
			MsgBox, 16, AutoHotFlow, % lang("The specified path exists but it is a file. It must be a folder!")
		}
		return false
	}
	
	; todo: check write permissions

	; working dir is ok
	return true
}