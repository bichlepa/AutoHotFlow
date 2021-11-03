
;load all flow information from file (additionally to meta data)
LoadFlow(p_filepath, p_demo = false)
{
	global currentlyLoadingFlow
	
	; Split file path
	ThisFlowFilepath := p_filepath
	SplitPath, ThisFlowFilepath, , ThisFlowFolder, , ThisFlowFilename

	logger("a1", "Loading flow from file: " ThisFlowFilePath)
	
	; check whether the file exists
	IfnotExist,% ThisFlowFilepath
	{
		logger("a0", "ERROR! Flow file " ThisFlowFilepath " does not exist!")
		MsgBox % "ERROR! Flow file " ThisFlowFilepath " does not exist!"
		return
	}

	FileRead, fileContent, % ThisFlowFilepath
	if ErrorLevel
	{
		logger("a0", "ERROR! Failed to load flow from " ThisFlowFilepath ". Error code: " A_LastError)
		MsgBox  % "ERROR! Failed to load flow from " ThisFlowFilepath ". Error code: " A_LastError
		return
	}

	if not fileContent
	{
		logger("a0", "ERROR! : " A_LastError)
		MsgBox  % "ERROR! Flow savefile " ThisFlowFilepath " is empty"
		return
	}
	
	; ensure that only one flow is loading at time
	if (currentlyLoadingFlow = true)
	{
		throw Exception("unexpected error. a flow is already currently loading")
		return
	}
	currentlyLoadingFlow:=true

	; convert to object
	fileContent := Jxon_Load(fileContent)

	_EnterCriticalSection()  ; We get, change and store an element in this function. keep this critical section to ensure data integrity
	
	if (not p_demo)
	{
		; We the category is saved as as name. After loading, we need the category ID here.
		categoryname := fileContent.category
		if (categoryname)
		{
			; category is set. Create category if it does not exist
			categoryID := _getCategoryIdByName(categoryname)
			if (not categoryID)
				categoryID := NewCategory(categoryname)

			; set the category ID
			fileContent.category := categoryID
		}
	}
	Else
	{
		; demo flows do not need a dedicated cetegory
	}

	; create a new flow
	flowID := NewFlow(fileContent.category, ThisFlowFilename)

	; get the flow object
	flow := _getFlow(FlowID)
	
	; write all values from savefile into the flow object
	flow := ObjFullyMerge(flow, fileContent)

	; add some information about the file path
	flow.file := ThisFlowFilepath
	flow.Folder := ThisFlowFolder
	flow.FileName := ThisFlowFilename

	if (p_demo)
	{
		; this is a demo flow. Set the flow property
		flow.demo := true
		flow.category := ""
	}

	; write the flow object
	flow.loaded := true
	_setFlow(FlowID, flow)
	
	; if we load a flow and do not find some element impelementations, probably a package is missing. We will write missing packages here and warn user later
	missingpackages := Object()
	AllElementClasses := _getShared("AllElementClasses")

	; Perform some tasks to all loaded elements
	for oneElementIndex, oneElementID in _getAllElementIds(FlowID)
	{
		oneElementClass := _getElementProperty(FlowID, oneElementID, "class")
		oneElementPackage := _getElementProperty(FlowID, oneElementID, "Package")
		
		;Check whether we have the implementation of the element class
		if not (ObjHasValue(AllElementClasses, oneElementClass))
		{
			; we do not have the implementation. A package is missing. Warn user later
			if not (ObjHasValue(missingpackages, oneElementPackage))
				missingpackages.push(oneElementPackage)
		}
		Else
		{
			;If property "default name" is enabled, regenerate the name of the element
			if (_getElementProperty(FlowID, oneElementID, "StandardName"))
			{
				Newname := Element_GenerateName_%oneElementClass%({flowID: flowID, elementID: oneElementID},  _getElementProperty(FlowID, oneElementID, "pars"))
				StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
				_setElementProperty(FlowID, oneElementID, "Name", Newname)
			}

			; get element icon
			icon := Element_getIconPath_%oneElementClass%()
			_setElementProperty(FlowID, oneElementID, "icon", icon)
		}

		; check whether the element class was parameters that were not saved
		; this may be required if the element implementation has been expanded and has new options
		elementPars := _getElementProperty(FlowID, oneElementID, "pars")
		parametersAndDefaultValues := Element_getParameters(oneElementClass, {flowID: FlowID, elementID: oneElementID})
		for oneParameterIndex, oneParameterInfo in parametersAndDefaultValues
		{
			if (not elementPars.hasKey(oneParameterInfo.id))
			{
				_setElementProperty(FlowID, oneElementID, "pars." oneParameterInfo.id, oneParameterInfo.default)
			}
		}
		
		; add some default element values
		_setElementProperty(FlowID, oneElementID, "UniqueID", flowID "_" oneElementID)
		_setElementProperty(FlowID, oneElementID, "info", object())
		_setElementInfo(FlowID, oneElementID, "selected", false)
		_setElementInfo(FlowID, oneElementID, "state", "idle")
		_setElementInfo(FlowID, oneElementID, "countRuns", 0)
		_setElementInfo(FlowID, oneElementID, "lastrun", 0)
		_setElementInfo(FlowID, oneElementID, "ClickPriority", 500)
		; move "enabled" property to info object
		_setElementInfo(FlowID, oneElementID, "enabled", _getElementProperty(FlowID, oneElementID, "enabled"))
		_deleteElementProperty(FlowID, oneElementID, "enabled")
		
		; Ensure backward compatibility (for later use)
		LoadFlowCheckCompabilityElement(flowID, oneElementID, _getFlowProperty(FlowID, "CompabilityVersion"))
	}
	
	for oneConnectionIndex, oneConnectionID in _getAllConnectionIDs(FlowID)
	{
		; ensure backward compatibility (for later use)
		LoadFlowCheckCompabilityConnection(FlowID, oneConnectionID, _getFlowProperty(FlowID, "CompabilityVersion"))
	
		; add some default element values
		_setConnectionProperty(FlowID, oneConnectionID, "info", object())
		_setConnectionInfo(FlowID, oneConnectionID, "selected", false)
		_setConnectionInfo(FlowID, oneConnectionID, "state", "idle")
		_setConnectionInfo(FlowID, oneConnectionID, "ClickPriority", 200)
	}

	; Ensure backward compatibility (for later use)
	LoadFlowCheckCompabilityFlow(flowID, _getFlowProperty(FlowID, "CompabilityVersion"))

	if not (_getFlowProperty(FlowID, "firstLoadedTime"))
		_setFlowProperty(FlowID, "firstLoadedTime", a_now)
	
	; ensure, we have a trigger. And if there are 1+ manual triggers, that one of them (and only one) is default trigger
	triggerFound := False
	anyManualTriggerFound := False
	defaultManualTriggerFound := False
	for oneElementIndex, oneElementID in _getAllElementIds(FlowID)
	{
		oneElementClass := _getElementProperty(FlowID, oneElementID, "class")

		if (substr(oneElementClass, 1, 8) = "Trigger_")
		{
			triggerFound := oneElementID
			if (oneElementClass = "Trigger_Manual")
			{
				anyManualTriggerFound := oneElementID
				if (_getElementProperty(FlowID, oneElementID, "DefaultTrigger"))
				{
					if (defaultManualTriggerFound)
					{
						logger("a0","Error in flow! Trigger '" oneElementID "' is default but trigger '" defaultManualTriggerFound "' is also a deafault trigger. Keeping '" defaultManualTriggerFound "' as default trigger.")
						_setElementProperty(FlowID, oneElementID, "DefaultTrigger", false)
					}
					Else
					{
						defaultManualTriggerFound := oneElementID
					}
				}
			}
		}
	}
	if not (triggerFound)
	{
		; create manual trigger
		logger("a0","Error in flow! Flow has no trigger. Creating a new manual trigger.")
		createDefaultManualTrigger(FlowID)
	}
	else if (anyManualTriggerFound and not defaultManualTriggerFound)
	{
		logger("a0","Error in flow! Flow has manual triggers but none of them is set default trigger. Setting '" anyManualTriggerFound "' as default trigger.")
		_setElementProperty(FlowID, anyManualTriggerFound, "DefaultTrigger", true)
	}

	; check working directory
	if not _getFlowProperty(FlowID, "flowSettings.DefaultWorkingDir")
	{
		flowWorkingDir := _getFlowProperty(FlowID, "flowSettings.WorkingDir")
		if not fileexist(flowWorkingDir)
		{
			logger("a1","Working directory '" flowWorkingDir "' of the flow does not exist. Creating it now.")
			FileCreateDir,% flowWorkingDir
			if errorlevel
			{
				logger("a0","Error in flow! Working directory '" flowWorkingDir "' of the flow couldn't be created. Fall back to default working directory")
				_setFlowProperty(FlowID, "flowSettings.DefaultWorkingDir", true)
			}
		}
	}

	; checking execution policy
	flowExecutionPolicy := _getFlowProperty(FlowID, "flowSettings.ExecutionPolicy")
	if (flowExecutionPolicy != "default" and flowExecutionPolicy != "parallel" and flowExecutionPolicy != "skip" and flowExecutionPolicy != "wait" and flowExecutionPolicy != "stop")
	{
		logger("a0","Error in flow! Execution policy has an invalid value. Fall back to default execution policy")
		_setFlowProperty(FlowID, "flowSettings.ExecutionPolicy", "default")
	}
	
	; checking zoom factor and offsets
	flowZoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomFactor")
	flowOffsetx := _getFlowProperty(FlowID, "flowSettings.Offsetx")
	flowOffsety := _getFlowProperty(FlowID, "flowSettings.Offsety")
	if (flowZoomFactor < default_zoomFactorMin or flowZoomFactor > default_zoomFactorMax)
	{
		logger("a0","Error in flow! Zoom factor an invalid value. Fall back to default value")
		_setFlowProperty(FlowID, "flowSettings.zoomFactor", default_ZoomFactor)
	}
	if flowOffsetx is not number
	{
		logger("a0","Error in flow! Offset X an invalid value. Fall back to default value")
		_setFlowProperty(FlowID, "flowSettings.Offsetx", default_OffsetX)
	}
	if flowOffsety is not number
	{
		logger("a0","Error in flow! Offset Y an invalid value. Fall back to default value")
		_setFlowProperty(FlowID, "flowSettings.Offsety", default_OffsetY)
	}
	
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
		
		; delete flow
		_deleteflow(FlowID)

		MsgBox, 4,, % lang("Attention!") " " lang("The flow '%1%' could not be loaded!", _getFlowProperty(FlowID, "name")) "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist "`n`n" lang("Debug Info") ":`n" lang("Filename") ": " ThisFlowFilepath "`n`n" lang("Do you want to delete this flow?")
		IfMsgBox, yes
			FileDelete, % ThisFlowFilepath
	}
	Else
	{
		
		; create a new state
		state_New(FlowID)
		_setFlowProperty(FlowID, "savedState", _getFlowProperty(FlowID, "currentState"))
	}
	
	_LeaveCriticalSection()
	currentlyLoadingFlow:=false

	return FlowID
}

