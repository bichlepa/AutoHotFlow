;Always add this element class name to the global list
AllElementClasses.push("Action_Shuffle_list")

;Element type of the element
Element_getElementType_Action_Shuffle_list()
{
	return "Action"
}

;Name of the element
Element_getName_Action_Shuffle_list()
{
	return lang("Shuffle_list")
}

;Category of the element
Element_getCategory_Action_Shuffle_list()
{
	return lang("Variable")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Action_Shuffle_list()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Action_Shuffle_list()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Action_Shuffle_list()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Action_Shuffle_list()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Action_Shuffle_list(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list name")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "List", content: "Expression", WarnIfEmpty: true})
	
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Action_Shuffle_list(Environment, ElementParameters)
{
	return lang("Shuffle_list") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Action_Shuffle_list(Environment, ElementParameters)
{	
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Action_Shuffle_list(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters)
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}


	tempList:=EvaluatedParameters.VarValue
	if not IsObject(tempList)
	{
		x_finish(Environment, "exception", lang("Variable '%1%' does not contain a list.",ElementParameters.VarValue)) 
		return
	}
	
	
	maxindex:=tempList.MaxIndex()
	
	tempObject:=Object()
	countOfElements:=0
	;Copy all numeric elements to a separate list
	for tempkey, tempvalue in tempList
	{
		if tempkey is number
		{
			tempObject.insert(tempvalue)
			countOfElements++
		}
	}
	;Delete all numeric elements
	Loop
	{
		tempkey:=tempList.MaxIndex()
		if tempkey!=
		{
			tempList.remove(tempkey)
		}
		else
			break
	}
	;Add all previous copied list to the list in random order
	loop %countOfElements%
	{
		random,randomnumber,1,% countOfElements + 1 - A_Index
		tempvalue:=tempObject.Remove(randomnumber)
		tempList.Insert(tempvalue)
		
	}
	x_SetVariable(Environment,Varname,tempList)
	

	x_finish(Environment,"normal")
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Action_Shuffle_list(Environment, ElementParameters)
{
}






