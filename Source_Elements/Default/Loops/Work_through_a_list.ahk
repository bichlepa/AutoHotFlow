;Always add this element class name to the global list
x_RegisterElementClass("Loop_Work_through_a_list")

Element_getPackage_Loop_Work_through_a_list()
{
	return "default"
}

Element_getElementType_Loop_Work_through_a_list()
{
	return "loop"
}

Element_getElementLevel_Loop_Work_through_a_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Loop_Work_through_a_list()
{
	return lang("Work_through_a_list")
}

Element_getCategory_Loop_Work_through_a_list()
{
	return lang("Variable")
}

Element_getParametrizationDetails_Loop_Work_through_a_list(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Performance")})
	parametersToEdit.push({type: "Checkbox", id: "CopyFirst", default: 1, label: lang("Copy list before first iteration")})

	return parametersToEdit
}

Element_GenerateName_Loop_Work_through_a_list(Environment, ElementParameters)
{
	global
	return lang("Work_through_a_list") ": " ElementParameters.Varname 
}

Element_run_Loop_Work_through_a_list(Environment, ElementParameters)
{
	entryPoint := x_getEntryPoint(environment)
	valueFound:=False
	
	
	if (entryPoint = "Head") ;Initialize loop
	{
		varname := x_replaceVariables(Environment, ElementParameters.varname)
		varContentList := x_GetVariable(Environment, Varname)
		
		if not isobject(varContentList)
		{
			x_finish(Environment, "exception", lang("Variable '%1%' does not contain a list.",varname))
			return
		}
		
		index:=1
		x_SetVariable(Environment, "A_Index", index, "loop")
		
		x_SetVariable(Environment, "A_LoopUseCopiedList", ElementParameters.CopyFirst, "loop", true)
		if (ElementParameters.CopyFirst)
		{
			x_SetVariable(Environment, "A_LoopCurrentList", varContentList, "loop", true)
		}
		else
		{
			x_SetVariable(Environment, "A_LoopUseVarName", varname, "loop", true)
		}
		
		;Set first element
		for tempkey, tempvalue in varContentList
		{
			valueFound := True
			x_SetVariable(Environment, "a_LoopValue", tempvalue, "loop")
			x_SetVariable(Environment, "a_LoopKey", tempkey, "loop")
			break
		}
		
		if (valueFound)
			x_finish(Environment, "head")
		else
			x_finish(Environment, "tail")
	}
	else if (entryPoint = "Tail") ;Continue loop
	{
		index := x_GetVariable(Environment, "A_Index")
		copiedFirst := x_GetVariable(Environment, "A_LoopUseCopiedList", true)
		index++
		if (copiedFirst)
		{
			varContentList := x_GetVariable(Environment, "A_LoopCurrentList", true)
		}
		else
		{
			varName := x_GetVariable(Environment, "A_LoopUseVarName", true)
			varContentList := x_GetVariable(Environment, varName)
		}
		
		for tempkey, tempvalue in varContentList
		{
			if (a_index = index)
			{
				
				valueFound := True
				x_SetVariable(Environment, "a_LoopValue", tempvalue, "loop")
				x_SetVariable(Environment, "a_LoopKey", tempkey, "loop")
				x_SetVariable(Environment, "A_Index", index, "loop")
				break
			}
		}
		
		
		if (valueFound)
			x_finish(Environment, "head")
		else
			x_finish(Environment, "tail")
	}
	else if (entryPoint = "Break") ;Break loop
	{
		x_finish(Environment, "tail")
		
	}
	else
	{
		x_finish(Environment, "exception", lang("No information whether the connection lead into head or tail"))
	}


}
