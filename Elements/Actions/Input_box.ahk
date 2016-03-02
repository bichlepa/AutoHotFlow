iniAllActions.="Input_box|" ;Add this action to list of all actions on initialisation
ActionInput_BoxAllGUIs:=Object()

runActionInput_box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempVarname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname)
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%message,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	local tempButtonLabel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabel,"normal")
	local tempButtonLabelCancel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabelcancel,"normal")
	local tempdefaultText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%defaultText,"normal")
	local tempWidth:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Width)
	local tempHeight:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Height)
	local tempTimeoutUnits:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%TimeoutUnits)
	local tempMultilineEditRows:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%MultilineEditRows)
	
	local TempTextHWND
	local tempx
	local tempy
	local tempw
	local temph
	local temphEdit
	local tempMaskInput
	
	if not v_CheckVariableName(tempVarname)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! List name '" tempVarname "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("List name '%1%'",tempVarname)) )
		return
	}
	
	if tempButtonLabel=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Button label is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Button label")))
		return
	}
	
	if tempTitle=
		tempTitle:=flowSettings.Name

	local tempNew:=Object()
	tempNew.insert("instanceID",InstanceID)
	tempNew.insert("ThreadID",ThreadID)
	tempNew.insert("ElementID",ElementID)
	tempNew.insert("ElementIDInInstance",ElementIDInInstance)
	tempNew.insert("Varname",tempVarname)
	tempNew.insert("Text",tempText)
	tempNew.insert("Title",tempTitle)
	tempNew.insert("Type",%ElementID%type)
	tempNew.insert("Name",%ElementID%name)
	tempNew.insert("ButtonLabel",tempButtonLabel)
	tempNew.insert("ButtonLabelCancel",tempButtonLabelCancel)
	tempNew.insert("IsTimeout",%ElementID%IsTimeout)
	tempNew.insert("OnTimeout",%ElementID%OnTimeout)
	tempNew.insert("TimeoutUnits",tempTimeoutUnits)
	tempNew.insert("Unit",%ElementID%Unit)
	tempNew.insert("IfDismiss",%ElementID%IfDismiss)
	tempNew.insert("Width",%ElementID%Width)
	tempNew.insert("Height",%ElementID%Height)
	tempNew.insert("ShowCancelButton",%ElementID%ShowCancelButton)
	
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
	
	
	local tempGUILabel:="GUI_InputBox_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance
	
	gui,%tempGUILabel%:margin,10,10
	
	gui,%tempGUILabel%:+LabelInputBoxGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	
	tempw:=tempWidth-10*2
	
	;at first add the edit field and get the size of the edit field
	if %ElementID%MaskUserInput
		tempMaskInput:="Password"
	if %ElementID%OnlyNumbers
		tempMaskInput:="Number"
	if %ElementID%MultilineEdit
	{
		if tempMultilineEditRows is not number
		{
			gui,%tempGUILabel%:Destroy
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Rows count " tempMultilineEditRows " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Rows count '%1%'",tempMultilineEditRows)) )
			return
		}
		tempRows:="r" tempMultilineEditRows
	}
	else
		tempRows:="r1"
	
	;~ MsgBox %tempRows%
	gui,%tempGUILabel%:add,edit, w%tempw% v%tempGUILabel%GUIEdit %tempMaskInput% %tempMaskInput% %tempRows% hwndTempTextHWND, % tempdefaultText
	controlgetpos,,,,temphEdit,,ahk_id %TempTextHWND%
	
	
	temph:=tempHeight-30-10*4-temphEdit
	if %ElementID%IsTimeout=2
		temph-=10 +15
	
	gui,%tempGUILabel%:add,edit, ReadOnly x10 y10 w%tempw% h%temph% vGUIText , % tempText
	tempy:=10+10+temph
	;~ MsgBox %tempy%
	guicontrol,%tempGUILabel%:move,%tempGUILabel%GUIEdit,x10 y%tempy%
	
	
	tempy:=10*3+temphEdit+temph
	
	if %ElementID%IsTimeout=2
	{
		gui,%tempGUILabel%:add,text, y%tempy% w%tempw% h15 x10 vTimeoutText
		tempy+=10+15
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
		
		tempw:=round((tempw-10)/2)
		gui,%tempGUILabel%:add,button,x10 y%tempy% w%tempw% h30  gActionInput_BoxButtonOK vActionInput_BoxButtonOK Default ,% tempButtonLabel
		gui,%tempGUILabel%:add,button,X+10 y%tempy% w%tempw% h30  gActionInput_BoxButtonCancel vActionInput_BoxButtonCancel  ,% tempButtonLabelCancel
	}
	else
		gui,%tempGUILabel%:add,button,x10 y%tempy% w%tempw% h30  gActionInput_BoxButtonOK vActionInput_BoxButtonOK Default ,% tempButtonLabel
	guicontrol,%tempGUILabel%:focus,ActionInput_BoxButtonOK
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
	
	
	
	gui,%tempGUILabel%:show,w%tempWidth% h%tempheight% ,% tempTitle
	
	
	ActionInput_BoxAllGUIs.insert(tempGUILabel,tempNew)
	
		;Set timer if a timeout is set
	if %ElementID%IsTimeout=2
		settimer,ActionInput_BoxTimeoutTimer,-1
	return
	
	ActionInput_BoxTimeoutTimer:
	
	ActionInput_Box_TimeoutTimerNextTime:=""
	ActionInput_Box_TimeoutTimerFoundSth:=false
	;~ ToolTip,% ActionInput_Box_TimeoutTimercntr++
	
	
	for tempInput_BoxTimeout_OneGUIID, tempInput_BoxTimeout_OneParameterList in ActionInput_BoxAllGUIs
	{
		
		if tempInput_BoxTimeout_OneParameterList.IsTimeout=2
		{
			ActionInput_Box_TimeoutTimerFoundSth:=true
			if (tempInput_BoxTimeout_OneParameterList.EndTime <= (A_TickCount))
			{
				;~ MsgBox % tempInput_BoxTimeout_OneParameterList.EndTime " - " A_TickCount
				gui,%tempInput_BoxTimeout_OneGUIID%:destroy
				if (tempInput_BoxTimeout_OneParameterList.OnTimeout=2)
				{
					
					logger("f0","Instance " tempInput_BoxTimeout_OneParameterList.instanceID " - " tempInput_BoxTimeout_OneParameterList.type " '" tempInput_BoxTimeout_OneParameterList.name "': Error! Timout reached")
					MarkThatElementHasFinishedRunning(tempInput_BoxTimeout_OneParameterList.instanceID,tempInput_BoxTimeout_OneParameterList.threadid,tempInput_BoxTimeout_OneParameterList.ElementID,tempInput_BoxTimeout_OneParameterList.ElementIDInInstance,"exception",lang("Timout reached"))
				}
				else
				{
					;~ MsgBox % strobj(tempInput_BoxTimeout_OneParameterList)
					v_setVariable(tempInput_BoxTimeout_OneParameterList.instanceID,tempInput_BoxTimeout_OneParameterList.threadid,tempInput_BoxTimeout_OneParameterList.varname,"") ;Set empty string as result
	
					logger("f0","Instance " tempInput_BoxTimeout_OneParameterList.instanceID " - " tempInput_BoxTimeout_OneParameterList.type " '" tempInput_BoxTimeout_OneParameterList.name "': Warning! Timout reached")
					MarkThatElementHasFinishedRunning(tempInput_BoxTimeout_OneParameterList.instanceID,tempInput_BoxTimeout_OneParameterList.threadid,tempInput_BoxTimeout_OneParameterList.ElementID,tempInput_BoxTimeout_OneParameterList.ElementIDInInstance,"normal")
				}
				ActionInput_BoxAllGUIs.Remove(tempInput_BoxTimeout_OneGUIID)
			}
			else
			{
				;Find out the next timestamp until the counter of any of the currently visible Input boxes must be decremented.
				tempActionInput_Box_NextTime:=tempInput_BoxTimeout_OneParameterList.EndTime - A_TickCount
				guicontrol,%tempInput_BoxTimeout_OneGUIID%:,TimeoutText,% lang("Timeout") ": " tempActionInput_Box_NextTime//1000 +1 " " lang("seconds") 
				tempActionInput_Box_NextTime:=round(((tempActionInput_Box_NextTime/1000)-(tempActionInput_Box_NextTime//1000))*1000 +10)
				if (ActionInput_Box_TimeoutTimerNextTime="" or ActionInput_Box_TimeoutTimerNextTime > tempActionInput_Box_NextTime)
				{
					ActionInput_Box_TimeoutTimerNextTime:=tempActionInput_Box_NextTime
				}
				
				
			}
		}
		
	}
	
	;~ ToolTip %ActionInput_Box_TimeoutTimerNextTime% --
	if (ActionInput_Box_TimeoutTimerFoundSth)
	{
		
		if ActionInput_Box_TimeoutTimerNextTime>0
		{
			;~ ToolTip % "-" round(ActionInput_Box_TimeoutTimerNextTime)
			SetTimer,ActionInput_BoxTimeoutTimer,% "-" ActionInput_Box_TimeoutTimerNextTime
			;~ SetTimer,ActionInput_BoxTimeoutTimer,-
		}
		else
			SetTimer,ActionInput_BoxTimeoutTimer,-1
	}
	else
		SetTimer,ActionInput_BoxTimeoutTimer,off
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
	ActionInput_BoxButtonCancel:
	gui,%a_gui%:submit
	gui,%a_gui%:destroy
	
	tempInputBoxBut:=ActionInput_BoxAllGUIs[a_gui]
	
	
	if (tempInputBoxBut.IfDismiss=2)
	{
		logger("f0","Instance " tempInputBoxBut.instanceID " - " tempInputBoxBut.type " '" tempInputBoxBut.name "': Error! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.ElementID,tempInputBoxBut.ElementIDInInstance,"exception",lang("User dismissed the dialog"))
	}
	else
	{
		v_setVariable(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.varname,"") ;Set empty string as result
	
		logger("f0","Instance " tempInputBoxBut.instanceID " - " tempInputBoxBut.type " '" tempInputBoxBut.name "': Warning! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempInputBoxBut.instanceID,tempInputBoxBut.threadid,tempInputBoxBut.ElementID,tempInputBoxBut.ElementIDInInstance,"normal")
	}
	

	
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
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variable name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "UserInput", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Message")})
	parametersToEdit.push({type: "Edit", id: "message", default: lang("Please, write something"), multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Edit field")})
	parametersToEdit.push({type: "Checkbox", id: "OnlyNumbers", default: 0, label: lang("Only allow numbers")})
	parametersToEdit.push({type: "Checkbox", id: "MaskUserInput", default: 0, label: lang("Mask user's imput")})
	parametersToEdit.push({type: "Checkbox", id: "MultilineEdit", default: 0, label: lang("Use a multiline edit field")})
	parametersToEdit.push({type: "Label", label: lang("Count of lines"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "MultilineEditRows", default: 4, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Default value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "defaultText", default: "", multiline: true, content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Button Text")})
	parametersToEdit.push({type: "Edit", id: "ButtonLabel", default: lang("OK"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: 1, choices: [lang("No timeout"), lang("Define timeout")]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], default: 1})
	parametersToEdit.push({type: "Label", label: lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", choices: [lang("Normal") " - " lang("Make output variable empty"), lang("Throw exception")], default: 1})
	parametersToEdit.push({type: "Label", label: lang("Width and height")})
	;~ parametersToEdit.push({type: "Radio", id: "Size", default: 1, choices: [lang("Automatic"), lang("Define width and height")]}) ;No automatic size yet
	;~ parametersToEdit.push({type: "Label", label: lang("Width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 250], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", choices: [lang("Normal") " - " lang("Make output variable empty"), lang("Throw exception")], default: 1})
	
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
	if (strlen(GUISettingsOfElement%ID%message)>100)
	{
		return lang("Input_box") ": " GUISettingsOfElement%ID%title " - " substr(GUISettingsOfElement%ID%message,1,100) " ... "
	}
	else
		return lang("Input_box") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%message
	
}

CheckSettingsActionInput_Box(ID)
{
	global
	
	if (GUISettingsOfElement%ID%OnlyNumbers = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%MaskUserInput
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%MaskUserInput
	}
	
	if (GUISettingsOfElement%ID%MaskUserInput = 1) 
	{
		GuiControl,Disable,GUISettingsOfElement%ID%OnlyNumbers
		GuiControl,Disable,GUISettingsOfElement%ID%MultilineEdit
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%OnlyNumbers
		GuiControl,Enable,GUISettingsOfElement%ID%MultilineEdit
	}
	
	if (GUISettingsOfElement%ID%MultilineEdit = 1) 
	{
		GuiControl,Disable,GUISettingsOfElement%ID%MaskUserInput
		GuiControl,Enable,GUISettingsOfElement%ID%MultilineEditRows
	}
	else
	{
		if (GUISettingsOfElement%ID%OnlyNumbers = 0) 
			GuiControl,Enable,GUISettingsOfElement%ID%MaskUserInput
		GuiControl,Disable,GUISettingsOfElement%ID%MultilineEditRows
	}
	
	if (GUISettingsOfElement%ID%IsTimeout1 = 1) ;no timeout
	{
		GuiControl,Disable,GUISettingsOfElement%ID%TimeoutUnits
		GuiControl,Disable,GUISettingsOfElement%ID%Unit1
		GuiControl,Disable,GUISettingsOfElement%ID%Unit2
		GuiControl,Disable,GUISettingsOfElement%ID%Unit3
		GuiControl,Disable,GUISettingsOfElement%ID%OnTimeout1
		GuiControl,Disable,GUISettingsOfElement%ID%OnTimeout2
	}
	else ;Timeout
	{
		GuiControl,Enable,GUISettingsOfElement%ID%TimeoutUnits
		GuiControl,Enable,GUISettingsOfElement%ID%Unit1
		GuiControl,Enable,GUISettingsOfElement%ID%Unit2
		GuiControl,Enable,GUISettingsOfElement%ID%Unit3
		GuiControl,Enable,GUISettingsOfElement%ID%OnTimeout1
		GuiControl,Enable,GUISettingsOfElement%ID%OnTimeout2
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