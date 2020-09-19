
;load all flow information from file (additionally to meta data)
;FlowID is needed
;if p_filepath is not set, the path in flow object is taken (this is the usual case)
;p_params: a string which can contain following strings:
; - keepPosition: do not load element positions
; - keepDraw: do not overwrite the object with the draw results
; - loadAgain: if a flow is already loaded, this parameter will suppress the error message and load anyway
; - noNewState: does not create a new state when loaded
LoadFlow(FlowID, p_filepath = "", p_params = "")
{
	global default_OffsetX, default_OffsetY, default_ZoomFactor
	global currentlyLoadingFlow

	; cath some bugs
	if (FlowID="")
	{
		throw Exception("unexpected error! A flow should be loaded but FlowID is empty!")
		return
	}
	
	; a flow cannot be loaded twice (anyway it can be loaded again if p_params contains "loadAgain")
	ifnotinstring, p_params, LoadAgain
	{
		if (_getFlowProperty(FlowID, "loaded"))
		{
			throw Exception("unexpected error. Flow %FlowID% should be loaded but it was already loaded")
			return
		}
	}
	
	; ensure that only one flow is loading at time
	if (currentlyLoadingFlow = true)
	{
		throw Exception("unexpected error. a flow is already currently loading")
		return
	}

	currentlyLoadingFlow:=true
	
	_EnterCriticalSection()  ; We get, change and store an element in this function. keep this critical section to ensure data integrity

	; if we need to keep position, copy the position data, to restore it later
	IfInString, p_params, keepPosition
	{
		oldPosition := objFullyClone(_getFlowProperty(FlowID, "flowSettings"))
	}
	
	
	if (p_filepath="")
	{
		; file path is not passed to this function. Take the path from flow object (this is the usual case)
		ThisFlowFilepath := _getFlowProperty(FlowID, "file")
		ThisFlowFolder := _getFlowProperty(FlowID, "Folder")
		ThisFlowFilename := _getFlowProperty(FlowID, "FileName")
	}
	else
	{
		; file path is passed, take this path
		ThisFlowFilepath := p_filepath
		SplitPath, ThisFlowFilepath, , ThisFlowFolder, , ThisFlowFilename
	}
	
	; if we load a flow and do not find some element impelementations, probably a package is missing. We will write missing packages here and warn user later
	missingpackages :=Object()

	logger("a1", "Loading flow from file: " ThisFlowFilePath)
	
	; check whether the file exists
	IfnotExist,%ThisFlowFolder%\%ThisFlowFilename%.ini
	{
		logger("a0", "ERROR! Flow file " ThisFlowFolder "\ "ThisFlowFilename ".ini" " does not exist!")
		MsgBox % "ERROR! Flow file " ThisFlowFolder "\" ThisFlowFilename ".ini" " does not exist!"
		return
	}
	
	
	;open ini file for read
	res := RIni_Read("IniFile", ThisFlowFilepath)
	if res
	{
		; there was an error
		logger("a0", "ERROR! Failed to load the ini file. Error code: " res)
		MsgBox  % "ERROR! Failed to load the ini file. Error code: " res
		return
	}

	; load flow settings. If not present in file, set default values
	flowSettings := Object()
	_setFlowProperty(FlowID, "CompabilityVersion", RIni_GetKeyValue("IniFile", "general", "FlowCompabilityVersion", 0))
	_setFlowProperty(FlowID, "ElementIDCounter", RIni_GetKeyValue("IniFile", "general", "count", 1))
	flowSettings.ExecutionPolicy := RIni_GetKeyValue("IniFile", "general", "SettingFlowExecutionPolicy", "default")
	flowSettings.DefaultWorkingDir := RIni_GetKeyValue("IniFile", "general", "SettingDefaultWorkingDir", True)
	flowSettings.WorkingDir := RIni_GetKeyValue("IniFile", "general", "SettingWorkingDir", _getSettings("path"))
	
	; load meta data ( which are general information which either is need by the manager or is often changed)
	flowSettings.Offsetx := RIni_GetKeyValue("IniFile", "general", "Offsetx", default_OffsetX)
	flowSettings.Offsety := RIni_GetKeyValue("IniFile", "general", "Offsety", default_OffsetY)
	flowSettings.zoomFactor := RIni_GetKeyValue("IniFile", "general", "zoomFactor", default_ZoomFactor)
	flowSettings.Name := RIni_GetKeyValue("IniFile", "general", "name", "")

	; load and chack folder with static variables
	flowSettings.FolderOfStaticVariables := RIni_GetKeyValue("IniFile", "general", "FolderOfStaticVariables", ThisFlowFolder "\Static variables\" ThisFlowFilename)
	if not fileexist(flowSettings.FolderOfStaticVariables)
	{
		FileCreateDir,% flowSettings.FolderOfStaticVariables
		if not fileexist(flowSettings.FolderOfStaticVariables)
		{
			logger("a0","Error! The working folder '" flowSettings.FolderOfStaticVariables "' does not exist and could not be created.")
			MsgBox % lang("Error!") "`n" lang("The working folder '%1%' does not exist and could not be created", flowSettings.FolderOfStaticVariables)
		}
	}

	; write loaded flow settings
	_setFlowProperty(FlowID, "flowSettings", flowSettings)

	; create object which will contain selected elements
	_setFlowProperty(FlowID, "selectedElements", Object())

	; create object which will contain draw results
	IfNotInString, p_params, keepDraw
		_setFlowProperty(FlowID, "draw", Object())

	; check working directory
	if not fileexist(flowSettings.WorkingDir)
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% flowSettings.WorkingDir
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
	}
	
	
	; restore position, if requested
	IfInString, p_params, keepPosition
	{
		_setFlowProperty(FlowID, "flowSettings.Offsetx", oldPosition.Offsetx)
		_setFlowProperty(FlowID, "flowSettings.Offsety", oldPosition.Offsety)
		_setFlowProperty(FlowID, "flowSettings.zoomFactor", oldPosition.zoomFactor)
	}
	
	;Loop through all ellements and load them
	AllSections := RIni_GetSections("IniFile")
	loop, parse, AllSections, `,
	{
		oneSection := A_LoopField

		; the section "general" does not contain an element or connection
		if (oneSection = "general")
			continue
		
		; get element ID
		loadElementID := RIni_GetKeyValue("IniFile", oneSection, "ID", "")
		if (loadElementID = "")
		{
			; the the element id must be defined in file. if not, skip it
			logger("a0","Error! Could not read the ID of an element " oneSection ". This element will not be loaded")
			continue
		}

		; get more informations
		loadElementType := RIni_GetKeyValue("IniFile", oneSection, "Type", "")
		loadElementPackage := RIni_GetKeyValue("IniFile", oneSection, "Package", "Unknown")
		
		; check wheter it is an element or a connection
		IfInString, oneSection, element
		{
			; this is an element.
			; create the new element keeping its ID
			element_New(FlowID, loadElementType, loadElementID)

			; we will change many properties, so get the whole element object
			loadElement := _getElement(FlowID, loadElementID)
			
			; get element name
			tempValue := RIni_GetKeyValue("IniFile", oneSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name := tempValue
			
			; get more common element properties
			loadElement.StandardName := RIni_GetKeyValue("IniFile", oneSection, "StandardName", "1")
			loadElement.x := RIni_GetKeyValue("IniFile", oneSection, "x", 200)
			loadElement.y := RIni_GetKeyValue("IniFile", oneSection, "y", 200)
			IsDefaultTriger := RIni_GetKeyValue("IniFile", oneSection, "DefaultTrigger", False) 
			loadElement.Class := RIni_GetKeyValue("IniFile", oneSection, "Class", "")
			
			if (loadElementType = "loop")
			{
				; get loop specific properties
				loadElement.HeightOfVerticalBar := RIni_GetKeyValue("IniFile", oneSection, "HeightOfVerticalBar", 200)
			}

			; get element icon
			loadElement.icon := Element_getIconPath_%loadElementClass%()

			; write the whole changed element object
			_setElement(FlowID, loadElementID, loadElement)

			;Check the class (compatibility to old savefiles)
			LoadFlowCheckCompabilityClass(flowID, loadElementID, oneSection)
			loadElementClass := _getElementProperty(FlowID, loadElementID, "class")
			
			;Check whether we have the implementation of the element class
			AllElementClasses := _getShared("AllElementClasses")
			if not (ObjHasValue(AllElementClasses, loadElementClass))
			{
				; we do not have the implementation. A package is missing. Warn user later
				if not (ObjHasValue(missingpackages, loadElementPackage))
					missingpackages.push(loadElementPackage)
			}

			; If there is one manual trigger, one of them must be manual. Following code ensures this
			if (loadElementType="trigger")
			{
				if (loadElement.Class = "trigger_manual")
				{
					if (IsDefaultTriger = True or Element_findDefaultTrigger(FlowID) = "")
					{
						Element_setDefaultTrigger(FlowID, loadElementID)
					}
				}
				; we loaded a trigger. Remember this
				AnyTriggerLoaded := true
			}

			;Get the list of all parameters and read all parameters from ini
			LoadFlowParametersOfElement(flowID, loadElementID, "IniFile", oneSection)
			
			; Ensure backward compatibility
			LoadFlowCheckCompabilityElement(flowID,loadElementID, oneSection, _getFlowProperty(FlowID, "CompabilityVersion"))
			
			;If property "default name" is enabled, regenerate the name of the element
			if (_getElementProperty(FlowID, loadElementID, "StandardName"))
			{
				if (IsFunc("Element_GenerateName_" loadElementClass))
				{
					Newname := Element_GenerateName_%loadElementClass%({flowID: flowID, elementID: loadElementID},  _getElementProperty(FlowID, loadElementID, "pars"))
					StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
					_setElementProperty(FlowID, loadElementID, "Name", Newname)
				}
			}
		}
		else IfInString,oneSection,connection
		{
			; this is a connection.
			; create a new connection and keep its ID
			connection_new(FlowID, loadElementID)

			; we will change many properties, so get the whole connection object
			loadElement := _getConnection(FlowID, loadElementID)
			
			; load element properties
			loadElement.from:=RIni_GetKeyValue("IniFile", oneSection, "from", "")
			loadElement.to:=RIni_GetKeyValue("IniFile", oneSection, "to", "")
			loadElement.ConnectionType:=RIni_GetKeyValue("IniFile", oneSection, "ConnectionType", "")
			loadElement.fromPart:=RIni_GetKeyValue("IniFile", oneSection, "fromPart", "")
			loadElement.ToPart:=RIni_GetKeyValue("IniFile", oneSection, "ToPart", "")

			; write the whole changed connection object
			loadElement := _setConnection(FlowID, loadElementID, loadElement)
			
			; ensure backward compatibility
			LoadFlowCheckCompabilityConnection(FlowID, loadElementID, oneSection, _getFlowProperty(FlowID, "CompabilityVersion"))
		}
		else
		{
			; the section name is invalid
			logger("a1","Flow " flowSettings.Name " error on loading: unknown section: '" oneSection "'.")
		}
	}

	; does the flow contain any trigger?
	if not AnyTriggerLoaded
	{
		; if not, this might be an empty flow. Create a new manual trigger
		loadElementID := element_New(FlowID, "trigger")
		loadElementClass := "Trigger_Manual"
		Element_SetClass(FlowID, loadElementID, loadElementClass)

		;Load default parameters for the new trigger (well knowin that it is not in file)
		LoadFlowParametersOfElement(flowID, loadElementID, "IniFile", "notExistingDummyName")
		Newname := Element_GenerateName_%loadElementClass%({flowID: flowID, elementID: loadElementID},  _getElementProperty(FlowID, loadElementID, "pars"))
		StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
		_setElementProperty(FlowID, loadElementID, "Name", Newname)
	}

	; ensure backward compatibility
	LoadFlowCheckCompabilityFlow(flowID, _getFlowProperty(FlowID, "CompabilityVersion"))
	
	; write time when we loaded the flow
	if not (_getFlowProperty(FlowID, "firstLoadedTime"))
		_setFlowProperty(FlowID, "firstLoadedTime", a_now)

	; the flow is now loaded, write this info
	_setFlowProperty(FlowID, "loaded", true)

	logger("a1","Flow " flowSettings.Name " was loaded.")
	
	; did we find missing packages
	if (missingpackages.length() > 0)
	{
		; warn user about the missing packages
		tempmissingpackageslist := ""
		for forkey, forvalue in missingpackages
		{
			tempmissingpackageslist .= forvalue ", "
		}
		StringTrimRight, tempmissingpackageslist, tempmissingpackageslist, 2
		MsgBox % lang("Attention!") " " lang("The flow '%1%' could not be loaded properly!" _getFlowProperty(FlowID, "name")) "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist "`n`n" lang("Debug Info") ":`n" lang("Filename") ": " ThisFlowFilepath
	}
	
	; close ini file
	RIni_Shutdown("IniFile")
	
	; create a new state (can be suppressed with paraemter)
	IfnotInString, p_params, NoNewState
	{
		state_New(FlowID)
		_setFlowProperty(FlowID, "savedState", _getFlowProperty(FlowID, "currentState"))
	}
	
	_LeaveCriticalSection()
	currentlyLoadingFlow:=false
}


;Loads the parameters of an element or trigger from the ini file
LoadFlowParametersOfElement(p_flowID, p_ElementID, p_Location, p_Section)
{
	; get element class
	loadElementClass := _getElementProperty(p_flowID, p_ElementID, "class")

	; get informations about the parameter which we need to load
	parametersToload := Element_getParameters(loadElementClass, {flowID: p_flowID, elementID: p_ElementID})
	parametersToloadDetails := Element_getParametrizationDetails(loadElementClass, {flowID: p_flowID, elementID: p_ElementID})

	; get object with the element parameters
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

		; get parameter from savefile, if not found, set default value
		tempContent := RIni_GetKeyValue(p_Location, p_Section, "par_" oneParameterID, parameterDefault)
		
		; replace some characters which are forbidden in an ini file
		StringReplace, tempContent, tempContent, |¶,`n, All
		if (substr(tempContent,1,3) = "ῸВĴ")
		{
			StringReplace, tempContent, tempContent, ῸВĴ
			StringReplace, tempContent, tempContent, linēfḙ℮d, `n
			StringReplace, tempContent, tempContent, ₸ÅḆ, % a_tab
			tempContent:=strobj(tempContent)
		}

		; write parameter in object
		pars[oneParameterID] := tempContent
	}

	; write object with element parameters
	_setElementProperty(p_flowID, p_ElementID, "pars", pars)
}
