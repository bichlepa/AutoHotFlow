iniAllActions.="Drag_with_mouse|" ;Add this action to list of all actions on initialisation

runActionDrag_with_mouse(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local temprelative
	local tempButton
	local tempupdown
	local delay:=v_evaluateExpression(InstanceID,ThreadID,%ElementID%delay)
	if delay is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Delay is not a number.")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Delay")))
		return
	}
	
	if %ElementID%SendMode=1
	{
		SendMode, Input
		SetMouseDelay,%delay%
	}
	else if %ElementID%SendMode=2
	{
		SendMode, Event
		SetMouseDelay,%delay%
	}
	else if %ElementID%SendMode=3
	{
		SendMode, Play
		SetMouseDelay,%delay%,play
	}
	
	
	
	
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
		MsgBox Unexpected error! unknown button
	
	
	if %ElementID%CoordMode=1
		CoordMode, Mouse, Screen
	else if %ElementID%CoordMode=2
		CoordMode, Mouse, Window
	else if %ElementID%CoordMode=3
		CoordMode, Mouse, Client

	if %ElementID%CoordMode=4
		temprelative=R
	
	
	;MsgBox % tempButton " - " %ElementID%Xpos " - " %ElementID%Ypos " - "  %ElementID%Drag_with_mouseCount " - " %ElementID%speed  " - " tempupdown " - " temprelative 
	MouseClickDrag,%tempButton%,% %ElementID%Xposfrom,% %ElementID%Yposfrom,% %ElementID%Xpos,% %ElementID%Ypos,% %ElementID%speed,%temprelative%
	
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionDrag_with_mouse()
{
	return lang("Drag_with_mouse")
}
getCategoryActionDrag_with_mouse()
{
	return lang("User_simulation")
}

getParametersActionDrag_with_mouse()
{
	global
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Which button")})
	parametersToEdit.push({type: "DropDown", id: "Button", default: 1, choices: [lang("Left button"), lang("Right button"), lang("Middle Button"), lang("Wheel up"), lang("Wheel down"), lang("Wheel left"), lang("Wheel right"), lang("4th mouse button (back)"), lang("5th mouse button (forward)")], result: "number"})
	parametersToEdit.push({type: "Label", label: lang("Position")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position"), lang("Relative to current mouse position")]})
	parametersToEdit.push({type: "Label", label: lang("Start coordinates") lang("(x,y)")})
	parametersToEdit.push({type: "Edit", id: ["XposFrom", "YposFrom"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("End coordinates") lang("(x,y)")})
	parametersToEdit.push({type: "Edit", id: ["Xpos", "Ypos"], default: [100, 200], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionDrag_with_MouseMouseTracker", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Radio", id: "SendMode", default: 1, choices: [lang("Input mode"), lang("Event mode"), lang("Play mode")]})
	parametersToEdit.push({type: "Label", label: lang("Speed")})
	parametersToEdit.push({type: "Slider", id: "speed", default: 2, options: "Range0-100 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Delay in ms")})
	parametersToEdit.push({type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true})


	
	return parametersToEdit
}

ActionDrag_with_MouseMouseTracker()
{
	MouseTracker({ImportMousePos:"Yes",SelectParMousePos:"Yes",SelectParMousePosLabelPos1:lang("Import Start coordinates"),SelectParMousePosLabelPos2:lang("Import End coordinates"),ParCoordMode:"CoordMode",ParMousePosX:"xposFrom", ParMousePosY:"yposFrom",ParMousePosX2:"xpos", ParMousePosY2:"ypos"})
}

GenerateNameActionDrag_with_mouse(ID)
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
	

	tempstring.=lang("Start coordinates") ": " 
	
	if GUISettingsOfElement%ID%CoordMode4=1
	{
		if GUISettingsOfElement%ID%Xpos>0
			tempstring.=lang("%1% pixel right",GUISettingsOfElement%ID%XposFrom) " "
		else if GUISettingsOfElement%ID%Xpos<0
			tempstring.=lang("%1% pixel left",-GUISettingsOfElement%ID%XposFrom) " "
		if GUISettingsOfElement%ID%Ypos>0
			tempstring.=lang("%1% pixel down",GUISettingsOfElement%ID%YposFrom) ". "
		else if GUISettingsOfElement%ID%Ypos<0
			tempstring.=lang("%1% pixel up",-GUISettingsOfElement%ID%YposFrom) ". "
	}
	else
	{
		tempstring.=lang("x%1%, y%2%",GUISettingsOfElement%ID%Xpos,GUISettingsOfElement%ID%YposFrom) ". "
		
	}
	
	tempstring.=lang("End coordinates") ": " 
	
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
		tempstring.=lang("x%1%, y%2%",GUISettingsOfElement%ID%Xpos,GUISettingsOfElement%ID%Ypos) ". "
		
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
	
	return % lang("Drag_with_mouse") "`n" tempstring
	
}

CheckSettingsActionDrag_with_mouse(ID)
{
	
		
	
	
	if (GUISettingsOfElement%ID%SendMode2 != 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%speed
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%speed
	}
	
	
}