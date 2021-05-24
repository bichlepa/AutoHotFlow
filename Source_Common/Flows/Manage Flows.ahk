

;Find flows in folder "saved Flows" und show them in the tv.
;Additionally read the state of flow and activate it if it should be active
;This function must be called once
FindFlows()
{
	logger("a2", "going to find flows")

	; ensure a folder for saved flows exists
	if not fileexist(_WorkingDir "\Saved Flows")
	{
		logger("a0", "Folder for saved flows not found. Creating empty folder.")
		FileCreateDir, % _WorkingDir "\Saved Flows"
		if ErrorLevel
		{
			logger("a0", "Folder for saved flows could not be created!")
			throw exception("Folder for saved flows could not be created!")
		}
	}
	
	;Load metadata of existing Flows
	loop %_WorkingDir%\Saved Flows\*.json
	{
		; load the flow from file
		newFlowid := LoadFlow(A_LoopFileFullPath)

		if not newFlowid
		{
			throw exception("no flow ID returned after LoadFlow()")
		}

		;Do not allow two flows to have the same name. If a loaded flow has a name that an other flow already has, the flow will be renamed
		tempflowName := _getFlowProperty(newFlowid, "name")
		Loop
		{
			if (_getFlowIdByName(tempflowName))
			{
				; try to find a number at the end of the flow name
				StringGetPos, posspace, tempflowName, %a_space%, R
				tempFlowNumberInName := substr(tempFlowName, posspace+2)

				; if a number exists at the end of the flow name, increment it. If not, append the number 2
				if tempFlowNumberInName is number
					tempflowName := substr(tempFlowName, 1, posspace) " " tempFlowNumberInName + 1
				else
					tempflowName := tempFlowName " " 2
			}
			else
				break ;there is no flow with same name
		}
	}
}

; enables all triggers which should be enabled
; should be called after the flows werde loaded
EnableLoadedFlows()
{
	allFlowIDs := _getAllFlowIds()
	; loop through all flows
	for oneFlowIndex, oneFlowID in allFlowIDs
	{
		; loop through all elements
		allElementIDs := _getAllElementIds(oneFlowID)
		for oneElementIndex, oneElementID in allElementIDs
		{
			; check whether this is an enabled trigger
			oneElementEnabled := _getElementInfo(oneFLowID, oneElementID, "enabled")
			if (oneElementEnabled)
			{
				; enable the trigger without saving its state
				enableOneTrigger(oneFlowID, oneElementID, false)
			}
		}
	}
}

;Create a new flow. Also create a new file for a flow
; returns the new flow ID
NewFlow(p_CategoryID = "", p_flowID = "")
{
	if (p_flowID)
	{
		; if flow ID is passed and a flow with that ID does not exist yet, keep it
		newFlowid := p_flowID
		if _existsFlow(newFlowid)
		{
			throw exception("should create a new flow, but flow with ID " p_flowID " but that ID already exists!")
		}
	}
	else
	{
		;Otherwise generate a new unique ID
		Loop
		{
			random, randomValue
			newFlowid := lang("Flow") " " randomValue
			; since we use a random value, it is (at very low probability) possible, that we already have that flow ID. If so, we try with another random number.
			if (not _existsFlow(newFlowid))
				break
		}
	}

	;Generate a new unique flow name.
	Loop
	{
		; increment the number after the flow name, until we get a name that does not exist yet
		newflowName := lang("New flow") " " a_index
		if (not _getFlowIdByName(newflowName))
			break
	}

	;Create the flow object with some basic data
	newFlow := object()
	newFlow.id := newFlowid
	newFlow.name := newflowName
	newFlow.Type := "Flow"
	newFlow.category := p_CategoryID
	newFlow.enabled := false
	newFlow.statesCounter := 0
	newFlow.ElementIDCounter := 0
	newFlow.CompabilityVersion := FlowCompabilityVersionOfApp
	newFlow.allElements := Object()
	newFlow.allConnections := Object()

	; set default flow settings
	newFlow.flowSettings := []
	newFlow.flowSettings.ExecutionPolicy := "default"
	newFlow.flowSettings.DefaultWorkingDir := True
	newFlow.flowSettings.WorkingDir := _getSettings("path")
	newFlow.flowSettings.Offsetx := default_OffsetX
	newFlow.flowSettings.Offsety := default_OffsetY
	newFlow.flowSettings.zoomFactor := default_zoomFactor

	;Set the file path of the new flow
	newFlow.folder := _WorkingDir "\Saved Flows"
	newFlow.filename := newFlowid
	newFlow.file := _WorkingDir "\Saved Flows\" newFlowid ".ini"

	; create empty objects for later use
	newFlow.draw := Object()
	newFlow.states := Object()
	; Set flow object
	_setFlow(newFlowid, newFlow)

	return newFlowid
}

; initialize a newly created flow
initNewFlow(p_flowID)
{
	createDefaultManualTrigger(p_flowID)
}

; create a default manual trigger
createDefaultManualTrigger(p_flowID)
{
	newElementID := element_New(p_flowID, "trigger")
	newElementClass := "Trigger_Manual"
	Element_SetClass(p_flowID, newElementID, newElementClass)
	Element_setDefaultTrigger(p_flowID, newElementID)
}

; delete a flow
DeleteFlow(par_ID)
{
	; close editor
	API_Editor_Exit(par_ID)

	; disable flow and stop execution
	API_Execution_DisableTriggers(par_ID)
	API_Execution_stopFlow(par_ID)
	
	; delete savefile
	FileDelete,% _getFlowProperty(par_ID, "file")
	
	; wait a little bit. TODO: find better solution than waiting
	sleep 300

	; delete flow object
	_deleteFlow(par_ID)
}

; duplicate an existing flow
DuplicateFlow(par_ID)
{
	;copy whole flow object and change some metadata
	newFlow := _getFlow(par_ID)

	;Generate a new unique ID
	Loop
	{
		random, randomValue
		newFlowid := lang("Flow") " " randomValue
		if (not  _existsFlow(newFlowid))
			break
	}
	
	;Generate a new unique flow name.
	indexString:=""
	Loop
	{
		if (a_index != 1)
		{
			indexString := " " a_index
		}
		; increment the number after the flow name, until we get a name that does not exist yet
		newflowName := newFlow.name " " lang("copy #verb") indexString
		if (not _getFlowIdByName(newflowName))
			break
	}

	;change some metadata
	newFlow := _getFlow(par_ID)
	newFlow.id := newFlowid
	newFlow.name := newflowName
	newFlow.enabled := "" ; make sure, the flow is disabled
	newFlow.demo := false ;If user copies a demo flow, the copy is not a demo flow anymore and user can edit it
	
	;we will need old flow name for later
	oldFile := newFlow.file

	;set new flow save file path
	newFlow.folder := _WorkingDir "\Saved Flows"
	newFlow.filename := newFlowid
	newFlow.file := newFlow.folder "\" newFlow.filename

	; Set flow object
	_setFlow(newFlowid, newFlow)

	; copy savefile
	filecopy,% oldFile, % newFlow.file
	
	; save changed metadata
	SaveFlowMetaData(newFlowid)

	return newFlowid
}


; create a new flow category.
; returns the category ID.
; optional parameter: par_Newname If category with this name exists, no new category will be created, and the ID of the existing category will be returned. If empty, a new category with a generated name will be created.
NewCategory(par_Newname = "")
{
	if (par_Newname = "")
	{
		;A new category should be created and the name is not given

		;Generate a new unique category name.
		Loop
		{
			; increment the number after the flow name, until we get a name that does not exist yet
			Newname := lang("New category") " " a_index
			if (not _getCategoryIdByName(Newname))
				break
		}
	}
	else
	{
		; if a name is specified, find out, whether the name already exists.
		Newname := par_Newname
		tempCategoryID := _getCategoryIdByName(Newname)
		if (tempCategoryID)
		{
			;If it already exists, return the id
			return tempCategoryID
		}
	}

	;Create the category object
	newCategoryid := "category" _getAndIncrementShared("CategoryIDCounter")
	newCategory := object()
	newCategory.id := newCategoryid
	newCategory.Name := Newname
	newCategory.Type := "Category"
	
	; write the category object
	_setCategory(newCategoryid, newCategory)

	return newCategoryid
}

; change the category of a flow
ChangeFlowCategory(par_FlowID, par_CategoryID)
{
	if (par_FlowID = "")
	{
		MsgBox,,Unexpected error, 5616486132156
	}
	
	; set category ID
	_setFlowProperty(par_FlowID, "category", par_CategoryID)

	; save changed metadata to savefile
	SaveFlowMetaData(par_FlowID)
}

; delete a flow category
DeleteCategory(par_ID)
{
	_deleteCategory(par_ID)
}
