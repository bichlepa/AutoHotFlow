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
			x1:=%ElementID%x1
			y1:=%ElementID%y1
			x2:=%ElementID%x2
			y2:=%ElementID%y2
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
			x1:=%ElementID%x1
			y1:=%ElementID%y1
			x2:=%ElementID%x2
			y2:=%ElementID%y2
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
			x1:=%ElementID%x1
			y1:=%ElementID%y1
			x2:=%ElementID%x2
			y2:=%ElementID%y2
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
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Transparent color " temp " is not a specified")
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
	
	parametersToEdit:=["Label|" lang("Output variables") " (" lang("Position: x,y") ")","Text2|ImagePosX;ImagePosY|varnameX;varnameY","Label|" lang("Screen region") "(x,y)","Radio|1|CoordMode|" lang("Relative to screen") ";" lang("Relative to active window position") ";" lang("Relative to active window client position"),"Checkbox|0|WholeScreen|" lang("Whole main screen"),"Checkbox|0|AllScreens|" lang("All screens"),"SmallLabel|"  lang("Upper left corner"), "Text2|10;20|x1;y1","SmallLabel|" lang("Lower right corner") " (x,y)","Text2|600;700|x2;y2","Label|" lang("Image file path"),"File||file|" lang("Select a file") "|8|" lang("Images and icons") " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)","Label|"  lang("File with multiple icons") ,"Checkbox|0|SetIconNumber|" lang("Set icon number"),"Text|1|IconNumber","Label|" lang("Variation"), "Slider|0|variation|Range0-255 TickInterval10 tooltip","Label|" lang("Transparent color") ,"Checkbox|0|makeTransparent|" lang("Make a color of image transparent"), "SmallLabel|"  lang("Color name or RGB value"),"Text||transparent", "Label|" lang("Scale image") ,"Checkbox|0|ScaleImage|" lang("Scale image"), "Checkbox|0|PreserveAspectRatio|" lang("Preserve aspect ratio"), "Radio|1|WhichSizeSet|" lang("Set width manually and set height automatically") ";" lang("Set height manually and set width automatically") , "SmallLabel|" lang("width, height"),"Text2|;|ImageWidth;ImageHeight" ]
	return parametersToEdit
}

GenerateNameActionSearch_image(ID)
{
	global
	;MsgBox % %ID%text_to_show
	
	
	return lang("Search_image") " " GUISettingsOfElement%ID%file 
	
}

CheckSettingsActionSearch_image(ID)
{
	if (GUISettingsOfElement%ID%CoordMode1 = 1)
	{
		GuiControl,,GUISettingsOfElement%ID%WholeScreen,% lang("Whole main screen")
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
