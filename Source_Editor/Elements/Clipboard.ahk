SaveToClipboard()
{
	global
	local tempsaveCounter=0
	local toreturn
	
	busy:=true
	maingui.disable()

	
	ToolTip(lang("saving to clipboard"),100000)
	logger("a2","Saving elements to clipboard")
	
	_share.clipboard:=Object()
	;~ RIni_Shutdown("ClipboardSaveFile")
	;~ Rini_Create("ClipboardSaveFile")
	
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
			_share.clipboard[saveElementID]:= saveElement.clone()
			;~ tempsaveCounter++
			;~ saveSection:="element" a_index
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ID", saveElementID)
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"Type", saveElement.type)
			
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"x", saveElement.x)
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"y", saveElement.y)
			;~ saveElementname:=saveElement.name
			;~ StringReplace, saveElementname, saveElementname, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable. 
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"name", saveElementname)
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"subType", saveElement.subType)
			
			;~ if (saveElementType="loop")
			;~ {
				;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"HeightOfVerticalBar", saveElement.HeightOfVerticalBar)
			;~ }
			
			;~ i_SaveParametersOfElement(saveElement,saveSection,"ClipboardSaveFile")
		}
	}
	
	for saveElementID, saveElement in allConnections
	{
		;A connection is saved to clipboard if its connected elements are both marked
		if (!(allelements[saveElement.to].marked=true and allelements[saveElement.from].marked=true) )
		{
			continue
		}
		_share.clipboard[saveElementID]:= saveElement.clone()
		;~ tempsaveCounter++
		;~ saveSection:="Connection" a_index
		;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ID", saveElementID)
		;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"Type", saveElement.type)
		
		;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"from", saveElement.from)
		;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"to", saveElement.to)
		;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"ConnectionType", saveElement.ConnectionType)
		;~ if (saveElement.frompart)
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"fromPart", saveElement.frompart)
		;~ if (saveElement.toPart)
			;~ RIni_SetKeyValue("ClipboardSaveFile", saveSection,"toPart", saveElement.toPart)
	}
	;~ MsgBox %tempsaveCounter%
	if (tempsaveCounter>0)
	{
		;~ ret:=RIni_Write("ClipboardSaveFile", flow.ClipboardFilePath)
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
	
	;~ RIni_Shutdown("ClipboardSaveFile")
	maingui.enable()
	busy:=false
	return toreturn
}


loadFromClipboard()
{
	global
	local TempMouseX
	local TempMouseY
	local TempControl
	local tempWin
	local tempOffsetX
	local tempOffsetY
	local tempPosUnderMouseX
	local tempPosUnderMouseY
	local tempOffsetAlreadySet
	local tempfound
	local tempx
	local tempy
	local tempClipboardconnectionList
	local tempCountLoadedElements=0
	
	if (busy=true)
		return
	
	busy:=true
	maingui.disable()
	
	
	ClipboardFlowFilename:=flow.ClipboardFilePath
	;~ RIni_Shutdown("ClipboardLoadFile")
	;~ res:=RIni_Read("ClipboardLoadFile",flow.ClipboardFilePath)
	
	logger("a2","Loading elements from clipboard")
	ToolTip(lang("loading from clipboard"),100000)
	UnmarkEverything()  ;Unmark all elements
	
	;Find mouse position and find out whether the mouse is hovering the editor
	MouseGetPos,TempMouseX,TempMouseY,tempWin,TempControl,2
	If (tempWin= maingui.hwnd and TempControl=PicFlowHWND)
	{
		tempPosUnderMouseX:=((TempMouseX)/zoomfactor)+offsetx
		tempPosUnderMouseY:=((TempMouseY)/zoomfactor)+offsety
	}
	else ;Insert in the middle of the screen
	{
		tempPosUnderMouseX:=(visibleArea.x1+visiblearea.w/2)
		tempPosUnderMouseY:=(visibleArea.y1+visiblearea.h/2)
	}
	
	tempClipboardconnectionList:=[]
	
	;~ AllSections:=RIni_GetSections("ClipboardLoadFile")	
	for loadElementID, loadElement in _share.clipboard
	{
		tempSection:=A_LoopField
		
		;~ loadElementType:=clipElement.type
		
		tempCountLoadedElements++
		
		
		if loadElementID contains element
		{
			loadElementID:=API_Main_element_New(loadElementType) ;Do not pass Element ID
			_flows[FlowID].allElements[loadElementID] := loadElement.clone()
			_flows[FlowID].allElements[loadElementID].OldID := _flows[FlowID].allElements[loadElementID].ID ;Save the old ID in order to be able to assign the correct elements to the connections
			_flows[FlowID].allElements[loadElementID].id := loadElementID ;Correct the ID
			
		
			
			;Correct position.
			if (not tempOffsetX) ;On first iteration, find out where was the position of the first element and put it near to the mouse
			{
				tempOffsetX:=ui_FitGridX(tempPosUnderMouseX-loadElement.X -0.5*ElementWidth) 
				tempOffsetY:=ui_FitGridY(tempPosUnderMouseY-loadElement.Y - 0.5* ElementHeight)
			}
			;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
			_flows[FlowID].allElements[loadElementID].x:=ui_FitGridX(loadElement.X+tempOffsetX) 
			_flows[FlowID].allElements[loadElementID].y:=ui_FitGridY(loadElement.Y+tempOffsetY) 
			
			
			markOne(loadElementID,true)
		}
		
		if loadElementID contains Connection
		{
			loadElementID:=API_Main_connection_new(loadElementType)
			_flows[FlowID].allConnections[loadElementID] := loadElement.clone()
			_flows[FlowID].allConnections[loadElementID].id := loadElementID ;Correct the ID
			
			tempClipboardconnectionList.push(loadElementID) ;Save new connection in order to be able to assign the correct elements to the connections
			
		}
		
		
	}
	
	;Assign the correct elements to the connections
	for index, tempConnectionID in tempClipboardconnectionList
	{
		tempConnection:=allConnections[tempConnectionID]
		for tempID, tempElement in _flows[FlowID].allElements
		{
			if (_flows[FlowID].allConnections[tempConnectionID].to=_flows[FlowID].allElements[tempID].OldID)
			{
				_flows[FlowID].allConnections[tempConnectionID].to:=_flows[FlowID].allElements[tempID].id
			}
			if (_flows[FlowID].allConnections[tempConnectionID].from=_flows[FlowID].allElements[tempID].OldID)
			{
				_flows[FlowID].allConnections[tempConnectionID].from:=_flows[FlowID].allElements[tempID].id
			}
		}
	}
	
	for tempID, tempElement in _flows[FlowID].allElements ;remove the oldIDs otherwise it will cause errors on next paste
	{
		_flows[FlowID].allElements[tempID].delete("oldID")
	}
	
	if tempCountLoadedElements>0
	{
		new state()
		ToolTip(lang("Loaded %1% elements from clipboard",index1),1000)
		logger("a2","Loaded " index1 " elements from clipboard")
	}
	else
	{
		ToolTip(lang("No elements found in clipboard"),1000)
		logger("a2","No elements found in clipboard")
	}
	

	
	;~ e_CorrectElementErrors("Loaded from clipboard")
	;~ RIni_Shutdown("ClipboardLoadFile")
	maingui.enable()
	
	API_Main_Draw()

	busy:=false
}

