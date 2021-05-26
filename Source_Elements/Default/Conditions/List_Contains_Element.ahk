﻿;Always add this element class name to the global list
x_RegisterElementClass("Condition_List_Contains_Element")

;Element type of the element
Element_getElementType_Condition_List_Contains_Element()
{
	return "Condition"
}

;Name of the element
Element_getName_Condition_List_Contains_Element()
{
	return x_lang("List_Contains_Element")
}

;Category of the element
Element_getCategory_Condition_List_Contains_Element()
{
	return x_lang("User_interaction")
}

;This function returns the package of the element.
;This is a reserved function for future releases,
;where it will be possible to install additional add-ons which provide more elements.
Element_getPackage_Condition_List_Contains_Element()
{
	return "default"
}

;Minimum user experience to use this element.
;Elements which are complicated or rarely used by beginners should not be visible to them.
;This will help them to get started with AHF
Element_getElementLevel_Condition_List_Contains_Element()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

;Icon path which will be shown in the background of the element
Element_getIconPath_Condition_List_Contains_Element()
{
}

;How stable is this element? Experimental elements will be marked and can be hidden by user.
Element_getStabilityLevel_Condition_List_Contains_Element()
{
	;"Stable" or "Experimental"
	return "Stable"
}

;Returns an array of objects which describe all controls which will be shown in the element settings GUI
Element_getParametrizationDetails_Condition_List_Contains_Element(Environment)
{
	parametersToEdit:=Object()
	
	parametersToEdit.push({type: "Label", label: x_lang("List name")})
	parametersToEdit.push({type: "Edit", id: "InputList", default: "List", content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Search for what")})
	parametersToEdit.push({type: "Radio", id: "SearchWhat", default: 2, choices: [x_lang("Search for an index or key"), x_lang("Search for an element with a specific content")], result: "enum", enum: ["Key", "Content"]})
	parametersToEdit.push({type: "Label", label: x_lang("Key or index")})
	parametersToEdit.push({type: "Edit", id: "Position", default: 1, content: ["String", "Expression"], contentID: "isExpressionPosition", contentDefault: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: x_lang("Seeked content")})
	parametersToEdit.push({type: "Edit", id: "SearchContent", default: "", content: ["String", "Expression"], contentID: "isExpressionSearchContent", contentDefault: "String", WarnIfEmpty: true})
	
	return parametersToEdit
}

;Returns the detailed name of the element. The name can vary depending on the parameters.
Element_GenerateName_Condition_List_Contains_Element(Environment, ElementParameters)
{
	return x_lang("List_Contains_Element") 
}

;Called every time the user changes any parameter.
;This function allows to check the integrity of the parameters. For example you can:
;- Disable options which are not available because of other options
;- Correct misconfiguration
Element_CheckSettings_Condition_List_Contains_Element(Environment, ElementParameters, staticValues)
{	
	if (ElementParameters.SearchWhat = "Key") ;Search for an index or key
	{
		x_Par_Enable("Position")
		x_Par_Disable("isExpressionSearchContent")
		x_Par_Disable("SearchContent")
	}
	else
	{
		x_Par_Disable("Position")
		x_Par_Enable("isExpressionSearchContent")
		x_Par_Enable("SearchContent")
	}
	
}


;Called when the element should execute.
;This is the most important function where you can code what the element acutally should do.
Element_run_Condition_List_Contains_Element(Environment, ElementParameters)
{
	EvaluatedParameters:=x_AutoEvaluateParameters(Environment, ElementParameters, ["Position", "SearchContent"])
	if (EvaluatedParameters._error)
	{
		x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
		return
	}

	
	found:=false
	InputList:=EvaluatedParameters.InputList
	SearchPosition:=EvaluatedParameters.Position
	if not IsObject(InputList)
	{
		x_finish(Environment, "exception", x_lang("Variable '%1%' does not contain a list.",ElementParameters.InputList)) 
		return
	}
	
	if (EvaluatedParameters.SearchWhat="Key") ;search for an index or key
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["Position"])
		if (ElementParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		for tempkey, tempvalue in InputList
		{
			if (tempkey=SearchPosition)
			{
				found:=true
				break
			}
		}
		if (found=true)
		{
			x_finish(Environment,"yes")
		}
		else
		{
			x_finish(Environment,"no")
		}
		
	}
	else  ;search for a value
	{
		x_AutoEvaluateAdditionalParameters(EvaluatedParameters, Environment, ElementParameters, ["SearchContent"])
		if (ElementParameters._error)
		{
			x_finish(Environment, "exception", EvaluatedParameters._errorMessage) 
			return
		}
		for tempkey, tempvalue in tempObject
		{
			
			if (tempvalue=SearchContent)
			{
				found:=true
				foundkey:=tempkey
				break
			}
		}
		if (found=true)
		{
			x_setVariable(Environment,"A_FoundKey",foundkey, "thread")
			x_finish(Environment,"yes")
		}
		else
		{
			x_finish(Environment,"no")
		}
		
	}
	
	
	return
	


	
}


;Called when the execution of the element should be stopped.
;If the task in Element_run_...() takes more than several seconds, then it is up to you to make it stoppable.
Element_stop_Condition_List_Contains_Element(Environment, ElementParameters)
{
}






