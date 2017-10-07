;Always add this element class name to the global list
AllElementClasses.push("Action_Get_Index_Of_Element_In_List")

Element_getPackage_Action_Get_Index_Of_Element_In_List()
{
	return "default"
}

Element_getElementType_Action_Get_Index_Of_Element_In_List()
{
	return "action"
}

Element_getElementLevel_Action_Get_Index_Of_Element_In_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Get_Index_Of_Element_In_List()
{
	return lang("Get_Index_Of_Element_In_List")
}

Element_getIconPath_Action_Get_Index_Of_Element_In_List()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Get_Index_Of_Element_In_List()
{
	return lang("Variable")
}

Element_getParameters_Action_Get_Index_Of_Element_In_List()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	parametersToEdit.push({id: "ListName"})
	parametersToEdit.push({id: "SearchContent"})
	parametersToEdit.push({id: "expression"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_Get_Index_Of_Element_In_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true})
	
	parametersToEdit.push({type: "Label", label: lang("Seeked content")})
	parametersToEdit.push({type: "Edit", id: "SearchContent", default: "keyName", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	
	return parametersToEdit
}

Element_GenerateName_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
{
	return % lang("Get_Index_Of_Element_In_List")
	
}


Element_CheckSettings_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
{
	
}

Element_run_Action_Get_Index_Of_Element_In_List(Environment, ElementParameters)
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
	
	
	if (ElementParameters.Expression = 2)
	{
		evRes := x_EvaluateExpression(Environment, ElementParameters.SearchContent)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.SearchContent) "`n`n" evRes.error) 
			return
		}
		else
		{
			SearchContent:=evRes.result
		}
	}
	else
		SearchContent := x_replaceVariables(Environment, ElementParameters.SearchContent)

	;Search for the object
	for tempkey, tempvalue in myList
	{
		if (tempvalue=SearchContent)
		{
			found:=true
			result:=tempkey
			break
		}
	}
	
	if (found!=true)
	{
		x_finish(Environment, "exception", lang("The list '%1%' does not contain the key '%2%'.",ListName,Position))
		return
	}	
	
	x_SetVariable(Environment,Varname,Result)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}