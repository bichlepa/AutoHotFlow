
;Can be called from other threads
LoadFlow(FlowID, filepath="", params="")
{
	if (FlowID="")
	{
		MsgBox internal error! A flow should be loaded but FlowID is empty!
		return
	}
	
	ifnotinstring,params,LoadAgain
	{
		if (_getFlowProperty(FlowID, "loaded"))
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
	
	EnterCriticalSection(_cs_shared)  ; We get, change and store an element in this function. keep this critical section to ensure data integrity

	IfInString, params, keepPosition
	{
		oldPosition:=objFullyClone(_getFlowProperty(FlowID, "flowSettings"))
	}
	
	
	if (filepath="")
	{
		ThisFlowFilepath := _getFlowProperty(FlowID, "file")
		ThisFlowFolder := _getFlowProperty(FlowID, "Folder")
		ThisFlowFilename := _getFlowProperty(FlowID, "FileName")
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
	
	flowSettings:=Object()
	IfNotInString, params,keepDraw
	;~ d(flow)
	AllSections:=RIni_GetSections("IniFile")
	_setFlowProperty(FlowID, "CompabilityVersion", RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0))
	_setFlowProperty(FlowID, "ElementIDCounter", RIni_GetKeyValue("IniFile", "general", "count", 1))
	flowSettings.ExecutionPolicy:=RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "default")
	flowSettings.DefaultWorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingDefaultWorkingDir", True)
	flowSettings.WorkingDir:=RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", _settings.FlowWorkingDir)
	
	_setFlowProperty(FlowID, "flowSettings", flowSettings)
	_setFlowProperty(FlowID, "markedElements", Object())
	IfNotInString, params, keepDraw
		_setFlowProperty(FlowID, "draw", Object())

	if not fileexist(flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% flowSettings.WorkingDir
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	loadFlowGeneralParameters(flowID)
	
	IfInString, params, keepPosition
	{
		_setFlowProperty(FlowID, "flowSettings.Offsetx", oldPosition.Offsetx)
		_setFlowProperty(FlowID, "flowSettings.Offsety", oldPosition.Offsety)
		_setFlowProperty(FlowID, "flowSettings.zoomFactor", oldPosition.zoomFactor)
	}
	
	
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
			;~ d(loadElementID,loadElementType)
			element_New(FlowID, loadElementType,loadElementID) ;Pass element ID, so it will be the same as the last time
			loadElement := _getElement(FlowID, loadElementID)
			
			tempValue:=RIni_GetKeyValue("IniFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name:=tempValue
			
			loadElement.StandardName:=RIni_GetKeyValue("IniFile", tempSection, "StandardName", "1")
			loadElement.x:=RIni_GetKeyValue("IniFile", tempSection, "x", 200)
			loadElement.y:=RIni_GetKeyValue("IniFile", tempSection, "y", 200)
			IsDefaultTriger:=RIni_GetKeyValue("IniFile", tempSection, "DefaultTrigger", False) 
			loadElement.Class := loadElementClass
			
			if (loadElementType="loop")
			{
				loadElement.HeightOfVerticalBar := RIni_GetKeyValue("IniFile", tempSection, "HeightOfVerticalBar", 200)
			}

			loadElement.icon:=Element_getIconPath_%loadElementClass%()
			_setElement(FlowID, loadElementID, loadElement)

			;Check the class (compatibility to old savefiles)
			LoadFlowCheckCompabilityClass(flowID, loadElementID, tempSection)
			loadElementClass := _getElementProperty(FlowID, loadElementID, "class")
			
			;If element class is not installed, prepare a warning message
			AllElementClasses := _getShared("AllElementClasses")
			if not (ObjHasValue(AllElementClasses, loadElementClass))
			{
				if not (ObjHasValue(missingpackages, loadElementPackage))
					missingpackages.push(loadElementPackage)
			}

			; If there is one manual trigger, one of them must be manual. Following code ensures this
			if (loadElementType="trigger")
			{
				;Set default trigger
				if (loadElement.Class = "trigger_manual")
				{
					if (IsDefaultTriger = True or Element_findDefaultTrigger(FlowID) = "")
					{
						Element_setDefaultTrigger(FlowID, loadElementID)
					}
				}
				AnyTriggerLoaded:=true
			}

			;Get the list of all parameters and read all parameters from ini
			LoadFlowParametersOfElement(flowID,loadElementID,"IniFile",tempSection)
			
			LoadFlowCheckCompabilityElement(flowID,loadElementID, tempSection, _getFlowProperty(FlowID, "CompabilityVersion"))
			
			;If default name is selected, generate the name of the element
			if (_getElementProperty(FlowID, ElementID, "StandardName"))
			{
				if (IsFunc("Element_GenerateName_" loadElementClass))
				{
					Newname:=Element_GenerateName_%loadElementClass%({flowID: flowID, elementID: loadElementID},  _getElementProperty(FlowID, loadElementID, "pars"))
					StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
					_setElementProperty(FlowID, ElementID, "Name", Newname)
				}
			}
		}
		else IfInString,tempSection,connection
		{
			connection_new(FlowID, loadElementID)
			loadElement := _getConnection(FlowID, loadElementID)
			
			loadElement.from:=RIni_GetKeyValue("IniFile", tempSection, "from", "")
			loadElement.to:=RIni_GetKeyValue("IniFile", tempSection, "to", "")
			loadElement.ConnectionType:=RIni_GetKeyValue("IniFile", tempSection, "ConnectionType", "")
			loadElement.fromPart:=RIni_GetKeyValue("IniFile", tempSection, "fromPart", "")
			loadElement.ToPart:=RIni_GetKeyValue("IniFile", tempSection, "ToPart", "")
			loadElement := _setConnection(FlowID, loadElementID, loadElement)
			
			LoadFlowCheckCompabilityElement(FlowID, loadElementID, tempSection, _flows[FlowID].CompabilityVersion)
		}
		else
		{
			logger("a1","Flow " flowSettings.Name " error on loading: unknown section: '" tempSection "'.")
		}
		
	}
	if not AnyTriggerLoaded
	{
		loadElementID := element_New(FlowID, "trigger")
		Element_SetClass(FlowID, loadElementID, "Trigger_Manual")
	}
	LoadFlowCheckCompabilityFlow(flowID, _getFlowProperty(FlowID, "CompabilityVersion"))
	
	
	if not (_getFlowProperty(FlowID, "firstLoadedTime"))
		_setFlowProperty(FlowID, "firstLoadedTime", a_now)
	_setFlowProperty(FlowID, "loaded", true)
	logger("a1","Flow " flowSettings.Name " was loaded.")
	
	if (missingpackages.length()>0)
	{ 
		tempmissingpackageslist := ""
		for forkey, forvalue in missingpackages
		{
			tempmissingpackageslist .= forvalue ", "
		}
		StringTrimRight, tempmissingpackageslist, tempmissingpackageslist, 2
		MsgBox % lang("Attention!") " " lang("The flow '%1%' could not be loaded properly!" _getFlowProperty(FlowID, "name")) "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist "`n`n" lang("Debug Info") ":`n" lang("Filename") ": " ThisFlowFilepath
	}
	
	RIni_Shutdown("IniFile")
	
	IfnotInString, params, NoNewState
	{
		state_New(FlowID)

		_setFlowProperty(FlowID, "savedState", _getFlowProperty(FlowID, "currentState"))
	}
	
	LeaveCriticalSection(_cs_shared)
	currentlyLoadingFlow:=false
}

loadFlowGeneralParameters(flowID)
{
	EnterCriticalSection(_cs_shared)
	
	flowSettings := _getFlowProperty(FlowID, "flowSettings")

	flowSettings.Offsetx:=RIni_GetKeyValue("IniFile", "general", "Offsetx", default_OffsetX)
	flowSettings.Offsety:=RIni_GetKeyValue("IniFile", "general", "Offsety", default_OffsetY)
	flowSettings.zoomFactor:=RIni_GetKeyValue("IniFile", "general", "zoomFactor", default_ZoomFactor)
	flowSettings.Name:=RIni_GetKeyValue("IniFile", "general", "name", "")
	flowSettings.FolderOfStaticVariables:=RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", ThisFlowFolder "\Static variables\" ThisFlowFilename)
	_setFlowProperty(FlowID, "flowSettings", flowSettings)
	LeaveCriticalSection(_cs_shared)
	
	if not fileexist(.flowSettings.FolderOfStaticVariables)
	{
		FileCreateDir,% flowSettings.FolderOfStaticVariables
		if not fileexist(flowSettings.FolderOfStaticVariables)
		{
			logger("a0","Error! The working folder '" flowSettings.FolderOfStaticVariables "' does not exist and could not be created.")
			MsgBox % lang("Error!") "`n" lang("The working folder '%1%' does not exist and could not be created", flowSettings.FolderOfStaticVariables)
		}
	}
	
}


;Loads the parameters of an element or trigger from the ini file
LoadFlowParametersOfElement(p_flowID,p_ElementID,p_Location, p_Section)
{
	loadElementClass := _getElementProperty(p_flowID, p_ElementID, "class")
	parametersToload := Element_getParameters(loadElementClass, {flowID: p_flowID, elementID: p_ElementID})
	parametersToloadDetails := Element_getParametrizationDetails(loadElementClass, {flowID: p_flowID, elementID: p_ElementID})

	pars := _getElementProperty(p_flowID, p_ElementID, "pars")

	; Loop through list of all parameters which must be loaded
	for index, oneParameterID in parametersToload
	{
		; Find the default value of this parameter in the detailed parameter list
		for index2, oneParameterDetail in parametersToloadDetails
		{
			if (oneParameterDetail.ID)
			{
				if not isobject(oneParameterDetail.ID)
				{
					oneParameterDetail.ID := [oneParameterDetail.ID]
				}
				if not isobject(oneParameterDetail.Default)
				{
					oneParameterDetail.Default := [oneParameterDetail.Default]
				}
				for index3, OneID in oneParameterDetail.ID
				{
					if (OneID = oneParameterID)
					{
						parameterDefault := oneParameterDetail.default[index3]
						break
					}
				}
			}
			if (oneParameterDetail.ContentID)
			{
				if not isobject(oneParameterDetail.ContentID)
				{
					oneParameterDetail.ContentID := [oneParameterDetail.ContentID]
				}
				if not isobject(oneParameterDetail.Default)
				{
					oneParameterDetail.ContentDefault := [oneParameterDetail.ContentDefault]
				}
				for index3, OneID in oneParameterDetail.ContentID
				{
					if (OneID = oneParameterID)
					{
						parameterDefault := oneParameterDetail.ContentDefault[index3]
						break
					}
				}
			}
		}
		tempContent:=RIni_GetKeyValue(p_Location, p_Section, "par_" oneParameterID, "ẺⱤᶉӧɼ")
			
			
		if (tempContent=="ẺⱤᶉӧɼ") ;If a parameter is not set (maybe because some new parameters were added to this element after Update of AHF)
		{
			tempContent:=parameterDefault
		}
		StringReplace, tempContent, tempContent, |¶,`n, All
		if (substr(tempContent,1,3) = "ῸВĴ")
		{
			StringReplace, tempContent, tempContent, ῸВĴ
			StringReplace, tempContent, tempContent, linēfḙ℮d, `n
			StringReplace, tempContent, tempContent, ₸ÅḆ, % a_tab
			tempContent:=strobj(tempContent)
		}
		pars[oneParameterID] := tempContent
		
	}
	_setElementProperty(p_flowID, p_ElementID, "pars", pars)
}
