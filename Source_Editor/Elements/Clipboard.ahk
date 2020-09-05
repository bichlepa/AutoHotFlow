SaveToClipboard()
{
	global
	local tempsaveCounter=0
	local toreturn
	

	EnterCriticalSection(_cs_flows)
	
	ToolTip(lang("saving to clipboard"),100000)
	logger("a2","Saving elements to clipboard")
	
	_share.clipboard:=Object()
	_share.clipboard.allElements:=Object()
	_share.clipboard.allConnections:=Object()
	;~ RIni_Shutdown("ClipboardSaveFile")
	;~ Rini_Create("ClipboardSaveFile")
	
	for saveElementID, saveElement in FlowObj.allElements
	{
		;~ d(saveElement,1)
		if (saveElement.marked!=true) ;Save only marked elements to clipboard
			continue
		
		_share.clipboard.allElements[saveElementID]:= objfullyclone(saveElement) 
		tempsaveCounter++
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
	
	for saveElementID, saveElement in FlowObj.allConnections
	{
		;A connection is saved to clipboard if its connected elements are both marked
		if (!(FlowObj.allelements[saveElement.to].marked=true and FlowObj.allelements[saveElement.from].marked=true) )
		{
			continue
		}
		_share.clipboard.allConnections[saveElementID]:= objfullyclone(saveElement) 
		tempsaveCounter++
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
	
	;~ d(_share.clipboard)
	
	LeaveCriticalSection(_cs_flows)
	
	;~ RIni_Shutdown("ClipboardSaveFile")
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
	
	EnterCriticalSection(_cs_flows)
	
	
	ClipboardFlowFilename:=flow.ClipboardFilePath
	;~ RIni_Shutdown("ClipboardLoadFile")
	;~ res:=RIni_Read("ClipboardLoadFile",flow.ClipboardFilePath)
	
	logger("a2","Loading elements from clipboard")
	ToolTip(lang("loading from clipboard"),100000)
	UnmarkEverything()  ;Unmark all elements
	
	;Find mouse position and find out whether the mouse is hovering the editor
	MouseGetPos,TempMouseX,TempMouseY,tempWin,TempControl,2
	;~ d("tempWin: " tempWin " - " _share.hwnds["editGUI" FlowID] "`nTempControl: " TempControl " - " _share.hwnds["editGUIDC" FlowID])
	If (tempWin= _share.hwnds["editGUI" FlowID])
	{
		tempPosUnderMouseX:=((TempMouseX)/FlowObj.flowSettings.zoomFactor)+FlowObj.flowSettings.offsetx
		tempPosUnderMouseY:=((TempMouseY)/FlowObj.flowSettings.zoomFactor)+FlowObj.flowSettings.offsety
		;~ d(tempPosUnderMouseX " - " tempPosUnderMouseY)
	}
	else ;Insert in the middle of the screen
	{
		tempPosUnderMouseX:=(visibleArea.x1+visiblearea.w/2)
		tempPosUnderMouseY:=(visibleArea.y1+visiblearea.h/2)
	}
	
	tempClipboardconnectionList:=Object()
	UnmarkEverything()
	
	;~ AllSections:=RIni_GetSections("ClipboardLoadFile")	
	for loadElementID, loadElement in _share.clipboard.allElements
	{
		tempCountLoadedElements++
		
		
		NewElementID:=element_New(FlowID) ;Do not pass Element ID
		_flows[FlowID].allElements[NewElementID] := objfullyclone(loadElement)
		_flows[FlowID].allElements[NewElementID].OldID := loadElementID ;Save the old ID in order to be able to assign the correct elements to the connections
		_flows[FlowID].allElements[NewElementID].id := NewElementID ;Correct the ID
		
		
		;Correct position.
		if (not tempOffsetX) ;On first iteration, find out where was the position of the first element and put it near to the mouse
		{
			tempOffsetX:=ui_FitGridX(tempPosUnderMouseX - loadElement.X - 0.5 * default_ElementWidth) 
			tempOffsetY:=ui_FitGridY(tempPosUnderMouseY - loadElement.Y - 0.5 * default_ElementHeight)
			;~ d(tempPosUnderMouseX " - " loadElement.X " - " 0.5*default_ElementWidth " = " tempOffsetX "`n" tempPosUnderMouseY " - " loadElement.Y " - " 0.5*default_ElementHeight " = " tempOffsetY)
		}
		;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
		_flows[FlowID].allElements[NewElementID].x:=ui_FitGridX(loadElement.X+tempOffsetX) 
		_flows[FlowID].allElements[NewElementID].y:=ui_FitGridY(loadElement.Y+tempOffsetY) 
		
		
		markOne(NewElementID,true)
	}
		
	;~ AllSections:=RIni_GetSections("ClipboardLoadFile")	
	for loadElementID, loadElement in _share.clipboard.allConnections
	{
		tempCountLoadedElements++
		
		;~ d(_flows[FlowID].allElements[NewElementID])
		
		
		NewElementID:=connection_new(FlowID)
		_flows[FlowID].allConnections[NewElementID] := objfullyclone(loadElement)
		
		_flows[FlowID].allConnections[NewElementID].id := NewElementID ;Correct the ID
		
		tempClipboardconnectionList.push(NewElementID) ;Save new connection in order to be able to assign the correct elements to the connections
		
		markOne(NewElementID,true)
		
		
		
	}
	
	;Assign the correct elements to the connections
	for index, tempConnectionID in tempClipboardconnectionList
	{
		for tempID, tempElement in _flows[FlowID].allElements
		{
			if (tempElement.oldID)
			{
				;~ d(_flows[FlowID].allConnections[tempConnectionID],tempElement.OldID)
				if (_flows[FlowID].allConnections[tempConnectionID].to = tempElement.OldID)
				{
					_flows[FlowID].allConnections[tempConnectionID].to := tempElement.id
				}
				if (_flows[FlowID].allConnections[tempConnectionID].from = tempElement.OldID)
				{
					_flows[FlowID].allConnections[tempConnectionID].from := tempElement.id
				}
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
	
	
	State_New(FlowID)
	
	LeaveCriticalSection(_cs_flows)
	
	API_Draw_Draw()

}

