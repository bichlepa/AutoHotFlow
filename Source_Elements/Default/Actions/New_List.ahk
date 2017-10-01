;Always add this element class name to the global list
AllElementClasses.push("Action_New_List")

Element_getPackage_Action_New_List()
{
	return "default"
}

Element_getElementType_Action_New_List()
{
	return "action"
}

Element_getElementLevel_Action_New_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_New_List()
{
	return lang("New_List")
}

Element_getIconPath_Action_New_List()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_New_List()
{
	return lang("Variable")
}

Element_getParameters_Action_New_List()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	parametersToEdit.push({id: "InitialContent"})
	parametersToEdit.push({id: "VarValue"})
	parametersToEdit.push({id: "expression"})
	parametersToEdit.push({id: "VarValues"})
	parametersToEdit.push({id: "DelimiterLinefeed"})
	parametersToEdit.push({id: "DelimiterComma"})
	parametersToEdit.push({id: "DelimiterSemicolon"})
	parametersToEdit.push({id: "DelimiterSpace"})
	parametersToEdit.push({id: "WhichPosition"})
	parametersToEdit.push({id: "Position"})
	parametersToEdit.push({id: "expressionPos"})
	
	return parametersToEdit
}

Element_getParametrizationDetails_Action_New_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Number of elements")})
	parametersToEdit.push({type: "Radio", id: "InitialContent", default: 1, result: "enum", choices: [lang("Empty list"), lang("Initialize with one element"), lang("Initialize with multiple elements")], enum: ["Empty", "One", "Multiple"]})
	parametersToEdit.push({type: "Label", label:  lang("Initial content")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "VarValues", default: "Element one`nElement two", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: lang("Use linefeed as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterComma", default: 0, label: lang("Use comma as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: lang("Use semicolon as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: lang("Use space as delimiter")})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: 1, choices: [lang("Numerically as first element"), lang("Following key")]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	

	return parametersToEdit
}

Element_GenerateName_Action_New_List(Environment, ElementParameters)
{
	if ElementParameters.InitialContent=empty
	{
		Text.= lang("New empty list") " " ElementParameters.Varname
	}
	else if ElementParameters.InitialContent=one
	{
		Text.= lang("New list %1% with initial content",ElementParameters.Varname) ": "
		Text.=  ElementParameters.VarValue
		
	}
	else
	{
		Text.= lang("New list %1% with initial content",ElementParameters.Varname) ": "
		Text.=  ElementParameters.VarValues
		
	}
	
	return % Text
	
}


Element_CheckSettings_Action_New_List(Environment, ElementParameters)
{
	static oldParFlowName
	static oldParThisFlow
	
	if (ElementParameters.InitialContent = "one") ;one element
	{
		x_Par_Enable("VarValue")
		x_Par_Enable("WhichPosition")
		x_Par_Enable("Position", (ElementParameters.WhichPosition = 2))
	}
	else
	{
		x_Par_Disable("VarValue")
		x_Par_Disable("WhichPosition")
		x_Par_Disable("Position")
	}
	
	if (ElementParameters.InitialContent = "multiple") ;Multiple elements
	{
		x_Par_Enable("VarValues")
		x_Par_Enable("DelimiterLinefeed")
		x_Par_Enable("DelimiterComma")
		x_Par_Enable("DelimiterSemicolon")
		x_Par_Enable("DelimiterSpace")
	}
	else
	{
		x_Par_Disable("VarValues")
		x_Par_Disable("DelimiterLinefeed")
		x_Par_Disable("DelimiterComma")
		x_Par_Disable("DelimiterSemicolon")
		x_Par_Disable("DelimiterSpace")
	}
	
	
}

Element_run_Action_New_List(Environment, ElementParameters)
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
	
	
	newList:=Object()
	
	if (ElementParameters.InitialContent = "empty")
	{
		x_SetVariable(Environment,Varname,newList)
	}
	else if (ElementParameters.InitialContent = "one") ;one element
	{
		if (ElementParameters.Expression = "expression")
		{
			evRes := x_EvaluateExpression(Environment, ElementParameters.VarValue)
			if (evRes.error)
			{
				;On error, finish with exception and return
				x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.VarValue) "`n`n" evRes.error) 
				return
			}
			else
			{
				Value:=evRes.result
			}
		}
		else
			Value := x_replaceVariables(Environment, ElementParameters.VarValue)
		
		
		
		if ElementParameters.WhichPosition=1 
		{
			newList.push(Value)
		}
		else
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
			
			newList[Position] :=Value
		}
		
		x_SetVariable(Environment,Varname,newList)
	}
	else if (ElementParameters.InitialContent = "multiple") 
	{
		Value := x_replaceVariables(Environment, ElementParameters.varvalues)
		
		if ElementParameters.DelimiterLinefeed
			StringReplace,Value,Value,`n,▬,all
		if ElementParameters.DelimiterComma
			StringReplace,Value,Value,`,,▬,all
		if ElementParameters.DelimiterSemicolon
			StringReplace,Value,Value,;,▬,all
		if ElementParameters.DelimiterSpace
			StringReplace,Value,Value,%A_Space%,▬,all
		
		loop,parse,Value,▬
		{
			newList.push(A_LoopField)
		}
		x_SetVariable(Environment,Varname,newList)
	}
	
		;~ d(newlist)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}