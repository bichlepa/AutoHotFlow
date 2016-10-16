
;Can be called from other threads
LoadFlow(FlowID)
{
	global
	local FinishedSaving, ThisFlowFolder, tempValue, FlowCompabilityVersion, ID_count, index1, index2
	local loadElement, loadElementID, loadElementType, loadElementTriggerContainer, loadElementClass
	local AllSections, tempSection, tempContainerID, missingpackages

	if (currentlyLoadingFlow = true)
	{
		MsgBox unexpected error. a flow is already currently loading
		return
	}
	currentlyLoadingFlow:=true
	
	ThisFlowFilepath := _flows[FlowID].file
	ThisFlowFolder := _flows[FlowID].Folder
	ThisFlowFilename :=_flows[FlowID].FileName
	missingpackages :=Object()
	logger("a1", "Loading flow from file: " ThisFlowFilePath)
	
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		;~ d(_flows, FlowID)
		logger("a0", "ERROR! Flow file does not exist!")
		ExitApp
	}
	
	
	;read ini file
	
	res:=RIni_Read("IniFile",_flows[FlowID].File)
	if res
		MsgBox Failed to load the ini file. Error code: %res%
	
	_flows[FlowID].allElements:=CriticalObject()
	_flows[FlowID].allConnections:=CriticalObject()
	_flows[FlowID].allTriggers:=CriticalObject()
	_flows[FlowID].markedElements:=CriticalObject()
	_flows[FlowID].flowSettings:=CriticalObject()
	_flows[FlowID].draw:=CriticalObject()
	;~ d(_flows[flowid])
	AllSections:=RIni_GetSections("IniFile")
	_flows[FlowID].CompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	_flows[FlowID].ElementIDCounter:=RIni_GetKeyValue("IniFile", "general", "count", 1)
	_flows[FlowID].flowSettings.ExecutionPolicy:=RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "parallel")
	_flows[FlowID].flowSettings.WorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", A_MyDocuments "\AutoHotFlow default working direction")
	_flows[FlowID].flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", 0)
	if not fileexist(share.flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% _flows[FlowID].flowSettings.WorkingDir
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	loadFlowGeneralParameters(FlowID) ;Outsourced in order to execute only that later when flow name changes
	
	Element_New(FlowID, "trigger", "trigger")
	
	;Loop through all ellements and load them
	loop,parse,AllSections,`,
	{
		if a_loopfield=general
			continue
		tempSection := A_LoopField
		
		loadElementID := RIni_GetKeyValue("IniFile", tempSection, "ID", "")
		if (loadElementID="")
		{
			logger("a0","Error! Could not read the ID of an element " tempSection ". This element will not be loaded")
			continue
		}
		loadElementClass := RIni_GetKeyValue("IniFile", tempSection, "Class", "")
		loadElementType := RIni_GetKeyValue("IniFile", tempSection, "Type", "")
		loadElementPackage := RIni_GetKeyValue("IniFile", tempSection, "Package", "Unknown")
		
		IfInString, tempSection ,element
		{
			if (loadElementType="Connection") ;outdated. kept for compability reasons
			{
				StringReplace,loadElementID,loadElementID,element,connection
				connection_New(FlowID, loadElementID)
				
				_flows[FlowID].allConnections[loadElementID].from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
				_flows[FlowID].allConnections[loadElementID].to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
				_flows[FlowID].allConnections[loadElementID].ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
				_flows[FlowID].allConnections[loadElementID].fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
				_flows[FlowID].allConnections[loadElementID].ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
			}
			else if (loadElementType="Trigger") ;this is the trigger container
			{
				loadElementID:=mainTriggerContainer
				
				_flows[FlowID].allElements[loadElementID].x:=RIni_GetKeyValue("IniFile", tempSection, "x", 100)
				_flows[FlowID].allElements[loadElementID].y:=RIni_GetKeyValue("IniFile", tempSection, "y", 100)
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				_flows[FlowID].allElements[loadElementID].Name:=tempValue
			}
			else
			{
				;~ d(loadElementID,loadElementType)
				element_New(FlowID, loadElementType,loadElementID) ;Pass element ID, so it will be the same as the last time
				
				tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
				StringReplace, tempValue, tempValue, |¶,`n, All
				_flows[FlowID].allElements[loadElementID].Name:=tempValue
				
				_flows[FlowID].allElements[loadElementID].StandardName:=RIni_GetKeyValue("IniFile", tempSection, "StandardName", "1")
				_flows[FlowID].allElements[loadElementID].x:=RIni_GetKeyValue("IniFile", tempSection, "x", 200)
				_flows[FlowID].allElements[loadElementID].y:=RIni_GetKeyValue("IniFile", tempSection, "y", 200)
				
				;Find out the element class
				if (loadElementClass="")
				{
					_flows[FlowID].allElements[loadElementID].subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", 200)
					_flows[FlowID].allElements[loadElementID].Class := _flows[FlowID].allElements[loadElementID].Type "_" _flows[FlowID].allElements[loadElementID].subType
				}
				else
				{
					_flows[FlowID].allElements[loadElementID].Class := loadElementClass
				}
				loadElementClass:=_flows[FlowID].allElements[loadElementID].Class

				;If element class is not installed, prepare a warning message
				if not (ObjHasValue(AllElementClasses,loadElementClass))
				{
					;~ MsgBox % _flows[FlowID].allElements[loadElementID].Class "`n" loadElementPackage
					if not (ObjHasValue(missingpackages,loadElementPackage))
						missingpackages.push(loadElementPackage)
				}
				
				LoadFlowCheckCompabilitySubtype(_flows[FlowID].allElements,loadElementID,tempSection)
				
				if (loadElementType="loop")
				{
					_flows[FlowID].allElements[loadElementID].HeightOfVerticalBar:=RIni_GetKeyValue("IniFile", tempSection, "HeightOfVerticalBar", 200)
				}
				
				;Get the list of all parameters and read all parameters from ini
				LoadFlowParametersOfElement(FlowID,_flows[FlowID].allElements,loadElementID,"IniFile",tempSection)
				
				;~ MsgBox % strobj(_flows[FlowID].allElements[loadElementID])
				
			}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
			LoadFlowCheckCompability(_flows[FlowID].allElements,loadElementID,tempSection,_flows[FlowID].CompabilityVersion)
			
			;If default name is selected, generate the name of the element
			if (_flows[FlowID].allElements[loadElementID].StandardName)
			{
				if (IsFunc("Element_GenerateName_" loadElementClass))
					_flows[FlowID].allElements[loadElementID].Name:=Element_GenerateName_%loadElementClass%(_flows[FlowID].allElements[loadElementID].par)
			}
		}
		
		IfInString,tempSection,connection
		{
			connection_new(FlowID, loadElementID)
			
			_flows[FlowID].allConnections[loadElementID].from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
			_flows[FlowID].allConnections[loadElementID].to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
			_flows[FlowID].allConnections[loadElementID].ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
			_flows[FlowID].allConnections[loadElementID].fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
			_flows[FlowID].allConnections[loadElementID].ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
			
			LoadFlowCheckCompability(_flows[FlowID].allConnections,loadElementID,tempSection,_flows[FlowID].CompabilityVersion)
		}
		
		
		IfInString,tempSection,trigger
		{
			tempContainerID:=RIni_GetKeyValue("IniFile", tempSection, "ContainerID", mainTriggerContainer)	;For later use. Maybe it will support multiple trigger container.
			
			trigger_new(FlowID, tempContainerID,loadElementID)
			
			_flows[FlowID].allTriggers[loadElementID].Type:=loadElementType
			
			;~ d(loadElement.Containerid,1)
			;~ d(allelements[loadElement.Containerid],1)
			
			tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			_flows[FlowID].allTriggers[loadElementID].Name:=tempValue
			
			
			_flows[FlowID].allTriggers[loadElementID].subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", "")
			
			LoadFlowParametersOfElement(FlowID,_flows[FlowID].allTriggers,loadElementID,"IniFile",tempSection)
			
			LoadFlowCheckCompability(_flows[FlowID].allTriggers,loadElementID,tempSection,_flows[FlowID].CompabilityVersion)
		}
		
	}
	_flows[FlowID].loaded:=true
	logger("a1","Flow " flowSettings.Name " was successfully loaded.")
	
	TriggerContainer_UpdateName(FlowID, mainTriggerContainer)
	
	;~ MsgBox % missingpackages.length()
	if (missingpackages.length()>0)
	{
		tempmissingpackageslist=
		for forkey, forvalue in missingpackages
		{
			tempmissingpackageslist.=forvalue ", "
		}
		StringTrimRight,tempmissingpackageslist,tempmissingpackageslist,2
		MsgBox % lang("Attention!") " " lang("This flow could not be loaded properly!") "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist 
	}
	;e_CorrectElementErrors("Loaded the saved flow")
	RIni_Shutdown("IniFile")
		
	currentlyLoadingFlow:=false
}

loadFlowGeneralParameters(FlowID)
{
	global
	local temp
	_flows[FlowID].flowSettings.Offsetx:=RIni_GetKeyValue("IniFile", "general", "Offsetx", default_OffsetX)
	_flows[FlowID].flowSettings.Offsety:=RIni_GetKeyValue("IniFile", "general", "Offsety", default_OffsetY)
	_flows[FlowID].flowSettings.zoomFactor:=RIni_GetKeyValue("IniFile", "general", "zoomFactor", default_ZoomFactor)
	_flows[FlowID].flowSettings.Name:=RIni_GetKeyValue("IniFile", "general", "name", "")
	_flows[FlowID].flowSettings.LogToFile:=RIni_GetKeyValue("IniFile", "general", "LogToFile", "")
	_flows[FlowID].flowSettings.FolderOfStaticVariables:=RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", flow.Folder "\Static variables\" flow.Filename)
	
	if not fileexist(_flows[FlowID].flowSettings.FolderOfStaticVariables)
	{
		FileCreateDir,% _flows[FlowID].flowSettings.FolderOfStaticVariables
		if not fileexist(_flows[FlowID].flowSettings.FolderOfStaticVariables)
		{
			MsgBox % lang("Attention!") "`n" lang("The working folder '%1%' does not exist and could not be created", _flows[FlowID].flowSettings.FolderOfStaticVariables)
		}
	}
	
}


;Loads the parameters of an element or trigger from the ini file
LoadFlowParametersOfElement(FlowID,parList,parElementID,parlocation, parSection)
{
	global
	local parametersToload, index, index2, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementClass:=parList[parElementID].class
	;~ d(parList,parElementID) 
	parametersToload:=Element_getParameters_%loadElementClass%()
	;~ d(parametersToload)
	for index, oneParameterID in parametersToload
	{
		;~ MsgBox % _flows[FlowID].CompabilityVersion
		if (_flows[FlowID].CompabilityVersion<=6)
			tempContent:=RIni_GetKeyValue(parlocation, parSection, oneParameterID, "ẺⱤᶉӧɼ")
		else
			tempContent:=RIni_GetKeyValue(parlocation, parSection, "par_" oneParameterID, "ẺⱤᶉӧɼ")
			
			
		if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
		{
			;~ MsgBox % "." strobj(parElement)
			tempContent:=parameterDefault[index2]
		}
		StringReplace, tempContent, tempContent, |¶,`n, All
		parList[parElementID].par[oneParameterID]:=tempContent
	
	}
}
