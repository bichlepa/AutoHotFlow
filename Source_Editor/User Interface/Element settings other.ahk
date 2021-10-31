

; disable element settings GUI
; Called, when some additional functions are used, e.g. get window informations
ui_disableElementSettingsWindow()
{
	global
	
	gui, GUISettingsOfElement: +disabled
}

; enable element settings GUI
ui_EnableElementSettingsWindow()
{
	global
	gui, GUISettingsOfElement: -disabled
}

; get the position of the element settings GUI
ui_GetElementSettingsGUIPos()
{
	global 
	WinGetPos, ElementSettingsGUIX, ElementSettingsGUIY, ElementSettingsGUIWidth, ElementSettingsGUIHeight, % "ahk_id " global_SettingWindowParentHWND
}

; opens a gui where user can select the element class
class ElementSettingsElementClassSelector
{
	open(p_ElementID)
	{
		global
		local forelementIndex, forElementClass, tempElementCategories, forindex, forcategory, tempOneCategory, tempcategoryTV, tempTV
		
		; save some information about the element which we will need repeadetely
		this.elementID := p_ElementID
		this.elementType := _getElementProperty(_FlowID, this.elementID, "type")
		this.elementClass := _getElementProperty(_FlowID, this.elementID, "Class")
		this.elementName := _getElementProperty(_FlowID, this.elementID, "Name")
		this.elementPars := _getElementProperty(_FlowID, this.elementID, "pars")

		; disable editor gui
		EditGUIDisable()

		; create gui with a treeview and two buttons
		gui, ElementClassSelector: default
		gui, destroy
		gui, -dpiscale
		gui, font, s12
		gui, add, text, , % lang("Which %1% should be created?", lang(this.elementType))
		gui, add, TreeView, w400 h500 vElementClassSelectorChoose gElementClassSelectorChoose AltSubmit
		gui, add, Button, w250 gElementClassSelectorOK vElementClassSelectorOK default Disabled, % lang("OK")
		gui, add, Button, w140 X+10 yp gElementClassSelectorCancel,% lang("Cancel")
		gui, +hwndglobal_SettingWindowHWND
		global_CurrentlyActiveWindowHWND := global_SettingWindowHWND
		
		; prepare variables which will contain element data for each TV ID
		this.TVelementIndex := Object()
		this.TVelementID := Object()
		this.TVelementClass := Object()
		
		AllElementClassInfos := _getShared("AllElementClassInfos")
		
		; Find all matching element classes and create a list of categories
		local matchingElementClasses := Object()
		local allCategories := Object()
		; loop through all element classes
		for forelementIndex, forElementClass in _getShared("AllElementClasses")
		{
			; check element type
			if (AllElementClassInfos[forElementClass].type = this.elementType)
			{
				; check required user experience level of this element. Always the selected element regardless of its required level
				if (ShouldShowThatelementLevel(Element_getElementLevel_%forElementClass%())
					OR this.elementClass = forElementClass)
				{
					; add the element class to the list
					matchingElementClasses.push(forElementClass)

					; add all categories of that element class to the list
					tempElementCategories := Element_getCategory_%forElementClass%()
					if (not tempElementCategories)
					{
						throw exception("Internal Error: No category defined in element class " forElementClass)
					}

					; there can be multiple categories which are separated by pipes
					loop, parse, tempElementCategories, |
					{
						if not (objhasvalue(allCategories, A_LoopField))
						{
							allCategories.push(A_LoopField)
						}
					}
				}
			}
		}
		
		if (not matchingElementClasses.MaxIndex() > 0)
		{
			throw exception("Internal Error: No matching elements classes found of type: " this.elementType)
		}
		if (not allCategories.MaxIndex() > 0)
		{
			throw exception("Internal Error: No matching elements categories found of type: " this.elementType)
		}
		
		; add all categories to the treeview
		categoryTVs := object()
		for forindex, forcategory in allCategories 
		{
			categoryTVs.push(TV_Add(forcategory))
		}
		
		; add all elements to the treeview
		for forelementIndex, forElementClass in matchingElementClasses
		{
			; loop through all categories of the element
			tempElementCategories := Element_getCategory_%forElementClass%()
			loop, parse, tempElementCategories, |
			{
				tempOneCategory := A_LoopField

				; get the category TV ID
				for forindex, forcategory in allCategories
				{
					if (tempOneCategory = forcategory)
						tempcategoryTV := categoryTVs[forindex]
				}

				; add the element class to the category in TV
				tempTV := TV_Add(Element_getName_%forElementClass%(), tempcategoryTV)

				; save informations about the just created TV ID
				this.TVelementIndex[tempTV] := forelementIndex
				this.TVelementID[tempTV] := this.elementID
				this.TVelementClass[tempTV] := forElementClass

				; If current element has already a class, select it
				if (this.elementClass = forElementClass) 
					TV_Modify(tempTV)
			}
		}
		
		; Calculate gui position. We want to show the settings window in the middle of the main window
		gui, show, hide
		local pos := EditGUIGetPos()
		DetectHiddenWindows, on
		local tempWidth, tempHeight
		wingetpos, , , tempWidth, tempHeight, ahk_id %global_SettingWindowHWND%
		local tempXpos := round(pos.x + pos.w / 2 - tempWidth / 2)
		local tempYpos := round(pos.y + pos.h / 2 - tempHeight / 2)

		; move gui to the calculated position
		gui, show, x%tempXpos% y%tempYpos%
		
		; We have to wait until user closes the window
		; Wait until this.result is set
		this.result := ""
		Loop
		{
			if (this.result = "")
				sleep 10
			else 
			{
				return this.result
			}
		}
	}

	; react if user chooses something
	ElementClassSelectorChoose()
	{
		global
		local GuiElementChoosedTV

		if (A_GuiEvent = "DoubleClick")
		{
			; apply selection and close window on double click
			ElementSettingsElementClassSelector.ElementClassSelectorOK()
			return
		}

		; get selected TV element
		gui, ElementClassSelector: default
		GuiElementChoosedTV := TV_GetSelection()
		
		; enable button "ok" if a class is selected
		if (this.TVelementIndex[GuiElementChoosedTV] > 0)
			GuiControl, enable, ElementClassSelectorOK
		else
			GuiControl, disable, ElementClassSelectorOK
	}

	; react if user clicks on cancel button
	ElementClassSelectorCancel()
	{
		; destroy gui and enable editor gui
		gui, ElementClassSelector: default
		gui, destroy
		EditGUIEnable()

		; set result
		this.result := "aborted"
	}

	; react if user clicks on OK button
	ElementClassSelectorOK()
	{
		global
		local GuiElementChoosedTV, GuiElementChoosedID

		; get selected TV element
		gui, ElementClassSelector: default
		GuiElementChoosedTV := TV_GetSelection()
		GuiElementChoosedClass := this.TVelementClass[GuiElementChoosedTV]

		; return if nothing chose. This can happen if user makes a double click on a category
		if not GuiElementChoosedClass
			return
		
		; destroy gui and enable editor gui
		gui,destroy
		EditGUIEnable()

		; set element class
		Element_SetClass(_FlowID, this.elementID, GuiElementChoosedClass)

		; set result to selected element class
		this.result := GuiElementChoosedClass
	}
}

; forward some glabel calls
ElementClassSelectorChoose()
{
	ElementSettingsElementClassSelector.ElementClassSelectorChoose()
}
ElementClassSelectorguiclose()
{
	ElementSettingsElementClassSelector.ElementClassSelectorCancel()
}
ElementClassSelectorCancel()
{
	ElementSettingsElementClassSelector.ElementClassSelectorCancel()
}
ElementClassSelectorOK()
{
	ElementSettingsElementClassSelector.ElementClassSelectorOK()
}


; opens a gui where user can select the connection type
class ElementSettingsConnectionTypeSelector
{
	open(p_connectionID)
	{
		global 
		
		; save some information about the connection which we will need repeadetely
		this.connectionID := p_connectionID

		; get some further information about the connection
		local setConnectionType := _getConnectionProperty(_FlowID, this.connectionID, "connectionType")
		local setConnectionFrom := _getConnectionProperty(_FlowID, this.connectionID, "from")
		local setConnectionFromType := _getElementProperty(_FlowID, setconnectionFrom, "type")
		
		; disable editor gui
		EditGUIDisable()

		; create gui
		gui, ConnectionTypeSelector: default
		gui, font, s12
		gui, add, text, , % lang("Select connection type")
			
		; depending on the element type from which the connection starts, we need different buttons
		if (setconnectionFromType = "Condition")
		{
			; we have a condition. Add the buttons "exception", "no" and "yes"
			gui, add, Button, w100 h50 gConnectionTypeSelectorButton vConnectionTypeSelectorButtonYes default, % lang("Yes")
			gui, add, Button, w100 h50 X+10 gConnectionTypeSelectorButton vConnectionTypeSelectorButtonNo, % lang("No")
			gui, add, Button, w100 h50 X+10 gConnectionTypeSelectorButton vConnectionTypeSelectorButtonException, % lang("Exception")
			
			; if connection type is set, set the corresponding button as default. Otherwise keep "yes" as default
			if (setConnectionType = "exception")
			{
				guicontrol, +default, ConnectionTypeSelectorButtonException
			}
			else if (setConnectionType = "no")
			{
				guicontrol, +default, ConnectionTypeSelectorButtonNo
			}
		}
		else
		{
			; we have anything else. Add the buttons "exception", "normal"
			gui, add, Button, w100 h50 gConnectionTypeSelectorButton vConnectionTypeSelectorButtonNormal default, % lang("Normal")
			gui, add, Button, w100 h50 X+10 gConnectionTypeSelectorButton vConnectionTypeSelectorButtonException, % lang("Exception")
			
			; if connection type is set, set the corresponding button as default. Otherwise keep "normal" as default
			if (setConnectionType = "exception")
			{
				guicontrol, +default, ConnectionTypeSelectorButtonException
			}
		}
		
		; add a cancel button
		gui, add, Button, w90 Y+10 gConnectionTypeSelectorButtonCancel, % lang("Cancel")

		gui, +hwndglobal_SettingWindowHWND
		global_CurrentlyActiveWindowHWND := global_SettingWindowHWND

		; Calculate gui position. We want to show the settings window in the middle of the main window
		gui, show, hide
		local pos := EditGUIGetPos()
		DetectHiddenWindows, on
		local tempWidth, tempHeight
		wingetpos, , , tempWidth, tempHeight, ahk_id %global_SettingWindowHWND%
		local tempXpos := round(pos.x + pos.w / 2 - tempWidth / 2)
		local tempYpos := round(pos.y + pos.h / 2 - tempHeight / 2)
		
		; move gui to the calculated position
		gui, show, x%tempXpos% y%tempYpos%
		
		; We have to wait until user closes the window
		; Wait until this.result is set
		this.result := ""
		Loop
		{
			if (this.result = "")
				sleep 10
			else 
			{
				return this.result
			}
		}
	}
	
	; react if user chooses a connection type
	ConnectionTypeSelectorButton()
	{
		; get the result from the button ID
		StringReplace, result, A_GuiControl, ConnectionTypeSelectorButton

		; set connection type
		_setConnectionProperty(_FlowID, this.connectionID, "ConnectionType", result)

		; destroy gui and enable editor gui
		gui,destroy
		EditGUIEnable()

		; set result to the connection type
		this.result := result
	}

	; react if user cancels
	ConnectionTypeSelectorCancel()
	{
		; destroy gui and enable editor gui
		gui,destroy
		EditGUIEnable()
		
		; set result
		this.result:="aborted"
	}
}

; forward some glabel calls
ConnectionTypeSelectorButton()
{
	ElementSettingsConnectionTypeSelector.ConnectionTypeSelectorButton()
}
ConnectionTypeSelectorguiclose()
{
	ElementSettingsConnectionTypeSelector.ConnectionTypeSelectorCancel()
}
ConnectionTypeSelectorButtonCancel()
{
	ElementSettingsConnectionTypeSelector.ConnectionTypeSelectorCancel()
}


; opens a gui where user can select the element container type
class ElementSettingsContainerTypeSelector
{
	open(p_ElementID)
	{
		global

		; save some information about the connection which we will need repeadetely
		this.elementID := p_ElementID

		; get some further information about the element
		setElementType := _getElementProperty(_FlowID, this.elementID, "type")

		; disable editor gui
		EditGUIDisable()
		
		; create gui
		gui, ContainerTypeSelector: default
		gui, font ,s12
		gui, add, text, , % lang("Select_element_type")
			
		; add the buttons
		gui, add, Button, w100 h50 gContainerTypeSelectorButton vContainerTypeSelectorButtonAction default, % lang("Action")
		gui, add, Button, w100 h50 X+10 gContainerTypeSelectorButton vContainerTypeSelectorButtonCondition, % lang("Condition")
		gui, add, Button, w100 h50 X+10 gContainerTypeSelectorButton vContainerTypeSelectorButtonLoop ,% lang("Loop")

		; if element container type is set, set the corresponding button as default. Otherwise keep "Action" as default
		if (setElementType = "Condition")
		{
			guicontrol, +default, ContainerTypeSelectorButtonCondition
		}
		if (setElementType = "Loop")
		{
			guicontrol, +default, ContainerTypeSelectorButtonLoop
		}
		
		; add a cancel button
		gui,add,Button,w90  Y+10 gContainerTypeSelectorButtonCancel,% lang("Cancel")

		gui, +hwndglobal_SettingWindowHWND
		global_CurrentlyActiveWindowHWND := global_SettingWindowHWND

		; Calculate gui position. We want to show the settings window in the middle of the main window
		gui, show, hide
		local pos := EditGUIGetPos()
		DetectHiddenWindows, on
		local tempWidth, tempHeight
		wingetpos, , , tempWidth, tempHeight, ahk_id %global_SettingWindowHWND%
		local tempXpos := round(pos.x + pos.w / 2 - tempWidth / 2)
		local tempYpos := round(pos.y + pos.h / 2 - tempHeight / 2)
		
		; move gui to the calculated position
		gui, show, x%tempXpos% y%tempYpos%
		
		this.result := ""
		Loop
		{
			if (this.result = "")
				sleep 10
			else 
			{
				return this.result
			}
		}
	}
		
	; react if user chooses a element container type
	ContainerTypeSelectorButton()
	{
		; get the result from the button ID
		StringReplace, result, A_GuiControl, ContainerTypeSelectorButton

		; set connection type
		Element_SetType(_FlowID, this.elementID, result)

		; destroy gui and enable editor gui
		gui,destroy
		EditGUIEnable()

		; set result to the connection type
		this.result := result
	}

	; react if user cancels
	ContainerTypeSelectorCancel()
	{
		; destroy gui and enable editor gui
		gui,destroy
		EditGUIEnable()
		
		; set result
		this.result:="aborted"
	}
}

; forward some glabel calls
ContainerTypeSelectorButton()
{
	ElementSettingsContainerTypeSelector.ContainerTypeSelectorButton()
}
ContainerTypeSelectorguiclose()
{
	ElementSettingsContainerTypeSelector.ContainerTypeSelectorCancel()
}
ContainerTypeSelectorButtonCancel()
{
	ElementSettingsContainerTypeSelector.ContainerTypeSelectorCancel()
}


; returns whether something should be shown to the user depending on its required user experience level
; if elementlevel is empty or invalid, it defaults to "beginner"
ShouldShowThatElementLevel(elementlevel)
{
	; convert level from settings to number
	if (_settings.ShowElementsLevel = "Beginner")
	{
		scoreFromSettings := 1
	}
	else if (_settings.ShowElementsLevel = "Advanced")
	{
		scoreFromSettings := 2
	}
	else if (_settings.ShowElementsLevel = "Programmer")
	{
		scoreFromSettings := 3
	}
	
	; convert level from elementlevel to number
	if (elementlevel = "Beginner")
	{
		score := 1
	}
	else if (elementlevel = "Advanced")
	{
		score := 2
	}
	else if (elementlevel = "Programmer")
	{
		score := 3
	}

	; compare numbers
	if (scoreFromSettings >= score)
		return True
	else
		return False
}

