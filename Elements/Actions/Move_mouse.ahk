iniAllActions.="Move_mouse|" ;Add this action to list of all actions on initialisation

runActionMove_mouse(InstanceID,ElementID,ElementIDInInstance)
{
	global
	
	if %ElementID%SendMode=1
		SendMode, Input
	else if %ElementID%SendMode=2
		SendMode, Event
	else if %ElementID%SendMode=3
		SendMode, Play
	
	if %ElementID%CoordMode=1
		CoordMode, Mouse, Screen
	else if %ElementID%CoordMode=2
		CoordMode, Mouse, Window
	else if %ElementID%CoordMode=3
		CoordMode, Mouse, Client

	if  %ElementID%CoordMode=4
		MouseMove,% %ElementID%Xpos,% %ElementID%Ypos,% %ElementID%speed,R
	else
		MouseMove,% %ElementID%Xpos,% %ElementID%Ypos,% %ElementID%speed
	
	MarkThatElementHasFinishedRunning(InstanceID,ElementID,ElementIDInInstance,"normal")
	return
}
getNameActionMove_mouse()
{
	return lang("Move_mouse")
}
getCategoryActionMove_mouse()
{
	return lang("User_simulation")
}

getParametersActionMove_mouse()
{
	global
	parametersToEdit:=["Label|" lang("Mouse position"),"Radio|1|CoordMode|" lang("Relative to screen") ";" lang("Relative to active window position") ";" lang("Relative to active window client position")  ";" lang("Relative to current mouse position"),"Label|" lang("Coordinates") " " lang("(x,y)"),"Text2|10;20|Xpos;Ypos","Label|" lang("Method"),"Radio|1|SendMode|" lang("Input mode") ";" lang("Event mode") ";" lang("Play mode"),"Label|" lang("Speed"),"Slider|2|speed|Range0-100 tooltip"]
	
	return parametersToEdit
}

GenerateNameActionMove_mouse(ID)
{
	global
	local tempstring
	
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
	
	return % lang("Move_mouse") "`n" tempstring
	
}

CheckSettingsActionMove_mouse(ID)
{
	if (GUISettingsOfElement%ID%Relatively = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode1
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode2
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode3
		GuiControl,Disable,GUISettingsOfElement%ID%CoordMode4
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode1
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode2
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode3
		GuiControl,Enable,GUISettingsOfElement%ID%CoordMode4
	}
	
	if (GUISettingsOfElement%ID%SendMode1 = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%speed
	}
	else
	{
		GuiControl,Enable,GUISettingsOfElement%ID%speed
	}
}