iniAllActions.="Get_index_of_element_in_list|" ;Add this action to list of all actions on initialisation

runActionGet_index_of_element_in_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local ListName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ListName)
	local SearchContent
	local tempObject:=v_getVariable(InstanceID,ThreadID,ListName,"list")
	local result
	local found:=false
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	if not v_CheckVariableName(ListName)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! List name '" ListName "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("List name '%1%'",ListName)) )
		return
	}
	
	if %ElementID%isExpressionSearchContent=1
		SearchContent:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchContent)
	else
		SearchContent:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchContent)
	
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	
	if not IsObject(tempObject)
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' does not contain a list.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",Varname))
		return
		
	}
	
	for tempkey, tempvalue in tempObject
	{
		
		if (tempvalue=SearchContent)
		{
			found:=true
			result:=tempkey
			break
		}
	}
	if (found!=true)
	{
		v_SetVariable(InstanceID,ThreadID,Varname,result)
		if %ElementID%ExceptionWhenNotFound=1
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" ListName "' does not contain the key '" Position "'.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain the key '%2%'.",ListName,Position))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Warning! The list '" ListName "' does not contain the key '" Position "'.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
			return
		}
		
		
	
	}	
	v_SetVariable(InstanceID,ThreadID,Varname,result)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	
	

	return
}
getNameActionGet_index_of_element_in_list()
{
	return lang("Get_index_of_element_in_list")
}
getCategoryActionGet_index_of_element_in_list()
{
	return lang("Variable")
}

getParametersActionGet_index_of_element_in_list()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Seeked content")})
	parametersToEdit.push({type: "Radio", id: "isExpressionSearchContent", default: 1, choices: [lang("This is a value"), lang("This is a variable name or expression")]})
	parametersToEdit.push({type: "Edit", id: "SearchContent", default: "", content: "StringOrExpression", contentParID: "isExpressionSearchContent", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Options")})
	parametersToEdit.push({type: "Checkbox", id: "ExceptionWhenNotFound", default: 0, label: lang("Throw exeption if no element was found")})

	return parametersToEdit
}

GenerateNameActionGet_index_of_element_in_list(ID)
{
	global
	
	return % lang("Get_index_of_element_in_list") "`n" GUISettingsOfElement%ID%Varname 
}

