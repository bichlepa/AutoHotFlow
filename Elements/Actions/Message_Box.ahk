iniAllActions.="Message_Box|" ;Add this action to list of all actions on initialisation
ActionMessage_BoxAllGUIs:=Object()

runActionMessage_Box(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	
	local tempText:=v_replaceVariables(InstanceID,ThreadID,%ElementID%message,"normal")
	local tempTitle:=v_replaceVariables(InstanceID,ThreadID,%ElementID%title,"normal")
	local tempButtonLabel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabel,"normal")
	local tempButtonLabelCancel:=v_replaceVariables(InstanceID,ThreadID,%ElementID%ButtonLabelcancel,"normal")
	local tempTimeoutUnits:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%TimeoutUnits)
	;~ local tempXpos:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Xpos)
	;~ local tempYpos:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Ypos)
	local tempWidth:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Width)
	local tempHeight:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Height)
	
	if tempTitle=
		tempTitle:=Flowname
	
	local tempEndTime
	local tempGUIHWND
	local TempTextHWND
	local tempx
	local tempy
	local tempw
	local temph
	local minresultrating
	local minresultw
	local minresulth
	local volume
	local difference
	local rating
	local toowide
	local toohigh
	local MaxTextHeight
	local MaxTextWidth
	local willbreak:=false
	
	if tempButtonLabel=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Button label is not specified.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is empty.",lang("Button label")))
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
	tempNew.insert("ButtonLabel",tempButtonLabel)
	tempNew.insert("IsTimeout",%ElementID%IsTimeout)
	tempNew.insert("OnTimeout",%ElementID%OnTimeout)
	tempNew.insert("TimeoutUnits",tempTimeoutUnits)
	tempNew.insert("Unit",%ElementID%Unit)
	tempNew.insert("IfDismiss",%ElementID%IfDismiss)
	tempNew.insert("Width",%ElementID%Width)
	tempNew.insert("Height",%ElementID%Height)
	
	
	;Create a gui label. This label will always be unique. 
	local tempGUILabel:="GUI_MessageBox_" instanceID "_" ThreadID "_" ElementID "_" ElementIDInInstance 
	
	gui,%tempGUILabel%:margin,10,10
	;Create GUI
	;~ gui,%tempGUILabel%:+LabelMessageBoxGUI ;This label leads to a jump label beneath. It's needed if user closes the window
	
	if %ElementID%Size=1 ;autosize
	{
		SysGet,MonitorWorkArea, MonitorWorkArea, 1

		MaxTextHeight:=(MonitorWorkAreaBottom -MonitorWorkAreaTop) -150
		if %ElementID%IsTimeout=2
			MaxTextHeight-=10 +15
		MaxTextWidth:=(MonitorWorkAreaRight -MonitorWorkAreaLeft)-50
		
		;Find the best size, by trying out multiple width, check the height and rate the size.
		loop,10
		{
			tempw:=round(MaxTextWidth-(A_Index-1)*MaxTextWidth/10)
			gui,%tempGUILabel%:add,edit,y0 x0 w%tempw% VScroll vText%A_Index% hwndTempTextHWND, % tempText
			controlgetpos,,,tempw,temph,,ahk_id %TempTextHWND%
			;~ gui,%tempGUILabel%:show, AutoSize
			;~ MsgBox %  tempw " - " temph " -- " volume " - " difference " - " toowide " - "  toohigh " -- "   rating
			
			volume:=tempw*temph
			difference:=abs(2*temph-tempw)
			toowide=0
			toohigh=0
			if (tempw>MaxTextWidth)
			{
				toowide:=tempw-MaxTextWidth
				gui,%tempGUILabel%:add,edit,y0 x0 w%MaxTextWidth% VScroll vText_B%A_Index% hwndTempTextHWND, % tempText
				controlgetpos,,,tempw,temph,,ahk_id %TempTextHWND%
				volume:=tempw*temph
				difference:=abs(2*temph-tempw)
				if (temph>MaxTextHeight)
					toohigh:=temph-MaxTextHeight
				willbreak:=true ;It has no sense to look whether a smaller wide is possible. It also increases performance
				;~ gui,%tempGUILabel%:show
			;~ MsgBox %  tempw " - " temph " -- " volume " - " difference " - " toowide " - "  toohigh " -- "   rating
			}
			else if (temph>MaxTextHeight)
				toohigh:=temph-MaxTextHeight
			rating:=volume + difference*100 + toohigh*100000 + toowide* 100000
			;~ gui,%tempGUILabel%:show
			;~ MsgBox %  tempw " - " temph " -- " volume " - " difference " - " toowide " - "  toohigh " -- "   rating
			if (a_index=1 or minresultrating>rating)
			{
				minresultrating:=rating
				minresultw:=tempw
				minresulth:=temph
				minresulttoohigh:=toohigh
				minresulttoowide:=toowide
			}
			
			guicontrol,hide,Text%A_Index%
			if willbreak
				break
		}
		
		gui,%tempGUILabel%:destroy
		
		gui,%tempGUILabel%:+LabelActionMessageBoxGUI ;This label leads to a jump label beneath. It's needed if user closes the window
		if (minresulttoohigh=0 and minresulttoowide=0)
		{
			if minresulth<100
			minresulth=100
			gui,%tempGUILabel%:add,edit, w%minresultw% h%minresulth% vText hwndTempTextHWND, % tempText
		}
		else
		{
			if (minresulttoohigh=0)
			{
				if minresulth<100
					minresulth=100
				gui,%tempGUILabel%:add,edit, ReadOnly  w%MaxTextWidth% h%minresulth% vText hwndTempTextHWND, % tempText
			}
			else
				gui,%tempGUILabel%:add,edit, ReadOnly  w%minresultw% h%MaxTextHeight% vText hwndTempTextHWND, % tempText
		}
		
		gui,%tempGUILabel%: +hwndtempGUIHWND
		
		gui,%tempGUILabel%:show,hide AutoSize
		
		WinGetPos,,,tempActionMessageBoxGUIW,tempActionMessageBoxGUIH,ahk_id %tempGUIHWND%
		;~ MsgBox % tempActionMessageBoxGUIW " - " tempGUIHWND
		tempw:=tempActionMessageBoxGUIW-20
		
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
			
			tempw:=round((tempw-10)/2)
			gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gActionMessage_BoxButtonOK vActionMessage_BoxButtonOK Default ,% tempButtonLabel
			gui,%tempGUILabel%:add,button,X+10 w%tempw% h30  gActionMessage_BoxButtonCancel vActionMessage_BoxButtonCancel  ,% tempButtonLabelCancel
		}
		else
			gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gActionMessage_BoxButtonOK vActionMessage_BoxButtonOK Default ,% tempButtonLabel
		
		

		guicontrol,%tempGUILabel%:focus,ActionMessage_BoxButtonOK
		gui,%tempGUILabel%:show,AutoSize,% tempTitle
		
	}
	else ;Given size
	{
		if tempWidth is not number
		{
			gui,%tempGUILabel%:Destroy
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Width " tempWidth " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Width '%1%'",tempWidth)) )
			return
		}
		if tempHeight is not number
		{
			gui,%tempGUILabel%:Destroy
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Height " tempHeight " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Height '%1%'",tempHeight)) )
			return
		}
		
		
		gui,%tempGUILabel%:+LabelActionMessageBoxGUI ;This label leads to a jump label beneath. It's needed if user closes the window
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
			tempw:=round((tempw-10)/2)
			gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gActionMessage_BoxButtonOK vActionMessage_BoxButtonOK Default ,% tempButtonLabel
			gui,%tempGUILabel%:add,button,X+10 w%tempw% h30  gActionMessage_BoxButtonCancel vActionMessage_BoxButtonCancel  ,% tempButtonLabelCancel
		}
		else
			gui,%tempGUILabel%:add,button,x10 w%tempw% h30  gActionMessage_BoxButtonOK vActionMessage_BoxButtonOK Default ,% tempButtonLabel
		
		
		guicontrol,%tempGUILabel%:focus,ActionMessage_BoxButtonOK
		gui,%tempGUILabel%:show,h%tempHeight% w%tempWidth% ,% tempTitle
		
	}
	
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
	ActionMessage_BoxAllGUIs.insert(tempGUILabel,tempNew)
	
	;Set timer if a timeout is set
	if %ElementID%IsTimeout=2
		settimer,ActionMessage_BoxTimeoutTimer,-1
	;~ ActionMessage_Box_TimeoutTimercntr=0
	return
	
	ActionMessage_BoxTimeoutTimer:
	
	ActionMessage_Box_TimeoutTimerNextTime:=""
	ActionMessage_Box_TimeoutTimerFoundSth:=false
	;~ ToolTip,% ActionMessage_Box_TimeoutTimercntr++
	
	
	for tempMessage_BoxTimeout_OneGUIID, tempMessage_BoxTimeout_OneParameterList in ActionMessage_BoxAllGUIs
	{
		
		if tempMessage_BoxTimeout_OneParameterList.IsTimeout=2
		{
			ActionMessage_Box_TimeoutTimerFoundSth:=true
			if (tempMessage_BoxTimeout_OneParameterList.EndTime <= (A_TickCount))
			{
				;~ MsgBox % tempMessage_BoxTimeout_OneParameterList.EndTime " - " A_TickCount
				gui,%tempMessage_BoxTimeout_OneGUIID%:destroy
				if (tempMessage_BoxTimeout_OneParameterList.OnTimeout=2)
				{
					
					logger("f0","Instance " tempMessage_BoxTimeout_OneParameterList.instanceID " - " tempMessage_BoxTimeout_OneParameterList.type " '" tempMessage_BoxTimeout_OneParameterList.name "': Error! Timout reached")
					MarkThatElementHasFinishedRunning(tempMessage_BoxTimeout_OneParameterList.instanceID,tempMessage_BoxTimeout_OneParameterList.threadid,tempMessage_BoxTimeout_OneParameterList.ElementID,tempMessage_BoxTimeout_OneParameterList.ElementIDInInstance,"exception",lang("Timout reached"))
				}
				else
				{
					;~ MsgBox % strobj(tempMessage_BoxTimeout_OneParameterList)
					logger("f0","Instance " tempMessage_BoxTimeout_OneParameterList.instanceID " - " tempMessage_BoxTimeout_OneParameterList.type " '" tempMessage_BoxTimeout_OneParameterList.name "': Warning! Timout reached")
					MarkThatElementHasFinishedRunning(tempMessage_BoxTimeout_OneParameterList.instanceID,tempMessage_BoxTimeout_OneParameterList.threadid,tempMessage_BoxTimeout_OneParameterList.ElementID,tempMessage_BoxTimeout_OneParameterList.ElementIDInInstance,"normal")
				}
				ActionMessage_BoxAllGUIs.Remove(tempMessage_BoxTimeout_OneGUIID)
			}
			else
			{
				;Find out the next timestamp until the counter of any of the currently visible message boxes must be decremented.
				tempActionMessage_Box_NextTime:=tempMessage_BoxTimeout_OneParameterList.EndTime - A_TickCount
				guicontrol,%tempMessage_BoxTimeout_OneGUIID%:,TimeoutText, % lang("Timeout") ": " tempActionMessage_Box_NextTime//1000 +1 " " lang("seconds") 
				tempActionMessage_Box_NextTime:=round(((tempActionMessage_Box_NextTime/1000)-(tempActionMessage_Box_NextTime//1000))*1000 +10)
				if (ActionMessage_Box_TimeoutTimerNextTime="" or ActionMessage_Box_TimeoutTimerNextTime > tempActionMessage_Box_NextTime)
				{
					ActionMessage_Box_TimeoutTimerNextTime:=tempActionMessage_Box_NextTime
				}
				
				
			}
		}
		
	}
	
	;~ ToolTip %ActionMessage_Box_TimeoutTimerNextTime% --
	if (ActionMessage_Box_TimeoutTimerFoundSth)
	{
		
		if ActionMessage_Box_TimeoutTimerNextTime>0
		{
			;~ ToolTip % "-" round(ActionMessage_Box_TimeoutTimerNextTime)
			SetTimer,ActionMessage_BoxTimeoutTimer,% "-" ActionMessage_Box_TimeoutTimerNextTime
			;~ SetTimer,ActionMessage_BoxTimeoutTimer,-
		}
		else
			SetTimer,ActionMessage_BoxTimeoutTimer,-1
	}
	else
		SetTimer,ActionMessage_BoxTimeoutTimer,off
	return

	
	
	ActionMessage_BoxButtonOK:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempMessageBoxBut:=ActionMessage_BoxAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	MarkThatElementHasFinishedRunning(tempMessageBoxBut.instanceID,tempMessageBoxBut.threadid,tempMessageBoxBut.ElementID,tempMessageBoxBut.ElementIDInInstance,"normal")
	
	;Remove this GUI from the list of all GUIs
	ActionMessage_BoxAllGUIs.Remove(a_gui)
	
	return
	
	ActionMessage_BoxButtonCancel:
	ActionMessageBoxGUIclose:
	
	gui,%a_gui%:destroy
	
	;Get the parameter list for the current GUI from the list of all GUIs
	tempMessageBoxBut:=ActionMessage_BoxAllGUIs[a_gui]
	
	;~ MsgBox % a_gui " - " temp.instanceID
	if (tempMessageBoxBut.IfDismiss=2)
	{
		logger("f0","Instance " tempMessageBoxBut.instanceID " - " tempMessageBoxBut.type " '" tempMessageBoxBut.name "': Error! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempMessageBoxBut.instanceID,tempMessageBoxBut.threadid,tempMessageBoxBut.ElementID,tempMessageBoxBut.ElementIDInInstance,"exception",lang("User dismissed the dialog"))
	}
	else
	{
		logger("f0","Instance " tempMessageBoxBut.instanceID " - " tempMessageBoxBut.type " '" tempMessageBoxBut.name "': Warning! User dismissed the dialog")
		MarkThatElementHasFinishedRunning(tempMessageBoxBut.instanceID,tempMessageBoxBut.threadid,tempMessageBoxBut.ElementID,tempMessageBoxBut.ElementIDInInstance,"normal")
	}
	
	ActionMessage_BoxAllGUIs.Remove(a_gui)
	return
}

stopActionMessage_Box(ID)
{
	global
	;Go through all GUI Labels that are in the list of all GUIs
	for tempActionMessageBoxGuiLabel, tempActionMessageBoxSettings in ActionMessage_BoxAllGUIs
	{
		gui,%tempActionMessageBoxGuiLabel%:destroy ;Close the window
		
	}
	
	ActionMessage_BoxAllGUIs:=Object() ;Delete all elements from the list of all GUIs
	
}



getParametersActionMessage_Box()
{
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Title")})
	parametersToEdit.push({type: "Edit", id: "title", default: lang("Title"), content: "String"})
	parametersToEdit.push({type: "Label", label: lang("Message")})
	parametersToEdit.push({type: "Edit", id: "message", default: lang("Message"), content: "String", multiline: true})
	parametersToEdit.push({type: "Label", label: lang("Button Text")})
	parametersToEdit.push({type: "Edit", id: "ButtonLabel", default: lang("OK"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Timeout")})
	parametersToEdit.push({type: "Radio", id: "IsTimeout", default: 1, choices: [lang("No timeout"), lang("Define timeout")]})
	parametersToEdit.push({type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Radio", id: "Unit", choices: [lang("Seconds"), lang("Minutes"), lang("Hours")], default: 1})
	parametersToEdit.push({type: "Label", label: lang("Result on timeout"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "OnTimeout", choices: [lang("Normal"), lang("Throw exception")], default: 1})
	
	;~ parametersToEdit.push({type: "Label", label: lang("Position")})
	;~ parametersToEdit.push({type: "Radio", id: "Position", default: 1, choices: [lang("In the middle of screen"), lang("Beneath current mouse position"), lang("Define coordinates")]})
	;~ parametersToEdit.push({type: "Label", label: lang("Coordinates") " (x,y)", size: "small"})
	;~ parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: ["A_ScreenWidth/2", "A_ScreenHeight/2"]})
	;~ parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionMove_WindowMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Width and height")})
	parametersToEdit.push({type: "Radio", id: "Size", default: 1, choices: [lang("Automatic"), lang("Define width and height")]})
	parametersToEdit.push({type: "Label", label: lang("Width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Cancelling")})
	parametersToEdit.push({type: "Checkbox", id: "ShowCancelButton", default: 0, label: lang("Show cancel button")})
	parametersToEdit.push({type: "Label", label: lang("Button text"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "ButtonLabelCancel", default: lang("Cancel"), content: "String", WarnIfEmpty: true })
	parametersToEdit.push({type: "Label", label: lang("Result if cancelled"), size: "small"})
	parametersToEdit.push({type: "Radio", id: "IfDismiss", choices: [lang("Normal"), lang("Throw exception")], default: 1})
	
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
	if (strlen(GUISettingsOfElement%ID%message)>100)
	{
		return lang("Message_Box") ": " GUISettingsOfElement%ID%title " - " substr(GUISettingsOfElement%ID%message,1,100) " ... "
	}
	else
		return lang("Message_Box") ": " GUISettingsOfElement%ID%title " - " GUISettingsOfElement%ID%message
	
}

CheckSettingsActionMessage_Box(ID)
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
	
	if (GUISettingsOfElement%ID%Size1 = 1) ;automatic size
	{

		GuiControl,Disable,GUISettingsOfElement%ID%Width
		GuiControl,Disable,GUISettingsOfElement%ID%Height
	}
	else ;custom 
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Width
		GuiControl,Enable,GUISettingsOfElement%ID%Height
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