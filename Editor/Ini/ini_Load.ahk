i_load(ThisFlowFilePath)
{
	global
	local FinishedSaving
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
	Iniread,FlowCompabilityVersion,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion,0

	Iniread,FinishedSaving,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Finished Saving,No ;Check whether the flow was saved completely
	if (FinishedSaving="no" and FlowCompabilityVersion>=3)
	{
		if fileexist(ThisFlowFolder "\" ThisFlowFilename "_Backup.txt")
		{
			MsgBox, 48, AutoHotFlow,%  lang("The flow was not saved properly last time.") " " lang("A backup is available. It will be loaded.")
			FileMove,%ThisFlowFolder%\%ThisFlowFilename%_Backup.txt,%ThisFlowFolder%\%ThisFlowFilename%.ini,1
			Iniread,FlowCompabilityVersion,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion,0
		}
		else
			MsgBox, 48, AutoHotFlow,% lang("The flow was not saved properly last time.") " " lang("Unfortunately no backup is available.")
	}
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
			i_LoadParametersOfElement(loadElementID,loadElementType,loadElementsubType,index1,"element")
			
			
			
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
		
		
		i_LoadParametersOfElement(loadElementID,loadElementType,loadElementsubType,index1,"trigger")
		
		i_CheckCompability(loadElementID,"trigger" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		
		
		
		;UpdateTriggerName()
		ui_draw()
		
		
		
	}
	
	logger("a1","Flow " FlowName " was successfully loaded.")
	ToolTip(lang("loaded"),1000)
	e_UpdateTriggerName()
	
	menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowName)
	Tray_OldShowName:=lang("Edit %1%", flowName)
	menu,tray,tip,% lang("Flow %1%",flowName)
	
	e_CorrectElementErrors("Loaded the saved flow")
	ui_EnableMainGUI()
	
	ui_draw()
	saved=yes
	busy:=false
}

i_loadGeneralParameters()
{
	global
	local temp

	Iniread,Offsetx,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Offsetx,%Offsetx%
	Iniread,Offsety,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,OffsetY,%OffsetY%
	Iniread,zoomFactor,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,zoomFactor,%zoomFactor%
	Iniread,FlowName,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,name
	Iniread,FlowCategory,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,category
	Iniread,SettingFlowLogToFile,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,LogToFile
	Iniread,FolderOfStaticVariables,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Static variables folder,%ThisFlowFolder%\Static variables\%ThisFlowFilename%
	if not fileexist(FolderOfStaticVariables)
		FileCreateDir,%FolderOfStaticVariables%
	
	;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	GuiControl,CommandWindow:text,CommandWindowFlowName,Ѻ%flowName%Ѻ§%CurrentManagerHiddenWindowID%§
	

	
	
	;Change the window title if it is visible
	DetectHiddenWindows,off
	IfWinExist,ahk_id %MainGuihwnd%
	{
		
		gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowName
	}
	DetectHiddenWindows,on
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
}

i_LoadParametersOfElement(loadElementID,loadElementType,loadElementsubType,loadElementIndex,Loadlocation)
{
	global
	local parametersToload
	local index
	local index2
	local parameter
	local parameterID
	local parameterDefault
	local tempContent
	local OneID
	parametersToload:=getParameters%loadElementType%%loadElementsubType%()
	for index, parameter in parametersToload
	{
		if not IsObject(parameter.id)
			parameterID:=[parameter.id]
		else
			parameterID:=parameter.id
		if not IsObject(parameter.default)
			parameterDefault:=[parameter.default]
		else
			parameterDefault:=parameter.default
		
		if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label for the edit fielt etc. Do nothing
			continue
		
		;~ MsgBox % strobj(parameter)
		;Certain types of control consist of multiple controls and thus contain multiple parameters.
		for index2, oneID in parameterID
		{
			
			if (Loadlocation="clipboard")
			{
				;~ MsgBox % loadElementID " - "  loadElementType " - "  loadElementsubType  " - "  loadElementIndex " - " Loadlocation
				Iniread,tempContent,%ClipboardFlowFilename%,Element%loadElementIndex%,%oneID%,ẺⱤᶉӧɼ
			}
			else if (Loadlocation="trigger")
			{
				Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%loadElementIndex%,%oneID%,ẺⱤᶉӧɼ
			}
			else if (Loadlocation="element")
				Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,Element%loadElementIndex%,%oneID%,ẺⱤᶉӧɼ
			
			if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
			{
				;~ MsgBox element %loadElementID% parameter %parameter3% nicht vorhanden setze es auf %parameter2%
				tempContent:=parameterDefault[index2]
			}
			StringReplace, tempContent, tempContent, |¶,`n, All
			%loadElementID%%oneID%:=tempContent
		}
	}
}