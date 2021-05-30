;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Mouse_Position")

;Element type of the element
Element_getElementType_Action_Get_Mouse_Position()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Mouse_Position()
{
	return x_lang("Get_Mouse_Position")
}

;Category of the element
Element_getCategory_Action_Get_Mouse_Position()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Mouse_Position()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Mouse_Position()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_Mouse_Position()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_Mouse_Position()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Mouse_Position(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variables") (x_lang("Position: x,y"))})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["posX", "posY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Mouse position"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: "Screen", result: "enum", choices: [x_lang("Relative to screen"), x_lang("Relative to active window position"), x_lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]})
	
	parametersToEdit.push({type: "Label", label: x_lang("Additional information")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherGetWindowID", default: 0, label: x_lang("Get window ID beneath the mouse")})
	parametersToEdit.push({type: "Edit", id: "varnameWindowID", default: "windowID", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherGetControlID", default: 0, label: x_lang("Get control ID beneath the mouse")})
	parametersToEdit.push({type: "Edit", id: "varnameControlID", default: "controlID", content: "VariableName", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	return x_lang("Get_Mouse_Position") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Mouse_Position(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["varnameWindowID", "varnameControlID"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	if (EvaluatedParameters.WhetherGetWindowID)
	{
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["varnameWindowID"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}
	if (EvaluatedParameters.WhetherGetControlID)
	{
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["varnameControlID"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
	}
	
	; set coord mode
	CoordMode, Mouse, % ElementParameters.CoordMode
	
	; get mouse coordinates and, if required, also window ID and control ID
	if (EvaluatedParameters.WhetherGetWindowID)
	{
		if (EvaluatedParameters.WhetherGetControlID)
			MouseGetPos, tempx, tempy, tempwin, tempcontrol, 2 ;Get mouse pos with window ID and control ID
		else 
			MouseGetPos, tempx, tempy, tempwin ;Get mouse pos with window ID
	}
	else
	{
		if (EvaluatedParameters.WhetherGetControlID)
			MouseGetPos, tempx, tempy,, tempcontrol, 2 ;Get mouse pos with control ID
		else 
			MouseGetPos, tempx, tempy ;Get mouse pos
	}
	
	; set output variables
	x_SetVariable(Environment, EvaluatedParameters.varnameX, tempx)
	x_SetVariable(Environment, EvaluatedParameters.varnameY, tempy)
	if (EvaluatedParameters.WhetherGetControlID)
		x_SetVariable(Environment, EvaluatedParameters.varnameControlID, tempcontrol)
	if (EvaluatedParameters.WhetherGetWindowID)
		x_SetVariable(Environment, EvaluatedParameters.varnameWindowID, tempwin)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	
}






