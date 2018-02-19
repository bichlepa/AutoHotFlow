
;Can be called from other threads
LoadFlow(FlowID, filepath="", params="")
{
	global
	local FinishedSaving, tempValue, FlowCompabilityVersion, ID_count, index1, index2
	local loadElement, loadElementID, loadElementType, loadElementTriggerContainer, loadElementClass
	local AllSections, tempSection, tempContainerID, missingpackages, tempName
	local AnyTriggerLoaded, OutdatedMainTriggerContainerData
	
	OutdatedMainTriggerContainerData:=Object()
	
	if (FlowID="")
	{
		MsgBox internal error! A flow should be loaded but no FlowID is empty!
		return
	}
	
	ifnotinstring,params,LoadAgain
	{
		if (_flows[FlowID].loaded)
		{
			MsgBox unexpected error. Flow %FlowID% should be loaded but it was already loaded
			return
		}
	}
	
	if (currentlyLoadingFlow = true)
	{
		MsgBox unexpected error. a flow is already currently loading
		return
	}
	currentlyLoadingFlow:=true
	
	IfInString, params, keepPosition
	{
		oldPosition:=objFullyClone(_flows[FlowID].flowSettings)
	}
	
	
	if (filepath="")
	{
		ThisFlowFilepath := _flows[FlowID].file
		ThisFlowFolder := _flows[FlowID].Folder
		ThisFlowFilename :=_flows[FlowID].FileName
	}
	else
	{
		ThisFlowFilepath:=filepath
		SplitPath, ThisFlowFilepath,,ThisFlowFolder,,ThisFlowFilename
	}
	
	;~ MsgBox %ThisFlowFilepath% - %ThisFlowFolder% - %ThisFlowFilename%
	
	missingpackages :=Object()
	logger("a1", "Loading flow from file: " ThisFlowFilePath)
	
		;~ d(_flows, FlowID)
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0", "ERROR! Flow file " ThisFlowFolder "\ "ThisFlowFilename ".ini" " does not exist!")
		MsgBox % "ERROR! Flow file " ThisFlowFolder "\" ThisFlowFilename ".ini" " does not exist!"
	}
	
	
	;read ini file
	
	res:=RIni_Read("IniFile",ThisFlowFilepath)
	if res
		MsgBox Failed to load the ini file. Error code: %res%
	
	_flows[FlowID].allElements:=CriticalObject()
	_flows[FlowID].allConnections:=CriticalObject()
	_flows[FlowID].markedElements:=CriticalObject()
	_flows[FlowID].flowSettings:=CriticalObject()
	IfNotInString, params,keepDraw
		_flows[FlowID].draw:=CriticalObject()
	;~ d(_flows[flowid])
	AllSections:=RIni_GetSections("IniFile")
	_flows[FlowID].CompabilityVersion:=RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0)
	_flows[FlowID].ElementIDCounter:=RIni_GetKeyValue("IniFile", "general", "count", 1)
	_flows[FlowID].flowSettings.ExecutionPolicy:=RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "default")
	_flows[FlowID].flowSettings.DefaultWorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingDefaultWorkingDir", True)
	_flows[FlowID].flowSettings.WorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", _settings.FlowWorkingDir)
	if not fileexist(_flows[FlowID].flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% _flows[FlowID].flowSettings.WorkingDir
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	loadFlowGeneralParameters(FlowID) ;Outsourced in order to execute only that later when flow name changes
	
	;~ Element_New(FlowID, "trigger", "trigger")
	
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
			else if (loadElementType="Trigger" && RIni_GetKeyValue("IniFile", tempSection, "class", "") =="") ;this is the outdated trigger container
			{
				;~ MsgBox outdated trigger container found
				OutdatedMainTriggerContainerData.id := loadElementID
				OutdatedMainTriggerContainerData.x:=RIni_GetKeyValue("IniFile", tempSection, "x", 100)
				OutdatedMainTriggerContainerData.y:=RIni_GetKeyValue("IniFile", tempSection, "y", 100)
				
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
				IsDefaultTriger:=RIni_GetKeyValue("IniFile", tempSection, "DefaultTrigger", False) 
				
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
				
				;Check the class
				LoadFlowCheckCompabilityClass(_flows[FlowID].allElements,loadElementID,tempSection)
				
				loadElementClass:=_flows[FlowID].allElements[loadElementID].Class
				
				;If element class is not installed, prepare a warning message
				if not (ObjHasValue(AllElementClasses,loadElementClass))
				{
					;~ d(_flows[FlowID], FlowID " - " loadElementPackage)
					if not (ObjHasValue(missingpackages,loadElementPackage))
						missingpackages.push(loadElementPackage)
				}
				
				
				if (loadElementType="loop")
				{
					_flows[FlowID].allElements[loadElementID].HeightOfVerticalBar:=RIni_GetKeyValue("IniFile", tempSection, "HeightOfVerticalBar", 200)
				}
				if (loadElementType="trigger")
				{
					
					;Set default trigger
					if (_flows[FlowID].allElements[loadElementID].Class = "trigger_manual")
					{
						if (IsDefaultTriger = True or Element_findDefaultTrigger(FlowID) = "")
						{
							Element_setDefaultTrigger(FlowID, loadElementID)
						}
					}
					AnyTriggerLoaded:=true
					;~ d(_flows[FlowID].allElements[loadElementID])
				}
				;Get the list of all parameters and read all parameters from ini
				LoadFlowParametersOfElement(FlowID,_flows[FlowID].allElements,loadElementID,"IniFile",tempSection)
				
				;~ MsgBox % strobj(_flows[FlowID].allElements[loadElementID])
				
				_flows[FlowID].allElements[loadElementID].icon:=Element_getIconPath_%loadElementClass%()
			}
			;~ d_ExportAllDataToFile()
			;~ MsgBox --- %loadElementID% %loadElementType%
			LoadFlowCheckCompability(_flows[FlowID].allElements,loadElementID,tempSection,_flows[FlowID].CompabilityVersion)
			
			;If default name is selected, generate the name of the element
			if (_flows[FlowID].allElements[loadElementID].StandardName)
			{
				if (IsFunc("Element_GenerateName_" loadElementClass))
				{
					Newname:=Element_GenerateName_%loadElementClass%(_flows[FlowID].allElements[loadElementID],_flows[FlowID].allElements[loadElementID].pars)
					StringReplace,Newname,Newname,`n,%a_space%-%a_space%,all
					_flows[FlowID].allElements[loadElementID].Name:=Newname
				}
			}
		}
		
		;outdated connections
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
		
		;Outdated triggers
		IfInString,tempSection,trigger
		{
			element_New(FlowID, "trigger", loadElementID)
			
			_flows[FlowID].allElements[loadElementID].Type:=loadElementType
			
			;~ d(loadElement.Containerid,1)
			;~ d(allelements[loadElement.Containerid],1)
			
			tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			_flows[FlowID].allElements[loadElementID].Name:=tempValue
			
			_flows[FlowID].allElements[loadElementID].subType:=RIni_GetKeyValue("IniFile", tempSection, "subType", "") 
			
			;Find out the trigger class
			if (loadElementClass="")
			{
				_flows[FlowID].allElements[loadElementID].Class := _flows[FlowID].allElements[loadElementID].Type "_" _flows[FlowID].allElements[loadElementID].subType
			}
			else
			{
				_flows[FlowID].allElements[loadElementID].Class := loadElementClass
			}
			
			
			
			;If element class is not installed, prepare a warning message
			if not (ObjHasValue(AllTriggerClasses,loadElementClass))
			{
				;~ MsgBox % _flows[FlowID].allElements[loadElementID].Class "`n" loadElementPackage
				if not (ObjHasValue(missingpackages,loadElementPackage))
					missingpackages.push(loadElementPackage)
			}
			
			
			;~ d(_flows[FlowID].allElements[loadElementID])
			LoadFlowParametersOfElement(FlowID,_flows[FlowID].allElements,loadElementID,"IniFile",tempSection)
			
			LoadFlowCheckCompability(_flows[FlowID].allElements,loadElementID,tempSection,_flows[FlowID].CompabilityVersion)
			
			;Set default trigger
			if (_flows[FlowID].allElements[loadElementID].Class = "trigger_manual")
			{
				if (Element_findDefaultTrigger(FlowID) = "")
				{
					Element_setDefaultTrigger(FlowID, loadElementID)
				}
			}
			
			AnyTriggerLoaded:=True
		}
		
	}
	if not AnyTriggerLoaded
	{
		loadElementID := element_New(FlowID, "trigger")
		Element_SetClass(FlowID, loadElementID, "Trigger_Manual")
		;~ d(_flows[flowID].allelements[loadElementID])
	}
	LoadFlowCheckCompabilityOverall(_flows[FlowID],_flows[FlowID].CompabilityVersion, OutdatedMainTriggerContainerData)
		;~ d(_flows[flowID].allelements[loadElementID])
	
	;Regenerate Names
	for forElementID, forElement in _flows[FlowID].allElements
	{
		if (forElement.StandardName = True)
		{
			loadElementClass:=forElement.class
			if isfunc(Element_GenerateName_%loadElementClass%)
				forElement.name:=Element_GenerateName_%loadElementClass%(forElement.pars)
			;~ d(forElement, Element_GenerateName_%loadElementClass%(forElement.pars))
		}
	}
	
	IfInString, params, keepPosition
	{
		_flows[FlowID].flowSettings.Offsetx:=oldPosition.Offsetx
		_flows[FlowID].flowSettings.Offsety:=oldPosition.Offsety
		_flows[FlowID].flowSettings.zoomFactor:=oldPosition.zoomFactor
	}
	
	if not (_flows[FlowID].firstLoadedTime)
		_flows[FlowID].firstLoadedTime:=a_now
	_flows[FlowID].loaded:=true
	logger("a1","Flow " flowSettings.Name " was successfully loaded.")
	
	;~ MsgBox % missingpackages.length()
	if (missingpackages.length()>0)
	{
		tempmissingpackageslist=
		for forkey, forvalue in missingpackages
		{
			tempmissingpackageslist.=forvalue ", "
		}
		StringTrimRight,tempmissingpackageslist,tempmissingpackageslist,2
		MsgBox % lang("Attention!") " " lang("The flow '%1%' could not be loaded properly!", _flows[FlowID].name) "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist "`n`n" lang("Debug Info") ":`n" lang("Filename") ": " _flows[FlowID].FileName
	}
	;e_CorrectElementErrors("Loaded the saved flow")
	RIni_Shutdown("IniFile")
	
	IfnotInString, params, NoNewState
	{
		state_New(FlowID)
		_flows[FlowID].savedState:=_flows[FlowID].currentState
	}
	
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
	_flows[FlowID].flowSettings.FolderOfStaticVariables:=RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", ThisFlowFolder "\Static variables\" ThisFlowFilename)
	
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
	local parametersToload, index, index2, oneParameterDetail, parameter, parameterID, parameterDefault, tempContent, OneID, loadElementType, loadElementsubType

	loadElementClass:=parList[parElementID].class
	;~ d(parList,parElementID) 
	parametersToload:=Element_getParameters(loadElementClass, {flowID: FlowID, elementID: parElementID})
	parametersToloadDetails:=Element_getParametrizationDetails(loadElementClass, {flowID: FlowID, elementID: parElementID})
	;~ d(parametersToload,"parametersToload")
	;~ d(parametersToloadDetails, "parametersToloadDetails")

	for index, oneParameterID in parametersToload
	{
		for index2, oneParameterDetail in parametersToloadDetails
		{
			if (oneParameterDetail.ID)
			{
				if not isobject(oneParameterDetail.ID)
				{
					oneParameterDetail.ID :=[oneParameterDetail.ID]
				}
				if not isobject(oneParameterDetail.Default)
				{
					oneParameterDetail.Default :=[oneParameterDetail.Default]
				}
				for index3, OneID in oneParameterDetail.ID
				{
					if (OneID = oneParameterID)
					{
						parameterDefault:=oneParameterDetail.default[index3]
						break
					}
				}
			}
			if (oneParameterDetail.ContentID)
			{
				if not isobject(oneParameterDetail.ContentID)
				{
					oneParameterDetail.ContentID :=[oneParameterDetail.ContentID]
				}
				if not isobject(oneParameterDetail.Default)
				{
					oneParameterDetail.ContentDefault :=[oneParameterDetail.ContentDefault]
				}
				for index3, OneID in oneParameterDetail.ContentID
				{
					if (OneID = oneParameterID)
					{
						parameterDefault:=oneParameterDetail.ContentDefault[index3]
						break
					}
				}
			}
		}
		;~ MsgBox % _flows[FlowID].CompabilityVersion
		if (_flows[FlowID].CompabilityVersion<=6)
			tempContent:=RIni_GetKeyValue(parlocation, parSection, oneParameterID, "ẺⱤᶉӧɼ")
		else
			tempContent:=RIni_GetKeyValue(parlocation, parSection, "par_" oneParameterID, "ẺⱤᶉӧɼ")
			
			
		if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
		{
			tempContent:=parameterDefault
			;~ d(oneParameterDetail, oneParameterID " - " tempContent)
		}
		StringReplace, tempContent, tempContent, |¶,`n, All
		if (substr(tempContent,1,3) = "ῸВĴ")
		{
			StringReplace, tempContent, tempContent, ῸВĴ
			StringReplace, tempContent, tempContent, linēfḙ℮d, `n
			StringReplace, tempContent, tempContent, ₸ÅḆ, % a_tab
			tempContent:=strobj(tempContent)
		}
		parList[parElementID].pars[oneParameterID]:=tempContent
		
	}
}
