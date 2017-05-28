
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