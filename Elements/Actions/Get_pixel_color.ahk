iniAllActions.="Get_pixel_color|" ;Add this action to list of all actions on initialisation

runActionGet_pixel_color(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	
	local x
	local y
	local x1
	local temp
	local tempcolor
	local method
	
	
	
	if %ElementID%OutputRGB
	{
		local varnameRGB:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameRGB)
		if not v_CheckVariableName(varnameRGB)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameRGB "' is not valid")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameRGB)) )
			return
		}
	}
	if %ElementID%OutputSeparate
	{
		local varnameR:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameR)
		local varnameG:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameG)
		local varnameB:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameB)
		if not v_CheckVariableName(varnameR)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameR "' is not valid")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameR)) )
			return
		}
		if not v_CheckVariableName(varnameG)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameG "' is not valid")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameG)) )
			return
		}
		if not v_CheckVariableName(varnameB)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameB "' is not valid")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameB)) )
			return
		}
	}
	
	;Set coord mode and region
	
	if %ElementID%CoordMode=1
	{
		CoordMode, Pixel, Screen
	}
	else if %ElementID%CoordMode=2
	{
		CoordMode, Pixel, Window
	}
	else if %ElementID%CoordMode=3
	{
		CoordMode, Pixel, Client
	}
	
	x:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%CoordinateX)
	if x is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x)) )
		return
	}
	y:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%Coordinatey)
	if y is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y)) )
		return
	}
	
	
	
	
	if %ElementID%Method=2
	{
		Method=Alt
	}
	else if %ElementID%Method=3
	{
		Method=Slow
	}
	
	;~ MsgBox %x1%,%y1%,%x2%,%y2%,%ColorID%,%variation%,RGB %WhetherFastMode%
	PixelGetColor,tempcolor,%x%,%y%,RGB %Method%
	
	if ErrorLevel
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! An unknown problem occured")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("An unknown problem occured"))
	}
	
	if %ElementID%OutputRGB
	{
		
		v_SetVariable(InstanceID,ThreadID,varnameRGB,tempcolor)
	}
	if %ElementID%OutputSeparate
	{
		temp:=SubStr(tempcolor,1,4)
		temp+=0
		v_SetVariable(InstanceID,ThreadID,varnameR,temp)
		temp:=("0x" SubStr(tempcolor,5,2))
		temp+=0
		v_SetVariable(InstanceID,ThreadID,varnameG,temp)
		temp:=("0x" SubStr(tempcolor,7,2))
		temp+=0
		v_SetVariable(InstanceID,ThreadID,varnameB,temp)
		
	}
	
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionGet_pixel_color()
{
	return lang("Get_pixel_color")
}
getCategoryActionGet_pixel_color()
{
	return lang("Image")
}

getParametersActionGet_pixel_color()
{
	global
	
	parametersToEdit:=["Label|" lang("Output variables"),"Checkbox|1|OutputRGB|" lang("Write RGB value in output variable"),"Checkbox|0|OutputSeparate|" lang("Write each color in separate variable"),"SmallLabel|"  lang("RGB value") ,"Text|ColorRBG|varnameRGB","SmallLabel|"  lang("Red, green, blue"),"Text3|ColorRed;ColorBlue;ColorGreen|varnameR;varnameG;varnameB","Label|" lang("Position"),"Radio|1|CoordMode|" lang("Relative to screen") ";" lang("Relative to active window position") ";" lang("Relative to active window client position"),"SmallLabel|"  "x, y", "Text2|10;20|CoordinateX;CoordinateY","button|ActionGet_pixel_colorMouseTracker|MouseTracker|" lang("Get coordinates"),"Label|" lang("Method"),"Radio|1|Method|" lang("Default method") ";" lang("Alternative method") ";" lang("Slow method")]
	return parametersToEdit
}

ActionGet_pixel_colorMouseTracker()
{
	MouseTracker({ImportMousePos:"Yes",ParCoordMode:"CoordMode",ParMousePosX:"CoordinateX", ParMousePosY:"CoordinateY"})
}


GenerateNameActionGet_pixel_color(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Get_pixel_color") " - " GUISettingsOfElement%ID%ColorID 
	
}

CheckSettingsActionGet_pixel_color(ID)
{
	static previousRGB=0
	static previousEach=0
	
	if (GUISettingsOfElement%ID%OutputRGB=0 and GUISettingsOfElement%ID%OutputSeparate=0)
	{
		if previousEach=1
		{
			GuiControl,,GUISettingsOfElement%ID%OutputRGB,1
			previousRGB=1
			previousEach=0
		}
		else
		{
			GuiControl,,GUISettingsOfElement%ID%OutputSeparate,1
			previousEach=1
			previousRGB=0
		}
		gui,submit,nohide
	}
	else
	{
		previousRGB:=GUISettingsOfElement%ID%OutputRGB
		previousEach:=GUISettingsOfElement%ID%OutputSeparate
	}
	
	
	
	
	
	
	if (GUISettingsOfElement%ID%OutputRGB = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%varnameRGB
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%varnameRGB
	}
	
	if (GUISettingsOfElement%ID%OutputSeparate = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%varnameR
		GuiControl,Enable,GUISettingsOfElement%ID%varnameB
		GuiControl,Enable,GUISettingsOfElement%ID%varnameG
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%varnameR
		GuiControl,Disable,GUISettingsOfElement%ID%varnameB
		GuiControl,Disable,GUISettingsOfElement%ID%varnameG
	}
		
	
		
	
	
}

