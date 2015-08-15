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
	
	if (busy=true)
		return
	
	busy:=true
	ui_disablemaingui()
	
	
	ClipboardFlowFilename=%A_ScriptDir%\Clipboard.ini
	
	logger("a2","Loading elements from clipboard")
	ToolTip(lang("loading from clipboard"),100000)
	tempClipboardconnectionList:=Object()
	markelement()  ;Unmark all elements
	
	;Find mouse position and find out whether the mouse is hovering the editor
	MouseGetPos,TempMouseX,TempMouseY,tempWin,TempControl,2
	
	;MsgBox % tempWin "`n" MainGuihwnd "`n" TempControl "`n" PicFlowHWND
	If (tempWin= MainGuihwnd and TempControl=PicFlowHWND)
	{
		tempPosUnderMouseX:=((TempMouseX)/zoomfactor)+offsetx
		tempPosUnderMouseY:=((TempMouseY)/zoomfactor)+offsety
	}
		
	
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
			
			Iniread,tempClipboardconnection%loadElementID%fromPart,%ClipboardFlowFilename%,element%index1%,fromPart,%A_Space%
			Iniread,tempClipboardconnection%loadElementID%ToPart,%ClipboardFlowFilename%,element%index1%,toPart,%A_Space%
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
			else if (loadElementType="loop")
				tempNewID:=e_NewLoop()
			;allElements.insert(tempNewID)
			tempClipboardMap%loadElementID%:=tempNewID ;Needed to realize connections later
			markelement(tempNewID,"true")
			%tempNewID%running=0
			
			
			Iniread,loadElementname,%ClipboardFlowFilename%,element%index1%,name
			StringReplace, loadElementname, loadElementname, |¶,`n, All
			
			Iniread,loadElementX,%ClipboardFlowFilename%,element%index1%,x
			Iniread,loadElementY,%ClipboardFlowFilename%,element%index1%,y
			
			if (tempOffsetAlreadySet!=true)
			{
				if tempPosUnderMouseX
				{
					tempOffsetX:=ui_FitGridX(tempPosUnderMouseX-loadElementX -0.5*ElementWidth) 
					tempOffsetY:=ui_FitGridY(tempPosUnderMouseY-loadElementY - 0.5* ElementHeight)
				}
				else
				{
					Loop
					{
						tempfound:=false
						tempX:=ui_FitGridX(loadElementX+ElementWidth*0.25*A_Index)
						tempY:=ui_FitGridY(loadElementY+ElementWidth*0.25*A_Index)
						for SaveIndex1, saveElementID in allElements
						{
							if (tempX=%saveElementID%x and tempY=%saveElementID%y)
							{
								tempfound:=true
								break
							}
						}
						if (tempfound=false)
						{
							tempOffsetX:=ElementWidth*0.25*A_Index
							tempOffsetY:=ElementWidth*0.25*A_Index
							break
						}
					}
					
				}
				tempOffsetAlreadySet:=true
			}
			
			%tempNewID%Name=%loadElementname%
			%tempNewID%x:=ui_FitGridX(loadElementX+tempOffsetX) 
			%tempNewID%y:=ui_FitGridY(loadElementY+tempOffsetY) 
			
			
			Iniread,loadElementsubType,%ClipboardFlowFilename%,element%index1%,subType
			%tempNewID%subType=%loadElementsubType%
			
			if (loadElementType="loop")
			{
				Iniread,loadElementHeightOfVerticalBar,%ClipboardFlowFilename%,element%index1%,HeightOfVerticalBar
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
		
		
		tempConn:=e_newConnection(tempClipboardMap%tempFrom%,tempClipboardMap%tempTo%,tempClipboardconnection%LoadElementID%ConnectionType)
		
		if tempClipboardconnection%loadElementID%fromPart!=
			%tempConn%fromPart:=tempClipboardconnection%loadElementID%fromPart
		if tempClipboardconnection%loadElementID%toPart!=
			%tempConn%toPart:=tempClipboardconnection%loadElementID%toPart
	}
	index1--
	if index1>0
	{
		saved=no
		ToolTip(lang("Loaded %1% elements from clipboard",index1),1000)
		logger("a2","Loaded " index1 " elements from clipboard")
	}
	else
	{
		ToolTip(lang("No elements found in clipboard"),1000)
		logger("a2","No elements found in clipboard")
	}
	

	e_UpdateTriggerName()
	e_CorrectElementErrors("Loaded from clipboard")
	
	ui_EnableMainGUI()
	
	ui_draw()

	busy:=false
}

