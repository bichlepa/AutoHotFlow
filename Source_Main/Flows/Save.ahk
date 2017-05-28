
MAX_COUNT_OF_BACKUPS:=10

SaveFlowMetaData(FlowID)
{
	global
	local enabledFlows
	
	if (_Flows[FlowID].file="")
	{
		;Do not save anything if flow does not exist. (Should not happen)
		MsgBox unexpected error. should save flow "%FlowID%", but no flow file specified
		return
	}
		
	
	;~ d(_Flows[FlowID],FlowID)
	if not fileexist(_Flows[FlowID].file)
	{
		IniWrite,% FlowCompabilityVersionOfApp,% _Flows[FlowID].file,general,FlowCompabilityVersion
	}
	
	IniWrite,% _Flows[FlowID].name,% _Flows[FlowID].file,general,name
	IniWrite,% _Flows[FlowID].id,% _Flows[FlowID].file,general,ID
	if (_Flows[FlowID].categoryname = lang("uncategorized"))
		IniWrite,% "",% _Flows[FlowID].file,general,category ;If the flow has no category, do not save the category name
	else
		IniWrite,% _Flows[FlowID].categoryname,% _Flows[FlowID].file,general,category
	
	if (shuttingDown<>true) ;Do not save if it is shutting down and disabling the flows
	{
		enabledTriggers:=""
		for oneID, oneElement in _Flows[FlowID].allElements
		{
			if (oneElement.type = "trigger" and oneElement.enabled)
			{
				if (enabledTriggers="")
					enabledTriggers.=oneID
				else
					enabledTriggers.= "|" oneID
			}
		}
		
		IniWrite,% enabledTriggers,% _Flows[FlowID].file,general,enabled
		
	}
}

SaveFlow(FlowID)
{
	global
	local elementCounter=0
	local triggerCounter=0
	local conncetionCounter=0
	local countBackupsToDelete=0
	local presentBackupFiles=Object()
	local ThisFlowFilepath, ThisFlowFolder, ThisFlowFilename
	local saveElementType, saveElement, saveElementID, saveElementIniID
	local oneID, oneElement, enabledTriggers
	;~ MsgBox %FlowID%
	;~ ui_DisableMainGUI()
	logger("a1","Saving flow " FlowName)
	;~ ToolTip(lang("saving"),100000)
	
	
	
	enabledTriggers:=""
	for oneID, oneElement in _Flows[FlowID].allElements
	{
		if (oneElement.type = "trigger" and oneElement.enabled)
		{
			if (enabledTriggers="")
				enabledTriggers.=oneID
			else
				enabledTriggers.= "|" oneID
		}
	}
	
	
	ThisFlowFilepath := _flows[FlowID].file
	ThisFlowFolder := _flows[FlowID].Folder
	ThisFlowFilename :=_flows[FlowID].FileName
	
	FileCreateDir,%ThisFlowFolder%
	
	

	RIni_Shutdown("iniSave")
	RIni_Create("iniSave")
	
	RIni_AddSection("iniSave","general")
	RIni_AppendValue("iniSave", "general", "name", _flows[FlowID].flowSettings.Name)
	RIni_AppendValue("iniSave", "general", "category", _share.allCategories[_flows[FlowID].category].Name )
	RIni_AppendValue("iniSave", "general", "ID", _flows[FlowID].id )
	RIni_AppendValue("iniSave", "general", "count", _flows[FlowID].ElementIDCounter)
	RIni_AppendValue("iniSave", "general", "SettingFlowExecutionPolicy", _flows[FlowID].flowSettings.ExecutionPolicy)
	RIni_AppendValue("iniSave", "general", "SettingWorkingDir", _flows[FlowID].flowSettings.WorkingDir)
	RIni_AppendValue("iniSave", "general", "SettingDefaultWorkingDir", _flows[FlowID].flowSettings.DefaultWorkingDir)
	RIni_AppendValue("iniSave", "general", "LogToFile", _flows[FlowID].flowSettings.LogToFile)
	RIni_AppendValue("iniSave", "general", "FlowCompabilityVersion", FlowCompabilityVersionOfApp)
	RIni_AppendValue("iniSave", "general", "Static variables folder", _flows[FlowID].flowSettings.FolderOfStaticVariables)
	RIni_AppendValue("iniSave", "general", "Offsetx", _flows[FlowID].flowSettings.Offsetx)
	RIni_AppendValue("iniSave", "general", "Offsety", _flows[FlowID].flowSettings.Offsety)
	RIni_AppendValue("iniSave", "general", "zoomFactor", _flows[FlowID].flowSettings.zoomFactor)
	
		
	
	RIni_AppendValue("iniSave", "general", "enabled", enabledTriggers)
	
	saveCopyOfallElements:=objfullyclone(_flows[FlowID].allElements)
	saveCopyOfallConnections:=objfullyclone(_flows[FlowID].allConnections)
	saveCopyOfallTriggers:=objfullyclone(_flows[FlowID].allTriggers) 

	

	
	for saveElementID, saveElement in saveCopyOfallElements
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
			
		
		i_SaveParametersOfElement(saveElement,saveElementIniID)
		
		
	}
	
	for saveElementID, saveElement in saveCopyOfallConnections
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
	
	
	for saveElementID, saveElement in saveCopyOfallTriggers
	{
		saveElementIniID := "trigger" ++triggerCounter
		RIni_AddSection("iniSave", saveElementIniID)
		RIni_AppendValue("iniSave", saveElementIniID, "ID", saveElement.ID)
		RIni_AppendValue("iniSave", saveElementIniID, "type", saveElement.type)
		RIni_AppendValue("iniSave", saveElementIniID, "class", saveElement.class)
		RIni_AppendValue("iniSave", saveElementIniID, "subType", saveElement.subType)
		RIni_AppendValue("iniSave", saveElementIniID, "name", saveElement.name)
		
		i_SaveParametersOfElement(saveElement,saveElementIniID)
		
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
	
	_flows[FlowID].savedState:=_flows[FlowID].currentState
	
	saved=yes
	busy:=false
	
}

i_SaveParametersOfElement(saveElement,saveElementIniID,Savelocation="")
{
	global
	local parametersToSave
	local index
	local index2
	local parameter
	local parameterID
	local parameterDefault
	local SaveContent
	local OneID
	local objectstring
	local elementClass:=saveElement.class
	
	parametersToSave:=Element_getParameters_%elementClass%()
	
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
	global _flows
	for tempID, tempflow in _flows
	{
		if (tempflow.currentState != tempflow.savedState)
		{
			SaveFlow(tempID)
		}
		
	}
	
}