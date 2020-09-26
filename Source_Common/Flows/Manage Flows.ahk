

;Find flows in folder "saved Flows" und show them in the tv.
;Additionally read the state of flow and activate it if it should be active
;This function must be called once
FindFlows()
{
	; ensure a folder for saved flows exists
	if not fileexist(_WorkingDir "\Saved Flows")
		FileCreateDir, % _WorkingDir "\Saved Flows"
	
	;Load metadata of existing Flows
	loop %_WorkingDir%\Saved Flows\*.ini
	{
		InitFlow(A_LoopFileFullPath)
	}
}

; Load metadata of a flow from savefile
; returns the flow ID
InitFlow(FileFullPath)
{
	; we will need some parts of the passed path
	SplitPath, FileFullPath,,ThisFlowFolder,,ThisFlowFilename

	;Load Flow ID
	iniread, newFlowid, %FileFullPath%, general, id, % a_space
	; if there is no flow id, we cannot proceed. The file may be corrupt or empty.
	if not newFlowid
	{
		logger("f0", "Could not init flow from file '" FileFullPath "'. No flow ID given")
		return
	}

	;read more flow information
	iniread, tempflowName, %FileFullPath%, general, name
	iniread, tempcategoryname, %FileFullPath%, general, category, %a_space% 
	iniread, tempflowenabled, %FileFullPath%, general, enabled, 0
	iniread, tempdemo, %FileFullPath%, general, demo, 0
	
	;Check category. Create new one if it does not exist yet. Demo flows don't need a dedicated category
	if (not tempdemo)
	{
		if (tempcategoryname)
		{
			; category is set. Create category if it does not exist
			tempCategoryID := _getCategoryIdByName(tempcategoryname)
			if (not tempCategoryID)
				tempCategoryID := NewCategory(tempcategoryname)
		}
	}

	;Make sure the flow ID does not exist yet. If it exists, generate a new one
	if _existsFlow(newFlowid)
	{
		Loop
		{
			random, randomValue
			newFlowid := lang("Flow") " " randomValue
			if (not _existsFlow(newFlowid))
				break
		}
	}

	;Do not allow two flows to have the same name. If a loaded flow has a name that an other flow already has, the flow will be renamed
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
	
	;Create flow object with basic data
	newFlow := Object()
	
	newFlow.file := FileFullPath
	newFlow.Folder := ThisFlowFolder
	newFlow.FileName := ThisFlowFilename
	
	newFlow.id := newFlowid
	newFlow.name := tempflowName
	newFlow.Type := "Flow"
	newFlow.category := tempCategoryID
	newFlow.demo := tempdemo
	
	; create empty objects for later use
	newFlow.draw := Object()
	newFlow.states := Object()

	; create initial counter values
	newFlow.statesCounter := 0
	
	; Set flow object
	_setFlow(newFlowid, newFlow)

	; if the flow is enabled, we will enable it right now
	if (tempflowenabled != 0)
	{
		; the property "enabled" in save file contains a list of all enabled triggers (since user can enable or disable single triggers). We will enable all the triggers
		loop, parse, tempflowenabled, |
		{
			enableOneTrigger(newFlowid, A_LoopField, False)
		}
	}

	return newFlowid
}

;Create a new flow. Also create a new file for a flow
; returns the new flow ID
NewFlow(par_CategoryID = "")
{
	;Generate a new unique ID
	Loop
	{
		random,randomValue
		newFlowid := lang("Flow") " " randomValue
		; since we use a random value, it is (at very low probability) possible, that we already have that flow ID. If so, we try with another random number.
		if (not _existsFlow(newFlowid))
			break
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
	newFlow.category := par_CategoryID
	newFlow.enabled := false
	
	;Set the file path of the new flow
	newFlow.folder := _WorkingDir "\Saved Flows"
	newFlow.filename := newFlowid
	newFlow.file := _WorkingDir "\Saved Flows\" newFlowid ".ini"

	; create empty objects for later use
	newFlow.draw := Object()
	newFlow.states := Object()
	
	; Set flow object
	_setFlow(newFlowid, newFlow)

	; create a new savefile for the flow and write the metadata inside 
	SaveFlowMetaData(newFlowid)

	return newFlowid
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
		newflowName := newFlow.name " " lang("copy") indexString
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
