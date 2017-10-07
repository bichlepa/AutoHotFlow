;Always add this element class name to the global list
AllElementClasses.push("Action_Get_Mouse_Position")

;Element type of the element
Element_getElementType_Action_Get_Mouse_Position()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Mouse_Position()
{
	return lang("Get_Mouse_Position")
}

;Category of the element
Element_getCategory_Action_Get_Mouse_Position()
{
	return lang("User_interaction")
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

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Get_Mouse_Position()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "varnameX"})
	parametersToEdit.push({id: "varnameY"})
	parametersToEdit.push({id: "CoordMode"})
	parametersToEdit.push({id: "WhetherGetWindowID"})
	parametersToEdit.push({id: "varnameWindowID"})
	parametersToEdit.push({id: "WhetherGetControlID"})
	parametersToEdit.push({id: "varnameControlID"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Mouse_Position(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output variables") (lang("Position: x,y"))})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["posX", "posY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Mouse position"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, result: "enum", choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position"), lang("Relative to current mouse position")], enum: ["Screen", "Window", "Cilent"]})
	
	parametersToEdit.push({type: "Label", label: lang("Additional information")})
	parametersToEdit.push({type: "Checkbox", id: "WhetherGetWindowID", default: 0, label: lang("Get window ID of the mouse")})
	parametersToEdit.push({type: "Edit", id: "varnameWindowID", default: "windowID", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "WhetherGetControlID", default: 0, label: lang("Get control ID of the mouse")})
	parametersToEdit.push({type: "Edit", id: "varnameControlID", default: "controlID", content: "VariableName", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	return lang("Get_Mouse_Position") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Mouse_Position(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	varnameX := x_replaceVariables(Environment, ElementParameters.varnameX)
	if not x_CheckVariableName(varnameX)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varnameX)))
		return
	}
	
	varnameY := x_replaceVariables(Environment, ElementParameters.varnameY)
	if not x_CheckVariableName(varnameY)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varnameY)))
		return
	}
	
	WhetherGetWindowID:=ElementParameters.WhetherGetWindowID
	if (WhetherGetWindowID)
	{
		varnameWindowID := x_replaceVariables(Environment, ElementParameters.varnameWindowID)
		if not x_CheckVariableName(varnameWindowID)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varnameWindowID)))
			return
		}
	}
	WhetherGetControlID:=ElementParameters.WhetherGetControlID
	if (WhetherGetWindowID)
	{
		varnameControlID := x_replaceVariables(Environment, ElementParameters.varnameControlID)
		if not x_CheckVariableName(varnameControlID)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varnameControlID)))
			return
		}
	}
	
	CoordModeValue := ElementParameters.CoordMode
	
	CoordMode, Mouse, %CoordModeValue%
	
	if (WhetherGetWindowID)
	{
		if (WhetherGetControlID)
			MouseGetPos,tempx,tempy,tempwin,tempcontrol,2 ;Get control hwnd
		else 
			MouseGetPos,tempx,tempy,tempwin
	}
	else
	{
		if (WhetherGetControlID)
			MouseGetPos,tempx,tempy,,tempcontrol,2 ;Get control hwnd
		else 
			MouseGetPos,tempx,tempy
	}
		
	x_SetVariable(Environment,varnameX,tempx)
	x_SetVariable(Environment,varnameY,tempy)
	if (WhetherGetControlID)
		x_SetVariable(Environment,varnameControlID,tempcontrol)
	if (WhetherGetWindowID)
		x_SetVariable(Environment,varnameWindowID,tempwin)
	
	x_finish(Environment,"normal")
	return
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Mouse_Position(Environment, ElementParameters)
{
	
}






