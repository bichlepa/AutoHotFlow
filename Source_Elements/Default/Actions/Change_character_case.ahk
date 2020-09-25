;Always add this element class name to the global list
x_RegisterElementClass("Action_Change_character_case")

;Element type of the element
Element_getElementType_Action_Change_character_case()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Change_character_case()
{
	return lang("Change_character_case")
}

;Category of the element
Element_getCategory_Action_Change_character_case()
{
	return lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Change_character_case()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Change_character_case()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Change_character_case()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Change_character_case()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Change_character_case(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Input string")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Which case (character case)")})
	parametersToEdit.push({type: "Radio", id: "CharCase", default: 1, choices: [lang("Uppercase"), lang("Lowercase"), lang("Firt character of a word is uppercase")], enum: ["upper", "lower", "firstUp"]})

	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Change_character_case(Environment, ElementParameters)
{
	return lang("Change_character_case") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Change_character_case(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Change_character_case(Environment, ElementParameters)
{
	radioValue := ElementParameters.radio
	
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", par_editVariableName)))
		return
	}
	
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
			VarValue:=evRes.result
		}
	}
	else
		VarValue := x_replaceVariables(Environment, ElementParameters.VarValue)
	
	CharCase := ElementParameters.CharCase
	
	if CharCase=upper ;Uppercase
		StringUpper,VarValue,VarValue
	else if CharCase=lower ;Lowercase
		StringLower,VarValue,VarValue
	else if CharCase=firstUp
		StringUpper,VarValue,VarValue,T ;First character of a word is uppercase
	x_SetVariable(Environment,Varname,VarValue)
	
	x_finish(Environment,"normal")
	return
	

	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Change_character_case(Environment, ElementParameters)
{
	
}





