;Always add this element class name to the global list
x_RegisterElementClass("Condition_Debug_Dialog")

Element_getPackage_Condition_Debug_Dialog()
{
	return "default"
}

Element_getElementType_Condition_Debug_Dialog()
{
	return "condition"
}

Element_getElementLevel_Condition_Debug_Dialog()
{
	;"Beginner" or "Advanced" or "Programmer"
	return "Beginner"
}

Element_getName_Condition_Debug_Dialog()
{
	return lang("Debug_Dialog")
}

Element_getIconPath_Condition_Debug_Dialog()
{
	return "Source_elements\default\icons\bug.png"
}

Element_getCategory_Condition_Debug_Dialog()
{
	return lang("Debugging")
}

Element_getParametrizationDetails_Condition_Debug_Dialog(Environment)
{
	parametersToEdit:=Object()

	return parametersToEdit
}

Element_GenerateName_Condition_Debug_Dialog(Environment, ElementParameters)
{
	global
	return % lang("Debug_dialog")
	
}

Element_run_Condition_Debug_Dialog(Environment, ElementParameters)
{
	global
	
	local tempGUIID, tempVariableNames, tempTitle, tempallVars
	tempGUIID:=x_GetMyUniqueExecutionID(Environment)
	
	;Create GUI
	gui,%tempGUIID%:+LabelDebug_DialogGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	gui,%tempGUIID%:add,text,x10 , % lang("Local variables")
	
	gui,%tempGUIID%:add,listbox, x10 w200 h200 vCondition_Debug_DialogAllVars%tempGUIID% gCondition_Debug_DialogAllVars ,%tempVariableNames% 
	
	gosub,Condition_Debug_DialogButtonUpdateVariableList
	
	
	gui,%tempGUIID%:add,edit,X+10 w200 yp h200 vCondition_Debug_DialogEditField%tempGUIID% gCondition_Debug_DialogEditField
	gui,%tempGUIID%:add,button,x10 w150 h30 gCondition_Debug_DialogButtonUpdateVariableList,% lang("Update variable list")
	gui,%tempGUIID%:add,button,X+20 w150 h30 gCondition_Debug_DialogButtonDeleteVariable vCondition_Debug_DialogButtonDeleteVariable Disabled,% lang("Delete variable")
	gui,%tempGUIID%:add,button,X+20 w150 h30 vCondition_Debug_DialogButtonChangeValue gCondition_Debug_DialogButtonChangeValue Disabled,% lang("Change value")
	gui,%tempGUIID%:add,button,x10 w150 h30 gCondition_Debug_DialogButtonYes,% lang("Yes")
	gui,%tempGUIID%:add,button,X+10 yp w150 h30 gCondition_Debug_DialogButtonNo,% lang("No")
	gui,%tempGUIID%:show, ,% tempTitle
	
	;Add the label to the list of all GUI labels, so it can be found.
	
	
	return
	
	Condition_Debug_DialogButtonUpdateVariableList:
	
	if a_gui
	{
		tempGUIID:=a_gui
		environment := x_GetMyEnvironmentFromExecutionID(a_gui)
		tempVariableNames=|
	}
	else
		tempVariableNames=
	
	;~ ToolTip  %tempVariableNames%,,2
	
	for tempIndex, tempVarName in x_GetListOfLoopVars(environment)
	{
		if (substr(tempVarName,1,2)="a_")
		{
			if a_index=1
				tempVariableNames.= "--- " lang("Loop variables") " ---|"
			tempVariableNames.=tempVarName "|"
		}
	}
	
	for tempIndex, tempVarName in x_GetListOfThreadVars(environment)
	{
		if (substr(tempVarName,1,2)="a_")
		{
			if a_index=1
				tempVariableNames.= "--- " lang("Thread variables") " ---|"
			tempVariableNames.=tempVarName "|"
		}
	}
	
	for tempIndex, tempVarName in x_GetListOfInstanceVars(environment)
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Instance variables") " ---|"
		tempVariableNames.=tempVarName "|"
	}
	for tempIndex, tempVarName in x_GetListOfStaticVars(environment)
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Static variables") " ---|"
		tempVariableNames.=tempVarName "|"
	}
	for tempIndex, tempVarName in x_GetListOfGlobalVars(environment)
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Global variables") " ---|"
		tempVariableNames.=tempVarName "|"
	}
	
	x_SetExecutionValue(environment, "VariableNames",tempVariableNames)
	guicontrol,%tempGUIID%:,Condition_Debug_DialogAllVars%tempGUIID%,%tempVariableNames%
	return
	
	Condition_Debug_DialogEditField:
	GuiControl,%a_gui%:enable,Condition_Debug_DialogButtonChangeValue
	GuiControl,%a_gui%:+default,Condition_Debug_DialogButtonChangeValue
	return
	
	Condition_Debug_DialogAllVars:
	GuiControl,%a_gui%:Disable,Condition_Debug_DialogButtonChangeValue
	gui,%a_gui%:submit,nohide
	tempvarname:=Condition_Debug_DialogAllVars%a_gui%
	IfInString,tempvarname,---
	{
		GuiControl,%a_gui%:Disable,Condition_Debug_DialogButtonDeleteVariable
		GuiControl,%a_gui%:,Condition_Debug_DialogEditField%a_gui%,%A_Space%
		GuiControl,%a_gui%:disable,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
		return
	}
	GuiControl,%a_gui%:Enable,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
	GuiControl,%a_gui%:Enable,Condition_Debug_DialogButtonDeleteVariable
	
	environment:=x_GetMyEnvironmentFromExecutionID(a_gui)
	
	
	tempVarContent:=x_GetVariable(environment,tempvarname)
	tempVarType:=x_getVariableType(environment,tempvarname)
	if tempVarType=object
	{
		tempVarContent:=strobj(tempVarContent)
		guicontrol,%a_gui%:,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
		x_SetExecutionValue(environment, "SelectedVarType","object")
	}
	else if tempVarType=normal
	{
		guicontrol,%a_gui%:,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
		x_SetExecutionValue(environment, "SelectedVarType","normal")
	}
	;~ guicontrol,%a_gui%:,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
	return
	
	
	Condition_Debug_DialogButtonChangeValue:
	GuiControl,%a_gui%:Disable,Condition_Debug_DialogButtonChangeValue
	gui,%a_gui%:submit,nohide
	
	environment:=x_GetMyEnvironmentFromExecutionID(a_gui)
	
	tempvarname:=Condition_Debug_DialogAllVars%a_gui%
	tempVarType:=x_GetExecutionValue(environment, "SelectedVarType") 
	;~ d(tempVarType)
	tempLocation:=x_GetVariableLocation(environment,tempvarname)
	
	;~ tempInstance:=tempInstance["instanceID"]
	tempVarContent:=x_GetVariable(Environment, tempvarname)
	tempNewVarContent:=Condition_Debug_DialogEditField%a_gui%
	;~ MsgBox %tempVarType%
	if tempVarType=object
	{
		tempNewVarContent:=strobj(tempNewVarContent)
		x_SetVariable(Environment, tempvarname, tempNewVarContent, tempLocation)
	}
	else if tempVarType=normal
	{
		x_SetVariable(Environment, tempvarname, tempNewVarContent, tempLocation)
		
	}
	;~ ToolTip(lang("Variable is set"),1000)
	;~ MsgBox % tempVarContent
	return
	
	
	Condition_Debug_DialogButtonDeleteVariable:
	gui,%a_gui%:submit,nohide
	
	environment:=x_GetMyEnvironmentFromExecutionID(a_gui)
	tempVarType:=x_GetExecutionValue(environment, "SelectedVarType") 
	tempVariableNames:=x_GetExecutionValue(environment, "VariableNames") 
	tempvarname:=Condition_Debug_DialogAllVars%a_gui%
	
	;~ MsgBox %tempVariableNames%
	;~ tempInstance:=tempInstance["instanceID"]
	;~ MsgBox %tempVarType%
	x_DeleteVariable(environment,tempvarname)
	
	tempVariableNames:="|" tempVariableNames "|"
	;~ MsgBox %tempVariableNames% - %tempvarname%
	StringReplace,tempVariableNames,tempVariableNames,% "|" tempvarname "|",|
	StringTrimRight,tempVariableNames,tempVariableNames,1
	;~ MsgBox %tempVariableNames%
	guicontrol,%a_gui%:,Condition_Debug_DialogAllVars%a_gui%,%tempVariableNames%
	guicontrol,%a_gui%:,Condition_Debug_DialogEditField%a_gui%
	GuiControl,%a_gui%:Disable,Condition_Debug_DialogButtonDeleteVariable
	GuiControl,%a_gui%:disable,Condition_Debug_DialogEditField%a_gui%,%tempVarContent%
	;~ ToolTip(lang("Variable deleted"),1000)
	;~ MsgBox % tempVarContent
	return
	
	
	
	
	Condition_Debug_DialogButtonYes:
	Condition_Debug_DialogButtonNo:
	gui,%a_gui%:destroy
	
	environment:=x_GetMyEnvironmentFromExecutionID(a_gui)
	
	;~ MsgBox % a_gui " - " temp.instanceID
	if A_ThisLabel=Condition_Debug_DialogButtonYes
		x_finish(Environment, "yes")
	else
		x_finish(Environment, "no")
	
	return
	
	Debug_DialogGUIclose:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	environment:=x_GetMyEnvironmentFromExecutionID(a_gui)
	
	;~ MsgBox % a_gui " - " temp.instanceID
	logger("f0","Instance " tempDebug_DialogBut.instanceID " - " tempDebug_DialogBut.type " '" tempDebug_DialogBut.name "': Error! User dismissed the dialog")
	x_finish(Environment, "exception")
	

	return
	
	

}

Element_stop_Condition_Debug_Dialog(Environment, ElementParameters)
{
	tempGUIID:=x_GetMyUniqueExecutionID(Environment)
	gui,%tempGUIID%:destroy
	;~ logger("f0","Instance " tempDebug_DialogBut.instanceID " - " tempDebug_DialogBut.type " '" tempDebug_DialogBut.name "': Error! User dismissed the dialog")
	
	return
}
