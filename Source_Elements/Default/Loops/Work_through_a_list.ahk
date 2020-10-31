;Always add this element class name to the global list
x_RegisterElementClass("Loop_Work_through_a_list")

;Element type of the element
Element_getElementType_Loop_Work_through_a_list()
{
	return "loop"
}

;Name of the element
Element_getName_Loop_Work_through_a_list()
{
	return x_lang("Work_through_a_list")
}

;Category of the element
Element_getCategory_Loop_Work_through_a_list()
{
	return x_lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Loop_Work_through_a_list()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Loop_Work_through_a_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Loop_Work_through_a_list()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Loop_Work_through_a_list()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Loop_Work_through_a_list(Environment)
{
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: x_lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Performance")})
	parametersToEdit.push({type: "Checkbox", id: "CopyFirst", default: 1, label: x_lang("Copy list before first iteration")})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Loop_Work_through_a_list(Environment, ElementParameters)
{
	global
	return x_lang("Work_through_a_list") ": " ElementParameters.Varname 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Loop_Work_through_a_list(Environment, ElementParameters)
{	
	
}

;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
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
			x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.",varname))
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
		x_finish(Environment, "exception", x_lang("No information whether the connection lead into head or tail"))
	}


}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Loop_Work_through_a_list(Environment, ElementParameters)
{
}