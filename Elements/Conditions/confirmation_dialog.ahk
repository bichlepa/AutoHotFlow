iniAllConditions.="Confirmation_Dialog|" ;Add this condition to list of all conditions on initialisation
ConditionConfirmation_DialogAllGUIs:=Object()

runConditionConfirmation_Dialog(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%message,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	local tempButtonLabelYes:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabelYes,"normal")
	local tempButtonLabelNo:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabelNo,"normal")
	local tempButtonLabelCancel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabelcancel,"normal")
	local tempTimeoutUnits:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%TimeoutUnits)
	local tempWidth:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Width)
	local tempHeight:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Height)
	
	
	local tempx
	local tempy
	local tempw
	local temph
	
	if tempButtonLabelYes=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Button label for yes is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Button label for '%1%'", lang("Yes"))))
		return
	}
	if tempButtonLabelNo=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Button label for no is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Button label for '%1%'", lang("No"))))
		return
	}
	
	
	local tempNew:=Object() ;create object that will contain all settings of the current element
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	tempNew.insert("Type",%ElementID%type)
	tempNew.insert("Name",%ElementID%name)
	tempNew.insert("ButtonLabelYes",tempButtonLabelYes)
	tempNew.insert("ButtonLabelNo",tempButtonLabelNo)
	tempNew.insert("ButtonLabelCancel",tempButtonLabelCancel)
	tempNew.insert("IsTimeout",%ElementID%IsTimeout)
	tempNew.insert("OnTimeout",%ElementID%OnTimeout)
	tempNew.insert("TimeoutUnits",tempTimeoutUnits)
	tempNew.insert("Unit",%ElementID%Unit)
	tempNew.insert("IfDismiss",%ElementID%IfDismiss)
	tempNew.insert("Width",%ElementID%Width)
	tempNew.insert("Height",%ElementID%Height)
	
	if tempWidth is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Width " tempWidth " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Width '%1%'",tempWidth)) )
		return
	}
	if tempHeight is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Height " tempHeight " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Height '%1%'",tempHeight)) )
		return
	}
	
	;Create a gui label. This label will always be unique. 
	local tempGUILabel:="GUI_Confirmation_Dialog_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance 
	
	gui,%tempGUILabel%:margin,10,10
	
	;Create GUI
	gui,%tempGUILabel%:+LabelConfirmation_DialogGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	
	temph:=tempHeight-30-10*3
	if %ElementID%IsTimeout=2
		temph-=10 +15
		
	tempw:=tempWidth-10*2
	gui,%tempGUILabel%:add,edit, ReadOnly  w%tempw% h%temph% vText hwndTempTextHWND, % tempText
	
	if %ElementID%IsTimeout=2
	{
		
		gui,%tempGUILabel%:add,text, Y+10 w%tempw% h15 vTimeoutText
	}
	
	if %ElementID%ShowCancelButton
	{
		if tempButtonLabelCancel=
		{
			gui,%tempGUILabel%:Destroy
			Logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Button label for cancel is not specified.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Button label for '%1%'", lang("Cancel"))))
			return
		}
		tempw:=round((tempw-10*2)/3)
		gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gConditionConfirmation_DialogButtonYes vConditionConfirmation_DialogButtonYes Default ,% tempButtonLabelYes
		gui,%tempGUILabel%:add,button,X+10 w%tempw% h30  gConditionConfirmation_DialogButtonNo gConditionConfirmation_DialogButtonNo  ,% tempButtonLabelNo
		gui,%tempGUILabel%:add,button,X+10 w%tempw% h30  gConditionConfirmation_DialogButtonCancel vConditionConfirmation_DialogCancel  ,% tempButtonLabelCancel
	}
	else
	{
		tempw:=round((tempw-10)/2)
		gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gConditionConfirmation_DialogButtonYes vConditionConfirmation_DialogButtonYes Default ,% tempButtonLabelYes
		gui,%tempGUILabel%:add,button,X+10 w%tempw% h30  gConditionConfirmation_DialogButtonNo gConditionConfirmation_DialogButtonNo  ,% tempButtonLabelNo
	}
	
	guicontrol,%tempGUILabel%:focus,ConditionConfirmation_DialogButtonYes
	
	gui,%tempGUILabel%:show,h%tempHeight% w%tempWidth% ,% tempTitle
	
	
	if %ElementID%IsTimeout=2 ;If timeout, establish it
	{
		if tempTimeoutUnits is not number
		{
			gui,%tempGUILabel%:Destroy
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Timeout " tempTimeoutUnits " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Timeout '%1%'",tempTimeoutUnits)) )
			return
		}
		;~ gui,%tempGUILabel%:add,text,x10 w200  Y+20 vTimeOutLabel,% lang("Timeout") ": "
		tempEndTime:=tempTimeoutUnits
		if %ElementID%Unit=2 ;Minutes
			tempEndTime*=60
		if %ElementID%Unit=3 ;Hours
			tempEndTime*=3600
		tempEndTime*=1000
		;~ MsgBox %tempEndTime% - %A_TickCount%
		tempEndTime+=A_TickCount
		;~ ToolTip %tempEndTime% - %A_TickCount%
		tempNew.insert("EndTime",tempEndTime)
	}
	
	;Add the label to the list of all GUI labels, so it can be found.
	ConditionConfirmation_DialogAllGUIs.insert(tempGUILabel,tempNew)
	
	;Set timer if a timeout is set
	if %ElementID%IsTimeout=2
		settimer,ConditionConfirmation_DialogTimeoutTimer,-1
	return
	
	ConditionConfirmation_DialogTimeoutTimer:
	
	ConditionConfirmation_Dialog_TimeoutTimerNextTime:=""
	ConditionConfirmation_Dialog_TimeoutTimerFoundSth:=false
	;~ ToolTip,% ConditionConfirmation_Dialog_TimeoutTimercntr++
	
	
	for tempConfirmation_DialogTimeout_OneGUIID, tempConfirmation_DialogTimeout_OneParameterList in ConditionConfirmation_DialogAllGUIs
	{
		
		if tempConfirmation_DialogTimeout_OneParameterList.IsTimeout=2
		{
			ConditionConfirmation_Dialog_TimeoutTimerFoundSth:=true
			if (tempConfirmation_DialogTimeout_OneParameterList.EndTime <= (A_TickCount))
			{
				;~ MsgBox % tempConfirmation_DialogTimeout_OneParameterList.EndTime " - " A_TickCount
				gui,%tempConfirmation_DialogTimeout_OneGUIID%:destroy
				if (tempConfirmation_DialogTimeout_OneParameterList.OnTimeout=1) ;Yes
				{
					;~ MsgBox % strobj(tempConfirmation_DialogTimeout_OneParameterList)
					logger("f0","Instance " tempConfirmation_DialogTimeout_OneParameterList.instanceID " - " tempConfirmation_DialogTimeout_OneParameterList.type " '" tempConfirmation_DialogTimeout_OneParameterList.name "': Warning! Timout reached")
					MarkThatElementHasFinishedRunning(tempConfirmation_DialogTimeout_OneParameterList.instanceID,tempConfirmation_DialogTimeout_OneParameterList.threadid,tempConfirmation_DialogTimeout_OneParameterList.ElementID,tempConfirmation_DialogTimeout_OneParameterList.ElementIDInInstance,"yes")
				}
				else if(tempConfirmation_DialogTimeout_OneParameterList.OnTimeout=2) ;No
				{
					;~ MsgBox % strobj(tempConfirmation_DialogTimeout_OneParameterList)
					logger("f0","Instance " tempConfirmation_DialogTimeout_OneParameterList.instanceID " - " tempConfirmation_DialogTimeout_OneParameterList.type " '" tempConfirmation_DialogTimeout_OneParameterList.name "': Warning! Timout reached")
					MarkThatElementHasFinishedRunning(tempConfirmation_DialogTimeout_OneParameterList.instanceID,tempConfirmation_DialogTimeout_OneParameterList.threadid,tempConfirmation_DialogTimeout_OneParameterList.ElementID,tempConfirmation_DialogTimeout_OneParameterList.ElementIDInInstance,"no")
				}
				else
				{
					
					logger("f0","Instance " tempConfirmation_DialogTimeout_OneParameterList.instanceID " - " tempConfirmation_DialogTimeout_OneParameterList.type " '" tempConfirmation_DialogTimeout_OneParameterList.name "': Error! Timout reached")
					MarkThatElementHasFinishedRunning(tempConfirmation_DialogTimeout_OneParameterList.instanceID,tempConfirmation_DialogTimeout_OneParameterList.threadid,tempConfirmation_DialogTimeout_OneParameterList.ElementID,tempConfirmation_DialogTimeout_OneParameterList.ElementIDInInstance,"exception",lang("Timout reached"))
				}
				
				ConditionConfirmation_DialogAllGUIs.Remove(tempConfirmation_DialogTimeout_OneGUIID)
			}
			else
			{
				;Find out the next timestamp until the counter of any of the currently visible message boxes must be decremented.
				tempConditionConfirmation_Dialog_NextTime:=tempConfirmation_DialogTimeout_OneParameterList.EndTime - A_TickCount
				guicontrol,%tempConfirmation_DialogTimeout_OneGUIID%:,TimeoutText,% lang("Timeout") ": " tempConditionConfirmation_Dialog_NextTime//1000 +1 " " lang("seconds") 
				tempConditionConfirmation_Dialog_NextTime:=round(((tempConditionConfirmation_Dialog_NextTime/1000)-(tempConditionConfirmation_Dialog_NextTime//1000))*1000 +10)
				if (ConditionConfirmation_Dialog_TimeoutTimerNextTime="" or ConditionConfirmation_Dialog_TimeoutTimerNextTime > tempConditionConfirmation_Dialog_NextTime)
				{
					ConditionConfirmation_Dialog_TimeoutTimerNextTime:=tempConditionConfirmation_Dialog_NextTime
				}
				
				
			}
		}
		
	}
	
	;~ ToolTip %ConditionConfirmation_Dialog_TimeoutTimerNextTime% --
	if (ConditionConfirmation_Dialog_TimeoutTimerFoundSth)
	{
		
		if ConditionConfirmation_Dialog_TimeoutTimerNextTime>0
		{
			;~ ToolTip % "-" round(ConditionConfirmation_Dialog_TimeoutTimerNextTime)
			SetTimer,ConditionConfirmation_DialogTimeoutTimer,% "-" ConditionConfirmation_Dialog_TimeoutTimerNextTime
			;~ SetTimer,ConditionConfirmation_DialogTimeoutTimer,-
		}
		else
			SetTimer,ConditionConfirmation_DialogTimeoutTimer,-1
	}
	else
		SetTimer,ConditionConfirmation_DialogTimeoutTimer,off
	return
	
	
	ConditionConfirmation_DialogButtonYes:
	ConditionConfirmation_DialogButtonNo:
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempConfirmation_DialogBut:=ConditionConfirmation_DialogAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	if A_ThisLabel=ConditionConfirmation_DialogButtonYes
	{
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"yes")
	}
	else
	{
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"no")
	}
	
	;Remove this GUI from the list of all GUIs
	ConditionConfirmation_DialogAllGUIs.Remove(a_gui)
	
	return
	
	Confirmation_DialogGUIclose:
	ConditionConfirmation_DialogButtonCancel:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempConfirmation_DialogBut:=ConditionConfirmation_DialogAllGUIs[a_gui]
	
	if (tempConfirmation_DialogBut.IfDismiss=1) ;Yes
	{
		logger("f0","Instance " tempConfirmation_DialogBut.instanceID " - " tempConfirmation_DialogBut.type " '" tempConfirmation_DialogBut.name "': Warning! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"yes")
	}
	else if (tempConfirmation_DialogBut.IfDismiss=2) ;No
	{
		logger("f0","Instance " tempConfirmation_DialogBut.instanceID " - " tempConfirmation_DialogBut.type " '" tempConfirmation_DialogBut.name "': Warning! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"No")
	}
	else ;Exception
	{
		logger("f0","Instance " tempConfirmation_DialogBut.instanceID " - " tempConfirmation_DialogBut.type " '" tempConfirmation_DialogBut.name "': Error! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempConfirmation_DialogBut.instanceID,tempConfirmation_DialogBut.threadid,tempConfirmation_DialogBut.ElementID,tempConfirmation_DialogBut.ElementIDInInstance,"exception",lang("User dismissed the dialog"))
	}

	
	ConditionConfirmation_DialogAllGUIs.Remove(a_gui)
	return
	
	
	
}

stopConditionConfirmation_Dialog(ID)
{
	global
	;Go through all GUI Labels that are in the list of all GUIs
	for tempConditionConfirmation_DialogGuiLabel, tempConditionConfirmation_DialogSettings in ConditionConfirmation_DialogAllGUIs
	{
		gui,%tempConditionConfirmation_DialogGuiLabel%:destroy ;Close the window
		
	}
	
	ConditionConfirmation_DialogAllGUIs:=Object() ;Delete all elements from the list of all GUIs
	
	gui,%ID%:default
	gui,destroy
}



getParametersConditionConfirmation_Dialog()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Question"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Question")})
	parametersToEdit.push({type: "Edit", id: "message", default: lang("Do_you_agree?"), content: "String", multiline: true})
	parametersToEdit.push({type: "Label", label: lang("Button Text")})
	parametersToEdit.push({type: "Label", label: lang("Button '%1%'",lang("Yes")), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelYes", default: lang("Yes"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Button '%1%'",lang("No")), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelNo", default: lang("No"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: 1, choices: [lang("No timeout"), lang("Define timeout")]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], default: 1})
	parametersToEdit.push({type: "Label", label: lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", choices: [lang("Yes"), lang("No"), lang("Throw exception")], default: 3})
	parametersToEdit.push({type: "Label", label: lang("Width and height")})
	;~ parametersToEdit.push({type: "Radio", id: "Size", default: 1, choices: [lang("Automatic"), lang("Define width and height")]}) ;No automatic size yet
	;~ parametersToEdit.push({type: "Label", label: lang("Width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 250], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", choices: [lang("Yes"), lang("No"), lang("Throw exception")], default: 3})
	
	return parametersToEdit
}

getNameConditionConfirmation_Dialog()
{
	return lang("Confirmation_Dialog")
}
getCategoryConditionConfirmation_Dialog()
{
	return lang("User_interaction")
}

GenerateNameConditionConfirmation_Dialog(ID)
{
	if (strlen(GUISettingsOfElement%ID%message)>100)
	{
		return lang("Confirmation_Dialog") ": " GUISettingsOfElement%ID%title " - " substr(GUISettingsOfElement%ID%message,1,100) " ... "
	}
	else
		return lang("Confirmation_Dialog") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%message
	
}


CheckSettingsConditionConfirmation_Dialog(ID)
{
	global
	if (GUISettingsOfElement%ID%IsTimeout1 = 1) ;no timeout
	{

		GuiControl,Disable,GUISettingsOfElement%ID%TimeoutUnits
		GuiControl,Disable,GUISettingsOfElement%ID%Unit1
		GuiControl,Disable,GUISettingsOfElement%ID%Unit2
		GuiControl,Disable,GUISettingsOfElement%ID%Unit3
		GuiControl,Disable,GUISettingsOfElement%ID%OnTimeout1
		GuiControl,Disable,GUISettingsOfElement%ID%OnTimeout2
		GuiControl,Disable,GUISettingsOfElement%ID%OnTimeout3
	}
	else ;Timeout
	{
		GuiControl,Enable,GUISettingsOfElement%ID%TimeoutUnits
		GuiControl,Enable,GUISettingsOfElement%ID%Unit1
		GuiControl,Enable,GUISettingsOfElement%ID%Unit2
		GuiControl,Enable,GUISettingsOfElement%ID%Unit3
		GuiControl,Enable,GUISettingsOfElement%ID%OnTimeout1
		GuiControl,Enable,GUISettingsOfElement%ID%OnTimeout2
		GuiControl,Enable,GUISettingsOfElement%ID%OnTimeout3
	}
	

	if (GUISettingsOfElement%ID%ShowCancelButton = 1) 
	{
		GuiControl,Enable,GUISettingsOfElement%ID%ButtonLabelCancel
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%ButtonLabelCancel
	}
	
}