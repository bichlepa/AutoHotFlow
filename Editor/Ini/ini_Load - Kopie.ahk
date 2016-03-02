i_load(ThisFlowFilePath)
{
	global
	local FinishedSaving, ThisFlowFolder, tempValue, FlowCompabilityVersion, ID_count, index1, index2
	local loadElement, loadElementID, loadElementType, loadElementTriggerContainer
	local AllSections
	
	flowSettings:=[]
	flow:=[]
	
	busy:=true
	maingui.disable()
	if ThisFlowFilePath=
	{
		logger("a0","ERROR! File path of the Flow not specified!")
		ExitApp
		
	}
	flow.Filename:=ThisFlowFilename
	SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	flow.Folder:=ThisFlowFolder
	flow.FilePath:=ThisFlowFilePath
	
	logger("a1","Loading flow from file: " ThisFlowFilePath)
	
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0","ERROR! Flow file does not exist!")
		ExitApp
	}
	
	ToolTip(lang("loading"),100000)
	
	;read ini file
	
	res:=RIni_Read("IniFile",flow.FilePath)
	if res
		MsgBox %res%
	
	AllSections:=RIni_GetSections("IniFile")
	flow.CompabilityVersion:=FlowCompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	flow.CompabilityVersion:=FlowCompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	
	loop,parse,AllSections,`,
	{
		if a_loopfield=general
			continue
		;~ MsgBox %a_loopfield%
	}
	
	Iniread,ID_count,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count,1
	globalcounter:=ID_count
	Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy,parallel
	flowSettings.ExecutionPolicy:=tempValue
	Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingWorkingDir,%A_MyDocuments%\AutoHotFlow default working direction
	flowSettings.WorkingDir:=tempValue
	if not fileexist(tempValue)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,%tempValue%
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	i_loadGeneralParameters() ;Outsourced in order to execute only that later when flow name changes
	
	
	loop ;load elements
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,Type
		
		
		if (loadElementType="Connection") ;outdated kept for compability reasons
		{
			StringReplace,loadElementID,loadElementID,element,connection
			loadElement:=new connection(loadElementType,loadElementID)
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,from
			loadElement.from:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,to
			loadElement.to:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ConnectionType
			loadElement.ConnectionType:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,fromPart,%A_Space%
			loadElement.fromPart:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,toPart,%A_Space%
			loadElement.ToPart:=tempValue
		}
		else if (loadElementType="Trigger")
		{
			loadElement:=maintrigger
			
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			loadElement.x:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			loadElement.y:=tempValue
			
		}
		else
		{
			loadElement:=new element(loadElementType,loadElementID)
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,name
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,StandardName,1
			loadElement.Standardname:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			loadElement.x:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			loadElement.y:=tempValue
			
			
			
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,subType
			loadElement.subType:=tempValue
			
			i_CheckCompabilitySubtype(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
			
			if (loadElementType="loop")
			{
				Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,HeightOfVerticalBar
				loadElement.HeightOfVerticalBar:=tempValue
			}
			;~ MsgBox % strobj(loadElement)
			;Get the list of all parameters and read all parameters from ini
			i_LoadParametersOfElement(loadElement,"file","element" index1)
			
			
			
		}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
		i_CheckCompability(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		ui_draw()
		
		
		
	}
	
	loop ;load connections
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,Type
		
		loadElement:=new connection(loadElementType,loadElementID)
		
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,from
		loadElement.from:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,to
		loadElement.to:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,ConnectionType
		loadElement.ConnectionType:=tempValue
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,fromPart,%A_Space%
		loadElement.fromPart:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,toPart,%A_Space%
		loadElement.ToPart:=tempValue
		
		i_CheckCompability(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		ui_draw()
		
		
		
	}
	
	
	loop ;Load triggers
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,Type
		
		
		
		;For later use. Maybe it will support multiple trigger container.
		Iniread,loadElementTriggerContainerID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ContainerID
		loadElementTriggerContainer:=element.IDtoObject(loadElementTriggerContainerID)
		if (FlowCompabilityVersion<7 or loadElementTriggerContainer="")
		{
			loadElementTriggerContainer:=maintrigger
		}
		
		loadTrigger:=new trigger(loadElementID)
		
		loadElementTriggerContainer.triggers.push(loadTrigger)
		
		
		loadTrigger.Type:=loadElementType
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,name
		StringReplace, tempValue, tempValue, |¶,`n, All
		loadTrigger.Name:=tempValue
		
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,subType
		loadTrigger.subType:=tempValue
		
		
		i_LoadParametersOfElement(loadTrigger,"file","trigger" index1)
		
		i_CheckCompability(loadTrigger,"trigger" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		
		
		
		;UpdateTriggerName()
		ui_draw()
		
		
		
	}
	logger("a1","Flow " FlowName " was successfully loaded.")
	ToolTip(lang("loaded"),1000)
	maintrigger.UpdateTriggerName()
	
	
	
	;e_CorrectElementErrors("Loaded the saved flow")
	
	new state()
	maingui.enable()
	
	ui_draw()
	saved=yes
	busy:=false
}

i_loadGeneralParameters()
{
	global
	local temp

	Iniread,Offsetx,% flow.FilePath,general,Offsetx,%Offsetx%
	flowSettings.Offsetx:=Category
	Iniread,Offsety,% flow.FilePath,general,OffsetY,%OffsetY%
	flowSettings.Offsety:=Category
	Iniread,zoomFactor,% flow.FilePath,general,zoomFactor,%zoomFactor%
	flowSettings.zoomFactor:=Category
	Iniread,FlowName,% flow.FilePath,general,name
	flowSettings.Name:=Category
	Iniread,FlowCategory,% flow.FilePath,general,category
	flowSettings.Category:=Category
	Iniread,temp,% flow.FilePath,general,LogToFile
	flowSettings.LogToFile:=temp
	Iniread,FolderOfStaticVariables,% flow.FilePath,general,Static variables folder,% flow.Folder "\Static variables\" flow.Filename
	if not fileexist(FolderOfStaticVariables)
		FileCreateDir,%FolderOfStaticVariables%
	
	;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	GuiControl,CommandWindow:text,CommandWindowFlowName,Ѻ%flowName%Ѻ§%CurrentManagerHiddenWindowID%§
	

	
	
	;Change the window title if it is visible
	DetectHiddenWindows,off
	IfWinExist,ahk_id %MainGuihwnd%
	{
		if A_IsCompiled
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowName
		else
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowName " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	}
	DetectHiddenWindows,on
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
	
	;menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowName)
	Tray_OldShowName:=lang("Edit %1%", flowName)
	if A_IsCompiled
		menu,tray,tip,% lang("Flow %1%",flowName) 
	else
		menu,tray,tip,% lang("Flow %1%",flowName) " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	
	
}

i_LoadParametersOfElement(parElement,parlocation, parElementID)
{
	global
	local parametersToload, index, index2, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementType:=parElement.type
	loadElementsubType:=parElement.subtype
	
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
			
			if (parlocation="clipboard")
			{
				;~ MsgBox % loadElementID " - "  loadElementType " - "  loadElementsubType  " - "  loadElementIndex " - " Loadlocation
				Iniread,tempContent,%ClipboardFlowFilename%,%parElementID%,%oneID%,ẺⱤᶉӧɼ
			}
			else if (parlocation="file")
			{
				
				Iniread,tempContent,% flow.FilePath,%parElementID%,%oneID%,ẺⱤᶉӧɼ
				
			}
			if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
			{
				
				;~ MsgBox % "." strobj(parElement)
				tempContent:=parameterDefault[index2]
			}
			StringReplace, tempContent, tempContent, |¶,`n, All
			parElement.par[oneID]:=tempContent
		}
	}
}




/*i_load(ThisFlowFilePath)
{
	global
	local FinishedSaving, ThisFlowFolder, tempValue, FlowCompabilityVersion, ID_count, index1, index2
	local loadElement, loadElementID, loadElementType, loadElementTriggerContainer
	
	flowSettings:=[]
	flow:=[]
	
	busy:=true
	maingui.disable()
	if ThisFlowFilePath=
	{
		logger("a0","ERROR! File path of the Flow not specified!")
		ExitApp
		
	}
	flow.Filename:=ThisFlowFilename
	SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	flow.Folder:=ThisFlowFolder
	flow.FilePath:=ThisFlowFilePath
	
	logger("a1","Loading flow from file: " ThisFlowFilePath)
	
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0","ERROR! Flow file does not exist!")
		ExitApp
	}
	
	ToolTip(lang("loading"),100000)
	Iniread,FlowCompabilityVersion,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion,0
	flow.CompabilityVersion:=CompabilityVersion
	
	Iniread,FinishedSaving,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Finished Saving,No ;Check whether the flow was saved completely
	if (FinishedSaving="no" and FlowCompabilityVersion>=3)
	{
		if fileexist(ThisFlowFolder "\" ThisFlowFilename "_Backup.txt") ;Find Backup and move it
		{
			MsgBox, 48, AutoHotFlow,%  lang("The flow was not saved properly last time.") " " lang("A backup is available. It will be loaded.")
			FileMove,%ThisFlowFolder%\%ThisFlowFilename%_Backup.txt,%ThisFlowFolder%\%ThisFlowFilename%.ini,1
			Iniread,FlowCompabilityVersion,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion,0
			logger("a1","Flow was not saved properly last time. A backup was found and restored.")
		}
		else
		{
			logger("a0","ERROR! The flow was not saved properly last time. Unfortunately no backup is available.")
			MsgBox, 48, AutoHotFlow,% lang("The flow was not saved properly last time.") " " lang("Unfortunately no backup is available.")
		}
	}
	Iniread,ID_count,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count,1
	globalcounter:=ID_count
	Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy,parallel
	flowSettings.ExecutionPolicy:=tempValue
	Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingWorkingDir,%A_MyDocuments%\AutoHotFlow default working direction
	flowSettings.WorkingDir:=tempValue
	if not fileexist(tempValue)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,%tempValue%
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	i_loadGeneralParameters() ;Outsourced in order to execute only that later when flow name changes
	
	
	loop ;load elements
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,Type
		
		
		if (loadElementType="Connection") ;outdated kept for compability reasons
		{
			StringReplace,loadElementID,loadElementID,element,connection
			loadElement:=new connection(loadElementType,loadElementID)
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,from
			loadElement.from:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,to
			loadElement.to:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ConnectionType
			loadElement.ConnectionType:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,fromPart,%A_Space%
			loadElement.fromPart:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,toPart,%A_Space%
			loadElement.ToPart:=tempValue
		}
		else if (loadElementType="Trigger")
		{
			loadElement:=maintrigger
			
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			loadElement.x:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			loadElement.y:=tempValue
			
		}
		else
		{
			loadElement:=new element(loadElementType,loadElementID)
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,name
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,StandardName,1
			loadElement.Standardname:=tempValue
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			loadElement.x:=tempValue
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			loadElement.y:=tempValue
			
			
			
			
			Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,subType
			loadElement.subType:=tempValue
			
			i_CheckCompabilitySubtype(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
			
			if (loadElementType="loop")
			{
				Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,HeightOfVerticalBar
				loadElement.HeightOfVerticalBar:=tempValue
			}
			;~ MsgBox % strobj(loadElement)
			;Get the list of all parameters and read all parameters from ini
			i_LoadParametersOfElement(loadElement,"file","element" index1)
			
			
			
		}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
		i_CheckCompability(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		ui_draw()
		
		
		
	}
	
	loop ;load connections
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,Type
		
		loadElement:=new connection(loadElementType,loadElementID)
		
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,from
		loadElement.from:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,to
		loadElement.to:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,ConnectionType
		loadElement.ConnectionType:=tempValue
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,fromPart,%A_Space%
		loadElement.fromPart:=tempValue
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,connection%index1%,toPart,%A_Space%
		loadElement.ToPart:=tempValue
		
		i_CheckCompability(loadElement,"element" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		ui_draw()
		
		
		
	}
	
	
	loop ;Load triggers
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,Type
		
		
		
		;For later use. Maybe it will support multiple trigger container.
		Iniread,loadElementTriggerContainerID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ContainerID
		loadElementTriggerContainer:=element.IDtoObject(loadElementTriggerContainerID)
		if (FlowCompabilityVersion<7 or loadElementTriggerContainer="")
		{
			loadElementTriggerContainer:=maintrigger
		}
		
		loadTrigger:=new trigger(loadElementID)
		
		loadElementTriggerContainer.triggers.push(loadTrigger)
		
		
		loadTrigger.Type:=loadElementType
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,name
		StringReplace, tempValue, tempValue, |¶,`n, All
		loadTrigger.Name:=tempValue
		
		
		Iniread,tempValue,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,subType
		loadTrigger.subType:=tempValue
		
		
		i_LoadParametersOfElement(loadTrigger,"file","trigger" index1)
		
		i_CheckCompability(loadTrigger,"trigger" index1,ThisFlowFolder "\" ThisFlowFilename ".ini")
		
		
		
		;UpdateTriggerName()
		ui_draw()
		
		
		
	}
	logger("a1","Flow " FlowName " was successfully loaded.")
	ToolTip(lang("loaded"),1000)
	maintrigger.UpdateTriggerName()
	
	
	
	;e_CorrectElementErrors("Loaded the saved flow")
	
	new state()
	maingui.enable()
	
	ui_draw()
	saved=yes
	busy:=false
}

i_loadGeneralParameters()
{
	global
	local temp

	Iniread,Offsetx,% flow.FilePath,general,Offsetx,%Offsetx%
	flowSettings.Offsetx:=Category
	Iniread,Offsety,% flow.FilePath,general,OffsetY,%OffsetY%
	flowSettings.Offsety:=Category
	Iniread,zoomFactor,% flow.FilePath,general,zoomFactor,%zoomFactor%
	flowSettings.zoomFactor:=Category
	Iniread,FlowName,% flow.FilePath,general,name
	flowSettings.Name:=Category
	Iniread,FlowCategory,% flow.FilePath,general,category
	flowSettings.Category:=Category
	Iniread,temp,% flow.FilePath,general,LogToFile
	flowSettings.LogToFile:=temp
	Iniread,FolderOfStaticVariables,% flow.FilePath,general,Static variables folder,% flow.Folder "\Static variables\" flow.Filename
	if not fileexist(FolderOfStaticVariables)
		FileCreateDir,%FolderOfStaticVariables%
	
	;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	GuiControl,CommandWindow:text,CommandWindowFlowName,Ѻ%flowName%Ѻ§%CurrentManagerHiddenWindowID%§
	

	
	
	;Change the window title if it is visible
	DetectHiddenWindows,off
	IfWinExist,ahk_id %MainGuihwnd%
	{
		if A_IsCompiled
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowName
		else
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowName " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	}
	DetectHiddenWindows,on
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
	
	;menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowName)
	Tray_OldShowName:=lang("Edit %1%", flowName)
	if A_IsCompiled
		menu,tray,tip,% lang("Flow %1%",flowName) 
	else
		menu,tray,tip,% lang("Flow %1%",flowName) " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	
	
}

i_LoadParametersOfElement(parElement,parlocation, parElementID)
{
	global
	local parametersToload, index, index2, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementType:=parElement.type
	loadElementsubType:=parElement.subtype
	
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
			
			if (parlocation="clipboard")
			{
				;~ MsgBox % loadElementID " - "  loadElementType " - "  loadElementsubType  " - "  loadElementIndex " - " Loadlocation
				Iniread,tempContent,%ClipboardFlowFilename%,%parElementID%,%oneID%,ẺⱤᶉӧɼ
			}
			else if (parlocation="file")
			{
				
				Iniread,tempContent,% flow.FilePath,%parElementID%,%oneID%,ẺⱤᶉӧɼ
				
			}
			if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
			{
				
				;~ MsgBox % "." strobj(parElement)
				tempContent:=parameterDefault[index2]
			}
			StringReplace, tempContent, tempContent, |¶,`n, All
			parElement.par[oneID]:=tempContent
		}
	}
}
*/