iniAllActions.="Search_pixel|" ;Add this action to list of all actions on initialisation

runActionSearch_pixel(InstanceID,ThreadID,ElementID,ElementIDInInstance)
{
	global
	local tempOptions=""
	local varnameX:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameX)
	local varnameY:=v_replaceVariables(InstanceID,ThreadID,%ElementID%varnameY)
	local VirtualWidth
	local VirtualHeight
	local Virtualx1
	local Virtualy1
	local foundx
	local foundy
	local x1
	local x2
	local y1
	local y2
	local winid
	local temp
	local variation
	local WhetherFastMode
	local WhetherSpecifiedRegion:=false
	
	

	
	if not v_CheckVariableName(varnameX)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameX "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameX)) )
		return
	}
	if not v_CheckVariableName(varnameY)
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Ouput variable name '" varnameY "' is not valid")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not valid",lang("Ouput variable name '%1%'",varnameY)) )
		return
	}
	
	;Set coord mode and region
	
	if %ElementID%CoordMode=1
	{
		CoordMode, Pixel, Screen
		if %ElementID%WholeScreen=1
		{
			
			if %ElementID%AllScreens=1
			{
				SysGet, VirtualWidth, 78
				SysGet, VirtualHeight, 79
				SysGet, Virtualx1, 76
				SysGet, Virtualy1, 77
				x1:=Virtualx1
				y1:=Virtualy1
				x2:=VirtualWidth
				y2:=VirtualHeight
			}
			else ;Only main screen
			{
				x1:=0
				y1:=0
				x2:=A_ScreenWidth
				y2:=A_ScreenHeight
			}
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	else if %ElementID%CoordMode=2
	{
		CoordMode, Pixel, Window
		
		if %ElementID%WholeScreen=1
		{
			x1:=0
			y1:=0
			wingetpos,,,x2,y2,A
			
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	else if %ElementID%CoordMode=3
	{
		CoordMode, Pixel, Client
		
		if %ElementID%WholeScreen=1
		{
			x1:=0
			y1:=0
			
			;Get window client size
			winget,wineid,id,a
			VarSetCapacity(temp, 16)
			DllCall("GetClientRect", "uint", wineid, "uint", &temp)
			x2 := NumGet(temp, 8, "int")
			y2 := NumGet(temp, 12, "int")
			
			;~ MsgBox % wineid " -- " tempWinPos " - " x2 " . " y2 " - " format("{1:X}",tempWinPos)
		}
		else ;Specified region
		{
			WhetherSpecifiedRegion:=true
		}
	}
	
	if (WhetherSpecifiedRegion=true)
	{
		x1:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%x1)
		if x is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x1)) )
			return
		}
		y1:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y1)
		if x is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y1)) )
			return
		}
		x2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%x2)
		if x is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x2)) )
			return
		}
		y2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y2)
		if x is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y2)) )
			return
		}
		
	}
	
	temp:=%ElementID%Variation
	if temp is not number
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variation " temp " is not a number")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Variation '%1%'",temp)) )
		return
	}
	if temp>0
	{
		variation:=temp
	}
	
	
	ColorID:=v_ReplaceVariables(InstanceID,ThreadID,%ElementID%ColorID)
	;TODO: check whether the string contains spaces
	if ColorID=
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Pixel color is not a specified")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Pixel color",temp)) )
		return
	}
	
	if %ElementID%FastMode=1
	{
		WhetherFastMode=Fast
	}
	
	;~ MsgBox %x1%,%y1%,%x2%,%y2%,%ColorID%,%variation%,RGB %WhetherFastMode%
	PixelSearch,foundx,foundy,%x1%,%y1%,%x2%,%y2%,% ColorID,% variation,RGB %WhetherFastMode%
	
	if ErrorLevel=2
	{
		
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Something prevented the command from conducting the search")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Something prevented the command from conducting the search"))
		return
		
	}
	if ErrorLevel=1
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Pixel '" ColorID "' not found")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Pixel '%1%' not found",ColorID))
		return
		
	}
	
	v_SetVariable(InstanceID,ThreadID,varnameX,foundx)
	v_SetVariable(InstanceID,ThreadID,varnameY,foundy)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionSearch_pixel()
{
	return lang("Search_pixel")
}
getCategoryActionSearch_pixel()
{
	return lang("Image")
}

getParametersActionSearch_pixel()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variables") (x, y)})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["PixelPosX", "PixelPosY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position")]})
	parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 0, label: lang("Whole screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 0, label: lang("All screens")})
	parametersToEdit.push({type: "Label", label: lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "ActionSearch_pixelGetCoordinates", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Pixel color") (RGB)})
	parametersToEdit.push({type: "Edit", id: "ColorID", default: 0xAA00FF, content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "SearchPixel", goto: "ActionSearch_pixelChooseColor", label: lang("Choose color")})
	parametersToEdit.push({type: "button", id: "MouseTracker", goto: "ActionSearch_pixelGetColor", label: lang("Get color from screen")})
	parametersToEdit.push({type: "Label", label: lang("Variation")})
	parametersToEdit.push({type: "Slider", id: "variation", default: 0, options: "Range0-255 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Method")})
	parametersToEdit.push({type: "Checkbox", id: "FastMode", default: 1, label: lang("Fast method")})

	return parametersToEdit
}

ActionSearch_pixelChooseColor()
{
	global
	tempActionSearch_pixelChooseColor:=chooseColor(GUISettingsOfElement%setElementID%ColorID)
	;~ MsgBox %tempActionSearch_pixelChooseColor%
	if tempActionSearch_pixelChooseColor=
	{
		return
		
	}
	GuiControl,,GUISettingsOfElement%setElementID%ColorID,%tempActionSearch_pixelChooseColor%
	GUISettingsOfElementUpdateName()
}

ActionSearch_pixelGetColor()
{
	MouseTracker({ImportColor:"Yes",ParColor:"ColorID"})
}
ActionSearch_pixelGetCoordinates()
{
	MouseTracker({ImportMousePos:"Yes",SelectParMousePos:"Yes",SelectParMousePosLabelPos1:lang("Import upper left corner"),SelectParMousePosLabelPos2:lang("Import lower right corner"),ParCoordMode:"CoordMode",ParMousePosX:"x1", ParMousePosY:"y1",ParMousePosX2:"x2", ParMousePosY2:"y2"})
}



GenerateNameActionSearch_pixel(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Search_pixel") " - " GUISettingsOfElement%ID%ColorID 
	
}

CheckSettingsActionSearch_pixel(ID)
{
	if (GUISettingsOfElement%ID%CoordMode1 = 1)
	{
		GuiControl,,GUISettingsOfElement%ID%WholeScreen,% lang("Whole screen")
		if (GUISettingsOfElement%ID%WholeScreen = 1)
			GuiControl,Enable,GUISettingsOfElement%ID%AllScreens
		else
			GuiControl,Disable,GUISettingsOfElement%ID%AllScreens
	}
	else if (GUISettingsOfElement%ID%CoordMode2 = 1)
	{
		GuiControl,,GUISettingsOfElement%ID%WholeScreen,% lang("Whole window")
		GuiControl,Disable,GUISettingsOfElement%ID%AllScreens
	}
	else
	{
		GuiControl,,GUISettingsOfElement%ID%WholeScreen,% lang("Whole window client")
		GuiControl,Disable,GUISettingsOfElement%ID%AllScreens
	}
	
	if (GUISettingsOfElement%ID%WholeScreen = 1)
	{
		GuiControl,Disable,GUISettingsOfElement%ID%x1
		GuiControl,Disable,GUISettingsOfElement%ID%x2
		GuiControl,Disable,GUISettingsOfElement%ID%y2
		GuiControl,Disable,GUISettingsOfElement%ID%y1
	}
	else
	{
		
		GuiControl,Enable,GUISettingsOfElement%ID%x1
		GuiControl,Enable,GUISettingsOfElement%ID%x2
		GuiControl,Enable,GUISettingsOfElement%ID%y2
		GuiControl,Enable,GUISettingsOfElement%ID%y1
		
	}
		
	
		
	
	
}

