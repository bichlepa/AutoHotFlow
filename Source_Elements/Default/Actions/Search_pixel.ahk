;Always add this element class name to the global list
x_RegisterElementClass("Action_Search_pixel")

;Element type of the element
Element_getElementType_Action_Search_pixel()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Search_pixel()
{
	return x_lang("Search_pixel")
}

;Category of the element
Element_getCategory_Action_Search_pixel()
{
	return x_lang("Image")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Search_pixel()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Search_pixel()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Search_pixel()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Search_pixel()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Search_pixel(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variables") (x, y)})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["PixelPosX", "PixelPosY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]})
	parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 0, label: x_lang("Whole screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 0, label: x_lang("All screens")})
	parametersToEdit.push({type: "Label", label: x_lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "number", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "Action_Search_Pixel_Button_MouseTracker", label: x_lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: x_lang("Pixel color") (RGB)})
	parametersToEdit.push({type: "Edit", id: "ColorID", default: "0xAA00FF", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "ChooseColor", goto: "Action_Search_Pixel_Button_ChooseColor", label: x_lang("Choose color")})
	parametersToEdit.push({type: "button", id: "GetColor", goto: "Action_Search_Pixel_Button_GetColorFromScreen", label: x_lang("Get color from screen")})
	parametersToEdit.push({type: "Label", label: x_lang("Variation")})
	parametersToEdit.push({type: "Slider", id: "variation", default: 0, result: "number", options: "Range0-255 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Checkbox", id: "FastMode", default: 1, label: x_lang("Fast method")})
	
	return parametersToEdit
}
Action_Search_Pixel_Button_MouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"x1",ypos:"y1",xpos2:"x2",ypos2:"y2"})
}
Action_Search_Pixel_Button_ChooseColor()
{
	x_assistant_ChooseColor({color: "ColorID"})
}
Action_Search_Pixel_Button_GetColorFromScreen()
{
	x_assistant_MouseTracker({color: "ColorID"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Search_pixel(Environment, ElementParameters)
{
	return x_lang("Search_pixel") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Search_pixel(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.CoordMode = "Screen")
	{
		x_par_SetLabel("WholeScreen", x_lang("Whole screen"))
		x_par_Enable("AllScreens", ElementParameters.WholeScreen)
	}
	else if (ElementParameters.CoordMode = "Window")
	{
		x_par_SetLabel("WholeScreen", x_lang("Whole window"))
		x_par_Disable("AllScreens")
	}
	else
	{
		x_par_SetLabel("WholeScreen", x_lang("Whole window client"))
		x_par_Disable("AllScreens")
	}
	
	if (ElementParameters.WholeScreen)
	{
		x_par_Disable("x1")
		x_par_Disable("x2")
		x_par_Disable("y1")
		x_par_Disable("y2")
	}
	else
	{
		x_par_Enable("x1")
		x_par_Enable("x2")
		x_par_Enable("y1")
		x_par_Enable("y2")
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Search_pixel(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["x1", "x2", "y1", "y2"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	;Set coord mode and region
	
	if (EvaluatedParameters.CoordMode="Screen")
	{
		CoordMode, Pixel, Screen
		if (EvaluatedParameters.WholeScreen)
		{
			
			if (EvaluatedParameters.AllScreens)
			{
				SysGet, VirtualWidth, 78
				SysGet, VirtualHeight, 79
				SysGet, Virtualx1, 76
				SysGet, Virtualy1, 77
				x1:=Virtualx1
				y1:=Virtualy1
				x2:=VirtualWidth
				y2:=VirtualHeight
			}
			else ;Only main screen
			{
				x1:=0
				y1:=0
				x2:=A_ScreenWidth
				y2:=A_ScreenHeight
			}
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	else if (EvaluatedParameters.CoordMode="Window")
	{
		CoordMode, Pixel, Window
		
		if (EvaluatedParameters.WholeScreen)
		{
			x1:=0
			y1:=0
			wingetpos,,,x2,y2,A
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	else if (EvaluatedParameters.CoordMode="Client")
	{
		CoordMode, Pixel, Client
		
		if (EvaluatedParameters.WholeScreen)
		{
			x1:=0
			y1:=0
			
			;Get window client size
			winget,wineid,id,a
			VarSetCapacity(temp, 16)
			DllCall("GetClientRect", "uint", wineid, "uint", &temp)
			x2 := NumGet(temp, 8, "int")
			y2 := NumGet(temp, 12, "int")
			
			;~ MsgBox % wineid " -- " tempWinPos " - " x2 " . " y2 " - " format("{1:X}",tempWinPos)
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	
	if (WhetherSpecifiedRegion=true)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["x1", "x2", "y1", "y2"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		x1:=EvaluatedParameters.x1
		x2:=EvaluatedParameters.x2
		y1:=EvaluatedParameters.y1
		y2:=EvaluatedParameters.y2
	}
	
	if (EvaluatedParameters.FastMode)
	{
		WhetherFastMode=Fast
	}
	
	;~ MsgBox %x1%,%y1%,%x2%,%y2%,%ColorID%,%variation%,RGB %WhetherFastMode%
	PixelSearch,foundx,foundy,%x1%,%y1%,%x2%,%y2%,% EvaluatedParameters.ColorID,% EvaluatedParameters.variation,RGB %WhetherFastMode%
	if ErrorLevel=2
	{
		x_finish(Environment, "exception", x_lang("Something prevented the command from conducting the search")) 
		return
	}
	if ErrorLevel=1
	{
		
		x_finish(Environment, "exception", x_lang("Pixel with color '%1%' not found",EvaluatedParameters.ColorID)) 
		return
	}
	
	
	x_SetVariable(Environment,EvaluatedParameters.varnameX,foundx)
	x_SetVariable(Environment,EvaluatedParameters.varnameY,foundy)
	
	
	x_finish(Environment,"normal")
	return
	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Search_pixel(Environment, ElementParameters)
{
}




