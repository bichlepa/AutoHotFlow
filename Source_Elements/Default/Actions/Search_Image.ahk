;Always add this element class name to the global list
AllElementClasses.push("Action_Search_Image")

;Element type of the element
Element_getElementType_Action_Search_Image()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Search_Image()
{
	return lang("Search_Image")
}

;Category of the element
Element_getCategory_Action_Search_Image()
{
	return lang("Image")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Search_Image()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Search_Image()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Search_Image()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Search_Image()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Search_Image(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output variables") (x, y)})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["ImagePosX", "ImagePosY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]})
	parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 0, label: lang("Whole screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 0, label: lang("All screens")})
	parametersToEdit.push({type: "Label", label: lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "Action_Search_Image_Button_MouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Image file path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8, filter: lang("Images and icons") " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)"})
	parametersToEdit.push({type: "Label", label: lang("File with multiple icons")})
	parametersToEdit.push({type: "Checkbox", id: "SetIconNumber", default: 0, label: lang("Set icon number")})
	parametersToEdit.push({type: "Edit", id: "IconNumber", default: 1, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Variation")})
	parametersToEdit.push({type: "Slider", id: "variation", content: "Number", default: 0, options: "Range0-255 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Transparent color")})
	parametersToEdit.push({type: "Checkbox", id: "makeTransparent", default: 0, label: lang("Make a color of image transparent")})
	parametersToEdit.push({type: "Label", label: lang("Color name or RGB value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "transparent", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "ChooseColor", goto: "Action_Search_Image_Button_ChooseColor", label: lang("Choose color")})
	parametersToEdit.push({type: "button", id: "GetColor", goto: "Action_Search_Image_Button_GetColorFromScreen", label: lang("Get color from screen")})
	parametersToEdit.push({type: "Label", label: lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "ScaleImage", default: 0, label: lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "PreserveAspectRatio", default: 0, label: lang("Preserve aspect ratio")})
	parametersToEdit.push({type: "Radio", id: "WhichSizeSet", default: 1, choices: [lang("Set width manually and set height automatically"), lang("Set height manually and set width automatically")], result: "enum", enum: ["widthManually", "heightManually"]})
	parametersToEdit.push({type: "Label", label: lang("width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["ImageWidth", "ImageHeight"], content: "Number", WarnIfEmpty: true})

	
	return parametersToEdit
}

Action_Search_Image_Button_MouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"x1",ypos:"y1",xpos2:"x2",ypos2:"y2"})
}
Action_Search_Image_Button_ChooseColor()
{
	x_assistant_ChooseColor({color: "transparent"})
}
Action_Search_Image_Button_GetColorFromScreen()
{
	x_assistant_MouseTracker({color: "transparent"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Search_Image(Environment, ElementParameters)
{
	return lang("Search_Image") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Search_Image(Environment, ElementParameters)
{	
	if (ElementParameters.CoordMode = "Screen")
	{
		x_par_SetLabel("WholeScreen", lang("Whole screen"))
		x_par_Enable("AllScreens", ElementParameters.WholeScreen)
	}
	else if (ElementParameters.CoordMode = "Window")
	{
		x_par_SetLabel("WholeScreen", lang("Whole window"))
		x_par_Disable("AllScreens")
	}
	else
	{
		x_par_SetLabel("WholeScreen", lang("Whole window client"))
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
		
	x_par_Enable("transparent", ElementParameters.makeTransparent)
	x_par_Enable("IconNumber", ElementParameters.SetIconNumber)
	
	if (ElementParameters.ScaleImage)
	{
		x_par_Enable("PreserveAspectRatio")
		if (ElementParameters.PreserveAspectRatio)
		{
			x_par_Enable("WhichSizeSet")
			if (ElementParameters.WhichSizeSet1 =1)
			{
				x_par_Disable("ImageHeight")
				x_par_Enable("ImageWidth")
			}
			else
			{
				x_par_Enable("ImageHeight")
				x_par_Disable("ImageWidth")
			}
		}
		else
		{
			x_par_Disable("WhichSizeSet")
			x_par_Disable("ImageHeight")
			x_par_Disable("ImageWidth")
		}
	}
	else
	{
		x_par_Disable("PreserveAspectRatio")
		x_par_Disable("WhichSizeSet")
		x_par_Disable("ImageHeight")
		x_par_Disable("ImageWidth")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Search_Image(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["x1", "x2", "y1", "y2", "IconNumber", "transparent", "ImageHeight", "ImageWidth"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	
	
	tempPath:=x_GetFullPath(Environment, EvaluatedParameters.file)

	
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
	
	tempOptions:=""
	if (EvaluatedParameters.SetIconNumber)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "IconNumber")
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		tempOptions.="*Icon" EvaluatedParameters.IconNumber " "
	}
	
	if (EvaluatedParameters.Variation > 0)
	{
		tempOptions.="*" EvaluatedParameters.Variation " "
	}
	
	if (EvaluatedParameters.makeTransparent)
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "transparent")
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		;TODO: check whether the string contains spaces
		tempOptions.="*Trans" EvaluatedParameters.transparent " "
	}
	
	if (EvaluatedParameters.ScaleImage)
	{
		if (EvaluatedParameters.PreserveAspectRatio)
		{
			if (EvaluatedParameters.WhichSizeSet = "widthManually") ;Set width manually
			{
				setHeight:=false
				setWidth:=true
				Height:=-1
			}
			else if (EvaluatedParameters.WhichSizeSet="heightManually") ;Set height manually
			{
				setHeight:=true
				setWidth:=false
				width:=-1
			}
		}
		else
		{
			setHeight:=true
			setWidth:=true
		}
		
		if setHeight
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "ImageHeight")
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			height:=EvaluatedParameters.ImageHeight
		}
		if setWidth
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "ImageWidth")
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			width:=EvaluatedParameters.ImageWidth
		}
		
		
		tempOptions.="*w" width " *h" height " "
	}
	
	ImageSearch,foundx,foundy,%x1%,%y1%,%x2%,%y2%,% tempOptions tempPath
	
	if ErrorLevel=2
	{
		if not fileexist(tempPath)
		{
			x_finish(Environment, "exception", lang("File '%1%' does not exist",tempPath)) 
			return
		}
		else
		{
			x_finish(Environment, "exception", lang("File '%1%' could not be read",tempPath)) 
			return
		}
	}
	if ErrorLevel=1
	{
		x_finish(Environment, "exception", lang("Image was not found on screen",tempPath)) 
		return
		
	}
	
	x_SetVariable(Environment,EvaluatedParameters.varnameX,foundx)
	x_SetVariable(Environment,EvaluatedParameters.varnameY,foundy)
	
	

	x_finish(Environment,"normal")
	return
	

}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Search_Image(Environment, ElementParameters)
{
}






