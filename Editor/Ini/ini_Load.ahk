i_load(ThisFlowFilePath)
{
	global
	
	busy:=true
	ui_disablemaingui()
	if ThisFlowFilePath=
	{
		logger("a0","ERROR! File path of the Flow not specified!")
		ExitApp
		
	}
	
	
	SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	
	logger("a1","Loading flow from file: " ThisFlowFilePath)
	
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0","ERROR! Flow file does not exist!")
		ExitApp
	}
	
	ToolTip(lang("loading"),100000)
	Iniread,ID_count,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count,1
	Iniread,SettingFlowExecutionPolicy,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy,parallel
	Iniread,SettingWorkingDir,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingWorkingDir,%A_MyDocuments%\AutoHotFlow default working direction
	if not fileexist(SettingWorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,%SettingWorkingDir%
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	Iniread,FlowCompabilityVersion,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion,0
	
	i_loadGeneralParameters() ;Outsourced in order to execute only that later when flow name changes
	
	
	loop
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,Type
		
		
		if (loadElementType="Connection")
		{
			allElements.insert(loadElementID)
			
			%loadElementID%marked=false
			%loadElementID%running=0
			
			%loadElementID%Type=%loadElementType%
			
			Iniread,%loadElementID%from,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,from
			Iniread,%loadElementID%to,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,to
			Iniread,%loadElementID%ConnectionType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ConnectionType
			
			Iniread,%loadElementID%fromPart,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,fromPart,%A_Space%
			Iniread,%loadElementID%ToPart,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,toPart,%A_Space%
		}
		else if (loadElementType="Trigger")
		{
			Iniread,loadElementX,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			Iniread,loadElementY,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			%loadElementID%x=%loadElementX%
			%loadElementID%y=%loadElementY%
			
		}
		else
		{
			allElements.insert(loadElementID)
		
			%loadElementID%marked=false
			%loadElementID%running=0
			
			%loadElementID%Type=%loadElementType%
			
			Iniread,loadElementname,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,name
			StringReplace, loadElementname, loadElementname, |¶,`n, All
			
			
			Iniread,loadElementX,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			Iniread,loadElementY,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			
			
			%loadElementID%Name=%loadElementname%
			%loadElementID%x=%loadElementX%
			%loadElementID%y=%loadElementY%
			
			
			Iniread,loadElementsubType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,subType
			%loadElementID%subType=%loadElementsubType%
			
			i_CheckCompabilitySubtype(loadElementID,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
			
			if (loadElementType="loop")
			{
				Iniread,loadElementHeightOfVerticalBar,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,HeightOfVerticalBar
				%loadElementID%HeightOfVerticalBar=%loadElementHeightOfVerticalBar%
			}
			
			;Get the list of all parameters and read all parameters from ini
			parametersToload:=getParameters%loadElementType%%loadElementsubType%()
			for index2, parameter in parametersToload
			{
				parameter1=
				parameter2=
				parameter3=
				StringSplit,parameter,parameter,|
				;parameter1: type of control
				;parameter2: default value
				;parameter3: parameter name
				;parameter4 ...: further options
				if (parameter3="" or parameter0<3) ; ;If this is only a label for the edit fielt etc. Do nothing
					continue
				;~ MsgBox %parameter3%
				tempparname1=
				tempparname2=
				tempdefault1=
				tempdefault2=
				StringSplit,tempparname,parameter3,; ;get the parameter names if it has more than one
				StringSplit,tempdefault,parameter2,; ;get the default parameter

				;Certain types of control consist of multiple controls and thus contain multiple parameters.
				loop,%tempparname0%
				{
					tempCurrentParName:=tempparname%a_index%
					;~ MsgBox %tempCurrentParName%
					Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,%tempCurrentParName%,ẺⱤᶉӧɼ
					if (tempContent=="ẺⱤᶉӧɼ")
					{
						;~ MsgBox element %loadElementID% parameter %parameter3% nicht vorhanden setze es auf %parameter2%
						tempContent:=tempdefault%a_index%
						
					}
					StringReplace, tempContent, tempContent, |¶,`n, All
					%loadElementID%%tempCurrentParName%=%tempContent%
				}
				
				
			}
			
			
		}
		i_CheckCompability(loadElementID,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		ui_draw()
		
		
		
	}
	loop
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,Type
		
		
		
		allTriggers.insert(loadElementID)
	
	
		%loadElementID%Type=%loadElementType%
		
		Iniread,loadElementname,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,name
		StringReplace, loadElementname, loadElementname, |¶,`n, All
		%loadElementID%Name=%loadElementname%
		
		
		Iniread,loadElementsubType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,subType
		%loadElementID%subType=%loadElementsubType%
		
		
		
		
		parametersToload:=getParameters%loadElementType%%loadElementsubType%()
		for index2, parameter in parametersToload
		{
			parameter1=
			parameter2=
			parameter3=
			StringSplit,parameter,parameter,|
			;parameter1: type of control
			;parameter2: default value
			;parameter3: parameter name
			;parameter4 ...: further options
			
			if (parameter3="" or parameter0<3) ;If this is only a label for the edit fielt etc. Do nothing
				continue
			
			tempparname1=
			tempparname2=
			tempdefault1=
			tempdefault2=
			StringSplit,tempparname,parameter3,; ;get the parameter names if it has more than one
			StringSplit,tempdefault,parameter2,; ;get the default parameter
			
			;Certain types of control consist of multiple controls and thus contain multiple parameters.
			loop,%tempparname0%
			{
				tempCurrentParName:=tempparname%a_index%
				Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,%tempCurrentParName%,ẺⱤᶉӧɼ
				if (tempContent=="ẺⱤᶉӧɼ")
				{
					;~ MsgBox element %loadElementID% parameter %parameter3% nicht vorhanden setze es auf %parameter2%
					tempContent:=tempdefault%a_index%
				}
				StringReplace, tempContent, tempContent, |¶,`n, All
				%loadElementID%%tempCurrentParName%=%tempContent%
			}
		
			
			
		}
			
			
		
		;UpdateTriggerName()
		ui_draw()
		
		
		
	}
	
	logger("a1","Flow " FlowName " was successfully loaded.")
	ToolTip(lang("loaded"),1000)
	e_UpdateTriggerName()
	
	menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowName)
	Tray_OldShowName:=lang("Edit %1%", flowName)
	menu,tray,tip,% lang("Flow %1%",flowName)
	
	ui_EnableMainGUI()
	
	ui_draw()
	saved=yes
	busy:=false
}

i_loadGeneralParameters()
{
	global
	
	Iniread,FlowName,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,name
	Iniread,FlowCategory,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,category
	Iniread,SettingFlowLogToFile,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,LogToFile
	
	GuiControl,CommandWindow:text,CommandWindowFlowName,Ѻ%flowName%Ѻ ;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
}