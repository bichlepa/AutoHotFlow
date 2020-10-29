
;load all flow information from file (additionally to meta data)
LoadFlow(p_filepath)
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
		oneElementPackage := RIni_GetKeyValue("IniFile", oneSection, "Package", "Unknown")
		
		;Check whether we have the implementation of the element class
		if not (ObjHasValue(AllElementClasses, oneElementClass))
		{
			; we do not have the implementation. A package is missing. Warn user later
			if not (ObjHasValue(missingpackages, oneElementPackage))
				missingpackages.push(oneElementPackage)
		}
	
		;If property "default name" is enabled, regenerate the name of the element
		if (_getElementProperty(FlowID, oneElementID, "StandardName"))
		{
			if (IsFunc("Element_GenerateName_" oneElementClass))
			{
				Newname := Element_GenerateName_%oneElementClass%({flowID: flowID, elementID: oneElementID},  _getElementProperty(FlowID, oneElementID, "pars"))
				StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
				_setElementProperty(FlowID, oneElementID, "Name", Newname)
			}
		}
		
		; get element icon
		icon := Element_getIconPath_%oneElementClass%()
		_setElementProperty(FlowID, oneElementID, "icon", icon)

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

		; TODO: check whether we have one default manual trigger (if there are any manual trigger)

		
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

	if not (_getFlowProperty(FlowID, "firstLoadedTime"))
		_setFlowProperty(FlowID, "firstLoadedTime", a_now)
	
	; todo: ensure, we have a trigger

	
	; TODO: check flow settings.

	; check working directory
	if not fileexist(_getSettings("WorkingDir"))
	{
		logger("a1","Working directory of the flow does not exist. Creating it now.")
		FileCreateDir,% _getSettings("WorkingDir")
		if errorlevel
		{
			logger("a0","Error! Working directory couldn't be created.")
		}
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
		MsgBox % lang("Attention!") " " lang("The flow '%1%' could not be loaded properly!" _getFlowProperty(FlowID, "name")) "`n" lang("Following packages are missing:") "`n`n" tempmissingpackageslist "`n`n" lang("Debug Info") ":`n" lang("Filename") ": " ThisFlowFilepath
	}
	
	; create a new state
	state_New(FlowID)
	_setFlowProperty(FlowID, "savedState", _getFlowProperty(FlowID, "currentState"))
	
	_LeaveCriticalSection()
	currentlyLoadingFlow:=false

	return FlowID
}

