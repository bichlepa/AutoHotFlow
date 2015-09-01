
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
	
	ui_DisableMainGUI()
	busy:=true
	GetKeyState,k,control,p 
	;~ if (ThisFlowFilename="" or k="d") ;this cannot happen anymore
	;~ {
		;~ FileSelectFile,ThisFlowFilePath,S24,Saved Flows,Save flow, *.ini
		;~ if errorlevel
		;~ {
			
			;~ ui_EnableMainGUI()
			;~ return
		;~ }
		;~ SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	;~ }

	logger("a1","Saving flow " FlowName)
	ToolTip(lang("saving"),100000)
	
	FileCreateDir,%ThisFlowFolder%
	Filemove,%ThisFlowFolder%\%ThisFlowFilename%.ini,%ThisFlowFolder%\%ThisFlowFilename%_backup.txt
	i_saveGeneralParameters()
	IniWrite,%ID_count%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count
	IniWrite,%SettingFlowExecutionPolicy%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy
	IniWrite,%SettingWorkingDir%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingWorkingDir
	IniWrite,%SettingFlowLogToFile%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,LogToFile
	IniWrite,%flowName%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,name
	IniWrite,%FlowCategory%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,category
	IniWrite,%FlowCompabilityVersionOfApp%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion
	IniWrite,%FolderOfStaticVariables%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Static variables folder
	saveCopyOfallElements:=allElements.clone()
	saveCopyOfallTriggers:=allTriggers.clone()
	
	
	
	for SaveIndex1, element in saveCopyOfallElements
	{
		saveElementID:=element
		saveElementType:=%saveElementID%Type
		
		;~ MsgBox %saveElementID%
		IniWrite,%element%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,ID
		IniWrite,%saveElementType%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,Type
		
		
		
		if (saveElementType="Connection")
		{
			saveElementfrom:=%saveElementID%from
			saveElementto:=%saveElementID%to
			saveElementConnectionType:=%saveElementID%ConnectionType
			IniWrite,%saveElementfrom%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,from
			IniWrite,%saveElementto%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,to
			IniWrite,%saveElementConnectionType%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,ConnectionType
			
			if %saveElementfrom%type=Loop
			{
				saveElementfromPart:=%saveElementID%fromPart
				IniWrite,%saveElementfromPart%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,fromPart
			}
			if %saveElementto%type=Loop
			{
				saveElementtoPart:=%saveElementID%toPart
				IniWrite,%saveElementtoPart%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,toPart
			}
			
			
		}
		else if (saveElementType="trigger")
		{
			saveElementX:=%saveElementID%x
			saveElementY:=%saveElementID%y
			saveElementname:=%saveElementID%name
			StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
			IniWrite,%saveElementname%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,name
			IniWrite,%saveElementX%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,x
			IniWrite,%saveElementY%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,y
		}
		else
		{
			saveElementX:=%saveElementID%x
			saveElementY:=%saveElementID%y
			saveElementsubType:=%saveElementID%subType
			saveElementname:=%saveElementID%name
			StringReplace, saveElementname, saveElementname, `n,|¶, All
			IniWrite,%saveElementsubType%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,subType
			IniWrite,%saveElementname%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,name
			IniWrite,%saveElementX%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,x
			IniWrite,%saveElementY%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,y
			
			if (saveElementType="loop")
			{
				saveElementHeightOfVerticalBar:=%saveElementID%HeightOfVerticalBar
				IniWrite,%saveElementHeightOfVerticalBar%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,HeightOfVerticalBar
			}
			
			i_SaveParametersOfElement(saveElementID,saveElementType,saveElementsubType,SaveIndex1,"element")
			
			
			
		}
	}
	
	for SaveIndex1, tempSaveElement in saveCopyOfallTriggers
	{
		saveElementID:=tempSaveElement
		saveElementType:=%saveElementID%Type
		
		
		IniWrite,%saveElementID%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%SaveIndex1%,ID
		IniWrite,%saveElementType%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%SaveIndex1%,Type
		
		
		saveElementsubType:=%saveElementID%subType
		saveElementname:=%saveElementID%name
		IniWrite,%saveElementsubType%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%SaveIndex1%,subType
		StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
		IniWrite,%saveElementname%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%SaveIndex1%,name
		
		i_SaveParametersOfElement(saveElementID,saveElementType,saveElementsubType,SaveIndex1,"trigger")
		
		
		
	}
	IniWrite,Yes,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Finished Saving
	
	Filedelete,%ThisFlowFolder%\%ThisFlowFilename%_backup.txt
	logger("a1","Flow " FlowName " was successfully saved.")
	ToolTip(lang("saved"))
	ui_EnableMainGUI()
	saved=yes
	busy:=false
}

i_saveGeneralParameters()
{
	global
	IniWrite,%Offsetx%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,Offsetx
	IniWrite,%OffsetY%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,OffsetY
	IniWrite,%zoomFactor%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,zoomFactor
}

i_SaveParametersOfElement(saveElementID,saveElementType,saveElementsubType,saveElementIndex,Savelocation)
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
	
	parametersToSave:=getParameters%saveElementType%%saveElementsubType%()
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
			SaveContent:=%saveElementID%%oneID%
			StringReplace, SaveContent, SaveContent, `n,|¶, All
			if (Savelocation="clipboard")
			{
				IniWrite,%SaveContent%,%ClipboardFlowFilename%,Element%saveElementIndex%,%oneID%
			}
			else if (Savelocation="trigger")
			{
				IniWrite,%SaveContent%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%saveElementIndex%,%oneID%
			}
			else if (Savelocation="element")
			{
				
				IniWrite,%SaveContent%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Element%saveElementIndex%,%oneID%
			}
			
			
		}
		
	
	}
}