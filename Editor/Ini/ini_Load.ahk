i_load(ThisFlowFilePath)
{
	global
	local FinishedSaving, ThisFlowFolder, tempValue, FlowCompabilityVersion, ID_count, index1, index2
	local loadElement, loadElementID, loadElementType, loadElementTriggerContainer
	local AllSections, tempSection, tempContainerID
	
	
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
	
	
	;read ini file
	
	res:=RIni_Read("IniFile",flow.FilePath)
	if res
		MsgBox %res%
	
	AllSections:=RIni_GetSections("IniFile")
	flow.CompabilityVersion:=FlowCompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	globalcounter:=RIni_GetKeyValue("IniFile", "general", "count", 1)
	flowSettings.ExecutionPolicy:=RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "parallel")
	flowSettings.WorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", A_MyDocuments "\AutoHotFlow default working direction")
	flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", 0)
	if not fileexist(flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% flowSettings.WorkingDir
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	i_loadGeneralParameters() ;Outsourced in order to execute only that later when flow name changes
	
	loop,parse,AllSections,`,
	{
		if a_loopfield=general
			continue
		tempSection:=A_LoopField
		
		loadElementID:=RIni_GetKeyValue("IniFile", tempSection, "ID", "")
		if (loadElementID="")
		{
			logger("a0","Error! Could not read the ID of an element " tempSection ". This element will not be loaded")
			continue
		}
		loadElementType:=RIni_GetKeyValue("IniFile", tempSection, "Type", "")
		
		IfInString,tempSection,element
		{
			
			if (loadElementType="Connection") ;outdated. kept for compability reasons
			{
				StringReplace,loadElementID,loadElementID,element,connection
				loadElement:=new connection(loadElementType,loadElementID)
				
				loadElement.from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
				loadElement.to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
				loadElement.ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
				loadElement.fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
				loadElement.ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
				
			}
			else if (loadElementType="Trigger")
			{
				loadElement:=maintrigger
				
				loadElement.x:=RIni_GetKeyValue("IniFile", tempSection, "x", 100)
				loadElement.y:=RIni_GetKeyValue("IniFile", tempSection, "y", 100)
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				loadElement.Name:=tempValue
				
			}
			else
			{
				loadElement:=new element(loadElementType,loadElementID) ;Pass element ID, so it will be the same as the last time
				
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				loadElement.Name:=tempValue
				
				loadElement.StandardName:=RIni_GetKeyValue("IniFile", tempSection, "StandardName", "")
				loadElement.x:=RIni_GetKeyValue("IniFile", tempSection, "x", 200)
				loadElement.y:=RIni_GetKeyValue("IniFile", tempSection, "y", 200)
				
				loadElement.subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", 200)
				
				i_CheckCompabilitySubtype(loadElement,tempSection)
				
				if (loadElementType="loop")
				{
					loadElement.HeightOfVerticalBar:=RIni_GetKeyValue("IniFile", tempSection, "HeightOfVerticalBar", 200)
				}
				;~ MsgBox % strobj(loadElement)
				;Get the list of all parameters and read all parameters from ini
				i_LoadParametersOfElement(loadElement,"IniFile",tempSection)
				
			}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
			i_CheckCompability(loadElement,tempSection)
			
		}
		
		IfInString,tempSection,connection
		{
			loadElement:=new connection(loadElementType,loadElementID)
			
			loadElement.from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
			loadElement.to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
			loadElement.ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
			loadElement.fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
			loadElement.ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
			
			i_CheckCompability(loadElement,tempSection)
		}
		
		
		IfInString,tempSection,trigger
		{
			tempContainerID:=RIni_GetKeyValue("IniFile", tempSection, "ContainerID", "trigger")	;For later use. Maybe it will support multiple trigger container.
			
			loadElement:=new trigger(tempContainerID,loadElementID)
			loadElement.Type:=loadElementType
			allelements[loadElement.Containerid].triggers.push(loadElement)
			;~ d(loadElement.Containerid,1)
			;~ d(allelements[loadElement.Containerid],1)
			
			tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name:=tempValue
			
			
			loadElement.subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", "")
			
			i_LoadParametersOfElement(loadElement,"IniFile",tempSection)
			
			i_CheckCompability(loadElement,tempSection)
		}
		
	}
	logger("a1","Flow " flowSettings.Name " was successfully loaded.")
	
	maintrigger.UpdateTriggerName()
	
	
	
	;e_CorrectElementErrors("Loaded the saved flow")
	RIni_Shutdown("IniFile")
	new state()
	savedState:=currentstateid
	maingui.enable()
	;~ MsgBox %savedState%
	ui_draw()
	busy:=false
}

i_loadGeneralParameters()
{
	global
	local temp

	Offsetx:=RIni_GetKeyValue("IniFile", "general", "Offsetx", Offsetx)
	Offsety:=RIni_GetKeyValue("IniFile", "general", "Offsety", Offsety)
	zoomFactor:=RIni_GetKeyValue("IniFile", "general", "zoomFactor", zoomFactor)
	flowSettings.Name:=RIni_GetKeyValue("IniFile", "general", "name", "")
	flowSettings.Category:=RIni_GetKeyValue("IniFile", "general", "Category", "")
	flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", "LogToFile", "")
	flowSettings.FolderOfStaticVariables:=RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", flow.Folder "\Static variables\" flow.Filename)
	
	if not fileexist(flowSettings.FolderOfStaticVariables)
		FileCreateDir,% flowSettings.FolderOfStaticVariables
	
	;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	GuiControl,CommandWindow:text,CommandWindowFlowName,% "Ѻ" flowSettings.Name "Ѻ§" CurrentManagerHiddenWindowID "§"
	

	
	
	;Change the window title if it is visible
	DetectHiddenWindows,off
	IfWinExist,ahk_id %MainGuihwnd%
	{
		if A_IsCompiled
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowSettings.Name
		else
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " flowSettings.Name " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	}
	DetectHiddenWindows,on
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
	
	;menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowSettings.Name)
	Tray_OldShowName:=lang("Edit %1%", flowSettings.Name)
	if A_IsCompiled
		menu,tray,tip,% lang("Flow %1%",flowSettings.Name) 
	else
		menu,tray,tip,% lang("Flow %1%",flowSettings.Name) " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	
	
}

i_LoadParametersOfElement(parElement,parlocation, parElementID)
{
	global
	local parametersToload, index, index2, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementType:=parElement.type
	loadElementsubType:=parElement.subtype
	
	parametersToload:=%loadElementType%%loadElementsubType%.getParameters()
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
			tempContent:=RIni_GetKeyValue(parlocation, parElementID, oneID, "ẺⱤᶉӧɼ")
				
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
