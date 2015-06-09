iniAllActions.="Input_box|" ;Add this action to list of all actions on initialisation

runActionInput_box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionInput_boxToStart))
		ActionInput_boxToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance
	ActionInput_boxToStart.insert(tempInstanceString)
	
	if (Input_boxStarted=true)
		return
	
	

	ActionInput_box_StartNextQuestion:
	Input_boxStarted:=false
	for count, tempcInput_boxidToStart in ActionInput_boxToStart ;get the first element
	{
		StringSplit,tempElement,tempcInput_boxidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = Thread ID
		; tempElement4 = element id
		; tempElement5 = element id in the instance
		ActionInput_boxToStart_Instance_ID:=tempElement4
		ActionInput_boxToStart_Element_ID:=tempElement4
		ActionInput_boxToStart_Trhead_ID:=tempElement3
		
		
		;gui,%tempcInput_boxidToStart%:default
		
		;gui,10:-SysMenu 
		
		gui,12:add,text,x10 w320 h100, % v_replaceVariables(ActionInput_boxToStart_Instance_ID,ActionInput_boxToStart_Trhead_ID,%ActionInput_boxToStart_Element_ID%text,"normal")
		gui,12:add,edit,x10 w320 h20 vActionInput_box_edit, 
		gui,12:add,button,x10 w150 h30 gActionInput_boxButtonOK Default,% lang("OK")
		gui,12:show,w330 h180 ,% v_replaceVariables(ActionInput_boxToStart_Instance_ID,ActionInput_boxToStart_Trhead_ID,%ActionInput_boxToStart_Element_ID%title,"normal")
		
		ActionInput_boxStart_Current:=tempcInput_boxidToStart
		ActionInput_boxStart_CurrentInstanceID:=ActionInput_boxToStart_Instance_ID
		ActionInput_boxStart_CurrentThreadID:=ActionInput_boxToStart_Trhead_ID
		Input_boxStarted:=true
		break
		
	}
	
	if (Input_boxStarted)
		ActionInput_boxToStart.remove(1) ;Remove the shown question
	
	return
	
	ActionInput_boxButtonOK:
	gui,12:submit
	
	gui,12:destroy
	
	;MsgBox %ActionInput_boxStart_CurrentInstanceID%
	v_setVariable(ActionInput_boxStart_CurrentInstanceID,ActionInput_boxStart_CurrentThreadID,"t_input",ActionInput_box_edit)
	MarkThatElementHasFinishedRunningOneVar(ActionInput_boxStart_Current,"normal")
	
	goto,ActionInput_box_StartNextQuestion
	
	
	
	12guiclose:
	gui,12:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ActionInput_boxStart_Current,"exception")
	
	
	goto,ActionInput_box_StartNextQuestion
}

stopActionInput_box(ID)
{
	
	gui,%ID%:default
	gui,destroy
}



getParametersActionInput_box()
{
	
	parametersToEdit:=["Label|" lang("Title"),"text|" lang("Title")" |title","Label|" lang("Question"),"multilinetext|" lang("Message") "|text"]
	
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