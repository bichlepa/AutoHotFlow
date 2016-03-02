
i_save()
{
	global
	
	local saveCopyOfallElements
	local saveCopyOfallTriggers
	local saveElementType
	local saveElementID
	local saveElementfrom
	local saveElementConnectionType
	local saveElementfromPart
	local saveElementtoPart
	local saveElementX
	local saveElementY
	local saveElementname
	local saveElementsubType
	local saveElementHeightOfVerticalBar
	local temponeparname
	local SaveContent
	local parametersToSave
	local CopyOfCurrentState
	local saveSection
	
	
	maingui.disable()
	
	
	busy:=true
	
	logger("a1","Saving flow " flowSettings.Name)
	CopyOfCurrentState:=ObjFullyClone(currentstate)
	ToolTip(lang("saving"),100000)
	
	
	FileCreateDir,% flow.Folder
	RIni_Shutdown("SaveFile")
	Rini_Create("SaveFile")
	
	RIni_SetKeyValue("SaveFile", "general", "OffsetX", Offsetx)
	RIni_SetKeyValue("SaveFile", "general", "OffsetY", Offsety)
	RIni_SetKeyValue("SaveFile", "general", "zoomFactor", zoomFactor)
	RIni_SetKeyValue("SaveFile", "general", "count", globalcounter)
	RIni_SetKeyValue("SaveFile", "general", "SettingFlowExecutionPolicy", flowSettings.ExecutionPolicy)
	RIni_SetKeyValue("SaveFile", "general", "SettingWorkingDir", flowSettings.WorkingDir)
	RIni_SetKeyValue("SaveFile", "general", "LogToFile", flowSettings.LogToFile)
	RIni_SetKeyValue("SaveFile", "general", "name", flowSettings.Name)
	RIni_SetKeyValue("SaveFile", "general", "category", flowSettings.category)
	RIni_SetKeyValue("SaveFile", "general", "FlowCompabilityVersion", FlowCompabilityVersionOfApp)
	RIni_SetKeyValue("SaveFile", "general", "Static variables folder", flowSettings.FolderOfStaticVariables)
	
	
	for saveElementID, saveElement in CopyOfCurrentState.allElements
	{
		saveSection:="element" a_index
		RIni_SetKeyValue("SaveFile", saveSection,"ID", saveElementID)
		RIni_SetKeyValue("SaveFile", saveSection,"Type", saveElement.type)
		
		if (saveElement.type="trigger")
		{
			
			RIni_SetKeyValue("SaveFile", saveSection,"x", saveElement.x)
			RIni_SetKeyValue("SaveFile", saveSection,"y", saveElement.y)
			saveElementname:=saveElement.name
			StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
			RIni_SetKeyValue("SaveFile", saveSection,"name", saveElementname)
		}
		else
		{
			RIni_SetKeyValue("SaveFile", saveSection,"x", saveElement.x)
			RIni_SetKeyValue("SaveFile", saveSection,"y", saveElement.y)
			saveElementname:=saveElement.name
			StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
			RIni_SetKeyValue("SaveFile", saveSection,"name", saveElementname)
			RIni_SetKeyValue("SaveFile", saveSection,"subType", saveElement.subType)
			
			if (saveElementType="loop")
			{
				RIni_SetKeyValue("SaveFile", saveSection,"HeightOfVerticalBar", saveElement.HeightOfVerticalBar)
			}
			
			i_SaveParametersOfElement(saveElement,saveSection,"SaveFile")
			
		}
	}
	
	for saveElementID, saveElement in CopyOfCurrentState.allConnections
	{
		saveSection:="Connection" a_index
		RIni_SetKeyValue("SaveFile", saveSection,"ID", saveElementID)
		RIni_SetKeyValue("SaveFile", saveSection,"Type", saveElement.type)
		
		RIni_SetKeyValue("SaveFile", saveSection,"from", saveElement.from)
		RIni_SetKeyValue("SaveFile", saveSection,"to", saveElement.to)
		RIni_SetKeyValue("SaveFile", saveSection,"ConnectionType", saveElement.ConnectionType)
		if (saveElement.frompart)
			RIni_SetKeyValue("SaveFile", saveSection,"fromPart", saveElement.frompart)
		if (saveElement.toPart)
			RIni_SetKeyValue("SaveFile", saveSection,"toPart", saveElement.toPart)
	}
	
	
	
	for index, saveElement in CopyOfCurrentState.allTriggers
	{
		saveSection:="Trigger" a_index
		saveElementID:="trigger" index
		RIni_SetKeyValue("SaveFile", saveSection,"ID", saveElementID)
		RIni_SetKeyValue("SaveFile", saveSection,"Type", saveElement.type)
		RIni_SetKeyValue("SaveFile", saveSection,"ContainerID", saveElement.ContainerID)
		
		RIni_SetKeyValue("SaveFile", saveSection,"subType", saveElement.subType)
		
		saveElementname:=saveElement.name
		StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
		RIni_SetKeyValue("SaveFile", saveSection,"name", saveElementname)
			
		
		i_SaveParametersOfElement(saveElement,saveSection,"SaveFile")
	}
	
	ret:=RIni_Write("SaveFile", flow.FilePath)
	if not ret
	{
		logger("a1","Flow " flowSettings.Name " was successfully saved.")
		ToolTip(lang("saved"))
	}
	else
	{
		logger("a0","Error. Flow " flowSettings.Name " couldn't be saved.")
		MsgBox % lang("Saving was unsuccessful")
	}
	

	RIni_Shutdown("SaveFile")
	;~ savedState:=currentstateid
	maingui.enable()
	busy:=false
}

i_SaveParametersOfElement(saveElement,saveSection,Savelocation)
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
	local saveElementType:=saveElement.type
	local saveElementsubType:=saveElement.subtype
	parametersToSave:=%saveElementType%%saveElementsubType%.getParameters()
	for index, parameter in parametersToSave
	{
		if not IsObject(parameter.id)
			parameterID:=[parameter.id]
		else
			parameterID:=parameter.id
	
		if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label for the edit fielt etc. Do nothing
			continue
		;~ MsgBox % strobj(parameterID)
		
		;Certain types of control consist of multiple controls and thus contain multiple parameters.
		for index2, oneID in parameterID
		{
			SaveContent:=saveElement.par[oneID]
			StringReplace, SaveContent, SaveContent, `n,|¶, All
			
			RIni_SetKeyValue(Savelocation, saveSection,oneID, SaveContent)
		}
	}
}

;May be called if no changes were made and user closes the script. Not yet implemented
i_saveGeneralParameters()
{
	global
	IniWrite,%Offsetx%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Offsetx
	IniWrite,%OffsetY%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,OffsetY
	IniWrite,%zoomFactor%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,zoomFactor
}

;Checks whether the flow is saved
i_CheckIfSaved()
{
	global
	;~ MsgBox % savedState "-" currentstateid
	if (savedState=currentstateid)
		return 1
	else
		return 0
}