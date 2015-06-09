iniAllActions.="Message_Box|" ;Add this action to list of all actions on initialisation

runActionMessage_Box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	if (!IsObject(ActionMessage_BoxToStart))
		ActionMessage_BoxToStart:=Object()
	
	tempInstanceString:="Instance_" InstanceID "_" ThreadID "_"ElementID "_" ElementIDInInstance
	ActionMessage_BoxToStart.insert(tempInstanceString)
	
	if (Message_BoxStarted=true)
		return
	
	

	ActionMessage_Box_StartNextQuestion:
	Message_BoxStarted:=false
	for count, tempcMessage_BoxidToStart in ActionMessage_BoxToStart ;get the first element
	{
		StringSplit,tempElement,tempcMessage_BoxidToStart,_
		; tempElement1 = word "instance"
		; tempElement2 = instance id
		; tempElement3 = Thread id
		; tempElement4 = element id
		; tempElement5 = element id in the instance
		ActionMessage_BoxToStart_Instance_ID:=tempElement2
		ActionMessage_BoxToStart_Element_ID:=tempElement4
		ActionMessage_BoxToStart_Thread_ID:=tempElement3
		
		
		;gui,%tempcMessage_BoxidToStart%:default
		
		;gui,10:-SysMenu 
		
		gui,11:add,text,x10 w320 h100, % v_replaceVariables(ActionMessage_BoxToStart_Instance_ID,ActionMessage_BoxToStart_Thread_ID,%ActionMessage_BoxToStart_Element_ID%text,"normal")
		gui,11:add,button,x10 w150 h30 gActionMessage_BoxButtonOK Default,% lang("OK")
		gui,11:show,w330 h150 ,% v_replaceVariables(ActionMessage_BoxToStart_Instance_ID,ActionMessage_BoxToStart_Thread_ID,%ActionMessage_BoxToStart_Element_ID%title,"normal")
		
		ActionMessage_BoxStart_Current:=tempcMessage_BoxidToStart
		Message_BoxStarted:=true
		break
		
	}
	
	if (Message_BoxStarted)
		ActionMessage_BoxToStart.remove(1) ;Remove the shown question
	
	return
	
	ActionMessage_BoxButtonOK:
	
	gui,11:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ActionMessage_BoxStart_Current,"normal")
	
	goto,ActionMessage_Box_StartNextQuestion
	
	
	
	11guiclose:
	gui,11:destroy
	
	MarkThatElementHasFinishedRunningOneVar(ActionMessage_BoxStart_Current,"normal")
	
	
	goto,ActionMessage_Box_StartNextQuestion
}

stopActionMessage_Box(ID)
{
	
	gui,%ID%:default
	gui,destroy
}



getParametersActionMessage_Box()
{
	
	parametersToEdit:=["Label|" lang("Title"),"text|" lang("Title")" |title","Label|" lang("Question"),"multilinetext|" lang("Message") "|text"]
	
	return parametersToEdit
}

getNameActionMessage_Box()
{
	return lang("Message_Box")
}
getCategoryActionMessage_Box()
{
	return lang("User_interaction")
}

GenerateNameActionMessage_Box(ID)
{
	return lang("Message_Box") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%text
	
}