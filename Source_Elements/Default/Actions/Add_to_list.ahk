;Always add this element class name to the global list
AllElementClasses.push("Action_Add_To_List")

Element_getPackage_Action_Add_To_List()
{
	return "default"
}

Element_getElementType_Action_Add_To_List()
{
	return "action"
}

Element_getElementLevel_Action_Add_To_List()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Action_Add_To_List()
{
	return lang("Add_To_List")
}

Element_getIconPath_Action_Add_To_List()
{
	return "Source_elements\default\icons\New variable.png"
}

Element_getCategory_Action_Add_To_List()
{
	return lang("Variable")
}

Element_getParameters_Action_Add_To_List()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	parametersToEdit.push({id: "NumberOfElements"})
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

Element_getParametrizationDetails_Action_Add_To_List(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "MyList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Number of elements")})
	parametersToEdit.push({type: "Radio", id: "NumberOfElements", default: 1, result: "enum", choices: [lang("Initialize with one element"), lang("Initialize with multiple elements")], enum: ["One", "Multiple"]})
	parametersToEdit.push({type: "Label", label:  lang("Content to add")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "New element", content: ["String", "Expression"], contentID: "Expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "multilineEdit", id: "VarValues", default: "Element one`nElement two", WarnIfEmpty: true})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterLinefeed", default: 1, label: lang("Use linefeed as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterComma", default: 0, label: lang("Use comma as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSemicolon", default: 0, label: lang("Use semicolon as delimiter")})
	parametersToEdit.push({type: "Checkbox", id: "DelimiterSpace", default: 0, label: lang("Use space as delimiter")})
	parametersToEdit.push({type: "Label", label: lang("Key")})
	parametersToEdit.push({type: "Radio", id: "WhichPosition", default: 1, result: "enum", choices: [lang("First position"), lang("Last position"), lang("Following position or key")], enum: ["First", "Last", "Specified"]})
	parametersToEdit.push({type: "Edit", id: "Position", default: "keyName", content: ["String", "Expression"], contentID: "expressionPos", contentDefault: "string", WarnIfEmpty: true})
	

	return parametersToEdit
}

Element_GenerateName_Action_Add_To_List(Environment, ElementParameters)
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


Element_CheckSettings_Action_Add_To_List(Environment, ElementParameters)
{
	
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

Element_run_Action_Add_To_List(Environment, ElementParameters)
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
	
	myList:=x_getVariable(Environment,Varname)
	
	if (!(IsObject(myList)))
	{
		if myList=
		{
			x_log(Environment, lang("Waring!") " " lang("Variable '%1%' is empty. A new list will be created.",Varname) ,1)
			myList:=Object()
		}
		else
		{
			x_finish(Environment, "exception", lang("Variable '%1%' is not empty and does not contain a list.",Varname))
			return
		}
	}
	
	if (ElementParameters.InitialContent = "one") ;one element
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
		
		
		
		if (ElementParameters.WhichPosition="First")
		{
			myList.insertat(1, Value)
		}
		else if (ElementParameters.WhichPosition="Last")
		{
			myList.push(Value)
		}
		else if (ElementParameters.WhichPosition="Specified")
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
			
			myList[Position] :=Value
		}
		
		x_SetVariable(Environment,Varname,myList)
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
		if (ElementParameters.WhichPosition="First")
		{
			loop,parse,Value,▬
			{
				myList.insertat(a_index, Value)
			}
		}
		else if (ElementParameters.WhichPosition="Last")
		{
			loop,parse,Value,▬
			{
				myList.push(Value)
			}
		}
		else if (ElementParameters.WhichPosition="Specified")
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
			
			if position is not Integer
			{
				x_finish(Environment, "exception", lang("Position is not a number: %1%", position)) 
			}
			
			loop,parse,Value,▬
			{
				myList.Insert(Position+A_Index-1, A_LoopField)
			}
		}
		x_SetVariable(Environment,Varname,myList)
	}
	
		;~ d(myList)
	
	;Always call v_finish() before return
	x_finish(Environment, "normal")
	return
}