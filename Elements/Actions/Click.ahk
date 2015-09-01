iniAllActions.="Click|" ;Add this action to list of all actions on initialisation

runActionClick(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temprelative
	local tempButton
	local tempupdown
	local Xpos
	local Ypos
	local ClickCount:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%ClickCount)
	if ClickCount is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Click count is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Click count")))
		return
	}
	
	
	if %ElementID%SendMode=1
		SendMode, Input
	else if %ElementID%SendMode=2
		SendMode, Event
	else if %ElementID%SendMode=3
		SendMode, Play
	else
		MsgBox Unexpected error! Send mode not set!
	
	if %ElementID%DownUp=1
		tempupdown=
	else if %ElementID%DownUp=2
		tempupdown=D
	else if %ElementID%DownUp=3
		tempupdown=U
	
		
	if %ElementID%Button=1
		tempButton=Left
	else if %ElementID%Button=2
		tempButton=Right
	else if %ElementID%Button=3
		tempButton=Middle
	else if %ElementID%Button=4
		tempButton=WheelUp
	else if %ElementID%Button=5
		tempButton=WheelDown
	else if %ElementID%Button=6
		tempButton=WheelLeft
	else if %ElementID%Button=7
		tempButton=WheelRight
	else if %ElementID%Button=8
		tempButton=X1
	else if %ElementID%Button=9
		tempButton=X2
	else
		MsgBox Unexpected error! Unknown button
	
	if %ElementID%changePosition=1
	{
		if %ElementID%CoordMode=1
			CoordMode, Mouse, Screen
		else if %ElementID%CoordMode=2
			CoordMode, Mouse, Window
		else if %ElementID%CoordMode=3
			CoordMode, Mouse, Client

		if %ElementID%CoordMode=4
			temprelative=R
		
		Xpos:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Xpos)
		Ypos:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%Ypos)
		if Xpos is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! X position is not a number.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("X position")))
			return
		}
		if Ypos is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Y position is not a number.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Y position")))
			return
		}
		
		;MsgBox % tempButton " - " %ElementID%Xpos " - " %ElementID%Ypos " - "  %ElementID%ClickCount " - " %ElementID%speed  " - " tempupdown " - " temprelative 
		MouseClick,%tempButton%,% Xpos,% Ypos,% ClickCount,% %ElementID%speed,%tempupdown%,%temprelative%
	}
	else
		MouseClick,%tempButton%,,,% %ElementID%ClickCount,,%tempupdown%
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionClick()
{
	return lang("Click")
}
getCategoryActionClick()
{
	return lang("User_simulation")
}

getParametersActionClick()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")], result: "number"})
	parametersToEdit.push({type: "Label", label: lang("Click count")})
	parametersToEdit.push({type: "Edit", id: "ClickCount", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Event")})
	parametersToEdit.push({type: "Radio", id: "DownUp", default: 1, choices: [lang("Click (Down and up)"), lang("Keep down"), lang("Release only")]})
	parametersToEdit.push({type: "Label", label: lang("Mouse position")})
	parametersToEdit.push({type: "Checkbox", id: "changePosition", default: 0, label: lang("Move mouse before clicking")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position"), lang("Relative to current mouse position")]})
	parametersToEdit.push({type: "Label", label: lang("Coordinates") lang("(x,y)"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionClickMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, choices: [lang("Input mode"), lang("Event mode"), lang("Play mode")]})
	parametersToEdit.push({type: "Label", label: lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})


	return parametersToEdit
}

ActionClickMouseTracker()
{
	MouseTracker({ImportMousePos:"Yes",ParCoordMode:"CoordMode",ParMousePosX:"xpos", ParMousePosY:"ypos"})
}


GenerateNameActionClick(ID)
{
	global
	local tempstring
	
	if GUISettingsOfElement%ID%Button=1
		tempstring.=lang("Left button") ". " 
	else if GUISettingsOfElement%ID%Button=2
		tempstring.=lang("Right button") ". " 
	else if GUISettingsOfElement%ID%Button=3
		tempstring.=lang("Middle button") ". "
	else if GUISettingsOfElement%ID%Button=4
		tempstring.=lang("Wheel up") ". "
	else if GUISettingsOfElement%ID%Button=5
		tempstring.=lang("Wheel down") ". " 
	else if GUISettingsOfElement%ID%Button=6
		tempstring.=lang("Wheel left") ". "
	else if GUISettingsOfElement%ID%Button=7
		tempstring.=lang("Wheel right") ". " 
	else if GUISettingsOfElement%ID%Button=8
		tempstring.=lang("4th button") ". " 
	else if GUISettingsOfElement%ID%Button=9
		tempstring.=lang("5th button") ". " 
	
	if GUISettingsOfElement%ID%ClickCount!=1
	{
		tempstring.=lang("%1% times",GUISettingsOfElement%ID%ClickCount) ". "
	}
	
	
	
	if GUISettingsOfElement%ID%CoordMode4=1
	{
		if GUISettingsOfElement%ID%Xpos>0
			tempstring.=lang("%1% pixel right",GUISettingsOfElement%ID%Xpos) " "
		else if GUISettingsOfElement%ID%Xpos<0
			tempstring.=lang("%1% pixel left",-GUISettingsOfElement%ID%Xpos) " "
		if GUISettingsOfElement%ID%Ypos>0
			tempstring.=lang("%1% pixel down",GUISettingsOfElement%ID%Ypos) ". "
		else if GUISettingsOfElement%ID%Ypos<0
			tempstring.=lang("%1% pixel up",-GUISettingsOfElement%ID%Ypos) ". "
	}
	else
	{
		tempstring.=lang("Position: x%1%, y%2%",GUISettingsOfElement%ID%Xpos,GUISettingsOfElement%ID%Ypos) ". "
		
	}
	
	if GUISettingsOfElement%ID%DownUp2=1
	{
		
		tempstring.=lang("Keep down") ". "
	}
	else if GUISettingsOfElement%ID%DownUp3=1
	{
		tempstring.=lang("Release only") ". "
	}
	
	if GUISettingsOfElement%ID%speed=0
		tempstring.=lang("Instantly")
	else if GUISettingsOfElement%ID%speed<=2
		tempstring.=lang("Very fast")
	else if GUISettingsOfElement%ID%speed<=10
		tempstring.=lang("Fast")
	else if GUISettingsOfElement%ID%speed<=40
		tempstring.=lang("Slow")
	else if GUISettingsOfElement%ID%speed<=100
		tempstring.=lang("Very slow")
	
	return % lang("Click") ": " tempstring
	
}

CheckSettingsActionClick(ID)
{
	if (GUISettingsOfElement%ID%changePosition = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%Xpos
		GuiControl,Enable,GUISettingsOfElement%ID%Ypos
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode1
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode2
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode3
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode4
		
		
		if (GUISettingsOfElement%ID%SendMode1 = 1)
		{
			GuiControl,Disable,GUISettingsOfElement%ID%speed
		}
		else
		{
			GuiControl,Enable,GUISettingsOfElement%ID%speed
		}
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode1
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode2
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode3
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode4
		GuiControl,Disable,GUISettingsOfElement%ID%speed
		GuiControl,Disable,GUISettingsOfElement%ID%Xpos
		GuiControl,Disable,GUISettingsOfElement%ID%Ypos
	}
}
