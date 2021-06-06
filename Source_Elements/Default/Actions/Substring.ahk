;Always add this element class name to the global list
x_RegisterElementClass("Action_Substring")

;Element type of the element
Element_getElementType_Action_Substring()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Substring()
{
	return x_lang("Substring")
}

;Category of the element
Element_getCategory_Action_Substring()
{
	return x_lang("Text")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Substring()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Substring()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Substring()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Substring()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Substring(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("Output variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  x_lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Start position")})
	parametersToEdit.push({type: "Radio", id: "WhereToBegin", default: "FromLeft", choices: [x_lang("Begin from left"), x_lang("Begin from right"), x_lang("Start from following position")], result: "enum", enum: ["FromLeft", "FromRight", "Position"]})
	parametersToEdit.push({type: "Edit", id: "StartPos", default: 1, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Count of characters")})
	parametersToEdit.push({type: "CheckBox", id: "UntilTheEnd", default: 0, label: x_lang("Until the end")})
	parametersToEdit.push({type: "Edit", id: "Length", default: 5, content: "Number", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "LeftOrRight", default: "GoLeft", choices: [x_lang("Go left"), x_lang("Go right")], result: "enum", enum: ["GoLeft", "GoRight"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Substring(Environment, ElementParameters)
{
	return x_lang("Substring") " - " ElementParameters.Varname " - " ElementParameters.VarValue 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Substring(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.WhereToBegin = "Position")
	{
		x_Par_Enable("StartPos")
		x_Par_Enable("LeftOrRight")
		x_Par_Enable("UntilTheEnd")
		
		x_Par_Disable("Length", ElementParameters.UntilTheEnd)
	}
	else
	{
		x_Par_Disable("StartPos")
		x_Par_Disable("LeftOrRight")
		x_Par_Disable("UntilTheEnd")
		x_Par_SetValue("UntilTheEnd", 0)
	}
	if (ElementParameters.WhereToBegin = "FromRight")
	{
		x_Par_SetValue("LeftOrRight", "GoLeft")
	}
	else if (ElementParameters.WhereToBegin = "FromLeft")
	{
		x_Par_SetValue("LeftOrRight", "GoRight")
	}
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Substring(Environment, ElementParameters)
{
	; evaluate parameters
	EvaluatedParameters := x_AutoEvaluateParameters(Environment, ElementParameters, ["StartPos", "Length"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}
	
	; Decide what to do
	if (EvaluatedParameters.WhereToBegin = "FromLeft")
	{
		; Begin from left

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Length"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}

		; get substring
		StringLeft, Result, % EvaluatedParameters.VarValue, % EvaluatedParameters.Length
	}
	else if (EvaluatedParameters.WhereToBegin = "FromRight")
	{
		; Begin from right

		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Length"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		; get substring
		StringRight, Result, % EvaluatedParameters.VarValue, % EvaluatedParameters.Length
	}
	else if (EvaluatedParameters.WhereToBegin = "Position")
	{
		; Begin from specified position
		
		; evaluate additional parameters
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["StartPos"])
		if (EvaluatedParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		
		
		if (EvaluatedParameters.LeftOrRight = "GoLeft")
		{
			; we need to go left. Set this option
			OptionToLeft := "L"
		}
		
		if (not EvaluatedParameters.UntilTheEnd)
		{
			; we don't go until the end
			
			; evaluate additional parameters
			x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Length"])
			if (EvaluatedParameters._error)
			{
				x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
				return
			}
			
			; get substring
			Stringmid, Result, % EvaluatedParameters.VarValue, % EvaluatedParameters.StartPos, % EvaluatedParameters.Length, %OptionToLeft%
		}
		else
		{
			; we go until the end

			; get substring
			Stringmid, Result, % EvaluatedParameters.VarValue, % EvaluatedParameters.StartPos,, %OptionToLeft%
		}
	}
	
	; set output variable
	x_SetVariable(Environment, EvaluatedParameters.Varname, result) 

	x_finish(Environment, "normal")
	return
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Substring(Environment, ElementParameters)
{
}






