iniAllActions.="Delete_from_list|" ;Add this action to list of all actions on initialisation

runActionDelete_from_list(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global

	local Varname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local Position:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Position)
	local temp
	;MsgBox,%  %ElementID%Varname "---" %ElementID%VarValue "---" v_replaceVariables(InstanceID,%ElementID%Varname) "---" v_replaceVariables(InstanceID,%ElementID%VarValue)
	

	if not v_CheckVariableName(varname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! List name '" varname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("List name '%1%'",varname)) )
		return
	}
	
	
	local tempObject:=v_getVariable(InstanceID,ThreadID,Varname,"list")
	
	if not IsObject(tempObject)
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" Varname "' does not contain a list.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",Varname))
		return
		
	}

	if %ElementID%WhitchPosition=1 ; Stupid misspelling :-(
	{
		temp:=tempObject.MinIndex()
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" varname "' does not contain an integer key.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain an integer key.",varname))
			return
		}
		
		tempObject.Remove(temp)
	}
	else if %ElementID%WhitchPosition=2
	{
		temp:=tempObject.MaxIndex()
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" varname "' does not contain an integer key.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain an integer key.",varname))
			return
		}
		tempObject.Remove(temp)
	}
	else if %ElementID%WhitchPosition=3
	{
		if Position=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Position is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not secified.",lang("Position")))
			return
		}
		if not tempObject.HasKey(Position)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! The list '" varname "' does not contain the key '" Position "'.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("The list '%1%' does not contain the key '%2%'.",varname,Position))
			return
		}
		tempObject.Remove(Position)
	}
	
	v_SetVariable(InstanceID,ThreadID,Varname,tempObject,"list")
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	

	
	

	return
}
getNameActionDelete_from_list()
{
	return lang("Delete_from_list")
}
getCategoryActionDelete_from_list()
{
	return lang("Variable")
}

getParametersActionDelete_from_list()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Which element")})
	parametersToEdit.push({type: "Radio", id: "WhitchPosition", default: 2, choices: [lang("First element"), lang("Last element"), lang("Following element or key")]})
	parametersToEdit.push({type: "Edit", id: "Position", default: 2, content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

GenerateNameActionDelete_from_list(ID)
{
	global
	if GUISettingsOfElement%ID%WhitchPosition1=1
		return % lang("Delete first element from list %1%", GUISettingsOfElement%ID%Varname )
	if GUISettingsOfElement%ID%WhitchPosition2=1
		return % lang("Delete last element from list %1%", GUISettingsOfElement%ID%Varname )
	if GUISettingsOfElement%ID%WhitchPosition3=1
		return % lang("Delete element %1% from list %2%", GUISettingsOfElement%ID%Position, GUISettingsOfElement%ID%Varname )
	
	
	
}

CheckSettingsActionDelete_from_list(ID)
{
	if (GUISettingsOfElement%ID%WhitchPosition3 = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Position
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%Position
	}
}