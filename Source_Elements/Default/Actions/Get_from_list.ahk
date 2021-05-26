;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_From_List")

;Element type of the element
Element_getElementType_Action_Get_From_List()
{
	return "action"
}

;Name of the element
Element_getName_Action_Get_From_List()
{
	return x_lang("Get_From_List")
}

;Category of the element
Element_getCategory_Action_Get_From_List()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_From_List()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_From_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_From_List()
{
	return "Source_elements\default\icons\New variable.png"
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Get_From_List()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_From_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Key or position")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: 1, result: "enum", choices: [x_lang("First position"), x_lang("Last position"), x_lang("Random position"), x_lang("Following position or key")], enum: ["First", "Last", "Random", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_From_List(Environment, ElementParameters)
{
	return x_lang("Get_From_List")
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_From_List(Environment, ElementParameters, staticValues)
{
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_From_List(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	Value := ""
	
	if not x_CheckVariableName(varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("%1% is not valid", x_lang("Ouput variable name '%1%'", varname)))
		return
	}
	
	
	evRes := x_evaluateExpression(Environment,ElementParameters.ListName)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.ListName) "`n`n" evRes.error) 
		return
	}
	ListName:=evRes.result
	
	myList:=x_getVariable(Environment,ListName)
	
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.",myList))
		return
	}
	
	if (ElementParameters.WhichPosition="First")
	{
		minindex:=myList.MinIndex()
		if minindex=
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		Result:=myList[MinIndex]
	}
	else if (ElementParameters.WhichPosition="Last")
	{
		maxindex:=myList.MaxIndex()
		if maxindex=
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		Result:=myList[maxindex]
	}
	else if (ElementParameters.WhichPosition="Random")
	{
		minindex:=tempObject.MinIndex()
		if minindex=
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		maxindex:=tempObject.MaxIndex()
		
		random,randomindex,%minindex%,%maxindex%
		Result:=myList[randomindex]
	}
	else  if (ElementParameters.WhichPosition="Specified")
	{
		if (ElementParameters.ExpressionPos = "expression")
		{
			evRes := x_EvaluateExpression(Environment, ElementParameters.Position)
			if (evRes.error)
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", x_lang("An error occured while parsing expression '%1%'", ElementParameters.Position) "`n`n" evRes.error) 
				return
			}
			else
			{
				Position:=evRes.result
			}
		}
		else
			Position := x_replaceVariables(Environment, ElementParameters.Position)
		
		if (position = "")
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", x_lang("Position is not specified")) 
			return
		}
		
		if (not myList.HasKey(Position))
		{
			x_finish(Environment, "exception", x_lang("The list '%1%' does not contain the key '%2%'.",ListName,Position)) 
			return
		}
		
		Result:=myList[Position]
	}
	
	x_SetVariable(Environment,Varname,Result)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_From_List(Environment, ElementParameters)
{
	
}
