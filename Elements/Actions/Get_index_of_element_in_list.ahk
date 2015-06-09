iniAllActions.="Get_index_of_element_in_list|" ;Add this action to list of all actions on initialisation

runActionGet_index_of_element_in_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local ListName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ListName)
	local SearchContent
	local tempObject:=v_getVariable(InstanceID,ThreadID,ListName,"list")
	local result
	
	if %ElementID%isExpressionSearchContent=1
		SearchContent:=v_replaceVariables(InstanceID,ThreadID,%ElementID%SearchContent)
	else
		SearchContent:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%SearchContent)
	
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	
	if IsObject(tempObject)
	{
		for tempkey, tempvalue in tempObject
		{
			
			if (tempvalue=SearchContent)
			{
				found:=true
				result:=tempkey
				break
			}
		}
		if (found=true)
		{
			v_SetVariable(InstanceID,ThreadID,Varname,result)
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
		else
		{
			v_SetVariable(InstanceID,ThreadID,Varname,result)
			if %ElementID%ExceptionWhenNotFound=1
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
			else
				MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		}
		
		
	}
	else
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception")
	

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
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|NewVariable|Varname","Label|" lang("Variable_name"),"VariableName|List|ListName","Label|" lang("Content"),"Radio|1|isExpressionSearchContent|" lang("This is a value") ";" lang("This is a variable name or expression"),"Text|Any element|SearchContent","Label|" lang("Options"),"Checkbox|0|ExceptionWhenNotFound|" lang("Throw exeption if no element was found")]
	
	return parametersToEdit
}

GenerateNameActionGet_index_of_element_in_list(ID)
{
	global
	
	return % lang("Get_index_of_element_in_list") "`n" GUISettingsOfElement%ID%Varname 
}

