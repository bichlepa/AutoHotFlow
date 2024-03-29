﻿
;Name of the element
Element_getName_Action_Get_Pixel_Color()
{
	return x_lang("Get_Pixel_Color")
}

;Category of the element
Element_getCategory_Action_Get_Pixel_Color()
{
	return x_lang("image")
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Pixel_Color()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon file name which will be shown in the background of the element
Element_getIconPath_Action_Get_Pixel_Color()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Pixel_Color()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Pixel_Color(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variables")})
	parametersToEdit.push({type: "Checkbox", id: "OutputRGB", default: 1, label: x_lang("Write RGB value in output variable")})
	parametersToEdit.push({type: "Checkbox", id: "OutputSeparate", default: 0, label: x_lang("Write each color in separate variable")})
	
	parametersToEdit.push({type: "Label", label: x_lang("RGB value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "varnameRGB", default: "ColorRBG", content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Red, green, blue"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["varnameR", "varnameG", "varnameB"], default: ["ColorRed", "ColorBlue", "ColorGreen"], content: "VariableName", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: x_lang("Position")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]})
	
	parametersToEdit.push({type: "Label", label: "x, y", size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "Action_Get_Pixel_Color_MouseTracker", label: x_lang("Get coordinates")})
	
	parametersToEdit.push({type: "Label", label: x_lang("Method")})
	parametersToEdit.push({type: "Radio", id: "Method", default: 1, choices: [x_lang("Default method"), x_lang("Alternative method"), x_lang("Slow method")], enum: ["Default", "Alt", "Slow"]})
	
	return parametersToEdit
}

Action_Get_Pixel_Color_MouseTracker()
{
	x_assistant_MouseTracker({ImportMousePos:"Yes",CoordMode:"CoordMode",xpos:"xpos",ypos:"ypos", color: "WeDontHaveColorButWeSpecifyItBecauseItWillShowTheColorFieldThen", colorGetMethod: "Method"})
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Pixel_Color(Environment, ElementParameters)
{
	return x_lang("Get_Pixel_Color") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Pixel_Color(Environment, ElementParameters, staticValues)
{	
	x_Par_Enable("varnameRGB", ElementParameters.OutputRGB)
	x_Par_Enable("varnameR", ElementParameters.OutputSeparate)
	x_Par_Enable("varnameG", ElementParameters.OutputSeparate)
	x_Par_Enable("varnameB", ElementParameters.OutputSeparate)
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Pixel_Color(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["varnameRGB", "varnameR", "varnameG", "varnameB"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	if (EvaluatedParameters.OutputRGB)
	{
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["varnameRGB"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}

	if (EvaluatedParameters.OutputSeparate)
	{
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["varnameR", "varnameG", "varnameB"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}
	
	; check whether we got numbers
	Xpos := EvaluatedParameters.Xpos
	Ypos := EvaluatedParameters.Ypos
	if Xpos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("X position"))) 
		return
	}
	if Ypos is not number
	{
		x_finish(Environment, "exception", x_lang("%1% is not a number.",x_lang("Y position"))) 
		return
	}
	
	; set coord mode
	CoordMode, Pixel, % EvaluatedParameters.CoordMode

	; prepare method parameter for PixelGetColor call
	if (EvaluatedParameters.method = "default")
	{
		method := ""
	}
	Else
	{
		method := EvaluatedParameters.method
	}
	
	; get pixel color
	PixelGetColor, pixelColor, %Xpos%, %Ypos%, RGB %method%
	
	; check for errors
	if ErrorLevel
	{
		x_finish(Environment, "exception", x_lang("Could not get pixel color from coordinates x%1% y%2%.", Xpos, Ypos)) 
		return
	}
	
	if (EvaluatedParameters.OutputRGB)
	{
		; set output variable which contains all colors
		x_SetVariable(Environment, EvaluatedParameters.varnameRGB, pixelColor)
	}
	if (EvaluatedParameters.OutputSeparate)
	{
		; set output variable which contains each color
		
		; get first color (wich starts with "0x")
		temp := SubStr(pixelColor, 1, 4)
		; convert hexadecimal value to decimal value
		temp += 0
		; set output variable
		x_SetVariable(Environment, EvaluatedParameters.varnameR, temp)
		
		; repeat with the remaining colors. This time we will need to add the "0x" to make sure that AHK interprets it as Hexadecimal number.
		temp := ("0x" SubStr(pixelColor, 5, 2))
		temp += 0
		x_SetVariable(Environment, EvaluatedParameters.varnameG, temp)

		temp := ("0x" SubStr(pixelColor, 7, 2))
		temp += 0
		x_SetVariable(Environment, EvaluatedParameters.varnameB, temp)
	}
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Pixel_Color(Environment, ElementParameters)
{
	
}






