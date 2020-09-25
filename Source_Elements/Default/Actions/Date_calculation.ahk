;Always add this element class name to the global list
x_RegisterElementClass("Action_Date_Calculation")

;Element type of the element
Element_getElementType_Action_Date_Calculation()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Date_Calculation()
{
	return lang("Date_Calculation")
}

;Category of the element
Element_getCategory_Action_Date_Calculation()
{
	return lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Date_Calculation()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Date_Calculation()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Date_Calculation()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Date_Calculation()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Date_Calculation(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "CalculatedTime", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input variable name")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "InputTime", content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Operation")})
	parametersToEdit.push({type: "Radio", id: "Operation", default: 1, result: "enum", choices: [lang("Add a period"), lang("Calculate time difference")], enum: ["AddPeriod", "TimeDifference"]})
	parametersToEdit.push({type: "Label", label:  lang("How many units to add")})
	parametersToEdit.push({type: "Edit", id: "Units", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Second input variable Name")})
	parametersToEdit.push({type: "Edit", id: "VarValue2", default: "a_now", content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label:  lang("Which unit")})
	parametersToEdit.push({type: "Radio", id: "Unit", default: 2, result: "enum", choices: [lang("Milliseconds"), lang("Seconds"), lang("Minutes"), lang("Hours"), lang("Days")], enum: ["Milliseconds", "Seconds", "Minutes", "Hours", "Days"]})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Date_Calculation(Environment, ElementParameters)
{
	return lang("Date_Calculation") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Date_Calculation(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Date_Calculation(Environment, ElementParameters)
{
	Varname := x_replaceVariables(Environment, ElementParameters.Varname)
	if not x_CheckVariableName(Varname)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("%1% is not valid", lang("Ouput variable name '%1%'", Varname)))
		return
	}
	
	evRes := x_evaluateExpression(Environment,ElementParameters.VarValue)
	if (evRes.error)
	{
		;On error, finish with exception and return
		x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.VarValue) "`n`n" evRes.error) 
		return
	}
	VarValue:=evRes.result
	if VarValue is not time
	{
		x_finish(Environment, "exception", lang("Input time is not a time: '%1%'.",VarValue)) 
		return
	}
		
	Operation := ElementParameters.Operation
	Unit := ElementParameters.Unit
	
	if (Operation = "AddPeriod")
	{
		evRes := x_evaluateExpression(Environment,ElementParameters.Units)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.Units) "`n`n" evRes.error) 
			return
		}
		Units:=evRes.result
		
		if (Unit = "Milliseconds")
		{
			Unit = "Seconds"
			Units:=round(Units/1000.0) ;Trim off milliseconds
		}
		
		envadd,VarValue,%Units%,%Unit%
		x_SetVariable(Environment,Varname,VarValue)
	}
	else if (Operation = "TimeDifference")
	{
		evRes := x_evaluateExpression(Environment,ElementParameters.VarValue2)
		if (evRes.error)
		{
			;On error, finish with exception and return
			x_finish(Environment, "exception", lang("An error occured while parsing expression '%1%'", ElementParameters.VarValue2) "`n`n" evRes.error) 
			return
		}
		VarValue2:=evRes.result
		
		if VarValue2 is not time
		{
			x_finish(Environment, "exception", lang("Input time is not a time: '%1%'.",VarValue2)) 
			return
		}
		
		if (Unit = "Milliseconds")
		{
			UnitCalc = "Seconds"
		}
		else
		{
			UnitCalc:=Unit
		}
		
		envsub,VarValue,%VarValue2%,%UnitCalc%
		
		if (Unit = "Milliseconds")
		{
			VarValue:=VarValue*1000
		}
		x_SetVariable(Environment,Varname,VarValue)
	}
	else
	{
		x_finish(Environment, "exception", lang("Operation not specified"))
		return
	}
	

	x_finish(Environment,"normal")
	return
	

	
}

;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Date_Calculation(Environment, ElementParameters)
{
	
}






