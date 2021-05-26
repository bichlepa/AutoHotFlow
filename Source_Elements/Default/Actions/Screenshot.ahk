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
	return x_lang("Screenshot")
}

;Category of the element
Element_getCategory_Action_Screenshot()
{
	return x_lang("Image")
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
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Output")})
	;~ parametersToEdit.push({type: "Radio", id: "WhichOutput", default: 1, choices: [x_lang("Write image into a variable"), x_lang("Write image to file")]}) ;TODO later
	;~ parametersToEdit.push({type: "Edit", id: "varname", default: "Screenshot", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file"), options: 8, filter: x_lang("Image") " (*.bmp; *.dib; *.rle; *.jpg; *.jpeg; *.jpe; *.jfif; *.gif; *.tif; *.tiff; *.png)"})
	
	
	parametersToEdit.push({type: "Label", label: x_lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "WhichRegion", default: 1, choices: [x_lang("Whole screen"), x_lang("Defined region"), x_lang("Specified window")], result: "enum", enum: ["Screen", "Region", "Window"]})
	parametersToEdit.push({type: "Label", label: x_lang("Which screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 1, label: x_lang("All screens")})
	parametersToEdit.push({type: "Edit", id: "ScreenNumber", default: 1, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Coordinates") (x1, y1)})
	parametersToEdit.push({type: "Label", label: x_lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "Action_Screenshot_ButtonMouseTracker", label: x_lang("Get coordinates")})
	
	; call function which adds all the required fields for window identification
	windowFunctions_addWindowIdentificationParametrization(parametersToEdit)
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, choices: [x_lang("Method %1%",1), x_lang("Method %1%",2), x_lang("Method %1%",3) " - " x_lang("Works only if window visible")], result: "enum", enum: ["Gdip_FromScreen", "Gdip_FromHWND", "Gdip_FromScreenCoordinates"]})
	
	return parametersToEdit
}

; opens the assistant for getting coordinates
Action_Screenshot_ButtonMouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Screenshot(Environment, ElementParameters)
{
	return x_lang("Screenshot") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Screenshot(Environment, ElementParameters, staticValues)
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
			x_finish(Environment, "exception", x_lang("Can't make screenshot from screen %1%", ScreenNumber)) 
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
			x_finish(Environment, "exception", x_lang("Coordinates are invalid") ": x" EvaluatedParameters.x1 "-" EvaluatedParameters.y1 " y" EvaluatedParameters.x2 "-" EvaluatedParameters.y2 ) 
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
				x_finish(Environment, "exception", x_lang("Error! No active window found!")) 
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
			
			; evaluate window parameters
			EvaluatedWindowParameters := windowFunctions_evaluateWindowParameters(EvaluatedParameters)
			if (EvaluatedWindowParameters.exception)
			{
				x_finish(Environment, "exception", EvaluatedWindowParameters.exception)
				return
			}

			; get window ID
			windowID := windowFunctions_getWindowID(EvaluatedWindowParameters)
			if (windowID.exception)
			{
				x_finish(Environment, "exception", windowID.exception)
				return
			}

			if not windowID
			{
				x_finish(Environment, "exception", x_lang("Error! Seeked window does not exist")) 
				return
			}
		}
		
		if (EvaluatedParameters.Method="Gdip_FromScreen")
		{
			pBitmap:=Gdip_BitmapFromScreen("hwnd:" windowID)
			if pBitmap=-1
			{
				x_finish(Environment, "exception", x_lang("Can't make screenshot from window")) 
				return
				
			}
		}
		else if (EvaluatedParameters.Method="Gdip_FromHWND")
		{
			pBitmap:=Gdip_BitmapFromHWND(windowID)
			if pBitmap=-1
			{
				x_finish(Environment, "exception", x_lang("Can't make screenshot from window")) 
				return
				
			}
		}
		else if (EvaluatedParameters.Method="Gdip_FromScreenCoordinates")
		{
			wingetpos,x1,y1,x2,y2,ahk_id %windowID%
			pBitmap:=Gdip_BitmapFromScreen(x1 "|" y1 "|" x2 "|" y2 )
			if pBitmap=-1
			{
				x_finish(Environment, "exception", x_lang("Can't make screenshot from window")) 
				return
				
			}
		}
		x_SetVariable(Environment,"A_WindowID",windowID,"thread")
	}
	
	
	filepath:=x_GetFullPath(Environment, EvaluatedParameters.file)
	result:=Gdip_SaveBitmapToFile(pBitmap,filepath)
	;~ MsgBox %result%
	if result=-1
	{
		x_finish(Environment, "exception", x_lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " x_lang("Wrong extension")) 
		return
	}
	else if result=-2
	{
		x_finish(Environment, "exception", x_lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " x_lang("Could not get a list of encoders on system.")) 
		return
	}
	else if result=-3
	{
		x_finish(Environment, "exception", x_lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " x_lang("Could not find matching encoder for specified file format.")) 
		return
	}
	else if result=-4
	{
		x_finish(Environment, "exception", x_lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " x_lang("Could not get WideChar name of output file.")) 
		return
	}
	else if result=-5
	{
		x_finish(Environment, "exception", x_lang("Can't save screenshot to file '%1%'", EvaluatedParameters.file) ": " x_lang("Could not save file to disk.")) 
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






