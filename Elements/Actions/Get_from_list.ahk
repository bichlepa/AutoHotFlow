iniAllActions.="Get_from_list|" ;Add this action to list of all actions on initialisation

runActionGet_from_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temp
	local Result
	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local ListName:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ListName)
	local Position:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Position)
	local tempObject:=v_getVariable(InstanceID,ThreadID,ListName,"list")
	
	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varname)) )
		return
	}
	if not v_CheckVariableName(ListName)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! List name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("List name '%1%'",varname)) )
		return
	}
	
	if not IsObject(tempObject)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' does not contain a list.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",Varname))
		return
	}
	
	if %ElementID%WhitchPosition=1 ;first item ; Stupid misspelling
	{
		temp:=tempObject.MinIndex()
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" ListName "' does not contain an integer key.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		Result:=tempObject[tempObject.MinIndex()]
	}
	else if %ElementID%WhitchPosition=2 ;Last item
	{
		temp:=tempObject.MaxIndex()
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" ListName "' does not contain an integer key.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		Result:=tempObject[tempObject.MaxIndex()]
		
	}
	else if %ElementID%WhitchPosition=3 ;Random item
	{
		temp:=tempObject.MaxIndex()
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" ListName "' does not contain an integer key.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain an integer key.",ListName))
			return
		}
		
		random,temp,tempObject.MinIndex(),tempObject.MaxIndex()
		Result:=tempObject[temp]
		
	}
	else if %ElementID%WhitchPosition=4 ;Specified item
	{
		if Position=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Position is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Position")))
			return
		}
		
		if not tempObject.HasKey(Position)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" ListName "' does not contain the key '" Position "'.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain the key '%2%'.",ListName,Position))
			return
		}
		
		Result:=tempObject[Position]
		
		
	}
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	v_SetVariable(InstanceID,ThreadID,Varname,Result)
	
	

	return
}
getNameActionGet_from_list()
{
	return lang("Get_from_list")
}
getCategoryActionGet_from_list()
{
	return lang("Variable")
}

getParametersActionGet_from_list()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Input list")})
	parametersToEdit.push({type: "Edit", id: "ListName", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Key or position")})
	parametersToEdit.push({type: "Radio", id: "WhitchPosition", default: 1, choices: [lang("First position"), lang("Last position"), lang("Random position"), lang("Following position or key")]})
	parametersToEdit.push({type: "Edit", id: "Position", default: 2, content: "Expression", WarnIfEmpty: true})

	
	return parametersToEdit
}

GenerateNameActionGet_from_list(ID)
{
	global
	
	return % lang("Get_from_list") "`n" GUISettingsOfElement%ID%Varname 
	
}

CheckSettingsActionGet_from_list(ID)
{
	if (GUISettingsOfElement%ID%WhitchPosition4 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Position
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
}