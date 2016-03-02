iniAllActions.="Screenshot|" ;Add this action to list of all actions on initialisation

runActionScreenshot(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varname)
	local pBitmap
	local result
	local parameterRegion
	local ScreenNumber
	local x1
	local x2
	local y1
	local y2
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=flowSettings.WorkingDir "\" tempPath
	
	
	
	;~ if not v_CheckVariableName(varname)
	;~ {
		;~ logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		;~ MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		;~ return
	;~ }

	
	if %ElementID%WhichRegion=1 ;Whole screen
	{
		if %ElementID%AllScreens
			parameterRegion:=0
		else
		{
			ScreenNumber:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%ScreenNumber) 
			;Check whether value is a number
			if ScreenNumber is not number
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Screen number " ScreenNumber " is not a number")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Screen number '%1%'",ScreenNumber)) )
				return
			}
			parameterRegion:=ScreenNumber
		}
		pBitmap:=Gdip_BitmapFromScreen(parameterRegion)
		if pBitmap=-1
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinates are invalid.") 
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Coordinates are invalid")) 
			return
			
		}
	}
	else if %ElementID%WhichRegion=2 ;Coordinates
	{
		x1:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%x1)
		if x1 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x1)) )
			return
		}
		y1:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y1)
		if y1 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y1)) )
			return
		}
		x2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%x2)
		if x2 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x2)) )
			return
		}
		y2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y2)
		if y2 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y2)) )
			return
		}
		parameterRegion:= x1 "|" y1 "|" x2-x1 "|" y2-y1 
		
		pBitmap:=Gdip_BitmapFromScreen(parameterRegion)
		if pBitmap=-1
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinates are invalid.") 
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Coordinates are invalid")) 
			return
			
		}
	}
	else if %ElementID%WhichRegion=3 ;Specific window
	{
		local tempWinid
		local tempwinstring
		
		if %ElementID%UseActiveWindow
		{
			tempwinstring=A
		}
		else
		{
			local tempWinTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Wintitle)
			local tempExcludeTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%excludeTitle)
			local tempWinText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%winText)
			local tempExcludeText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ExcludeText)
			local tempTitleMatchMode :=%ElementID%TitleMatchMode
			local tempahk_class:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_class)
			local tempahk_exe:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_exe)
			local tempahk_id:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_id)
			local tempahk_pid:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ahk_pid)
			tempwinstring:=tempWinTitle
			
			if tempahk_class<>
				tempwinstring=%tempwinstring% ahk_class %tempahk_class%
			if tempahk_id<>
				tempwinstring=%tempwinstring% ahk_id %tempahk_id%
			if tempahk_pid<>
				tempwinstring=%tempwinstring% ahk_pid %tempahk_pid%
			if tempahk_exe<>
				tempwinstring=%tempwinstring% ahk_exe %tempahk_exe%
			if (tempwinstring="" and tempWinText="" and tempExcludeTitle = "" and tempExcludeText ="")
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! No window specified")
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No window specified.") )
				return
				
			}
		
		
			SetTitleMatchMode,%tempTitleMatchMode%
			
			if %ElementID%findhiddenwindow=0
				DetectHiddenWindows off
			else
				DetectHiddenWindows on
			if %ElementID%findhiddentext=0
				DetectHiddenText off
			else
				DetectHiddenText on
		}
		
		tempWinid:=winexist(tempwinstring,tempWinText,tempExcludeTitle,tempExcludeText)
		If not tempWinid
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Seeked window does not exist")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"Exception", lang("Seeked window does not exist"))
			return
			
		}
		if %ElementID%Method=1
		{
			pBitmap:=Gdip_BitmapFromScreen("hwnd:" tempWinid)
			if pBitmap=-1
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinates are invalid.") 
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Coordinates are invalid")) 
				return
				
			}
		}
		else if %ElementID%Method=2
		{
			pBitmap:=Gdip_BitmapFromHWND(tempWinid)
			
		}
		else if %ElementID%Method=3
		{
			wingetpos,x1,y1,x2,y2,ahk_id %tempWinid%
			pBitmap:=Gdip_BitmapFromScreen(x1 "|" y1 "|" x2 "|" y2 )
			
		}
		
		
		v_SetVariable(InstanceID,ThreadID,"A_WindowID",tempWinid,,c_SetBuiltInVar)
		
		
		
	}
	
	
	
	
	result:=Gdip_SaveBitmapToFile(pBitmap,tempPath)
	;~ MsgBox %result%
	if result=-1
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Wrong extention.") 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Wrong extension")) 
		return
	}
	else if result=-2
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Could not get a list of encoders on system.") 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("System error.") lang("See log for details."))
		return
	}
	else if result=-3
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Could not find matching encoder for specified file format.") 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("System error.") lang("See log for details."))
		return
	}
	else if result=-4
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Could not get WideChar name of output file.") 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("System error.") lang("See log for details."))
		return
	}
	else if result=-5
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Could not save file to disk.") 
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Could not save file to disk."))
		return
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionScreenshot()
{
	return lang("Screenshot")
}
getCategoryActionScreenshot()
{
	return lang("Image")
}

getParametersActionScreenshot()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output")})
	;~ parametersToEdit.push({type: "Radio", id: "WhichOutput", default: 1, choices: [lang("Write image into a variable"), lang("Write image to file")]})
	;~ parametersToEdit.push({type: "Edit", id: "varname", default: "Screenshot", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8, filter: lang("Image") " (*.bmp; *.dib; *.rle; *.jpg; *.jpeg; *.jpe; *.jfif; *.gif; *.tif; *.tiff; *.png)"})
	
	
	parametersToEdit.push({type: "Label", label: lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "WhichRegion", default: 1, choices: [lang("Whole screen"), lang("Defined region"), lang("Specified window")]})
	;~ parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 1, label: lang("Whole_screen")})
	parametersToEdit.push({type: "Label", label: lang("Which screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 1, label: lang("All screens")})
	parametersToEdit.push({type: "Edit", id: "ScreenNumber", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") (x1, y1)})
	parametersToEdit.push({type: "Label", label: lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "ActionScreenshotGetCoordinates", label: lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: lang("Window")})
	parametersToEdit.push({type: "Checkbox", id: "UseActiveWindow", default: 1, label: lang("Use active window")})
	parametersToEdit.push({type: "Label", label: lang("Title_of_Window"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "TitleMatchMode", default: 1, choices: [lang("Start_with"), lang("Contain_anywhere"), lang("Exactly")]})
	parametersToEdit.push({type: "Edit", id: "Wintitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Exclude_title"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "excludeTitle", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Text_of_a_control_in_Window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "winText", content: "String"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenText", default: 0, label: lang("Detect hidden text")})
	parametersToEdit.push({type: "Label", label: lang("Exclude_text_of_a_control_in_window"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ExcludeText", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Window_Class"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_class", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Process_Name"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_exe", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_window_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_id", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Unique_Process_ID"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ahk_pid", content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Hidden window"), size: "small"})
	parametersToEdit.push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: lang("Detect hidden window")})
	parametersToEdit.push({type: "Label", label: lang("Get_parameters"), size: "small"})
	parametersToEdit.push({type: "button", id: "FunctionsForElementGetWindowInformation" ,goto: "FunctionsForElementGetWindowInformation", label: lang("Get_Parameters")})
	
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, choices: [lang("Method %1%",1), lang("Method %1%",2), lang("Method %1%",3) " - " lang("Works only if window visible")]})
	
	

	return parametersToEdit
}

ActionScreenshotChooseColor()
{
	global
	tempActionScreenshotChooseColor:=chooseColor(GUISettingsOfElement%setElementID%transparent)
	;~ MsgBox %tempActionSearch_pixelChooseColor%
	if tempActionScreenshotChooseColor!=
	{
		GuiControl,,GUISettingsOfElement%setElementID%transparent,%tempActionScreenshotChooseColor%
		GUISettingsOfElementUpdateName()
	}
}

ActionScreenshotGetColor()
{
	MouseTracker({ImportColor:"Yes",ParColor:"transparent"})
}
ActionScreenshotGetCoordinates()
{
	MouseTracker({ImportMousePos:"Yes",SelectParMousePos:"Yes",SelectParMousePosLabelPos1:lang("Import upper left corner"),SelectParMousePosLabelPos2:lang("Import lower right corner"),CoordMode: "screen",ParMousePosX:"x1", ParMousePosY:"y1",ParMousePosX2:"x2", ParMousePosY2:"y2"})
}


GenerateNameActionScreenshot(ID)
{
	global
	local String := lang("Screenshot")   " - " 
	if (GUISettingsOfElement%ID%WhichRegion1 = 1)
	{
		if (GUISettingsOfElement%ID%AllScreens = 1)
			string.=lang("All screens") " - "
		else 
			string.=lang("Screen %1%",GUISettingsOfElement%ID%ScreenNumber) " - "
	}
	else if (GUISettingsOfElement%ID%WhichRegion2 = 1)
	{
		string.=lang("Defined region") " - "
	}
	else if (GUISettingsOfElement%ID%WhichRegion3 = 1)
	{
		if (GUISettingsOfElement%ID%UseActiveWindow = 1)
			string.=lang("Active window") " - "
		else 
			string.=lang("Specified window") " - "
	}
	
	string.=GUISettingsOfElement%ID%file 
	

	
	
	return string
	
}

CheckSettingsActionScreenshot(ID)
{
	
	if (GUISettingsOfElement%ID%WhichRegion1 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%AllScreens
		if GUISettingsOfElement%ID%AllScreens=1
			GuiControl,Disable,GUISettingsOfElement%ID%ScreenNumber
		else
			GuiControl,Enable,GUISettingsOfElement%ID%ScreenNumber
			
		GuiControl,Disable,GUISettingsOfElement%ID%x1
		GuiControl,Disable,GUISettingsOfElement%ID%x2
		GuiControl,Disable,GUISettingsOfElement%ID%y2
		GuiControl,Disable,GUISettingsOfElement%ID%y1
		GuiControl,Disable,GUISettingsOfElement%ID%GetCoordinates
		GuiControl,Disable,GUISettingsOfElement%ID%UseActiveWindow
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode3
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode2
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode1
		GuiControl,Disable,GUISettingsOfElement%ID%Wintitle
		GuiControl,Disable,GUISettingsOfElement%ID%excludeTitle
		GuiControl,Disable,GUISettingsOfElement%ID%winText
		GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenText
		GuiControl,Disable,GUISettingsOfElement%ID%ExcludeText
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_class
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_id
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_exe
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_pid
		GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenWindow
		GuiControl,Disable,GUISettingsOfElement%ID%FunctionsForElementGetWindowInformation
		GuiControl,Disable,GUISettingsOfElement%ID%Method1
		GuiControl,Disable,GUISettingsOfElement%ID%Method2
		GuiControl,Disable,GUISettingsOfElement%ID%Method3
	} 
	else if (GUISettingsOfElement%ID%WhichRegion2 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%AllScreens
		GuiControl,Disable,GUISettingsOfElement%ID%ScreenNumber
		GuiControl,Enable,GUISettingsOfElement%ID%x1
		GuiControl,Enable,GUISettingsOfElement%ID%x2
		GuiControl,Enable,GUISettingsOfElement%ID%y2
		GuiControl,Enable,GUISettingsOfElement%ID%y1
		GuiControl,Enable,GUISettingsOfElement%ID%GetCoordinates
		GuiControl,Disable,GUISettingsOfElement%ID%UseActiveWindow
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode3
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode2
		GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode1
		GuiControl,Disable,GUISettingsOfElement%ID%Wintitle
		GuiControl,Disable,GUISettingsOfElement%ID%excludeTitle
		GuiControl,Disable,GUISettingsOfElement%ID%winText
		GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenText
		GuiControl,Disable,GUISettingsOfElement%ID%ExcludeText
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_class
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_id
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_exe
		GuiControl,Disable,GUISettingsOfElement%ID%ahk_pid
		GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenWindow
		GuiControl,Disable,GUISettingsOfElement%ID%FunctionsForElementGetWindowInformation
		GuiControl,Disable,GUISettingsOfElement%ID%Method1
		GuiControl,Disable,GUISettingsOfElement%ID%Method2
		GuiControl,Disable,GUISettingsOfElement%ID%Method3
		
	}
	else if (GUISettingsOfElement%ID%WhichRegion3 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%AllScreens
		GuiControl,Disable,GUISettingsOfElement%ID%ScreenNumber
		GuiControl,Disable,GUISettingsOfElement%ID%x1
		GuiControl,Disable,GUISettingsOfElement%ID%x2
		GuiControl,Disable,GUISettingsOfElement%ID%y2
		GuiControl,Disable,GUISettingsOfElement%ID%y1
		GuiControl,Disable,GUISettingsOfElement%ID%GetCoordinates
		
		GuiControl,Enable,GUISettingsOfElement%ID%UseActiveWindow
		if GUISettingsOfElement%ID%UseActiveWindow=1
		{
			GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode3
			GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode2
			GuiControl,Disable,GUISettingsOfElement%ID%TitleMatchMode1
			GuiControl,Disable,GUISettingsOfElement%ID%Wintitle
			GuiControl,Disable,GUISettingsOfElement%ID%excludeTitle
			GuiControl,Disable,GUISettingsOfElement%ID%winText
			GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenText
			GuiControl,Disable,GUISettingsOfElement%ID%ExcludeText
			GuiControl,Disable,GUISettingsOfElement%ID%ahk_class
			GuiControl,Disable,GUISettingsOfElement%ID%ahk_id
			GuiControl,Disable,GUISettingsOfElement%ID%ahk_exe
			GuiControl,Disable,GUISettingsOfElement%ID%ahk_pid
			GuiControl,Disable,GUISettingsOfElement%ID%FindHiddenWindow
			GuiControl,Disable,GUISettingsOfElement%ID%FunctionsForElementGetWindowInformation
			
		}
		else
		{
			GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode3
			GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode2
			GuiControl,Enable,GUISettingsOfElement%ID%TitleMatchMode1
			GuiControl,Enable,GUISettingsOfElement%ID%Wintitle
			GuiControl,Enable,GUISettingsOfElement%ID%excludeTitle
			GuiControl,Enable,GUISettingsOfElement%ID%winText
			GuiControl,Enable,GUISettingsOfElement%ID%FindHiddenText
			GuiControl,Enable,GUISettingsOfElement%ID%ExcludeText
			GuiControl,Enable,GUISettingsOfElement%ID%ahk_class
			GuiControl,Enable,GUISettingsOfElement%ID%ahk_id
			GuiControl,Enable,GUISettingsOfElement%ID%ahk_exe
			GuiControl,Enable,GUISettingsOfElement%ID%ahk_pid
			GuiControl,Enable,GUISettingsOfElement%ID%FindHiddenWindow
			GuiControl,Enable,GUISettingsOfElement%ID%FunctionsForElementGetWindowInformation
		}
		
		GuiControl,Enable,GUISettingsOfElement%ID%Method1
		GuiControl,Enable,GUISettingsOfElement%ID%Method2
		GuiControl,Enable,GUISettingsOfElement%ID%Method3
		
	}
		
	
	
}

