iniAllConditions.="Debug_Dialog|" ;Add this condition to list of all conditions on initialisation

runConditionDebug_Dialog(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	if (!IsObject(ConditionDebug_DialogAllGUIs))
		ConditionDebug_DialogAllGUIs:=Object()
	
	local tempNew:=Object() ;create object that will contain all settings of the current element
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	
	;Create a gui label. This label will always be unique. 
	local tempGUILabel:="GUI_Debug_Dialog_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance 
	ConditionDebug_DialogAllGUIs.insert(tempGUILabel,tempNew)
	
	;Create GUI
	gui,%tempGUILabel%:+LabelDebug_DialogGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	gui,%tempGUILabel%:add,text,x10 , % lang("Local variables")
	
	gosub,ConditionDebug_DialogButtonUpdateVariableList
	
	
	
	
	StringTrimRight,temptriggerNames,temptriggerNames,1
	
	gui,%tempGUILabel%:add,listbox, x10 w200 h200 vConditionDebug_DialogLocalVars%tempGUILabel% gConditionDebug_DialogLocalVars ,%tempVariableNames% 
	
	

	gui,%tempGUILabel%:add,edit,X+10 w200 yp h200 vConditionDebug_DialogEditField%tempGUILabel% gConditionDebug_DialogEditField
	gui,%tempGUILabel%:add,button,x10 w150 h30 gConditionDebug_DialogButtonUpdateVariableList,% lang("Update variable list")
	gui,%tempGUILabel%:add,button,X+20 w150 h30 gConditionDebug_DialogButtonDeleteVariable vConditionDebug_DialogButtonDeleteVariable Disabled,% lang("Delete variable")
	gui,%tempGUILabel%:add,button,X+20 w150 h30 vConditionDebug_DialogButtonChangeValue gConditionDebug_DialogButtonChangeValue Disabled,% lang("Change value")
	gui,%tempGUILabel%:add,button,x10 w150 h30 gConditionDebug_DialogButtonYes,% lang("Yes")
	gui,%tempGUILabel%:add,button,X+10 yp w150 h30 gConditionDebug_DialogButtonNo,% lang("No")
	gui,%tempGUILabel%:show, ,% tempTitle
	
	;Add the label to the list of all GUI labels, so it can be found.
	
	
	return
	
	ConditionDebug_DialogButtonUpdateVariableList:
	
	if a_gui
	{
		tempGUILabel:=a_gui
		tempVariableNames=|
	}
	else
		tempVariableNames=
	tempInstance:=ConditionDebug_DialogAllGUIs[tempGUILabel]["instanceID"]
	tempThread:=ConditionDebug_DialogAllGUIs[tempGUILabel]["ThreadID"]
	
	for tempVarName, tempVarValue in Instance_%tempInstance%_Thread_%tempThread%_Variables[c_loopVarsName]
	{
		
		if (substr(tempVarName,1,2)="a_")
		{
			if a_index=1
				tempVariableNames.= "--- " lang("Loop variables") " ---|"
			tempVariableNames.=tempVarName "|"
		}
	}
	
	for tempVarName, tempVarValue in Instance_%tempInstance%_Thread_%tempThread%_Variables
	{
		if (substr(tempVarName,1,2)="a_")
		{
			if a_index=1
				tempVariableNames.= "--- " lang("Thread variables") " ---|"
			tempVariableNames.=tempVarName "|"
		}
	}
	
	
	
	
	for tempVarName, tempVarValue in Instance_%tempInstance%_LocalVariables
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Local variables") " ---|"
		tempVariableNames.=tempVarName "|"
	}
	
	loop,%FolderOfStaticVariables%\static_*.txt
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Static variables") " ---|"
		StringTrimRight,tempVarName,A_LoopFileName,4
		tempVariableNames.=tempVarName "|"
	}
	
	loop,global variables\global_*.txt
	{
		if a_index=1
			tempVariableNames.= "--- " lang("Global variables") " ---|"
		StringTrimRight,tempVarName,A_LoopFileName,4
		tempVariableNames.=tempVarName "|"
	}
	tempNew.insert("VariableNames",tempVariableNames)
	guicontrol,%a_gui%:,ConditionDebug_DialogLocalVars%a_gui%,%tempVariableNames%
	return
	
	ConditionDebug_DialogEditField:
	GuiControl,%a_gui%:enable,ConditionDebug_DialogButtonChangeValue
	GuiControl,%a_gui%:+default,ConditionDebug_DialogButtonChangeValue
	return
	
	ConditionDebug_DialogLocalVars:
	GuiControl,%a_gui%:Disable,ConditionDebug_DialogButtonChangeValue
	gui,%a_gui%:submit,nohide
	tempvarname:=ConditionDebug_DialogLocalVars%a_gui%
	IfInString,tempvarname,---
	{
		GuiControl,%a_gui%:Disable,ConditionDebug_DialogButtonDeleteVariable
		GuiControl,%a_gui%:,ConditionDebug_DialogEditField%a_gui%,%A_Space%
		GuiControl,%a_gui%:disable,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
		return
	}
	GuiControl,%a_gui%:Enable,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
	GuiControl,%a_gui%:Enable,ConditionDebug_DialogButtonDeleteVariable
	tempInstance:=ConditionDebug_DialogAllGUIs[a_gui]["instanceID"]
	tempThread:=ConditionDebug_DialogAllGUIs[a_gui]["ThreadID"]
	;~ tempInstance:=tempInstance["instanceID"]
	tempVarContent:=v_getVariable(tempInstance,tempThread,tempvarname,"asIs")
	tempVarType:=v_getVariableType(tempInstance,tempThread,tempvarname)
	if tempVarType=list
	{
		tempVarContent:=strobj(tempVarContent)
		guicontrol,%a_gui%:,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
		ConditionDebug_DialogAllGUIs[a_gui]["SelectedVarType"]:="list"
	}
	else if tempVarType=normal
	{

		guicontrol,%a_gui%:,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
		ConditionDebug_DialogAllGUIs[a_gui]["SelectedVarType"]:="normal"
	}
	else if tempVarType=date
	{
		guicontrol,%a_gui%:,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
		ConditionDebug_DialogAllGUIs[a_gui]["SelectedVarType"]:="date"
	
		
	}
	guicontrol,%a_gui%:,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
	;~ MsgBox % tempVarContent
	return
	
	
	ConditionDebug_DialogButtonChangeValue:
	GuiControl,%a_gui%:Disable,ConditionDebug_DialogButtonChangeValue
	gui,%a_gui%:submit,nohide
	tempvarname:=ConditionDebug_DialogLocalVars%a_gui%
	tempInstance:=ConditionDebug_DialogAllGUIs[a_gui]["instanceID"]
	tempThread:=ConditionDebug_DialogAllGUIs[a_gui]["ThreadID"]
	tempVarType:=ConditionDebug_DialogAllGUIs[a_gui]["SelectedVarType"]
	
	tempLocation:=getVariableLocation(tempInstance,tempThread,tempvarname)
	if tempLocation=thread
		tempPermission:=c_SetBuiltInVar
	else if tempLocation=loop
		tempPermission:=c_SetLoopVar
	else
		tempPermission=0
	;~ MsgBox % tempPermission
	;~ tempInstance:=tempInstance["instanceID"]
	tempVarContent:=Instance_%tempInstance%_LocalVariables[tempvarname]
	tempNewVarContent:=ConditionDebug_DialogEditField%a_gui%
	;~ MsgBox %tempVarType%
	if tempVarType=list
	{
		tempNewVarContent:=strobj(tempNewVarContent)
		
		v_SetVariable(tempInstance,tempThread,tempvarname,tempNewVarContent,"list",tempPermission)
	}
	else if tempVarType=normal
	{
		v_SetVariable(tempInstance,tempThread,tempvarname,tempNewVarContent,"normal",tempPermission)
		
	}
	else if tempVarType=date
	{
		;~ MsgBox %tempNewVarContent%
		v_SetVariable(tempInstance,tempThread,tempvarname,tempNewVarContent,"date",tempPermission)
		
	}
	ToolTip(lang("Variable is set"),1000)
	;~ MsgBox % tempVarContent
	return
	
	
	ConditionDebug_DialogButtonDeleteVariable:
	gui,%a_gui%:submit,nohide
	tempvarname:=ConditionDebug_DialogLocalVars%a_gui%
	tempInstance:=ConditionDebug_DialogAllGUIs[a_gui]["instanceID"]
	tempThread:=ConditionDebug_DialogAllGUIs[a_gui]["ThreadID"]
	tempVarType:=ConditionDebug_DialogAllGUIs[a_gui]["SelectedVarType"]
	tempVariableNames:=ConditionDebug_DialogAllGUIs[a_gui]["VariableNames"]
	;~ MsgBox %tempVariableNames%
	;~ tempInstance:=tempInstance["instanceID"]
	tempVarContent:=Instance_%tempInstance%_LocalVariables[tempvarname]
	tempNewVarContent:=ConditionDebug_DialogEditField%a_gui%
	;~ MsgBox %tempVarType%
	v_deleteVariable(tempInstance,tempThread,tempvarname)
	tempVariableNames:="|" tempVariableNames "|"
	;~ MsgBox %tempVariableNames% - %tempvarname%
	StringReplace,tempVariableNames,tempVariableNames,% "|" tempvarname "|",|
	StringTrimRight,tempVariableNames,tempVariableNames,1
	;~ MsgBox %tempVariableNames%
	guicontrol,%a_gui%:,ConditionDebug_DialogLocalVars%a_gui%,%tempVariableNames%
	guicontrol,%a_gui%:,ConditionDebug_DialogEditField%a_gui%
	GuiControl,%a_gui%:Disable,ConditionDebug_DialogButtonDeleteVariable
	GuiControl,%a_gui%:disable,ConditionDebug_DialogEditField%a_gui%,%tempVarContent%
	ToolTip(lang("Variable deleted"),1000)
	;~ MsgBox % tempVarContent
	return
	
	
	
	
	ConditionDebug_DialogButtonYes:
	ConditionDebug_DialogButtonNo:
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempDebug_DialogBut:=ConditionDebug_DialogAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	if A_ThisLabel=ConditionDebug_DialogButtonYes
		MarkThatElementHasFinishedRunning(tempDebug_DialogBut.instanceID,tempDebug_DialogBut.threadid,tempDebug_DialogBut.ElementID,tempDebug_DialogBut.ElementIDInInstance,"yes")
	else
		MarkThatElementHasFinishedRunning(tempDebug_DialogBut.instanceID,tempDebug_DialogBut.threadid,tempDebug_DialogBut.ElementID,tempDebug_DialogBut.ElementIDInInstance,"no")
	
	;Remove this GUI from the list of all GUIs
	ConditionDebug_DialogAllGUIs.Remove(a_gui)
	
	return
	
	Debug_DialogGUIclose:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempDebug_DialogBut:=ConditionDebug_DialogAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempDebug_DialogBut.instanceID,tempDebug_DialogBut.threadid,tempDebug_DialogBut.ElementID,tempDebug_DialogBut.ElementIDInInstance,"exception")

	
	ConditionDebug_DialogAllGUIs.Remove(a_gui)
	return
	
	
	
}

stopConditionDebug_Dialog(ID)
{
	global
	;Go through all GUI Labels that are in the list of all GUIs
	for tempConditionDebug_DialogGuiLabel, tempConditionDebug_DialogSettings in ConditionDebug_DialogAllGUIs
	{
		gui,%tempConditionDebug_DialogGuiLabel%:destroy ;Close the window
		
	}
	
	ConditionDebug_DialogAllGUIs:=Object() ;Delete all elements from the list of all GUIs
	
	gui,%ID%:default
	gui,destroy
}

getParametersConditionDebug_Dialog()
{
	
	parametersToEdit:=[]
	
	return parametersToEdit
}

getNameConditionDebug_Dialog()
{
	return lang("Debug_Dialog")
}
getCategoryConditionDebug_Dialog()
{
	return lang("Debugging")
}

GenerateNameConditionDebug_Dialog(ID)
{
	return lang("Debug_Dialog") 
	
}