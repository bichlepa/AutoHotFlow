iniAllActions.="Input_box|" ;Add this action to list of all actions on initialisation

runActionInput_box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%text,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	
	
	if (!IsObject(ActionInput_BoxAllGUIs))
		ActionInput_BoxAllGUIs:=Object()
	
	local tempNew:=Object()
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Varname",tempVarname)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	
	
	local tempGUILabel:="GUI_InputBox_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance
	
	;~ gui,tempGUILabel:default
	
	gui,%tempGUILabel%:+LabelInputBoxGUI
	

	gui,%tempGUILabel%:add,text,x10 w320 h100, % tempText
	gui,%tempGUILabel%:add,edit,x10 w320 h20 v%tempGUILabel%GUIEdit, 
	gui,%tempGUILabel%:add,button,x10 w150 h30 gActionInput_boxButtonOK Default,% lang("OK")
	gui,%tempGUILabel%:show,w330 h180 ,% tempTitle
	
	
	ActionInput_BoxAllGUIs.insert(tempGUILabel,tempNew)
	
	return
	
	ActionInput_BoxButtonOK:
	;~ MsgBox %a_gui%
	
	gui,%a_gui%:submit
	gui,%a_gui%:destroy
	
	tempInputBoxBut:=ActionInput_BoxAllGUIs[a_gui]
	
	v_setVariable(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.varname,%a_gui%GUIEdit)
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.ElementID,tempInputBoxBut.ElementIDInInstance,"normal")
	
	
	ActionInput_BoxAllGUIs.Remove(a_gui)
	
	return
	
	InputBoxGUIclose:
	gui,%a_gui%:destroy
	
	tempInputBoxBut:=ActionInput_BoxAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.ElementID,tempInputBoxBut.ElementIDInInstance,"exception")

	
	ActionInput_BoxAllGUIs.Remove(a_gui)
	return
	

}

stopActionInput_box(ID)
{
	global
	for tempActionInputBoxGuiLabel, tempActionInputBoxSettings in ActionInput_BoxAllGUIs
	{
		gui,%tempActionInputBoxGuiLabel%:destroy
		
	}
	ActionInput_BoxAllGUIs:=Object()
}



getParametersActionInput_box()
{
	
	parametersToEdit:=["Label|" lang("Output variable name"),"VariableName|UserInput|Varname","Label|" lang("Title"),"text|" lang("Title")" |title","Label|" lang("Question"),"multilinetext|" lang("Message") "|text"]
	
	return parametersToEdit
}

getNameActionInput_box()
{
	return lang("Input_box")
}
getCategoryActionInput_box()
{
	return lang("User_interaction")
}

GenerateNameActionInput_box(ID)
{
	return lang("Input_box") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%text
	
}