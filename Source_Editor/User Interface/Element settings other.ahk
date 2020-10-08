﻿

; disable element settings GUI
; Called, when some additional functions are used, e.g. get window informations
ui_disableElementSettingsWindow()
{
	global
	
	gui,GUISettingsOfElement:+disabled
}

; enable element settings GUI
ui_EnableElementSettingsWindow()
{
	global
	gui,GUISettingsOfElement:-disabled
}

; get the position of the element settings GUI
ui_GetElementSettingsGUIPos()
{
	global 
	WinGetPos, ElementSettingsGUIX, ElementSettingsGUIY, ElementSettingsGUIWidth, ElementSettingsGUIHeight, % "ahk_id " global_SettingWindowParentHWND
}

;Select element subtype
selectSubType(p_ElementID, wait = false)
{
	global
	static global_resultEditingElement
	
	;~ d(setelement)
	global_setElementID:=p_ElementID
	global_setElementType:= _getElementProperty(FlowID, global_setElementID, "type")
	global_setElementClass:= _getElementProperty(FlowID, global_setElementID, "Class")
	global_setElementName:= _getElementProperty(FlowID, global_setElementID, "Name")
	global_setElementPars:= _getElementProperty(FlowID, global_setElementID, "pars")

	local matchingElementClasses:=Object()
	local allCategories:=Object()
	local tempcategory
	
	global_resultEditingElement:=""
	
	
	EditGUIDisable()
	gui,3:default
	
	gui,destroy
	gui,-dpiscale
	gui,font,s12
	gui,add,text,,% lang("Which %1% should be created?", lang(global_setElementType))
	gui,add,TreeView,w400 h500 vGuiElementChoose gGuiElementChoose AltSubmit
	gui,add,Button,w250 gGuiElementChooseOK vGuiElementChooseOK default Disabled,% lang("OK")
	gui,add,Button,w140 X+10 yp gGuiElementChooseCancel,% lang("Cancel")
	
	TVnum:=Object()
	TVID:=Object()
	TVSubType:=Object()
	TVClass:=Object()
	
	;Find out wich categories exist
	for forelementIndex, forElementClass in _getShared("AllElementClasses")
	{
		if (Element_getElementType_%forElementClass%() = global_setElementType)
		{
			if (ShouldShowThatelementLevel(IsFunc("Element_getElementLevel_" forElementClass) ? Element_getElementLevel_%forElementClass%() : "Beginner")
				OR global_setElementClass = forElementClass)
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
		MsgBox,Internal Error: No elements found of type: %global_setElementType%
	
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
				OR global_setElementClass = forElementClass)
			{
				tempTV:=TV_Add(Element_getName_%forElementClass%(),tempcategoryTV)
				TVnum[tempTV]:=forelementIndex
				TVID[tempTV]:=global_setElementID
				TVClass[tempTV]:=forElementClass
				if (global_setElementClass=forElementClass) ;Select the current element type, if any
					TV_Modify(tempTV) 
			}
		}
		
	}
	
	
	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	global_CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	;~ d(TVnum)
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait)
	{
		Loop
		{
			if (global_resultEditingElement="")
				sleep 10
			else 
			{
				if (global_resultEditingElement!="aborted")
				{
					_setElementProperty(FlowID, ElementID, "subtype", global_resultEditingElement)
					; setElement.setUnsetDefaults() TODO: Did I forget this function on last refactoring?
				}
				break
			}
		}
		
		EditGUIEnable()
	}
	
	;~ MsgBox
	return global_resultEditingElement

	3guiclose:
	GuiElementChooseCancel:
	gui,3:default
	gui,destroy
	if (global_setElementClass="" and global_setElementType!="Trigger")
	{
		Element_Remove(FlowID, global_setElementId)
		;~ API_Draw_Draw(FlowID)
	}
	global_resultEditingElement=aborted
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
	
	Element_SetClass(FlowID,global_setElementID,TVClass[GuiElementChoosedTV])

	
	
	global_resultEditingElement:=TVClass[GuiElementChoosedTV]
	
	EditGUIEnable()
	
	return 
	
}




;Select connection type
selectConnectionType(p_ElementID, wait = false)
{
	global 
	static global_resultEditingElement, temp_from, ConnectionType
	
	global_resultEditingElement:=""
	
	global_setElementID:=p_ElementID
	global_setElementType:= _getConnectionProperty(FlowID, global_setElementID, "type")
	setElementFrom:= _getConnectionProperty(FlowID, global_setElementID, "from")
	setElementFromType:= _getElementProperty(FlowID, setElementFrom, "type")
	
	EditGUIDisable()
	gui, 7:default
	gui,font,s12
	gui,add,text,,% lang("Select_Connection_type")
		
	
	if (setElementFromType="Condition")
	{
		if (global_setElementType="exception")
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseTrue vGuiConnectionChooseTrue ,% lang("Yes")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseFalse vGuiConnectionChooseFalse,% lang("No")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException default,% lang("Exception")
		}
		else if (global_setElementType="no")
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
		if (global_setElementType="exception")
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
	global_CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	;~ d(pos, tempWidth "-" tempHeight "-" tempXpos "-" tempYpos "#" SettingsHWND)
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait)
	{
		Loop
		{
			if (global_resultEditingElement="")
				sleep 10
			else 
			{
				if (global_resultEditingElement!="aborted")
				{
					_setConnectionProperty(FlowID, global_setElementID, "ConnectionType", global_resultEditingElement)
				}
				break
			}
		}
	}
	return global_resultEditingElement
	
	
	7guiclose:
	GuiConnectionChooseCancel:
	gui,destroy
	EditGUIEnable()
	global_resultEditingElement:="aborted"
	return 
	
	GuiConnectionChooseTrue:
	gui,destroy
	EditGUIEnable()
	global_resultEditingElement:="yes"
	_setConnectionProperty(FlowID, global_setElementID, "ConnectionType", global_resultEditingElement)
	return
	
	GuiConnectionChooseFalse:
	gui,destroy
	EditGUIEnable()
	global_resultEditingElement:="no"
	_setConnectionProperty(FlowID, global_setElementID, "ConnectionType", global_resultEditingElement)
	return 
	
	GuiConnectionChooseException:
	gui,destroy
	EditGUIEnable()
	global_resultEditingElement:="exception"
	_setConnectionProperty(FlowID, global_setElementID, "ConnectionType", global_resultEditingElement)
	return 
	
	GuiConnectionChooseNormal:
	gui,destroy
	EditGUIEnable()
	global_resultEditingElement:="normal"
	_setConnectionProperty(FlowID, global_setElementID, "ConnectionType", global_resultEditingElement)
	return 
	
	
}

;Select container type
selectContainerType(p_ElementID, wait = false)
{
	global 
	static global_resultEditingElement
	global_resultEditingElement:=""
	global_setElementID:=p_ElementID
	global_setElementType:= _getElementProperty(FlowID, global_setElementID, "type")
	EditGUIDisable()
	gui, 8:default
	

	gui,font,s12
	gui,add,text,,% lang("Select_element_type")
		
	
	if (global_setElementType="Action" or global_setElementType="")
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
	global_CurrentlyActiveWindowHWND:=SettingsHWND
	gui,show,hide
	pos:=EditGUIGetPos()
	DetectHiddenWindows,on
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
	tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
	
	gui,show,x%tempXpos% y%tempYpos%
	
	if (wait)
	{
		Loop
		{
			if (global_resultEditingElement="")
				sleep 10
			else 
			{
				if (global_resultEditingElement!="aborted")
					Element_SetType(FlowID, global_setElementID,global_resultEditingElement)
				break
			}
		}
	}
	
	return global_resultEditingElement
	
	
	8guiclose:
	GuiElementTypeChooseCancel:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	global_resultEditingElement:="aborted"
	return 
	
	GuiElementTypeChooseAction:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	global_resultEditingElement:="action"
	return
	
	GuiElementTypeChooseCondition:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	global_resultEditingElement:="condition"
	return
	
	GuiElementTypeChooseLoop:
	gui,destroy
	EditGUIEnable()
	gui,MainGUI:default
	global_resultEditingElement:="loop"
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

