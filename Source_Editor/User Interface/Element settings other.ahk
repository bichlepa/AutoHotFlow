
/* prototypes
selectContainerType(parelement, "wait")
selectConnectionType(parelement,"wait")
selectSubType(parElement,"wait")
ElementSettings.open(newElement,"wait")
selectTrigger(parelement, "wait")
*/











;Called, when some additional functions are used, e.g. get window informations
ui_disableElementSettingsWindow()
{
	global
	
	gui,SettingsOfElement:+disabled
}

ui_EnableElementSettingsWindow()
{
	global
	
	gui,SettingsOfElement:-disabled
	WinActivate,% "·AutoHotFlow· " lang("Settings")
}

ui_GetElementSettingsGUIPos()
{
	global 
	WinGetPos,ElementSettingsGUIX,ElementSettingsGUIY,ElementSettingsGUIWidth,ElementSettingsGUIHeight,% "ahk_id " _share.hwnds["ElementSettingsParent" Flowobj.ID]
}

;Select element subtype
selectSubType(p_ElementID,wait="")
{
	global
	static NowResultEditingElement
	setElementID:=p_ElementID
	if isobject(flowObj.allElements[setElementID])
		setElement:=flowObj.allElements[setElementID]
	else if isobject(flowObj.allTriggers[setElementID])
		setElement:=flowObj.allTriggers[setElementID]
	else
		MsgBox Internal Error in selectSubType()! `n The element was not found
	;~ d(setelement)
	setElementType:=setElement.type 
	local matchingElementClasses:=Object()
	local allCategories:=Object()
	local tempcategory
	;~ d(setElement, p_ID)
	NowResultEditingElement:=""
	
	;~ d(_share.AllElementClasses)
	
	EditGUIDisable()
	gui,3:default
	
	gui,destroy
	gui,-dpiscale
	gui,font,s12
	gui,add,text,,% lang("Which %1% should be created?", lang(setElementType))
	gui,add,TreeView,w400 h500 vGuiElementChoose gGuiElementChoose AltSubmit
	gui,add,Button,w250 gGuiElementChooseOK vGuiElementChooseOK default Disabled,% lang("OK")
	gui,add,Button,w140 X+10 yp gGuiElementChooseCancel,% lang("Cancel")
	
	TVnum:=Object()
	TVID:=Object()
	TVSubType:=Object()
	TVClass:=Object()
	
	;Find out wich categories exist
	for forelementIndex, forElementClass in _share.AllElementClasses
	{
		if (Element_getElementType_%forElementClass%() = setElementType)
		{
			if (ShouldShowThatelementLevel(IsFunc("Element_getElementLevel_" forElementClass) ? Element_getElementLevel_%forElementClass%() : "Beginner")
				OR setElement.class = forElementClass)
			{
				matchingElementClasses.push(forElementClass)
				tempcategory:=Element_getCategory_%forElementClass%()
				
				StringSplit,tempcategory,tempcategory,|
				;MsgBox %tempElementCategory1%
				loop %tempcategory0%
				{
					if not (objhasvalue(allCategories,tempcategory%a_index%))
						allCategories.push(tempcategory%a_index%)
				}
			}
		}
	}
	
	;add all categories to the treeview
	for forindex, forcategory in allCategories 
	{
		tempcategoryTV%forindex%:=TV_Add(forcategory)
	}
	if not (matchingElementClasses.MaxIndex()>0)
		MsgBox,Internal Error: No elements found of type: %setElementType%
	
	;add all elements to the treeview
	for forelementIndex, forElementClass in matchingElementClasses
	{
		tempcategory:=Element_getCategory_%forElementClass%()
		;MsgBox %tempElementCategory%
		StringSplit,tempcategory,tempcategory,|
		;MsgBox %tempElementCategory1%
		loop %tempcategory0%
		{
			;MsgBox %tempElementCategory1%
			tempAnCategory:=tempcategory%A_Index%
			for forindex, forcategory in allCategories
			{
				if (tempAnCategory = forcategory)
					tempcategoryTV:=tempcategoryTV%forindex%
			}
			if (ShouldShowThatelementLevel(IsFunc("Element_getElementLevel_" forElementClass) ? Element_getElementLevel_%forElementClass%() : "Beginner")
				OR setElement.class = forElementClass)
			{
				tempTV:=TV_Add(Element_getName_%forElementClass%(),tempcategoryTV)
				TVnum[tempTV]:=forelementIndex
				TVID[tempTV]:=setElementID
				TVClass[tempTV]:=forElementClass
				if (setElement.class=forElementClass) ;Select the current element type, if any
					TV_Modify(tempTV) 
			}
		}
		
	}
	
	
	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	;~ d(TVnum)
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait=1 or wait="wait")
	{
		Loop
		{
			if (NowResultEditingElement="")
				sleep 100
			else 
			{
				if (NowResultEditingElement!="aborted")
				{
					setElement.subtype:=NowResultEditingElement
					setElement.setUnsetDefaults()
				}
				break
			}
		}
		
		EditGUIEnable()
	}
	
	;~ MsgBox
	return NowResultEditingElement

	3guiclose:
	GuiElementChooseCancel:
	gui,3:default
	gui,destroy
	if (setElement.class="" and setElement.Type!="Trigger")
	{
		;~ d(setelement)
		Element_Remove(FlowID, setElement.id)
		;~ API_Draw_Draw()
	}
	NowResultEditingElement=aborted
	EditGUIEnable()
	return
	GuiElementChoose:
	gui,3:default
	if A_GuiEvent =DoubleClick 
		goto GuiElementChooseOK
	GuiElementChoosedTV:=TV_GetSelection()
	;~ ToolTip %GuiElementChoosedTV%
	gui,submit,nohide
	if TVnum[GuiElementChoosedTV]>0	
		GuiControl,enable,GuiElementChooseOK
	else
		GuiControl,disable,GuiElementChooseOK
	
	return
	GuiElementChooseOK:
	
	gui,3:default
	gui,Submit,nohide
	GuiElementChoosedTV:=TV_GetSelection()
	TV_GetText(GuiElementChoosedText, TV_GetSelection())
	GuiElementChoosedID:=TVID[GuiElementChoosedTV]
	if GuiElementChoosedID=
		return
	gui,destroy
	EditGUIEnable()
	
	Element_SetClass(FlowID,setElementID,TVClass[GuiElementChoosedTV])

	
	;MsgBox,%setElementID% %GuiElementChoose%
	
	
	NowResultEditingElement:=TVClass[GuiElementChoosedTV]
	
	;~ MsgBox %setElementID%
	EditGUIEnable()
	;~ ElementSettings.open(setElementID,wait)
	
	return 
	
}




;Select connection type
selectConnectionType(p_ElementID,wait="")
{
	global 
	static NowResultEditingElement, setElement, temp_from, ConnectionType
	
	NowResultEditingElement:=""
	
	setElementID:=p_ElementID
	setElement:=flowObj.allConnections[setElementID]
	temp_from:=flowObj.allelements[setElement.from]
	ConnectionType:=setElement.Type
	
	
	EditGUIDisable()
	gui, 7:default
	gui,font,s12
	gui,add,text,,% lang("Select_Connection_type")
		
	
	if (temp_from.type="Condition")
	{
		if (setElement.Type="exception")
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseTrue vGuiConnectionChooseTrue ,% lang("Yes")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseFalse vGuiConnectionChooseFalse,% lang("No")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException default,% lang("Exception")
		}
		else if (setElement.Type="no")
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseTrue vGuiConnectionChooseTrue ,% lang("Yes")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseFalse vGuiConnectionChooseFalse default,% lang("No")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException ,% lang("Exception")
		}
		else
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseTrue vGuiConnectionChooseTrue default,% lang("Yes")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseFalse vGuiConnectionChooseFalse,% lang("No")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException ,% lang("Exception")
		}
		
		
		
		
	}
	else
	{
		if (setElement.Type="exception")
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseNormal vGuiConnectionChooseNormal,% lang("Normal")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException default,% lang("Exception")
		}
		else
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseNormal vGuiConnectionChooseNormal default,% lang("Normal")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException ,% lang("Exception")
		}
		

		
	}
	
	gui,add,Button,w90 Y+10 gGuiConnectionChooseCancel,% lang("Cancel")
	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	;~ d(pos, tempWidth "-" tempHeight "-" tempXpos "-" tempYpos "#" SettingsHWND)
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait=1 or wait="wait")
	{
		Loop
		{
			if (NowResultEditingElement="")
				sleep 100
			else 
			{
				if (NowResultEditingElement!="aborted")
					setElement.ConnectionType:=NowResultEditingElement
				break
			}
		}
	}
	return NowResultEditingElement
	
	
	7guiclose:
	GuiConnectionChooseCancel:
	gui,destroy
	EditGUIEnable()
	NowResultEditingElement:="aborted"
	return 
	
	GuiConnectionChooseTrue:
	gui,destroy
	EditGUIEnable()
	NowResultEditingElement:="yes"
	setElement.ConnectionType:=NowResultEditingElement
	return
	
	GuiConnectionChooseFalse:
	gui,destroy
	EditGUIEnable()
	NowResultEditingElement:="no"
	setElement.ConnectionType:=NowResultEditingElement
	return 
	
	GuiConnectionChooseException:
	gui,destroy
	EditGUIEnable()
	NowResultEditingElement:="exception"
	setElement.ConnectionType:=NowResultEditingElement
	return 
	
	GuiConnectionChooseNormal:
	gui,destroy
	EditGUIEnable()
	NowResultEditingElement:="normal"
	setElement.ConnectionType:=NowResultEditingElement
	return 
	
	
}

;Select container type
selectContainerType(p_ElementID, wait="")
{
	global 
	static NowResultEditingElement
	NowResultEditingElement:=""
	setElementID:=p_ElementID
	setElement:=flowObj.allElements[setElementID]
	EditGUIDisable()
	gui, 8:default
	

	gui,font,s12
	gui,add,text,,% lang("Select_element_type")
		
	
	if (setElement.type="Action" or setElement.type="")
	{
		gui,add,Button,w100 h50 gGuiElementTypeChooseAction gGuiElementTypeChooseAction default,% lang("Action")
		gui,add,Button,w100 h50 X+10 gGuiElementTypeChooseCondition gGuiElementTypeChooseCondition,% lang("Condition")
		gui,add,Button,w100 h50 X+10 gGuiElementTypeChooseLoop gGuiElementTypeChooseLoop,% lang("Loop")
		
	}
	else
	{
		gui,add,Button,w100 h50 gGuiElementTypeChooseAction gGuiElementTypeChooseAction ,% lang("Action")
		gui,add,Button,w100 h50 X+10  gGuiElementTypeChooseCondition gGuiElementTypeChooseCondition default,% lang("Condition")
		gui,add,Button,w100 h50 X+10 gGuiElementTypeChooseLoop gGuiElementTypeChooseLoop,% lang("Loop")

		
	}
	
	gui,add,Button,w90  Y+10 gGuiElementTypeChooseCancel,% lang("Cancel")
	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait=1 or wait="wait")
	{
		Loop
		{
			if (NowResultEditingElement="")
				sleep 100
			else 
			{
				if (NowResultEditingElement!="aborted")
					Element_SetType(FlowID,setElementID,NowResultEditingElement)
				break
			}
		}
	}
	
	return NowResultEditingElement
	
	
	8guiclose:
	GuiElementTypeChooseCancel:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	NowResultEditingElement:="aborted"
	return 
	
	GuiElementTypeChooseAction:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	NowResultEditingElement:="action"
	return
	
	GuiElementTypeChooseCondition:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	NowResultEditingElement:="condition"
	return
	
	GuiElementTypeChooseLoop:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	NowResultEditingElement:="loop"
	return 
	
	
	
	
}

ShouldShowThatElementLevel(elementlevel)
{
	if (_settings.ShowElementsLevel = "Beginner")
	{
		scoreFromSettings:=1
	}
	else if (_settings.ShowElementsLevel = "Advanced")
	{
		scoreFromSettings:=2
	}
	else if (_settings.ShowElementsLevel = "Programmer")
	{
		scoreFromSettings:=3
	}
	else if (_settings.ShowElementsLevel = "Custom")
	{
		;TODO
	}
	if (elementlevel = "Beginner")
	{
		score:=1
	}
	else if (elementlevel = "Advanced")
	{
		score:=2
	}
	else if (elementlevel = "Programmer")
	{
		score:=3
	}
	if (scoreFromSettings >=score)
		return True
	else
		return False
}

