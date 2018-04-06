;Always add this element class name to the global list
x_RegisterElementClass("Action_Get_Volume")

;Element type of the element
Element_getElementType_Action_Get_Volume()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Get_Volume()
{
	return lang("Get_Volume")
}

;Category of the element
Element_getCategory_Action_Get_Volume()
{
	return lang("Sound")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Get_Volume()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Get_Volume()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Get_Volume()
{
}

;Returns a list of all parameters of the element.
;Only those parameters will be saved.
Element_getParameters_Action_Get_Volume()
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({id: "Varname"})
	
	return parametersToEdit
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Get_Volume(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output_Variable_name")})
	parametersToEdit.push({type: "edit", id: "Varname", default: "Volume", content: "VariableName", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Get_Volume(Environment, ElementParameters)
{
	return lang("Get_Volume") "`n" ElementParameters.Varname " = |" ElementParameters.VarValue "|"
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Get_Volume(Environment, ElementParameters)
{
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Get_Volume(Environment, ElementParameters)
{
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", varname)))
		return
	}

	SoundGet,Result

	x_SetVariable(Environment,Varname,Result)
	
	x_finish(Environment,"normal")
	
	return
	
}

;Called when the execution of the element should be stopped.
;If the taks takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Get_Volume(Environment, ElementParameters)
{
	
}


