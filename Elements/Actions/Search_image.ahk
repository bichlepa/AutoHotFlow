iniAllActions.="Search_image|" ;Add this action to list of all actions on initialisation

runActionSearch_image(InstanceID,ThreadID,ElementID,ElementIDInInstance)
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
	local setHeight
	local setWidth
	local Height
	local Width
	
	
	local tempPath:=% v_replaceVariables(InstanceID,ThreadID,%ElementID%file)
	if  DllCall("Shlwapi.dll\PathIsRelative","Str",tempPath)
		tempPath:=SettingWorkingDir "\" tempPath

	
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
		if x1 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x1)) )
			return
		}
		y1:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y1)
		if y1 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y1 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y1)) )
			return
		}
		x2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%x2)
		if x2 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " x2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",x2)) )
			return
		}
		y2:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%y2)
		if y2 is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Coordinate " y2 " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Coordinate '%1%'",y2)) )
			return
		}
		
	}
	
	if %ElementID%SetIconNumber
	{
		temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%IconNumber)
		if temp is not number
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Icon number " temp " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Icon number '%1%'",temp)) )
			return
		}
		tempOptions.="*Icon" temp " "
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
		tempOptions.="*" temp " "
	}
	
	if %ElementID%makeTransparent
	{
		temp:=v_ReplaceVariables(InstanceID,ThreadID,%ElementID%transparent)
		;TODO: check whether the string contains spaces
		if temp=
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Transparent color is not specified")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not specified.",lang("Transparent color",temp)) )
			return
		}
		tempOptions.="*Trans" temp " "
	}
	
	if %ElementID%ScaleImage
	{
		if %ElementID%PreserveAspectRatio
		{
			if %ElementID%WhichSizeSet=1 ;Set width manually
			{
				setHeight:=false
				setWidth:=true
				Height:=-1
			}
			else if %ElementID%WhichSizeSet=2 ;Set height manually
			{
				setHeight:=true
				setWidth:=false
				width:=-1
			}
		}
		else
		{
			setHeight:=true
			setWidth:=true
		}
		
		if setHeight
		{
			temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%ImageHeight)
			if temp=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Image height " temp " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Image height '%1%'",temp)) )
				return
			}
			
			height:=temp
		}
		if setWidth
		{
			temp:=v_EvaluateExpression(InstanceID,ThreadID,%ElementID%ImageWidth)
			if temp=
			{
				logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Image width " temp " is not a number")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("%1% is not a number.",lang("Image width '%1%'",temp)) )
				return
			}
			
			width:=temp
		}
		
		
		tempOptions.="*w" width " *h" height " "
	}
	
	ImageSearch,foundx,foundy,%x1%,%y1%,%x2%,%y2%,% tempOptions tempPath
	
	if ErrorLevel=2
	{
		if not fileexist(tempPath)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! File '" tempPath "' does not exist")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' does not exist",tempPath))
			return
		}
		else
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Image '" tempPath "' could not be read")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("File '%1%' could not be read",tempPath))
			return
		}
	}
	if ErrorLevel=1
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Image was not found")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Image was not found",tempPath))
		return
		
	}
	
	v_SetVariable(InstanceID,ThreadID,varnameX,foundx)
	v_SetVariable(InstanceID,ThreadID,varnameY,foundy)
	MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normal")
	
	return
}
getNameActionSearch_image()
{
	return lang("Search_image")
}
getCategoryActionSearch_image()
{
	return lang("Image")
}

getParametersActionSearch_image()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Output variables") (x, y)})
	parametersToEdit.push({type: "Edit", id: ["varnameX", "varnameY"], default: ["ImagePosX", "ImagePosY"], content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Screen region")})
	parametersToEdit.push({type: "Radio", id: "CoordMode", default: 1, choices: [lang("Relative to screen"), lang("Relative to active window position"), lang("Relative to active window client position")]})
	parametersToEdit.push({type: "Checkbox", id: "WholeScreen", default: 0, label: lang("Whole screen")})
	parametersToEdit.push({type: "Checkbox", id: "AllScreens", default: 0, label: lang("All screens")})
	parametersToEdit.push({type: "Label", label: lang("Upper left corner") (x1, y1), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Lower right corner") (x2, y2), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "GetCoordinates", goto: "ActionSearch_imageGetCoordinates", label: lang("Get coordinates")})
	parametersToEdit.push({type: "Label", label: lang("Image file path")})
	parametersToEdit.push({type: "File", id: "file", label: lang("Select a file"), options: 8, filter: lang("Images and icons") " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)"})
	parametersToEdit.push({type: "Label", label: lang("File with multiple icons")})
	parametersToEdit.push({type: "Checkbox", id: "SetIconNumber", default: 0, label: lang("Set icon number")})
	parametersToEdit.push({type: "Edit", id: "IconNumber", default: 1, content: "Expression", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Variation")})
	parametersToEdit.push({type: "Slider", id: "variation", default: 0, options: "Range0-255 TickInterval10 tooltip"})
	parametersToEdit.push({type: "Label", label: lang("Transparent color")})
	parametersToEdit.push({type: "Checkbox", id: "makeTransparent", default: 0, label: lang("Make a color of image transparent")})
	parametersToEdit.push({type: "Label", label: lang("Color name or RGB value"), size: "small"})
	parametersToEdit.push({type: "Edit", id: "transparent", content: "String", WarnIfEmpty: true})
	parametersToEdit.push({type: "button", id: "ChooseColor", goto: "ActionSearch_imageChooseColor", label: lang("Choose color")})
	parametersToEdit.push({type: "button", id: "GetColor", goto: "ActionSearch_imageGetColor", label: lang("Get color from screen")})
	parametersToEdit.push({type: "Label", label: lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "ScaleImage", default: 0, label: lang("Scale image")})
	parametersToEdit.push({type: "Checkbox", id: "PreserveAspectRatio", default: 0, label: lang("Preserve aspect ratio")})
	parametersToEdit.push({type: "Radio", id: "WhichSizeSet", default: 1, choices: [lang("Set width manually and set height automatically"), lang("Set height manually and set width automatically")]})
	parametersToEdit.push({type: "Label", label: lang("width, height"), size: "small"})
	parametersToEdit.push({type: "Edit", id: ["ImageWidth", "ImageHeight"], content: "Expression", WarnIfEmpty: true})

	return parametersToEdit
}

ActionSearch_imageChooseColor()
{
	global
	tempActionSearch_imageChooseColor:=chooseColor(GUISettingsOfElement%setElementID%transparent)
	;~ MsgBox %tempActionSearch_pixelChooseColor%
	if tempActionSearch_imageChooseColor!=
	{
		GuiControl,,GUISettingsOfElement%setElementID%transparent,%tempActionSearch_imageChooseColor%
		GUISettingsOfElementUpdateName()
	}
}

ActionSearch_imageGetColor()
{
	MouseTracker({ImportColor:"Yes",ParColor:"transparent"})
}
ActionSearch_imageGetCoordinates()
{
	MouseTracker({ImportMousePos:"Yes",SelectParMousePos:"Yes",SelectParMousePosLabelPos1:lang("Import upper left corner"),SelectParMousePosLabelPos2:lang("Import lower right corner"),ParCoordMode:"CoordMode",ParMousePosX:"x1", ParMousePosY:"y1",ParMousePosX2:"x2", ParMousePosY2:"y2"})
}


GenerateNameActionSearch_image(ID)
{
	global
	local String := lang("Search_image")   " - " 
	
	string.=GUISettingsOfElement%ID%file " "
	

	
	
	return string
	
}

CheckSettingsActionSearch_image(ID)
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
		
	if (GUISettingsOfElement%ID%makeTransparent = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%transparent 
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%transparent
	}
	
	if (GUISettingsOfElement%ID%SetIconNumber = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%IconNumber
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%IconNumber
	}
	
	if (GUISettingsOfElement%ID%ScaleImage = 1)
	{
		GuiControl,Enable,GUISettingsOfElement%ID%PreserveAspectRatio
		GuiControl,Enable,GUISettingsOfElement%ID%WhichSizeSet1
		GuiControl,Enable,GUISettingsOfElement%ID%WhichSizeSet2
		if (GUISettingsOfElement%ID%PreserveAspectRatio = 1)
		{
			GuiControl,Enable,GUISettingsOfElement%ID%WhichSizeSet1
			GuiControl,Enable,GUISettingsOfElement%ID%WhichSizeSet2
			if (GUISettingsOfElement%ID%WhichSizeSet1 =1)
			{
				GuiControl,Disable,GUISettingsOfElement%ID%ImageHeight
				GuiControl,Enable,GUISettingsOfElement%ID%ImageWidth
			}
			else
			{
				GuiControl,Enable,GUISettingsOfElement%ID%ImageHeight
				GuiControl,Disable,GUISettingsOfElement%ID%ImageWidth
			}
		}
		else
		{
			GuiControl,Disable,GUISettingsOfElement%ID%WhichSizeSet1
			GuiControl,Disable,GUISettingsOfElement%ID%WhichSizeSet2
			GuiControl,Enable,GUISettingsOfElement%ID%ImageHeight
			GuiControl,Enable,GUISettingsOfElement%ID%ImageWidth
		}
	}
	else
	{
		GuiControl,Disable,GUISettingsOfElement%ID%PreserveAspectRatio
		GuiControl,Disable,GUISettingsOfElement%ID%WhichSizeSet1
		GuiControl,Disable,GUISettingsOfElement%ID%WhichSizeSet2
		GuiControl,Disable,GUISettingsOfElement%ID%ImageHeight
		GuiControl,Disable,GUISettingsOfElement%ID%ImageWidth
	}
		
		
		
	
	
}

