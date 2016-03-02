i_SaveToClipboard()
{
	global
	local tempsaveCounter=0
	local toreturn
	
	busy:=true
	maingui.disable()

	
	ToolTip(lang("saving to clipboard"),100000)
	logger("a2","Saving elements to clipboard")

	RIni_Shutdown("ClipboardSaveFile")
	Rini_Create("ClipboardSaveFile")
	
	for saveElementID, saveElement in allElements
	{
		;~ d(saveElement,1)
		if (saveElement.marked!=true) ;Save only marked elements to clipboard
			continue
		
		if (saveElement.type="trigger")
		{
			;Trigger cannot be saved to clipboard
			continue
		}
		else
		{
			tempsaveCounter++
			saveSection:="element" a_index
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ID", saveElementID)
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"Type", saveElement.type)
			
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"x", saveElement.x)
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"y", saveElement.y)
			saveElementname:=saveElement.name
			StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"name", saveElementname)
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"subType", saveElement.subType)
			
			if (saveElementType="loop")
			{
				RIni_SetKeyValue("ClipboardSaveFile", saveSection,"HeightOfVerticalBar", saveElement.HeightOfVerticalBar)
			}
			
			i_SaveParametersOfElement(saveElement,saveSection,"ClipboardSaveFile")
		}
	}
	
	for saveElementID, saveElement in allConnections
	{
		;A connection is saved to clipboard if its connected elements are both marked
		if (!(allelements[saveElement.to].marked=true and allelements[saveElement.from].marked=true) )
		{
			continue
		}
		
		tempsaveCounter++
		saveSection:="Connection" a_index
		RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ID", saveElementID)
		RIni_SetKeyValue("ClipboardSaveFile", saveSection,"Type", saveElement.type)
		
		RIni_SetKeyValue("ClipboardSaveFile", saveSection,"from", saveElement.from)
		RIni_SetKeyValue("ClipboardSaveFile", saveSection,"to", saveElement.to)
		RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ConnectionType", saveElement.ConnectionType)
		if (saveElement.frompart)
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"fromPart", saveElement.frompart)
		if (saveElement.toPart)
			RIni_SetKeyValue("ClipboardSaveFile", saveSection,"toPart", saveElement.toPart)
	}
	;~ MsgBox %tempsaveCounter%
	if (tempsaveCounter>0)
	{
		ret:=RIni_Write("ClipboardSaveFile", flow.ClipboardFilePath)
		if not ret
		{
			logger("a2","Saved %1% elements to clipboard")
			ToolTip(lang("Saved %1% elements to clipboard",tempsaveCounter))
			toreturn:=0 ;No errors. The return value is needed if user presses Ctrl + x. Now all marked elements will be deleted
		}
		else
		{
			logger("a0","Error. Couldn't save to clipboard.")
			MsgBox % lang("Couldn't save to clipboard")
			toreturn:= 1 ;Error appears. The return value is needed if user presses Ctrl + x. Markede elements will not be deleted
		}
	}
	else
	{
		logger("a2","No elements saved to clipboard")
		ToolTip(lang("No elements selected",saveCounter))
		toreturn:= -1
	}
	
	RIni_Shutdown("ClipboardSaveFile")
	maingui.enable()
	busy:=false
	return toreturn
}