i_loadFromClipboard()
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
	RIni_Shutdown("ClipboardLoadFile")
	res:=RIni_Read("ClipboardLoadFile",flow.ClipboardFilePath)
	
	logger("a2","Loading elements from clipboard")
	ToolTip(lang("loading from clipboard"),100000)
	element.unmarkall()  ;Unmark all elements
	
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
	
	AllSections:=RIni_GetSections("ClipboardLoadFile")	
	loop,parse,AllSections,`,
	{
		tempSection:=A_LoopField
		
		loadElementID:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "ID", "")
		if (loadElementID="")
		{
			logger("a0","Error! Could not read the ID of an element " tempSection ". This element will not be loaded")
			continue
		}
		loadElementType:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "Type", "")
		
		tempCountLoadedElements++
		
		
		IfInString,tempSection,element
		{
			loadElement:=new element(loadElementType) ;Do not pass Element ID
			loadElement.OldID:=loadElementID ;Save the old ID in order to be able to assign the correct elements to the connections
			
			tempValue:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "name", "")
			StringReplace, tempValue, tempValue, |¶,`n, All
			loadElement.Name:=tempValue
			
			loadElement.StandardName:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "StandardName", "")
			loadElement.x:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "x", 200)
			loadElement.y:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "y", 200)
			
			loadElement.subType:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "subType", 200)
			
			i_CheckCompabilitySubtype(loadElement,tempSection)
			
			if (loadElementType="loop")
			{
				loadElement.HeightOfVerticalBar:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "HeightOfVerticalBar", 200)
			}
			
			;Get the list of all parameters and read all parameters from ini
			i_LoadParametersOfElement(loadElement,"ClipboardLoadFile",tempSection)
			
			
			;Correct position.
			if (not tempOffsetX) ;On first iteration, find out where was the position of the first element and put it near to the mouse
			{
				tempOffsetX:=ui_FitGridX(tempPosUnderMouseX-loadElement.X -0.5*ElementWidth) 
				tempOffsetY:=ui_FitGridY(tempPosUnderMouseY-loadElement.Y - 0.5* ElementHeight)
			}
			;Correct the position. Each element should have the same relative position to each other as in the flow where they were copied from
			loadElement.x:=ui_FitGridX(loadElement.X+tempOffsetX) 
			loadElement.y:=ui_FitGridY(loadElement.Y+tempOffsetY) 
			
			
			loadElement.mark(true)
		}
		
		IfInString,tempSection,Connection
		{
			loadElement:=new connection(loadElementType)
			
			tempClipboardconnectionList.push(loadElement.id) ;Save new connection in order to be able to assign the correct elements to the connections
			
			loadElement.from:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "from", "")
			loadElement.to:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "to", "")
			loadElement.ConnectionType:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "ConnectionType", "")
			loadElement.fromPart:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "fromPart", "")
			loadElement.ToPart:=RIni_GetKeyValue("ClipboardLoadFile", tempSection, "ToPart", "")
			
		}
		
		
	}
	
	;Assign the correct elements to the connections
	for index, tempConnectionID in tempClipboardconnectionList
	{
		tempConnection:=allConnections[tempConnectionID]
		for tempID, tempElement in allelements
		{
			if (tempConnection.to=tempElement.OldID)
			{
				tempConnection.to:=tempElement.id
			}
			if (tempConnection.from=tempElement.OldID)
			{
				tempConnection.from:=tempElement.id
			}
		}
	}
	
	for tempID, tempElement in allelements ;remove the oldIDs otherwise it will cause errors on next paste
	{
		tempElement.delete("oldID")
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
	RIni_Shutdown("ClipboardLoadFile")
	maingui.enable()
	
	ui_draw()

	busy:=false
}

