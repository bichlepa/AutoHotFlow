;Always add this element class name to the global list
x_RegisterElementClass("Action_Search_Image")

;Element type of the element
Element_getElementType_Action_Search_Image()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Search_Image()
{
	return x_lang("Search_Image")
}

;Category of the element
Element_getCategory_Action_Search_Image()
{
	return x_lang("Image")
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
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variables") (x, y)})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["ImagePosX", "ImagePosY"], content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: "Screen", result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]})
	parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 0, label: x_lang("Whole screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 0, label: x_lang("All screens")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "Action_Search_Image_Button_MouseTracker", label: x_lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Image file path")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select a file"), options: 8, filter: x_lang("Images and icons") " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)"})
	
	parametersToEdit.push({type: "Label", label: x_lang("File with multiple icons")})
	parametersToEdit.push({type: "Checkbox", id: "SetIconNumber", default: 0, label: x_lang("Set icon number")})
	parametersToEdit.push({type: "Edit", id: "IconNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Variation")})
	parametersToEdit.push({type: "Slider", id: "variation", content: "PositiveNumber", default: 0, options: "Range0-255 TickInterval10 tooltip"})
	
	parametersToEdit.push({type: "Label", label: x_lang("Transparent color")})
	parametersToEdit.push({type: "Checkbox", id: "makeTransparent", default: 0, label: x_lang("Make a color of image transparent")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Color name or RGB value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "transparent", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "ChooseColor", goto: "Action_Search_Image_Button_ChooseColor", label: x_lang("Choose color")})
	parametersToEdit.push({type: "button", id: "GetColor", goto: "Action_Search_Image_Button_GetColorFromScreen", label: x_lang("Get color from screen")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "ScaleImage", default: 0, label: x_lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "PreserveAspectRatio", default: 0, label: x_lang("Preserve aspect ratio")})
	parametersToEdit.push({type: "Radio", id: "WhichSizeSet", default: "widthManually", choices: [x_lang("Set width manually and set height automatically"), x_lang("Set height manually and set width automatically")], result: "enum", enum: ["widthManually", "heightManually"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["ImageWidth", "ImageHeight"], content: "Number", WarnIfEmpty: true})

	return parametersToEdit
}

; opens assistant for coordinates
Action_Search_Image_Button_MouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos: "Yes", CoordMode: "CoordMode", xpos: "x1", ypos: "y1", xpos2: "x2", ypos2: "y2"})
}
; opens assistant for a color selector
Action_Search_Image_Button_ChooseColor()
{
	x_assistant_ChooseColor({color: "transparent"})
}
; opens assistant for a color picker
Action_Search_Image_Button_GetColorFromScreen()
{
	x_assistant_MouseTracker({color: "transparent"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Search_Image(Environment, ElementParameters)
{
	switch (ElementParameters.CoordMode)
	{
		case "Screen":
		if (ElementParameters.WholeScreen)
		{
			if (ElementParameters.AllScreens)
			{
				areaString := x_lang("All screens")
			}
			Else
			{
				areaString := x_lang("Whole screen")
			}
		}
		Else
		{
			areaString := x_lang("Screen region '%1%','%2%'-'%3%','%4%'", ElementParameters.x1, ElementParameters.y1, ElementParameters.x2, ElementParameters.y2)
		}
		case "Window":
		if (ElementParameters.WholeScreen)
		{
			areaString := x_lang("Whole window")
		}
		Else
		{
			areaString := x_lang("Window region '%1%','%2%'-'%3%','%4%'", ElementParameters.x1, ElementParameters.y1, ElementParameters.x2, ElementParameters.y2)
		}
		case "Client":
		if (ElementParameters.WholeScreen)
		{
			areaString := x_lang("Whole window client")
		}
		Else
		{
			areaString := x_lang("Window client region '%1%','%2%'-'%3%','%4%'", ElementParameters.x1, ElementParameters.y1, ElementParameters.x2, ElementParameters.y2)
		}
	}

	return x_lang("Search_Image") " - " areaString " - " ElementParameters.file
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Search_Image(Environment, ElementParameters, staticValues)
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
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["x1", "x2", "y1", "y2", "IconNumber", "transparent", "ImageHeight", "ImageWidth"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	;Set coord mode and region
	
	if (EvaluatedParameters.CoordMode = "Screen")
	{
		; We will search in screen.
		CoordMode, Pixel, Screen

		if (EvaluatedParameters.WholeScreen)
		{
			; we will search in whole screen

			if (EvaluatedParameters.AllScreens)
			{
				; we will search in all screens
				
				; get coordinates which enclose all screens
				SysGet, VirtualWidth, 78
				SysGet, VirtualHeight, 79
				SysGet, Virtualx1, 76
				SysGet, Virtualy1, 77
				x1 := Virtualx1
				y1 := Virtualy1
				x2 := VirtualWidth
				y2 := VirtualHeight
			}
			else ;Only main screen
			{
				; we will search only in main screen

				; Get coordinates of the main screen
				x1 := 0
				y1 := 0
				x2 := A_ScreenWidth
				y2 := A_ScreenHeight
			}
		}
		else
		{
			;Specified region. We will evaluate the coordinates later
			WhetherSpecifiedRegion := true
		}
	}
	else if (EvaluatedParameters.CoordMode="Window")
	{
		; we will search in a window
		CoordMode, Pixel, Window
		
		if (EvaluatedParameters.WholeScreen)
		{
			; we will search in whole window

			x1 := 0
			y1 := 0

			; get size of the active window
			wingetpos,,, x2, y2, A
		}
		else ;Specified region
		{
			;Specified region. We will evaluate the coordinates later
			WhetherSpecifiedRegion := true
		}
	}
	else if (EvaluatedParameters.CoordMode="Client")
	{
		; we will search in a window client
		CoordMode, Pixel, Client
		
		if (EvaluatedParameters.WholeScreen)
		{
			; we will search in whole window client

			x1 := 0
			y1 := 0
			
			;Get client size of the active window
			winget, wineid, id, a
			VarSetCapacity(temp, 16)
			DllCall("GetClientRect", "uint", wineid, "uint", &temp)
			x2 := NumGet(temp, 8, "int")
			y2 := NumGet(temp, 12, "int")
		}
		else ;Specified region
		{
			;Specified region. We will evaluate the coordinates later
			WhetherSpecifiedRegion := true
		}
	}
	
	if (WhetherSpecifiedRegion = true)
	{
		; we need the coordinate parameters

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, ["x1", "x2", "y1", "y2"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; those will be our coordinates
		x1 := EvaluatedParameters.x1
		x2 := EvaluatedParameters.x2
		y1 := EvaluatedParameters.y1
		y2 := EvaluatedParameters.y2
	}
	
	; prepare options for the ImageSearch call
	ImageSearchOptions := ""
	if (EvaluatedParameters.SetIconNumber)
	{
		; we need the icon number parameter
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "IconNumber")
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; add the icon number parameter to the options string
		ImageSearchOptions .= "*Icon" EvaluatedParameters.IconNumber " "
	}
	
	if (EvaluatedParameters.Variation > 0)
	{
		; variation is not zero. We will add it to the options string
		ImageSearchOptions .= "*" EvaluatedParameters.Variation " "
	}
	
	if (EvaluatedParameters.makeTransparent)
	{
		; we need the transparent color parameter
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "transparent")
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		;TODO: check whether the string contains spaces

		; add the icon number parameter to the options string
		ImageSearchOptions.="*Trans" EvaluatedParameters.transparent " "
	}
	
	if (EvaluatedParameters.ScaleImage)
	{
		; scale image is selected
		if (EvaluatedParameters.PreserveAspectRatio)
		{
			; we preserve aspect ratio. Therefore we only need one size parameter
			if (EvaluatedParameters.WhichSizeSet = "widthManually") ;Set width manually
			{
				; We will need the width parameter
				setHeight := false
				setWidth := true
				Height := -1
			}
			else if (EvaluatedParameters.WhichSizeSet="heightManually") ;Set height manually
			{
				; We will need the height parameter
				setHeight := true
				setWidth := false
				width := -1
			}
		}
		else
		{
			; we don't preserve aspect ratio. Therefore we need both size parameters
			setHeight := true
			setWidth := true
		}
		
		if setHeight
		{
			; evaluate additional parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "ImageHeight")
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}

			; set height
			height := EvaluatedParameters.ImageHeight
		}
		if setWidth
		{
			; evaluate additional parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters,Environment, ElementParameters, "ImageWidth")
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			
			; set width
			width := EvaluatedParameters.ImageWidth
		}
		
		; add the size parameters to the options string
		ImageSearchOptions .= "*w" width " *h" height " "
	}
	
	; search for the image
	ImageSearch, foundx, foundy, %x1%, %y1%, %x2%, %y2%, % ImageSearchOptions EvaluatedParameters.file
	
	; check for errors
	if (ErrorLevel = 2)
	{
		; there was a problem reading the file. Check whether file exists and report error.
		if not fileexist(EvaluatedParameters.file)
		{
			x_finish(Environment, "exception", x_lang("File '%1%' does not exist", EvaluatedParameters.file)) 
			return
		}
		else
		{
			x_finish(Environment, "exception", x_lang("File '%1%' could not be read", EvaluatedParameters.file)) 
			return
		}
	}
	if (ErrorLevel = 1)
	{
		; the image was not found.
		x_finish(Environment, "exception", x_lang("Image was not found on screen", EvaluatedParameters.file)) 
		return
	}
	
	; set output variables
	x_SetVariable(Environment, EvaluatedParameters.varnameX, foundx)
	x_SetVariable(Environment, EvaluatedParameters.varnameY, foundy)
	
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Search_Image(Environment, ElementParameters)
{
}






