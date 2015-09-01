i_SaveToClipboard()
{
	global
	
	busy:=true
	ui_DisableMainGUI()

	
	ClipboardFlowFilename=%A_ScriptDir%\Clipboard.ini
	
	ToolTip(lang("saving to clipboard"),100000)
	logger("a2","Saving elements to clipboard")


	
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
			if (%tempTo%marked="true" and %tempFrom%marked="true" and %tempFrom%type!="Trigger") ;Ignore connections from trigger
				tempShouldBeStoredToClipboard:=true
			
		}
		else if (saveElementType="trigger")
		{
			temp= ;TODO
			if (%saveElementID%marked="true")
				ToolTip("No triggers can be copied to the clipboard by now. Sorry.")
			
		}
		else if (saveElementType="action" or saveElementType="condition" or saveElementType="loop")
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
				
				if %saveElementfrom%type=Loop
				{
					saveElementfromPart:=%saveElementID%fromPart
					IniWrite,%saveElementfromPart%,%ClipboardFlowFilename%,element%saveCounter%,fromPart
				}
				if %saveElementto%type=Loop
				{
					saveElementtoPart:=%saveElementID%toPart
					IniWrite,%saveElementtoPart%,%ClipboardFlowFilename%,element%saveCounter%,toPart
				}
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
				
				if (saveElementType="loop")
				{
					saveElementHeightOfVerticalBar:=%saveElementID%HeightOfVerticalBar
					IniWrite,%saveElementHeightOfVerticalBar%,%ClipboardFlowFilename%,element%saveCounter%,HeightOfVerticalBar
				}
				
				
				i_SaveParametersOfElement(saveElementID,saveElementType,saveElementsubType,saveCounter,"clipboard")
			}
			
			
		}
	}
	
	if saveCounter>0
	{
		logger("a2","Saved %1% elements to clipboard")
		ToolTip(lang("Saved %1% elements to clipboard",saveCounter))
	}
	else
	{
		logger("a2","No elements saved to clipboard")
		ToolTip(lang("No elements selected",saveCounter))
	}
	ui_EnableMainGUI()
	busy:=false
	
}