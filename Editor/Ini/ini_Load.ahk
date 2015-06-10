i_load(ThisFlowFilePath="")
{
	global
	
	busy:=true
	ui_disablemaingui()
	if ThisFlowFilePath=
	{
		FileSelectFile,ThisFlowFilePath,1,Saved Flows,% lang("Open_flow"),  *.ini
		if errorlevel
		{
			ui_EnableMainGUI()
			return
		}
		
		
		
	}
	
		
	SplitPath,ThisFlowFilePath,,ThisFlowFolder,,ThisFlowFilename
	
	ToolTip(lang("loading"),100000)
	Iniread,ID_count,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,count,1
	Iniread,SettingFlowExecutionPolicy,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,SettingFlowExecutionPolicy,parallel
	
	i_loadGeneralParameters() ;Outsourced in order to execute only that later when flow name changes
	
	
	loop
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,Type
		
		
		if (loadElementType="Connection")
		{
			allElements.insert(loadElementID)
			
			%loadElementID%marked=false
			%loadElementID%running=0
			
			%loadElementID%Type=%loadElementType%
			
			Iniread,%loadElementID%from,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,from
			Iniread,%loadElementID%to,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,to
			Iniread,%loadElementID%ConnectionType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ConnectionType
			
			Iniread,%loadElementID%fromPart,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,fromPart,%A_Space%
			Iniread,%loadElementID%ToPart,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,toPart,%A_Space%
		}
		else if (loadElementType="Trigger")
		{
			Iniread,loadElementX,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			Iniread,loadElementY,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			%loadElementID%x=%loadElementX%
			%loadElementID%y=%loadElementY%
			
		}
		else
		{
			allElements.insert(loadElementID)
		
			%loadElementID%marked=false
			%loadElementID%running=0
			
			%loadElementID%Type=%loadElementType%
			
			Iniread,loadElementname,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,name
			StringReplace, loadElementname, loadElementname, |¶,`n, All
			
			
			Iniread,loadElementX,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,x
			Iniread,loadElementY,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,y
			
			
			%loadElementID%Name=%loadElementname%
			%loadElementID%x=%loadElementX%
			%loadElementID%y=%loadElementY%
			
			
			Iniread,loadElementsubType,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,subType
			%loadElementID%subType=%loadElementsubType%
			
			if (loadElementType="loop")
			{
				Iniread,loadElementHeightOfVerticalBar,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,HeightOfVerticalBar
				%loadElementID%HeightOfVerticalBar=%loadElementHeightOfVerticalBar%
			}
			
			
			parametersToload:=getParameters%loadElementType%%loadElementsubType%()
			for index2, parameter in parametersToload
			{
				StringSplit,parameter,parameter,|
				if (parameter3="" or parameter0<3) ; ;If this is only a label for the edit fielt etc. Do nothing
					continue
				StringSplit,tempparname,parameter3,; ;get the parameter names
				StringSplit,tempdefault,parameter2,; ;get the default parameter
				Loop % tempparname0
				{
					temponeparname:=tempparname%A_Index%
					Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,%temponeparname%
					if (tempContent=="ERROR")
						tempContent:=tempdefault%A_Index%
					StringReplace, tempContent, tempContent, |¶,`n, All
					
					%loadElementID%%temponeparname%=%tempContent%
				}
			}
			
			
		}
		
		ui_draw()
		
		
		
	}
	loop
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ThisFlowFolder%\%ThisFlowFilename%.ini,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		Iniread,loadElementType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,Type
		
		
		
		allTriggers.insert(loadElementID)
	
	
		%loadElementID%Type=%loadElementType%
		
		Iniread,loadElementname,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,name
		StringReplace, loadElementname, loadElementname, |¶,`n, All
		%loadElementID%Name=%loadElementname%
		
		
		Iniread,loadElementsubType,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,subType
		%loadElementID%subType=%loadElementsubType%
		
		
		
		
		parametersToload:=getParameters%loadElementType%%loadElementsubType%()
		for index2, parameter in parametersToload
		{
			StringSplit,parameter,parameter,|
			;~ MsgBox,% "-" parameter3 "-"
			if (parameter3="" or parameter0<3) ;If this is only a label for the edit fielt etc. Do nothing
				continue
			;~ MsgBox,% "-" parameter3 "_"
			;~ MsgBox,% parameter
			Iniread,tempContent,%ThisFlowFolder%\%ThisFlowFilename%.ini,Trigger%index1%,%parameter3%
			if (tempContent=="ERROR")
					tempContent=%parameter2%
			;~ MsgBox,% tempContent "-" parameter2 "`n" trigger1ahk_class
			StringReplace, tempContent, tempContent, |¶,`n, All
			;~ setParameter(loadElementID,parameter3,tempContent
			%loadElementID%%parameter3%=%tempContent%
		}
			
			
		
		;UpdateTriggerName()
		ui_draw()
		
		
		
	}
	
	ToolTip(lang("loaded"),1000)
	e_UpdateTriggerName()
	
	menu, tray, rename, % Tray_OldShowName, % lang("Edit %1%", flowName)
	Tray_OldShowName:=lang("Edit %1%", flowName)
	menu,tray,tip,% lang("Flow %1%",flowName)
	
	ui_EnableMainGUI()
	d_logger("Flow loaded`nName: "FlowName)
	ui_draw()
	saved=yes
	busy:=false
}

i_loadGeneralParameters()
{
	global
	
	Iniread,FlowName,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,name
	Iniread,FlowCategory,%ThisFlowFolder%\%ThisFlowFilename%.ini,general,category
	
	GuiControl,CommandWindow:text,CommandWindowFlowName,Ѻ%flowName%Ѻ ;Set the name of the flow as text in the hidden window. So the other ahks can find the right window
	
	;IfWinExist,·AutoHotFlow·
		;ui_showgui()
}