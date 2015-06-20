
i_save()
{
	global
	
	
	ui_DisableMainGUI()
	busy:=true
	GetKeyState,k,control,p 
	if (ThisFlowFilename="" or k="d")
	{
		FileSelectFile,ThisFlowFilePath,S24,Saved Flows,Save flow, *.ini
		if errorlevel
		{
			
			ui_EnableMainGUI()
			return
		}
		SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	}

	
	ToolTip(lang("saving"),100000)
	
	FileCreateDir,%ThisFlowFolder%
	Filemove,%ThisFlowFolder%\%ThisFlowFilename%.ini,%ThisFlowFolder%\%ThisFlowFilename%backup.ini
	IniWrite,%ID_count%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count
	IniWrite,%SettingFlowExecutionPolicy%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy
	IniWrite,%SettingWorkingDir%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingWorkingDir
	IniWrite,%flowName%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,name
	IniWrite,%FlowCategory%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,category
	IniWrite,%FlowCompabilityVersionOfApp%,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,FlowCompabilityVersion
	saveCopyOfallElements:=allElements.clone()
	
	for SaveIndex1, element in saveCopyOfallElements
	{
		saveElementID:=element
		saveElementType:=%saveElementID%Type
		
		
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
			
			
			parametersToSave:=getParameters%saveElementType%%saveElementsubType%()
			for tempSaveindex2, tempSaveParameter in parametersToSave
			{
				StringSplit,tempSaveParameter,tempSaveParameter,|
				
				; tempSaveParameter3 contains the parameter ID
				if tempSaveParameter3= ;If this is only a label for the edit fielt etc. Do nothing
					continue
				StringSplit,tempparname,tempSaveParameter3,; ;get the parameter names
				Loop % tempparname0
				{
					temponeparname:=tempparname%A_Index%
					SaveContent:=%saveElementID%%temponeparname%
					StringReplace, SaveContent, SaveContent, `n,|¶, All
					
					IniWrite,%SaveContent%,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%SaveIndex1%,%temponeparname%
				}	
			}
			
			
		}
	}
	saveCopyOfallTriggers:=allTriggers.clone()
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
		parametersToSave:=getParameters%saveElementType%%saveElementsubType%()
		for tempSaveindex2, tempSaveParameter in parametersToSave
		{
			StringSplit,tempSaveParameter,tempSaveParameter,|
			if tempSaveParameter3= ;If this is only a labe for the edit fielt etc. Do nothing
				continue
			SaveContent:=%saveElementID%%tempSaveParameter3%
			StringReplace, SaveContent, SaveContent, `n,|¶, All
			IniWrite,%SaveContent%,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%SaveIndex1%,%tempSaveParameter3%
			
		}
		
			
		
	}
	Filedelete,%ThisFlowFolder%\%ThisFlowFilename%backup.ini
	
	ToolTip(lang("saved"))
	ui_EnableMainGUI()
	saved=yes
	busy:=false
}