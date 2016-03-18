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
	share.flow.Filename:=ThisFlowFilename
	SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	share.flow.Folder:=ThisFlowFolder
	share.flow.FilePath:=ThisFlowFilePath
	
	logger("a1","Loading flow from file: " ThisFlowFilePath)
	
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0","ERROR! Flow file does not exist!")
		ExitApp
	}
	
	
	;read ini file
	
	res:=RIni_Read("IniFile",share.flow.FilePath)
	if res
		MsgBox Failed to load the ini file. Error code: %res%
	
	AllSections:=RIni_GetSections("IniFile")
	share.flow.CompabilityVersion:=FlowCompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	globalcounter:=RIni_GetKeyValue("IniFile", "general", "count", 1)
	share.flowSettings.ExecutionPolicy:=RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "parallel")
	share.flowSettings.WorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", A_MyDocuments "\AutoHotFlow default working direction")
	share.flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", 0)
	if not fileexist(share.flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% share.flowSettings.WorkingDir
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
				connection_New(loadElementID)
				
				allConnections[loadElementID].from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
				allConnections[loadElementID].to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
				allConnections[loadElementID].ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
				allConnections[loadElementID].fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
				allConnections[loadElementID].ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
				
			}
			else if (loadElementType="Trigger") ;this is the trigger container
			{
				
				loadElementID:=mainTriggerContainer
				
				allElements[loadElementID].x:=RIni_GetKeyValue("IniFile", tempSection, "x", 100)
				allElements[loadElementID].y:=RIni_GetKeyValue("IniFile", tempSection, "y", 100)
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				allElements[loadElementID].Name:=tempValue
				
			}
			else
			{
				;~ d(loadElementID,loadElementType)
				element_New(loadElementType,loadElementID) ;Pass element ID, so it will be the same as the last time
				
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				allElements[loadElementID].Name:=tempValue
				
				allElements[loadElementID].StandardName:=RIni_GetKeyValue("IniFile", tempSection, "StandardName", "")
				allElements[loadElementID].x:=RIni_GetKeyValue("IniFile", tempSection, "x", 200)
				allElements[loadElementID].y:=RIni_GetKeyValue("IniFile", tempSection, "y", 200)
				
				allElements[loadElementID].subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", 200)
				
				i_CheckCompabilitySubtype(allElements,loadElementID,tempSection)
				
				if (loadElementType="loop")
				{
					allElements[loadElementID].HeightOfVerticalBar:=RIni_GetKeyValue("IniFile", tempSection, "HeightOfVerticalBar", 200)
				}
				;~ MsgBox % strobj(loadElement)
				;Get the list of all parameters and read all parameters from ini
				i_LoadParametersOfElement(allElements,loadElementID,"IniFile",tempSection)
				
			}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
			i_CheckCompability(allElements,loadElementID,tempSection)
			
		}
		
		IfInString,tempSection,connection
		{
			connection_new(loadElementID)
			
			allConnections[loadElementID].from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
			allConnections[loadElementID].to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
			allConnections[loadElementID].ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
			allConnections[loadElementID].fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
			allConnections[loadElementID].ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
			
			i_CheckCompability(allConnections,loadElementID,tempSection)
		}
		
		
		IfInString,tempSection,trigger
		{
			tempContainerID:=RIni_GetKeyValue("IniFile", tempSection, "ContainerID", mainTriggerContainer)	;For later use. Maybe it will support multiple trigger container.
			
			trigger_new(tempContainerID,loadElementID)
			
			allTriggers[loadElementID].Type:=loadElementType
			
			;~ d(loadElement.Containerid,1)
			;~ d(allelements[loadElement.Containerid],1)
			
			tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			allTriggers[loadElementID].Name:=tempValue
			
			
			allTriggers[loadElementID].subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", "")
			
			i_LoadParametersOfElement(allTriggers,loadElementID,"IniFile",tempSection)
			
			i_CheckCompability(allTriggers,loadElementID,tempSection)
		}
		
	}
	logger("a1","Flow " flowSettings.Name " was successfully loaded.")
	
	TriggerContainer_UpdateName(mainTriggerContainer)
	
	
	
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
	share.flowSettings.Name:=RIni_GetKeyValue("IniFile", "general", "name", "")
	share.flowSettings.Category:=RIni_GetKeyValue("IniFile", "general", "Category", "")
	share.flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", "LogToFile", "")
	share.flowSettings.FolderOfStaticVariables:=RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", flow.Folder "\Static variables\" flow.Filename)
	
	if not fileexist(share.flowSettings.FolderOfStaticVariables)
		FileCreateDir,% share.flowSettings.FolderOfStaticVariables
	
	;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	GuiControl,CommandWindow:text,CommandWindowFlowName,% "Ѻ" share.flowSettings.Name "Ѻ§" CurrentManagerHiddenWindowID "§"
	

	
	
	;Change the window title if it is visible
	DetectHiddenWindows,off
	IfWinExist,"ahk_id " MainGui.hwnd
	{
		if A_IsCompiled
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " share.flowSettings.Name
		else
			gui,1:show,  NA,% "·AutoHotFlow· " lang("Editor") " - " share.flowSettings.Name " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	}
	DetectHiddenWindows,on
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
	
	;menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowSettings.Name)
	Tray_OldShowName:=lang("Edit %1%", share.flowSettings.Name)
	if A_IsCompiled
		menu,tray,tip,% lang("Flow %1%",share.flowSettings.Name) 
	else
		menu,tray,tip,% lang("Flow %1%",share.flowSettings.Name) " - UNCOMPILED" ;Makes it easier for me to find the uncompiled instance
	
	
}


;Loads the parameters of an element or trigger from the ini file
i_LoadParametersOfElement(parList,parElementID,parlocation, parSection)
{
	global
	local parametersToload, index, index2, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementType:=parList[parElementID].type
	loadElementsubType:=parList[parElementID].subtype
	
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
			tempContent:=RIni_GetKeyValue(parlocation, parSection, oneID, "ẺⱤᶉӧɼ")
				
			if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
			{
				
				;~ MsgBox % "." strobj(parElement)
				tempContent:=parameterDefault[index2]
			}
			StringReplace, tempContent, tempContent, |¶,`n, All
			parList[parElementID].par[oneID]:=tempContent
		}
	}
}
