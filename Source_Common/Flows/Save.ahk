
global MAX_COUNT_OF_BACKUPS:=10

SaveFlowMetaData(FlowID)
{
	flow := _getFlow(FlowID)
	FlowName := flow.name
	logger("a2","Saving meta data of flow " FlowName)
	if (flow.file="")
	{
		;Do not save anything if flow does not exist. (Should not happen)
		MsgBox unexpected error. should save metadata of flow "%FlowID%", but no flow file specified
		return
	}
	
	if (flow.demo and _getSettings("developing") != True)
	{
		;A demo flow cannot be saved
		logger("a0","Cannot save metadata of flow " FlowName ". It is a demonstation flow.")
		return
	}
	
	_EnterCriticalSection()

	;~ d(flow,FlowID)
	if not fileexist(flow.file)
	{
		IniWrite,% FlowCompabilityVersionOfApp,% flow.file,general,FlowCompabilityVersion
	}
	
	IniWrite,% flow.name,% flow.file,general,name
	IniWrite,% flow.id,% flow.file,general,ID
	IniWrite,% flow.demo,% flow.file,general,demo
	IniWrite,% _getCategoryProperty(flow.category, "name"), % flow.file,general,category
	
	if (_exitingNow<>true) ;Do not save if it is shutting down and disabling the flows
	{
		enabledTriggers:=""
		for oneID, oneElement in flow.allElements
		{
			if (oneElement.type = "trigger" and oneElement.enabled)
			{
				if (enabledTriggers="")
					enabledTriggers.=oneID
				else
					enabledTriggers.= "|" oneID
			}
		}
		
		IniWrite,% enabledTriggers,% flow.file,general,enabled
	}
	
	_LeaveCriticalSection()
}

SaveFlow(FlowID)
{
	; TODO: get flow from current state
	flow := _getFlow(FlowID)
	FlowName := flow.name

	logger("a1","Saving flow " FlowName)
	;~ ToolTip(lang("saving"),100000)
	
	
	if (flow.demo and _getSettings("developing") != True)
	{
		;A demo flow cannot be saved
		logger("a0","Cannot save metadata of flow " FlowName ". It is a demonstation flow.")
		MsgBox, 48, % lang("Save flow"), % lang("This flow cannot be saved because it is a demonstration flow.") " " lang("You may duplicate this flow first and then you can edit it.")
		return
	}
	
	_EnterCriticalSection()

	enabledTriggers:=""
	for oneID, oneElement in flow.allElements
	{
		if (oneElement.type = "trigger" and oneElement.enabled)
		{
			if (enabledTriggers="")
				enabledTriggers.=oneID
			else
				enabledTriggers.= "|" oneID
		}
	}
	
	
	ThisFlowFilepath := flow.file
	ThisFlowFolder := flow.Folder
	ThisFlowFilename :=flow.FileName
	
	FileCreateDir,%ThisFlowFolder%
	
	

	RIni_Shutdown("iniSave")
	RIni_Create("iniSave")
	
	RIni_AddSection("iniSave","general")
	RIni_AppendValue("iniSave", "general", "name", flow.flowSettings.Name)
	RIni_AppendValue("iniSave", "general", "category", _getCategoryProperty(flow.category, "Name") )
	RIni_AppendValue("iniSave", "general", "ID", flow.id )
	RIni_AppendValue("iniSave", "general", "count", flow.ElementIDCounter)
	RIni_AppendValue("iniSave", "general", "SettingFlowExecutionPolicy", flow.flowSettings.ExecutionPolicy)
	RIni_AppendValue("iniSave", "general", "SettingWorkingDir", flow.flowSettings.WorkingDir)
	RIni_AppendValue("iniSave", "general", "SettingDefaultWorkingDir", flow.flowSettings.DefaultWorkingDir)
	RIni_AppendValue("iniSave", "general", "FlowCompabilityVersion", FlowCompabilityVersionOfApp)
	RIni_AppendValue("iniSave", "general", "Static variables folder", flow.flowSettings.FolderOfStaticVariables)
	RIni_AppendValue("iniSave", "general", "Offsetx", flow.flowSettings.Offsetx)
	RIni_AppendValue("iniSave", "general", "Offsety", flow.flowSettings.Offsety)
	RIni_AppendValue("iniSave", "general", "zoomFactor", flow.flowSettings.zoomFactor)
	RIni_AppendValue("iniSave", "general", "demo", flow.demo)
	
		
	
	RIni_AppendValue("iniSave", "general", "enabled", enabledTriggers)

	for saveElementID, saveElement in flow.allElements
	{
		saveElementIniID := "element" ++elementCounter
		RIni_AddSection("iniSave", saveElementIniID)
		RIni_AppendValue("iniSave", saveElementIniID, "ID", saveElement.ID)
		RIni_AppendValue("iniSave", saveElementIniID, "type", saveElement.type)
		RIni_AppendValue("iniSave", saveElementIniID, "class", saveElement.class)
		RIni_AppendValue("iniSave", saveElementIniID, "package", saveElement.package)
		RIni_AppendValue("iniSave", saveElementIniID, "x", saveElement.x)
		RIni_AppendValue("iniSave", saveElementIniID, "y", saveElement.y)
		RIni_AppendValue("iniSave", saveElementIniID, "name", saveElement.name)
		RIni_AppendValue("iniSave", saveElementIniID, "StandardName", saveElement.StandardName)
		
		
		
		RIni_AppendValue("iniSave", saveElementIniID, "subType", saveElement.subType)
		if (saveElement.HeightOfVerticalBar)
			RIni_AppendValue("iniSave", saveElementIniID, "HeightOfVerticalBar", saveElement.HeightOfVerticalBar)	
		if (saveElement.class = "trigger_manual")
			RIni_AppendValue("iniSave", saveElementIniID, "DefaultTrigger", saveElement.DefaultTrigger)	
			
		
		i_SaveParametersOfElement(saveElement,FlowID,saveElementIniID)
		
		
	}
	
	for saveElementID, saveElement in flow.allConnections
	{
		saveElementIniID := "connection" ++conncetionCounter
		RIni_AddSection("iniSave", saveElementIniID)
		RIni_AppendValue("iniSave", saveElementIniID, "ID", saveElement.ID)
		RIni_AppendValue("iniSave", saveElementIniID, "type", saveElement.type)
		
		RIni_AppendValue("iniSave", saveElementIniID, "from", saveElement.from)
		RIni_AppendValue("iniSave", saveElementIniID, "to", saveElement.to)
		RIni_AppendValue("iniSave", saveElementIniID, "ConnectionType", saveElement.ConnectionType)
		if (saveElement.fromPart)
			RIni_AppendValue("iniSave", saveElementIniID, "fromPart", saveElement.fromPart)			
		if (saveElement.toPart)
			RIni_AppendValue("iniSave", saveElementIniID, "toPart", saveElement.toPart)
			
		
	}
	
	
	for saveElementID, saveElement in flow.allTriggers
	{
		saveElementIniID := "trigger" ++triggerCounter
		RIni_AddSection("iniSave", saveElementIniID)
		RIni_AppendValue("iniSave", saveElementIniID, "ID", saveElement.ID)
		RIni_AppendValue("iniSave", saveElementIniID, "type", saveElement.type)
		RIni_AppendValue("iniSave", saveElementIniID, "class", saveElement.class)
		RIni_AppendValue("iniSave", saveElementIniID, "subType", saveElement.subType)
		RIni_AppendValue("iniSave", saveElementIniID, "name", saveElement.name)
		
		i_SaveParametersOfElement(saveElement,FlowID,saveElementIniID)
		
	}
	
	;Make a backup of the old flow. It will be possible to restore the old state.
	FileCreateDir,%ThisFlowFolder%\backup
	Filemove,%ThisFlowFolder%\%ThisFlowFilename%.ini,%ThisFlowFolder%\backup\%ThisFlowFilename%_backup_%a_now%.ini
	;Delete old backups
	loop, files, %ThisFlowFolder%\backup\%ThisFlowFilename%_backup_*.ini
	{
		presentBackupFiles.push(A_LoopFileFullPath)
	}
	countBackupsToDelete:=presentBackupFiles.MaxIndex() - MAX_COUNT_OF_BACKUPS
	if (countBackupsToDelete > 0)
	{
		Loop %countBackupsToDelete%
		{
			FileDelete,% presentBackupFiles[1]
			presentBackupFiles.removeat(1)
		}
	}
	
	;Write new file
	RIni_Write("iniSave", ThisFlowFolder "\" ThisFlowFilename ".ini")
	
	;Todo: Delete old backups
	
	
	logger("a1","Flow " FlowName " was successfully saved.")
	;~ ToolTip(lang("saved"))
	;~ ui_EnableMainGUI()
	
	_setFlowProperty(FlowID, "savedState", flow.currentState)
	
	_LeaveCriticalSection()
}

i_SaveParametersOfElement(saveElement,FlowID,saveElementIniID,Savelocation="")
{
	elementClass:=saveElement.class
	elementID:=saveElement.id
	
	parametersToSave:=Element_getParameters(elementClass, {flowID: FlowID, elementID: elementID})
	
	for index2, oneParID in parametersToSave
	{
		if (Savelocation="clipboard")
		{
			;TODO
			;~ IniWrite,%SaveContent%,%ClipboardFlowFilename%,Element%saveElementIndex%,%oneParID%
		}
		else 
		{
			if isobject(saveElement.pars[oneParID])
			{
				objectstring := "ῸВĴ" strobj(saveElement.pars[oneParID])
				StringReplace, objectstring, objectstring, `n, linēfḙ℮d
				StringReplace, objectstring, objectstring, `r
				StringReplace, objectstring, objectstring, % a_tab, ₸ÅḆ
				RIni_AppendValue("iniSave", saveElementIniID, "par_" oneParID, objectstring)
				
			}
			else
			{
				RIni_AppendValue("iniSave", saveElementIniID, "par_" oneParID, saveElement.pars[oneParID])
			}
		}
		
		
	}
	
}

i_SaveUnsavedFlows()
{
	_EnterCriticalSection()
	
	flowIDs := _getAllFlowIds()
	for oneIndex, oneFlowID in flowIDs
	{
		if (_getFlowProperty(FlowID, "currentState") != _getFlowProperty(FlowID, "savedState") and not _getFlowProperty(FlowID, "demo"))
		{
			SaveFlow(tempID)
		}
		
	}
	
	_LeaveCriticalSection()
}