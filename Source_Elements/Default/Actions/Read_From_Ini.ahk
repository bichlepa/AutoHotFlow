;Always add this element class name to the global list
x_RegisterElementClass("Action_Read_From_Ini")

;Element type of the element
Element_getElementType_Action_Read_From_Ini()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Read_From_Ini()
{
	return x_lang("Read_From_Ini")
}

;Category of the element
Element_getCategory_Action_Read_From_Ini()
{
	return x_lang("File")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Read_From_Ini()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Read_From_Ini()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Read_From_Ini()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Read_From_Ini()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Read_From_Ini(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output Variable name")})
	parametersToEdit.push({type: "Edit", id: "varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Path of .ini file")})
	parametersToEdit.push({type: "File", id: "file", label: x_lang("Select an .ini file")})
	parametersToEdit.push({type: "Label", label: x_lang("Action")})
	parametersToEdit.push({type: "Radio", id: "Action", default: 1, choices: [x_lang("Read a key"), x_lang("Read the entire section"), x_lang("Read the section names")], result: "enum", enum: ["Key", "EntireSection", "SectionNames"]})
	parametersToEdit.push({type: "Label", label: x_lang("Section")})
	parametersToEdit.push({type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Key")})
	parametersToEdit.push({type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Behavior on error")})
	parametersToEdit.push({type: "Radio", id: "WhenError", default: 1, choices: [x_lang("Insert default value in the variable"), x_lang("Throw exception")], result: "enum", enum: ["Default", "Exception"]})
	parametersToEdit.push({type: "Label", label: x_lang("Default value on failure")})
	parametersToEdit.push({type: "Edit", id: "Default", default: "ERROR", content: "String"})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Read_From_Ini(Environment, ElementParameters)
{
	return x_lang("Read_From_Ini") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Read_From_Ini(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.Action = "Key") ;Read key
	{
		x_Par_Enable("Section")
		x_Par_Enable("Key")
		x_Par_Enable("WhenError")
		x_Par_Enable("Default", ElementParameters.WhenError = "default")
	}
	else if (ElementParameters.Action = "EntireSection") ;Read section
	{
		x_Par_Enable("Section")
		x_Par_Disable("Key")
		x_Par_Disable("WhenError")
		x_Par_Disable("Default")
	}
	else ;Read section names
	{
		x_Par_Disable("Section")
		x_Par_Disable("Key")
		x_Par_Disable("WhenError")
		x_Par_Disable("Default")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Read_From_Ini(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["section", "key", "Default"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	filepath := x_GetFullPath(Environment, EvaluatedParameters.file)
	if not fileexist(filepath)
	{
		x_finish(Environment, "exception",  x_lang("File '%1%' does not exist",filepath))
		return
	}
	
	
	
	if (EvaluatedParameters.Action="key") ;Read a key
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["section", "key"])
		
		if (EvaluatedParameters.section="")
		{
			x_finish(Environment, "exception",x_lang("%1% is not specified.",x_lang("Section name")))
			return
		}
		if (EvaluatedParameters.key="")
		{
			x_finish(Environment, "exception",x_lang("%1% is not specified.",x_lang("Key name")))
			return
			
		}
		
		if (EvaluatedParameters.WhenError="Default")
		{
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["default"])
			
			if (EvaluatedParameters.Default = "")
				EvaluatedParameters.Default := " "
			IniRead,result,% filepath,% EvaluatedParameters.section,% EvaluatedParameters.key,% EvaluatedParameters.Default
		}
		else
		{
			IniRead,result,% filepath,% EvaluatedParameters.section,% EvaluatedParameters.key,E?R ROR
			if result=E?R ROR
			{
				x_finish(Environment, "exception",x_lang("Section '%1%' and key '%2%' not found.",EvaluatedParameters.section,EvaluatedParameters.key))
				return
			}
		}
		
	}
	else if (EvaluatedParameters.Action="entireSection") ;Read entire section
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["section"])
		if (EvaluatedParameters.section="")
		{
			x_finish(Environment, "exception",x_lang("%1% is not specified.",x_lang("Section name")))
			return
		}
		
		IniRead,result,% filepath,% EvaluatedParameters.section
		
	}
	else ;Get section list
	{
		IniRead,resultstr,% filepath
		x_SetVariable(Environment,EvaluatedParameters.varname,result)
		
		result:=Object()
		loop, parse, resultstr, `n
		{
			result.push(A_LoopField)
		}
	}
	
	x_SetVariable(Environment,EvaluatedParameters.varname,result)
	x_finish(Environment,"normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Read_From_Ini(Environment, ElementParameters)
{
}






