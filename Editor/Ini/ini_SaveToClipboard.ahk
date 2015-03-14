i_SaveToClipboard()
{
	global
	
	
	ui_DisableMainGUI()

	
	ClipboardFlowFilename=%A_ScriptDir%\Clipboard.ini
	
	ToolTip(lang("saving to clipboard"),100000)
	


	
	saveCounter=0
	
	FileDelete,%ClipboardFlowFilename%
	for SaveIndex1, saveElementID in allElements
	{
		saveElementType:=%saveElementID%type
		
		;Check whether this element is selected and should be saved to clipboard
		tempShouldBeStoredToClipboard:=false
		if (saveElementType="Connection")
		{
			;a connetion is saved when it connects two selected elements
			
			tempTo:=%saveElementID%to
			tempFrom:=%saveElementID%from
			if (%tempTo%marked="true" and %tempFrom%marked="true")
				tempShouldBeStoredToClipboard:=true
			
		}
		else if (saveElementType="trigger")
		{
			temp= ;TODO
			if (%saveElementID%marked="true")
				ToolTip("No triggers can be copied to the clipboard by now. Sorry.")
			
		}
		else if (saveElementType="action" or saveElementType="condition")
		{
			
			if %saveElementID%marked=true
				tempShouldBeStoredToClipboard:=true
			
		}
		
		
		if (tempShouldBeStoredToClipboard) ;If the current element should be selected
		{
			saveCounter++
			
			
			
			IniWrite,% saveElementID,%ClipboardFlowFilename%,element%saveCounter%,ID
			IniWrite,% %saveElementID%Type,%ClipboardFlowFilename%,element%saveCounter%,Type
			
			
			if (saveElementType="Connection")
			{
				saveElementfrom:=%saveElementID%from
				saveElementto:=%saveElementID%to
				saveElementConnectionType:=%saveElementID%ConnectionType
				IniWrite,%saveElementfrom%,%ClipboardFlowFilename%,element%saveCounter%,from
				IniWrite,%saveElementto%,%ClipboardFlowFilename%,element%saveCounter%,to
				IniWrite,%saveElementConnectionType%,%ClipboardFlowFilename%,element%saveCounter%,ConnectionType
				
			}
			else if (saveElementType="trigger")
			{
				saveElementX:=%saveElementID%x
				saveElementY:=%saveElementID%y
				saveElementname:=%saveElementID%name
				StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
				IniWrite,%saveElementname%,%ClipboardFlowFilename%,element%saveCounter%,name
				IniWrite,%saveElementX%,%ClipboardFlowFilename%,element%saveCounter%,x
				IniWrite,%saveElementY%,%ClipboardFlowFilename%,element%saveCounter%,y
			}
			else
			{
				saveElementX:=%saveElementID%x
				saveElementY:=%saveElementID%y
				saveElementsubType:=%saveElementID%subType
				saveElementname:=%saveElementID%name
				StringReplace, saveElementname, saveElementname, `n,|¶, All
				IniWrite,%saveElementsubType%,%ClipboardFlowFilename%,element%saveCounter%,subType
				IniWrite,%saveElementname%,%ClipboardFlowFilename%,element%saveCounter%,name
				IniWrite,%saveElementX%,%ClipboardFlowFilename%,element%saveCounter%,x
				IniWrite,%saveElementY%,%ClipboardFlowFilename%,element%saveCounter%,y
				
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
						
						IniWrite,%SaveContent%,%ClipboardFlowFilename%,element%saveCounter%,%temponeparname%
					}	
				}	
			}
			
			
		}
	}
	
	ToolTip(lang("saved %1% elements to clipboard",saveCounter))
	ui_EnableMainGUI()
	
	
}