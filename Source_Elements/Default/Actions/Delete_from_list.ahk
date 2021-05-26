;Always add this element class name to the global list
x_RegisterElementClass("Action_Delete_From_List")

;Element type of the element
Element_getElementType_Action_Delete_From_List()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Delete_From_List()
{
	return x_lang("Delete_From_List")
}

;Category of the element
Element_getCategory_Action_Delete_From_List()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Delete_From_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Delete_From_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Delete_From_List()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Delete_From_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Delete_From_List(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Which element")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", result: "enum", default: 2, choices: [x_lang("First element"), x_lang("Last element"), x_lang("Following element or key")], enum: ["First", "Last", "Specific"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: 2, content: "Expression", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Delete_From_List(Environment, ElementParameters)
{
	return x_lang("Delete_From_List") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Delete_From_List(Environment, ElementParameters, staticValues)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Delete_From_List(Environment, ElementParameters)
{

	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("%1% is not valid", x_lang("Ouput variable name '%1%'", Varname)))
		return
	}
	
	WhichPosition := ElementParameters.WhichPosition

	
	tempObject:=x_getVariable(Environment,Varname)
	
	if not IsObject(tempObject)
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.",Varname)) 
		return
	}

	if (WhichPosition="First")
	{
		index:=tempObject.MinIndex()
		if index=
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.",varname)) 
			return
		}
		
		tempObject.delete(index)
	}
	else if (WhichPosition="Last")
	{
		index:=tempObject.MaxIndex()
		if index=
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.",varname)) 
			return
		}
		tempObject.delete(index)
	}
	else if (WhichPosition="Specific")
	{
		evRes := x_evaluateExpression(Environment,ElementParameters.Position)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.Position) "`n`n" evRes.error) 
			return
		}
		Position:=evRes.result
		
		if (not Position)
		{
			x_finish(Environment, "exception", x_lang("%1% is not secified.",x_lang("Position")))
			return
		}
		if (not tempObject.HasKey(Position))
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain the key '%2%'.",varname,Position))
			return
		}
		tempObject.Remove(Position)
	}
	
	x_SetVariable(Environment,Varname,tempObject)
	
	
	x_finish(Environment,"normal")
	return
	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Delete_From_List(Environment, ElementParameters)
{
	
}






