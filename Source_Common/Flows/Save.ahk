
global MAX_COUNT_OF_BACKUPS:=10

; save flow metadata. TODO: either impelement only metadata or remove it.
SaveFlowMetaData(FlowID)
{
	SaveFlow(FlowID)
}

; save a flow to savefile
SaveFlow(FlowID)
{
	FlowName := _getFlowProperty(FlowID, "name")

	logger("a1", "Saving flow " FlowName)	
	
	if (flow.demo and _getSettings("developing") != True)
	{
		;A demo flow cannot be saved
		logger("a0","Cannot save flow " FlowName ". It is a demonstation flow.")
		MsgBox, 48, % lang("Save flow"), % lang("This flow cannot be saved because it is a demonstration flow.") " " lang("You may duplicate this flow first and then you can edit it.")
		return
	}
	
	_EnterCriticalSection()

	; get flow object from current state
	; we save the current state because we don't want to save temporary changes while user edits the flow
	currentState := _getFlowProperty(FlowID, "currentState")
	flow := _getFlowProperty(FlowID, "states." currentState)
	
	; get flow savefile path
	ThisFlowFilepath := _getFlowProperty(FlowID, "file")
	ThisFlowFolder := _getFlowProperty(FlowID, "Folder")
	ThisFlowFilename := _getFlowProperty(FlowID, "FileName")
	
	; create folder just in case
	FileCreateDir, %ThisFlowFolder%
	
	; create a new flow object where we will copy all data that is worth for saving
	flowSave := object()

	; write some common data
	flowSave.name := FlowName
	flowSave.ElementIDCounter := _getFlowProperty(FlowID, "ElementIDCounter")
	flowSave.flowSettings := _getFlowProperty(FlowID, "flowSettings")
	; we will save the category name instead of the categry ID
	flowSave.category := _getCategoryProperty(_getFlowProperty(FlowID, "category"), "Name")
	
	; Add elements
	flowSave.allElements :=  object()
	for forElementID, forElement in flow.allElements
	{
		; create empty object where we will write all data needed
		saveElement := Object()

		; write common information
		saveElement.ID := forElement.ID
		saveElement.type := forElement.type
		saveElement.class := forElement.class
		saveElement.x := forElement.x
		saveElement.y := forElement.y
		saveElement.name := forElement.name
		saveElement.StandardName := forElement.StandardName
		
		; write some data that is only needed for special element types
		if (forElement.type = "loop")
			saveElement.HeightOfVerticalBar := forElement.HeightOfVerticalBar
		if (forElement.class = "trigger_manual")
			saveElement.DefaultTrigger := forElement.DefaultTrigger
		if (forElement.type = "trigger")
			saveElement.enabled := _getElementInfo(FlowID, forElementID, "enabled")
		
		; write the package which is needed for this element.
		; usecase: if a flow will be exported and imported in an other installation of AHF
		;   and this flow has elements which require additional packages, the user will get a message.
		saveElementClass := saveElement.class
		saveElement.package := Element_getPackage_%saveElementClass%()
		
		; write element parameters. We will write only the parameters which are needed by the element.
		; because, if an element class was changed, the property "pars" may contain parameters which are not needed anymore.
		parametersToSave := Element_getParameters(forElement.class, {flowID: FlowID, elementID: forElement.ID})
		saveElement.pars := object()
		for onParIndex, oneParID in parametersToSave
		{
			saveElement.pars[oneParID] := forElement.pars[oneParID]
		}
		
		; write the new element in the flow object
		flowSave.allElements[forElementID] := saveElement
	}
	
	; add connections
	flowSave.allConnections :=  object()
	for forConnectionID, forConnection in flow.allConnections
	{
		; create empty object where we will write all data needed
		saveConnection := Object()

		; write common information
		saveConnection.ID := forConnection.ID
		saveConnection.from := forConnection.from
		saveConnection.to := forConnection.to

		; todo: remove type and rename connectionType to condition
		saveConnection.type := forConnection.type
		saveConnection.ConnectionType := forConnection.ConnectionType
		
		; some connectoins have information about the part of the element, where they are connected to. copy it if present.
		if (forConnection.fromPart)
			saveConnection.fromPart := forConnection.fromPart
		if (forConnection.toPart)
			saveConnection.toPart := forConnection.toPart
			
		; write the new connection in the flow object
		flowSave.allConnections[forConnectionID] := saveConnection
	}
	
	;Make a backup of the old flow. TODO: It will be possible to restore the old state later.
	FileCreateDir, %ThisFlowFolder%\backup
	Filemove, %ThisFlowFolder%\%ThisFlowFilename%.txt, %ThisFlowFolder%\backup\%ThisFlowFilename%_backup_%a_now%.json

	;Delete old backups
	loop, files, %ThisFlowFolder%\backup\%ThisFlowFilename%_backup_*.json
	{
		; we assume that the files are alphabetically sorted todo: is this assumption correct?
		presentBackupFiles.push(A_LoopFileFullPath)
	}
	countBackupsToDelete := presentBackupFiles.MaxIndex() - MAX_COUNT_OF_BACKUPS
	if (countBackupsToDelete > 0)
	{
		Loop %countBackupsToDelete%
		{
			FileDelete,% presentBackupFiles[1]
			presentBackupFiles.removeat(1)
		}
	}
	
	;Write new file. TODO: error check
	FileDelete, % ThisFlowFolder "\" ThisFlowFilename ".json"
	FileAppend, % Jxon_Dump(flowSave, 2), % ThisFlowFolder "\" ThisFlowFilename ".json"
	
	logger("a1","Flow " FlowName " was successfully saved.")
	
	; update the state of saved flow
	_setFlowProperty(FlowID, "savedState", flow.currentState)
	
	_LeaveCriticalSection()
}

; save unsaved flows
i_SaveUnsavedFlows()
{
	_EnterCriticalSection()
	flowIDs := _getAllFlowIds()
	for oneIndex, oneFlowID in flowIDs
	{
		if (_getFlowProperty(oneFlowID, "currentState") != _getFlowProperty(oneFlowID, "savedState"))
		{
			SaveFlow(oneFlowID)
		}
	}
	
	_LeaveCriticalSection()
}