SaveToClipboard()
{
	EnterCriticalSection(_cs_shared)
	
	ToolTip(lang("saving to clipboard"),100000)
	logger("a2","Saving elements to clipboard")
	

	newClipboard:=Object()
	newClipboard.allElements:=Object()
	newClipboard.allConnections:=Object()
	;~ RIni_Shutdown("ClipboardSaveFile")
	;~ Rini_Create("ClipboardSaveFile")
	
	
	for forIndex, forElementID in _getAllElementIds(FlowID)
	{
		;~ d(saveElement,1)
		marked := _getElementProperty(FlowID, forElementID, "marked")
		if (marked != true) ;Save only marked elements to clipboard
			continue
		
		newClipboard.allElements[forElementID]:= _getElement(FlowID, forElementID)
		tempsaveCounter++
	}
	
	for forIndex, forConnectionID in _getAllConnectionIds(FlowID) 
	{
		from := _getConnectionProperty(FlowID, forConnectionID, "saveElement.from")
		to := _getConnectionProperty(FlowID, forConnectionID, "saveElement.to")
		fromMarked := _getElementProperty(FlowID, from, "marked")
		toMarked := _getElementProperty(FlowID, to, "marked")
		;A connection is saved to clipboard if its connected elements are both marked
		if (!(fromMarked=true and toMarked=true) )
		{
			continue
		}
		newClipboard.allConnections[saveElementID]:= _getConnection(FlowID, forConnectionID)
		tempsaveCounter++
	}
	;~ MsgBox %tempsaveCounter%
	if (tempsaveCounter>0)
	{
		logger("a2","Saved %1% elements to clipboard")
		ToolTip(lang("Saved %1% elements to clipboard",tempsaveCounter))
		toreturn:=0 ;No errors. The return value is needed if user presses Ctrl + x. Now all marked elements will be deleted
		
	}
	else
	{
		logger("a2","No elements saved to clipboard")
		ToolTip(lang("No elements selected",saveCounter))
		toreturn:= -1
	}
	
	_setShared("clipboard", newClipboard)
	
	LeaveCriticalSection(_cs_shared)
	
	;~ RIni_Shutdown("ClipboardSaveFile")
	return toreturn
}


loadFromClipboard()
{
	EnterCriticalSection(_cs_shared)
	
	
	ClipboardFlowFilename:=flow.ClipboardFilePath
	;~ RIni_Shutdown("ClipboardLoadFile")
	;~ res:=RIni_Read("ClipboardLoadFile",flow.ClipboardFilePath)
	
	logger("a2","Loading elements from clipboard")
	ToolTip(lang("loading from clipboard"),100000)
	UnmarkEverything()  ;Unmark all elements
	
	;Find mouse position and find out whether the mouse is hovering the editor
	winHWND:= _getSharedProperty("hwnds.editGUI" FlowID)
	MouseGetPos,TempMouseX,TempMouseY,tempWin,TempControl,2
	If (tempWin = winHWND)
	{
		zoomFactor := _getFlowProperty(FlowID, "flowSettings.zoomFactor") 
		offsetx := _getFlowProperty(FlowID, "flowSettings.offsetx") 
		offsety := _getFlowProperty(FlowID, "flowSettings.offsetx") 
		tempPosUnderMouseX:=((TempMouseX)/zoomFactor)+offsetx
		tempPosUnderMouseY:=((TempMouseY)/zoomFactor)+offsety
		;~ d(tempPosUnderMouseX " - " tempPosUnderMouseY)
	}
	else ;Insert in the middle of the screen
	{
		tempPosUnderMouseX:=(visibleArea.x1+visiblearea.w/2)
		tempPosUnderMouseY:=(visibleArea.y1+visiblearea.h/2)
	}
	
	tempClipboardconnectionList:=Object()
	tempClipboardElementList:=Object()
	UnmarkEverything()
	
	clipboardContent := _getShared("clipboard")
	;~ AllSections:=RIni_GetSections("ClipboardLoadFile")	
	for loadElementID, loadElement in clipboardContent.allElements
	{
		tempCountLoadedElements++
		
		
		NewElementID:=element_New(FlowID) ;Do not pass Element ID
		_setElement(FlowID, NewElementID, loadElement)
		_setElementProperty(FlowID, NewElementID, "id", NewElementID) ;Correct the ID
		
		;Correct position.
		if (not tempOffsetX) ;On first iteration, find out where was the position of the first element and put it near to the mouse
		{
			tempOffsetX:=ui_FitGridX(tempPosUnderMouseX - loadElement.X - 0.5 * default_ElementWidth) 
			tempOffsetY:=ui_FitGridY(tempPosUnderMouseY - loadElement.Y - 0.5 * default_ElementHeight)
			;~ d(tempPosUnderMouseX " - " loadElement.X " - " 0.5*default_ElementWidth " = " tempOffsetX "`n" tempPosUnderMouseY " - " loadElement.Y " - " 0.5*default_ElementHeight " = " tempOffsetY)
		}
		;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
		_setElementProperty(FlowID, NewElementID, "x", ui_FitGridX(loadElement.X+tempOffsetX))
		_setElementProperty(FlowID, NewElementID, "y", ui_FitGridY(loadElement.Y+tempOffsetY))
		
		tempClipboardElementList[loadElementID] := NewElementID ;Save new element IDs in order to be able to assign the correct elements to the connections
		
		markOne(NewElementID,true)
	}
		
	;~ AllSections:=RIni_GetSections("ClipboardLoadFile")	
	for loadElementID, loadElement in clipboardContent.allConnections
	{
		tempCountLoadedElements++
		
		
		NewElementID := connection_new(FlowID)
		_setConnection(FlowID, NewElementID, loadElement)
		_setElementProperty(FlowID, NewElementID, "id", NewElementID) ;Correct the ID
		_setElementProperty(FlowID, NewElementID, "to", tempClipboardElementList[loadElement.to]) ;Correct connected element ID
		_setElementProperty(FlowID, NewElementID, "from", tempClipboardElementList[loadElement.from]) ;Correct connected element ID
		
		tempClipboardconnectionList.push(NewElementID) ;Save new connection IDs in order to be able to assign the correct elements to the connections
		
		markOne(NewElementID,true)
	}

	if tempCountLoadedElements>0
	{
		State_New(FlowID)
		ToolTip(lang("Loaded %1% elements from clipboard",index1),1000)
		logger("a2","Loaded " index1 " elements from clipboard")
	}
	else
	{
		ToolTip(lang("No elements found in clipboard"),1000)
		logger("a2","No elements found in clipboard")
	}
	
	LeaveCriticalSection(_cs_shared)
	
	API_Draw_Draw(FlowID)

}

