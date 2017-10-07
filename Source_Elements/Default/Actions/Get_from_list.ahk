;Always add this element class name to the global list
AllElementClasses.push("Action_Get_From_List")

Element_getPackage_Action_Get_From_List()
{
	return "default"
}

Element_getElementType_Action_Get_From_List()
{
	return "action"
}

Element_getElementLevel_Action_Get_From_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Get_From_List()
{
	return lang("Get_From_List")
}

Element_getIconPath_Action_Get_From_List()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Get_From_List()
{
	return lang("Variable")
}

Element_getParameters_Action_Get_From_List()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	parametersToEdit.push({id: "ListName"})
	parametersToEdit.push({id: "Position"})
	parametersToEdit.push({id: "expressionPos"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_Get_From_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key or position")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: 1, result: "enum", choices: [lang("First position"), lang("Last position"), lang("Random position"), lang("Following position or key")], enum: ["First", "Last", "Random", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	

	return parametersToEdit
}

Element_GenerateName_Action_Get_From_List(Environment, ElementParameters)
{
	return lang("Get_From_List")
}


Element_CheckSettings_Action_Get_From_List(Environment, ElementParameters)
{
	
}

Element_run_Action_Get_From_List(Environment, ElementParameters)
{
	;~ d(ElementParameters, "element parameters")
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	Value := ""
	
	if not x_CheckVariableName(varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}
	
	
	evRes := x_evaluateExpression(Environment,ElementParameters.ListName)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.ListName) "`n`n" evRes.error) 
		return
	}
	ListName:=evRes.result
	
	myList:=x_getVariable(Environment,ListName)
	
	if (!(IsObject(myList)))
	{
		x_finish(Environment, "exception", lang("Variable '%1%' does not contain a list.",myList))
		return
	}
	
	if (ElementParameters.WhichPosition="First")
	{
		minindex:=myList.MinIndex()
		if minindex=
		{
			x_finish(Environment, "exception", lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		Result:=myList[MinIndex]
	}
	else if (ElementParameters.WhichPosition="Last")
	{
		maxindex:=myList.MaxIndex()
		if maxindex=
		{
			x_finish(Environment, "exception", lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		Result:=myList[maxindex]
	}
	else if (ElementParameters.WhichPosition="Random")
	{
		minindex:=tempObject.MinIndex()
		if minindex=
		{
			x_finish(Environment, "exception", lang("The list '%1%' does not contain an integer key.",ListName))
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
				x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Position) "`n`n" evRes.error) 
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
			x_finish(Environment, "exception", lang("Position is not specified")) 
			return
		}
		
		if (not myList.HasKey(Position))
		{
			x_finish(Environment, "exception", lang("The list '%1%' does not contain the key '%2%'.",ListName,Position)) 
			return
		}
		
		Result:=myList[Position]
	}
	
	x_SetVariable(Environment,Varname,Result)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}