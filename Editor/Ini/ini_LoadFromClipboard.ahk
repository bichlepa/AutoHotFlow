i_loadFromClipboard()
{
	global
	
	ui_disablemaingui()
	
	
	ClipboardFlowFilename=%A_ScriptDir%\Clipboard.ini
	
	ToolTip(lang("loading from clipboard"),100000)
	tempClipboardconnectionList:=Object()
	markelement()  ;Unmark all elements
	
	loop
	{
		index1:=A_Index
		
		Iniread,loadElementID,%ClipboardFlowFilename%,element%index1%,ID
		;MsgBox,,, %ID_count%`nIniread,loadElementID,%ClipboardFlowFilename%,element%index1%,ID`n%loadElementID%
		if loadElementID=Error
			break
		
		Iniread,loadElementType,%ClipboardFlowFilename%,element%index1%,Type
		
		if (loadElementType="Connection")
		{
			;Store the connections to a list and add them later
			tempClipboardconnectionList.insert(loadElementID)
			
			
			Iniread,tempClipboardconnection%loadElementID%from,%ClipboardFlowFilename%,element%index1%,from
			Iniread,tempClipboardconnection%loadElementID%to,%ClipboardFlowFilename%,element%index1%,to
			Iniread,tempClipboardconnection%loadElementID%ConnectionType,%ClipboardFlowFilename%,element%index1%,ConnectionType
			
			
		}
		else if (loadElementType="Trigger")
		{
			;TODO
			
		}
		else
		{
			if (loadElementType="action")
				tempNewID:=e_NewAction()
			else if (loadElementType="condition")
				tempNewID:=e_Newcondition()
			;allElements.insert(tempNewID)
			tempClipboardMap%loadElementID%:=tempNewID ;Needed to realize connections later
			markelement(tempNewID,"true")
			%tempNewID%running=0
			
			
			
			Iniread,loadElementname,%ClipboardFlowFilename%,element%index1%,name
			StringReplace, loadElementname, loadElementname, |¶,`n, All
			
			Iniread,loadElementX,%ClipboardFlowFilename%,element%index1%,x
			Iniread,loadElementY,%ClipboardFlowFilename%,element%index1%,y
			
			
			%tempNewID%Name=%loadElementname%
			%tempNewID%x=%loadElementX%
			%tempNewID%y=%loadElementY%
			
			
			Iniread,loadElementsubType,%ClipboardFlowFilename%,element%index1%,subType
			%tempNewID%subType=%loadElementsubType%
			
			
			
			
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
					Iniread,tempContent,%ClipboardFlowFilename%,element%index1%,% temponeparname
					;MsgBox % temponeparname " " tempContent
					if (tempContent=="ERROR")
						tempContent:=tempdefault%A_Index%
					StringReplace, tempContent, tempContent, |¶,`n, All
					
					%tempNewID%%temponeparname%=%tempContent%
				}
			}
				
			
			
			
		}
		
		ui_draw()
		
		
		
	}
	for SaveIndex1, LoadElementID in tempClipboardconnectionList
		{
			
			tempFrom:=tempClipboardconnection%LoadElementID%from
			tempTo:=tempClipboardconnection%LoadElementID%to
			
			
			e_newConnection(tempClipboardMap%tempFrom%,tempClipboardMap%tempTo%,tempClipboardconnection%LoadElementID%ConnectionType)
			
		}
	ToolTip(lang("loaded"),1000)
	e_UpdateTriggerName()
	
	
	ui_EnableMainGUI()
	d_logger("Flow loaded`nName: "FlowName)
	ui_draw()
	saved=yes
}

