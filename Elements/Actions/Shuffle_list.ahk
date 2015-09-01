iniAllActions.="Shuffle_list|" ;Add this action to list of all actions on initialisation

runActionShuffle_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempList:=v_getVariable(InstanceID,ThreadID,Varname,"list")
	local tempObject:=Object()
	local tempkey
	local tempvalue
	local maxindex
	local minindex
	local randomnumber	
	local countOfElements=0

	
	
	if not IsObject(tempList)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' does not contain a list.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",Varname))
		return
	}
	
	
	maxindex:=tempList.MaxIndex()
	
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
	v_SetVariable(InstanceID,ThreadID,Varname,tempList,"list")
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
		
	
	
	

	return
}
getNameActionShuffle_list()
{
	return lang("Shuffle_list")
}
getCategoryActionShuffle_list()
{
	return lang("Variable")
}

getParametersActionShuffle_list()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output list name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list name")})
	parametersToEdit.push({type: "Edit", id: "VarValue", default: "List", content: "VariableName", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionShuffle_list(ID)
{
	global
	
	return % lang("Shuffle_list") "`n" GUISettingsOfElement%ID%Varname 
	
}

CheckSettingsActionShuffle_list(ID)
{
	
}