;Always add this element class name to the global list
x_RegisterElementClass("Action_Screenshot")

;Element type of the element
Element_getElementType_Action_Screenshot()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Screenshot()
{
	return lang("Screenshot")
}

;Category of the element
Element_getCategory_Action_Screenshot()
{
	return lang("Image")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Screenshot()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Screenshot()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Screenshot()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Screenshot()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Screenshot(Environment)
{
	parametersToEdit:=Object()
	
	
	parametersToEdit.push({type: "Label", label: lang("Output")})
	;~ parametersToEdit.push({type: "Radio", id: "WhichOutput", default: 1, choices: [lang("Write image into a variable"), lang("Write image to file")]}) ;TODO later
	;~ parametersToEdit.push({type: "Edit", id: "varname", default: "Screenshot", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8, filter: lang("Image") " (*.bmp; *.dib; *.rle; *.jpg; *.jpeg; *.jpe; *.jfif; *.gif; *.tif; *.tiff; *.png)"})
	
	
	parametersToEdit.push({type: "Label", label: lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "WhichRegion", default: 1, choices: [lang("Whole screen"), lang("Defined region"), lang("Specified window")], result: "enum", enum: ["Screen", "Region", "Window"]})
	parametersToEdit.push({type: "Label", label: lang("Which screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 1, label: lang("All screens")})
	parametersToEdit.push({type: "Edit", id: "ScreenNumber", default: 1, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") (x1, y1)})
	parametersToEdit.push({type: "Label", label: lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "Action_Screenshot_ButtonMouseTracker", label: lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: lang("Window identification")})
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
	parametersToEdit.push({type: "Label", label: lang("Import window identification"), size: "small"})
	parametersToEdit.push({type: "button", id: "GetWindow", goto: "Action_Screenshot_ButtonWindowAssistant", label: lang("Import window identification")})
	
	
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, choices: [lang("Method %1%",1), lang("Method %1%",2), lang("Method %1%",3) " - " lang("Works only if window visible")], result: "enum", enum: ["Gdip_FromScreen", "Gdip_FromHWND", "Gdip_FromScreenCoordinates"]})
	
	return parametersToEdit
}

Action_Screenshot_ButtonWindowAssistant()
{
	x_assistant_windowParameter({wintitle: "Wintitle", excludeTitle: "excludeTitle", winText: "winText", FindHiddenText: "FindHiddenText", ExcludeText: "ExcludeText", ahk_class: "ahk_class", ahk_exe: "ahk_exe", ahk_id: "ahk_id", ahk_pid: "ahk_pid", FindHiddenWindow: "FindHiddenWindow"})
}

Action_Screenshot_ButtonMouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Screenshot(Environment, ElementParameters)
{
	return lang("Screenshot") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Screenshot(Environment, ElementParameters)
{	
	
	if (ElementParameters.WhichRegion = "Screen")
	{
		x_Par_Enable("AllScreens")
		x_Par_Enable("ScreenNumber", ElementParameters.AllScreens = False)
		x_Par_Disable("x1")
		x_Par_Disable("x2")
		x_Par_Disable("y1")
		x_Par_Disable("y2")
		x_Par_Disable("GetCoordinates")
		x_Par_Disable("UseActiveWindow")
		x_Par_Disable("TitleMatchMode")
		x_Par_Disable("Wintitle")
		x_Par_Disable("excludeTitle")
		x_Par_Disable("winText")
		x_Par_Disable("FindHiddenText")
		x_Par_Disable("ExcludeText")
		x_Par_Disable("ahk_class")
		x_Par_Disable("ahk_id")
		x_Par_Disable("ahk_exe")
		x_Par_Disable("ahk_pid")
		x_Par_Disable("FindHiddenWindow")
		x_Par_Disable("GetWindow")
		x_Par_Disable("Method")
	} 
	else if (ElementParameters.WhichRegion = "Region")
	{
		x_Par_Disable("AllScreens")
		x_Par_Disable("ScreenNumber")
		x_Par_Enable("x1")
		x_Par_Enable("x2")
		x_Par_Enable("y1")
		x_Par_Enable("y2")
		x_Par_Enable("GetCoordinates")
		x_Par_Disable("UseActiveWindow")
		x_Par_Disable("TitleMatchMode")
		x_Par_Disable("Wintitle")
		x_Par_Disable("excludeTitle")
		x_Par_Disable("winText")
		x_Par_Disable("FindHiddenText")
		x_Par_Disable("ExcludeText")
		x_Par_Disable("ahk_class")
		x_Par_Disable("ahk_id")
		x_Par_Disable("ahk_exe")
		x_Par_Disable("ahk_pid")
		x_Par_Disable("FindHiddenWindow")
		x_Par_Disable("GetWindow")
		x_Par_Disable("Method")
		
	}
	else if (ElementParameters.WhichRegion = "Window")
	{
		x_Par_Disable("AllScreens")
		x_Par_Disable("ScreenNumber")
		x_Par_Disable("x1")
		x_Par_Disable("x2")
		x_Par_Disable("y1")
		x_Par_Disable("y2")
		x_Par_Disable("GetCoordinates")
		x_Par_Enable("UseActiveWindow")
		
		if (ElementParameters.UseActiveWindow)
		{
			x_Par_Disable("TitleMatchMode")
			x_Par_Disable("Wintitle")
			x_Par_Disable("excludeTitle")
			x_Par_Disable("winText")
			x_Par_Disable("FindHiddenText")
			x_Par_Disable("ExcludeText")
			x_Par_Disable("ahk_class")
			x_Par_Disable("ahk_id")
			x_Par_Disable("ahk_exe")
			x_Par_Disable("ahk_pid")
			x_Par_Disable("FindHiddenWindow")
			x_Par_Disable("GetWindow")
			
		}
		else
		{
			x_Par_Enable("TitleMatchMode")
			x_Par_Enable("Wintitle")
			x_Par_Enable("excludeTitle")
			x_Par_Enable("winText")
			x_Par_Enable("FindHiddenText")
			x_Par_Enable("ExcludeText")
			x_Par_Enable("ahk_class")
			x_Par_Enable("ahk_id")
			x_Par_Enable("ahk_exe")
			x_Par_Enable("ahk_pid")
			x_Par_Enable("FindHiddenWindow")
			x_Par_Enable("GetWindow")
		}
		
		x_Par_Enable("Method")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Screenshot(Environment, ElementParameters)
{
	EvaluatedParameters:=Object()
	x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["file", "WhichRegion", "UseActiveWindow", "AllScreens"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.WhichRegion = "Screen")
	{
		if (ElementParameters.AllScreens)
		{
			parameterRegion:=0
		}
		else
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["ScreenNumber"])
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			parameterRegion:=EvaluatedParameters.ScreenNumber
		}
		pBitmap:=Gdip_BitmapFromScreen(parameterRegion)
		if pBitmap=-1
		{
			x_finish(Environment, "exception", lang("Can't make screenshot from screen %1%", ScreenNumber)) 
			return
		}
	}
	else if (EvaluatedParameters.WhichRegion = "Region")
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["y1", "y2", "x1", "x2"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		parameterRegion:= EvaluatedParameters.x1 "|" EvaluatedParameters.y1 "|" EvaluatedParameters.x2-EvaluatedParameters.x1 "|" EvaluatedParameters.y2-EvaluatedParameters.y1 
		
		pBitmap:=Gdip_BitmapFromScreen(parameterRegion)
		if pBitmap=-1
		{
			x_finish(Environment, "exception", lang("Coordinates are invalid") ": x" EvaluatedParameters.x1 "-" EvaluatedParameters.y1 " y" EvaluatedParameters.x2 "-" EvaluatedParameters.y2 ) 
			return
		}
	}
	else if (EvaluatedParameters.WhichRegion = "Window")
	{
		if (EvaluatedParameters.UseActiveWindow)
		{
			tempWinid:=winexist("A")
			if not tempWinid
			{
				x_finish(Environment, "exception", lang("Error! No active window found!")) 
				return
			}
		}
		else
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["Wintitle", "winText", "TitleMatchMode", "Wintitle", "excludeTitle", "winText", "FindHiddenText", "ExcludeText", "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"])
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			
			tempWinTitle:=EvaluatedParameters.Wintitle
			tempWinText:=EvaluatedParameters.winText
			tempTitleMatchMode :=EvaluatedParameters.TitleMatchMode
			tempahk_class:=EvaluatedParameters.ahk_class
			tempahk_exe:=EvaluatedParameters.ahk_exe
			tempahk_id:= EvaluatedParameters.ahk_id
			tempahk_pid:= EvaluatedParameters.ahk_pid
			
			tempwinstring:=EvaluatedParameters.Wintitle
			if (EvaluatedParameters.ahk_class)
				tempwinstring:=tempwinstring " ahk_class " EvaluatedParameters.ahk_class
			if (EvaluatedParameters.ahk_id)
				tempwinstring:=tempwinstring " ahk_id " EvaluatedParameters.ahk_id
			if (EvaluatedParameters.ahk_pid)
				tempwinstring:=tempwinstring " ahk_pid " EvaluatedParameters.ahk_pid
			if (EvaluatedParameters.ahk_exe)
				tempwinstring:=tempwinstring " ahk_exe " EvaluatedParameters.ahk_exe
			
			;If no window specified, error
			if (tempwinstring="" and EvaluatedParameters.winText="")
			{
				x_finish(Environment, "exception", lang("No window specified"))
				return
			}
			
			if (ElementParameters.findhiddenwindow=0)
				tempFindHiddenWindows = off
			else
				tempFindHiddenWindows = on
			if (ElementParameters.findhiddentext=0)
				tempfindhiddentext = off
			else
				tempfindhiddentext = on

			SetTitleMatchMode,% EvaluatedParameters.TitleMatchMode
			DetectHiddenWindows,%tempFindHiddenWindows%
			DetectHiddenText,%tempfindhiddentext%
			
			tempWinid:=winexist(tempwinstring,EvaluatedParameters.winText,EvaluatedParameters.ExcludeTitle,EvaluatedParameters.ExcludeText)
			if not tempWinid
			{
				x_finish(Environment, "exception", lang("Error! Seeked window does not exist")) 
				return
			}
		}
		
		if (EvaluatedParameters.Method="Gdip_FromScreen")
		{
			pBitmap:=Gdip_BitmapFromScreen("hwnd:" tempWinid)
			if pBitmap=-1
			{
				x_finish(Environment, "exception", lang("Can't make screenshot from window")) 
				return
				
			}
		}
		else if (EvaluatedParameters.Method="Gdip_FromHWND")
		{
			pBitmap:=Gdip_BitmapFromHWND(tempWinid)
			if pBitmap=-1
			{
				x_finish(Environment, "exception", lang("Can't make screenshot from window")) 
				return
				
			}
		}
		else if (EvaluatedParameters.Method="Gdip_FromScreenCoordinates")
		{
			wingetpos,x1,y1,x2,y2,ahk_id %tempWinid%
			pBitmap:=Gdip_BitmapFromScreen(x1 "|" y1 "|" x2 "|" y2 )
			if pBitmap=-1
			{
				x_finish(Environment, "exception", lang("Can't make screenshot from window")) 
				return
				
			}
		}
		x_SetVariable(Environment,"A_WindowID",tempWinid,"thread")
	}
	
	
	filepath:=x_GetFullPath(Environment, EvaluatedParameters.file)
	result:=Gdip_SaveBitmapToFile(pBitmap,filepath)
	;~ MsgBox %result%
	if result=-1
	{
		x_finish(Environment, "exception", lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " lang("Wrong extension")) 
		return
	}
	else if result=-2
	{
		x_finish(Environment, "exception", lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " lang("Could not get a list of encoders on system.")) 
		return
	}
	else if result=-3
	{
		x_finish(Environment, "exception", lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " lang("Could not find matching encoder for specified file format.")) 
		return
	}
	else if result=-4
	{
		x_finish(Environment, "exception", lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " lang("Could not get WideChar name of output file.")) 
		return
	}
	else if result=-5
	{
		x_finish(Environment, "exception", lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " lang("Could not save file to disk.")) 
		return
	}

	x_finish(Environment,"normal")
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Screenshot(Environment, ElementParameters)
{
}






