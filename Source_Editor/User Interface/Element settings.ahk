;Needed translations which we will use indirectly. Those calls will make the lang crawler to add them to the translation list.
temp := lang("Trigger")
temp := lang("Action")
temp := lang("Condition")
temp := lang("Loop")

global global_SettingWindowParentHWND
global global_SettingWindowHWND

class ElementSettings
{
	; Open GUI for settings parameters of an element.
	; alreadyChangedSomething: if set, on return, the value will be added to the count of detected changes
	; returns "aborted" or "xx changes". xx is the count of detected changes.
	open(setElementID, alreadyChangedSomething = 0)
	{
		global
		local temp, tempYPos, tempXPos, tempEditwidth, tempIsDefault, tempAssigned, tempChecked, tempMakeNewGroup, temptoChoose, tempAltSumbit, tempChoises, tempAllChoices, tempParameterOptions, tempres, tempelement

		if not setElementID
		{
			throw exception("cannot open element settings. The element ID is empty", -1)
		}

		;will be incremented if a change will be detected
		this.changes := alreadyChangedSomething

		; save some information about the element which we will need repeadetely
		this.element := setElementID
		this.elementType := _getElementProperty(FlowID, this.element, "type")
		this.elementClass := _getElementProperty(FlowID, this.element, "Class")
		this.elementName := _getElementProperty(FlowID, this.element, "Name")
		this.elementPars := _getElementProperty(FlowID, this.element, "pars")

		if (not this.elementType)
		{
			throw exception("cannot open element settings. The element type of element ID '" setElementID "' is empty", -1)
		}
		if (not this.elementClass)
		{
			throw exception("cannot open element settings. The element class of element ID '" setElementID "' is empty", -1)
		}

		; save the "wait" option
		this.wait := wait
		
		this.fields := {} ;contains the fields which will be shown in the GUI. Each field is a bunch of controls
		this.fieldHWNDs := {} ;Contains the field objects of all field related controls hwnds. Needed for responding user input
		this.fieldParIDs := {} ;Contains the field objects of all parameter IDs. Needed for responding user input
		
		; disable editor gui
		EditGUIDisable()
		
		;block some update while the gui is initialized
		this.initializing := true
		this.generalUpdateRunning := true

		; this variable will help us not to miss any user input
		this.tasks := []

		;Create a scrollable Child GUI will almost all controls
		gui, GUISettingsOfElement: default
		gui, +hwndglobal_SettingWindowHWND
		gui, +vscroll
		gui, -DPIScale
		
		;Get the parameter list
		this.parametersToEdit := Element_getParametrizationDetails(this.elementClass, {flowID: FlowID, elementID: this.elementID, updateOnEdit: true})

		; add first gui elements
		; All elements have the parameter "name" and "StandardName"
		this.fields.push(new this.label({label: lang("name (name)")}))
		this.fields.push(new this.name({id: ["name", "StandardName"]}))
		
		;Loop through all parameters
		for index, parameter in this.parametersToEdit
		{
			;Add one or a group of controls. This is done dynamically, dependending on the parameter types
			if (parameter.type="Label")
			{
				this.fields.push(new this.label(parameter))
			}
			else if (parameter.type="Edit")
			{
				this.fields.push(new this.edit(parameter))
			}
			else if (parameter.type="multilineEdit")
			{
				this.fields.push(new this.multilineEdit(parameter))
			}
			else if (parameter.type="Checkbox")
			{
				this.fields.push(new this.checkbox(parameter))
			}
			else if (parameter.type="Radio")
			{
				this.fields.push(new this.radio(parameter))
			}
			else if (parameter.type="Slider")
			{
				this.fields.push(new this.slider(parameter))
			}
			else if (parameter.type="DropDown")
			{
				this.fields.push(new this.DropDown(parameter))
			}
			else if (parameter.type="ComboBox")
			{
				this.fields.push(new this.ComboBox(parameter))
			}
			else if (parameter.type="Hotkey")
			{
				this.fields.push(new this.Hotkey(parameter))
			}
			else if (parameter.type="Button")
			{
				this.fields.push(new this.Button(parameter))
			}
			else if (parameter.type="File")
			{
				this.fields.push(new this.file(parameter))
			}
			else if (parameter.type="Folder")
			{
				this.fields.push(new this.folder(parameter))
			}
			else if (parameter.type="weekdays")
			{
				this.fields.push(new this.weekdays(parameter))
			}
			else if (parameter.type="DateAndTime")
			{
				this.fields.push(new this.DateAndTime(parameter))
			}
			else if (parameter.type="listbox")
			{
				this.fields.push(new this.listbox(parameter))
			}
		}
		
		; Create the parent window which contains some always visible controls (which can't be scrolled away)
		Gui, GUISettingsOfElementParent: New
		gui, GUISettingsOfElementParent: -DPIScale
		Gui, GUISettingsOfElementParent: Margin, 0, 20
		gui, GUISettingsOfElementParent: +resize
		gui, GUISettingsOfElementParent: +hwndglobal_SettingWindowParentHWND
		gui, GUISettingsOfElementParent: +LabelGUISettingsOfElementParent
		
		;Make the scrollable child window appear inside the parent window
		Gui, GUISettingsOfElement: -Caption
		Gui, GUISettingsOfElement: +parentGUISettingsOfElementParent
		gui, GUISettingsOfElement: show, x0 y20
		
		;Get the size of the child window
		WinGetPos, , , WsettingsChild, HsettingsChild, % "ahk_id " global_SettingWindowHWND
		Winmove, % "ahk_id " global_SettingWindowHWND, , , , % WsettingsChild + 10, % HsettingsChild
		WinGetPos, , , WsettingsChild, HsettingsChild, % "ahk_id " global_SettingWindowHWND
		
		;Calculate the position of controls which are outside the child window (this is temporary calculation. it will be recalculated in the size-routine)
		YsettingsButtoPos := HsettingsChild + 30
		HSettingsParent := HsettingsChild + 90
		WSettingsParent := WsettingsChild
		
		;Define minimal and maximal size of the parent window. Ensure constant width.
		gui, GUISettingsOfElementParent: +minsize%WSettingsParent%x200
		gui, GUISettingsOfElementParent: +maxsize%WSettingsParent%x%HSettingsParent%
		
		;add the always visible buttons
		setElementClass := this.elementClass
		gui, GUISettingsOfElementParent: font, s8 cDefault wnorm
		; button for changing element type
		gui, GUISettingsOfElementParent: add, button, w370 x10 y10 gGUISettingsOfElementSelectType h20, % lang("%1%_type:_%2%", lang(this.elementType) ,Element_getName_%setElementClass%())
		; button for getting help
		gui, GUISettingsOfElementParent: add, button, w20 X+10 yp h20 gGUISettingsOfElementHelp vGUISettingsOfElementHelp, ?
		; save button
		Gui, GUISettingsOfElementParent: Add, Button, gGUISettingsOfElementSave vButtonSave w145 x10 h30 y%YsettingsButtoPos%,% lang("Save")
		; cancel button
		Gui, GUISettingsOfElementParent: Add, Button, gGUISettingsOfElementCancel vButtonCancel default w145 h30 yp X+10,% lang("Cancel")

		; we want to get the size of the created gui. Following line allows that
		Gui, GUISettingsOfElementParent: Show, hide w%WSettingsParent%,% lang("Settings") " - " lang(this.elementType) " - " Element_getName_%setElementClass%()
		
		;Calculate gui position. We want to show the settings window in the middle of the main window
		pos := EditGUIGetPos()
		tempHeight := round(pos.h - 100) ;This will be the max height. If child gui is larger, its content will be scrollable
		DetectHiddenWindows, on
		WinGetPos, ElSetingGUIX, ElSetingGUIY, ElSetingGUIW, ElSetingGUIH, ahk_id %global_SettingWindowParentHWND%
		if (ElSetingGUIH < tempHeight)
			tempHeight := ElSetingGUIH
		tempXpos := round(pos.x + (pos.w / 2) - (ElSetingGUIW / 2))
		tempYpos := round(pos.y + (pos.h / 2) - (tempHeight / 2))
		
		;move gui to the calculated position
		gui, GUISettingsOfElementParent: show, % "x" tempXpos " y" tempYpos " h" tempHeight " hide" 
		
		 ;make the autosize function trigger, which resizes and moves the scrollgui. This will update the position of lower buttons
		wingetpos, , , ElSetingGUIW, ElSetingGUIH, ahk_id %global_SettingWindowParentHWND%
		WinMove, ahk_id %global_SettingWindowParentHWND%, , , , % ElSetingGUIW, % ElSetingGUIH + 1
		
		; save the currently active gui
		global_CurrentlyActiveWindowHWND := global_SettingWindowParentHWND
		
		; show the gui
		gui, GUISettingsOfElementParent:show
		
		;Initialization done. Do a general update as last step
		this.initializing := false
		this.generalUpdateRunning := false
		this.generalUpdate(True)
		
		;We have to wait until user closes the window
		;Wait until this.result is set
		this.result := ""
		Loop
		{
			if (this.result = "")
				sleep 10
			else 
				break
		}
		return this.result
	}

	;If user clicks on the button to change the element class
	GUISettingsOfElementSelectType()
	{
		; close the element settings gui
		ElementSettings.close()
		
		; let user select the sub type and wait until he finishes
		tempres := ElementSettingsElementClassSelector.open(ElementSettings.element)
		if (tempres != "aborted")
		{
			; reopen the element settings window
			ElementSettings.open(ElementSettings.element, 1)
		}
		else 
		{
			; if user aborted
			this.result := "aborted"
		}
	}
		
	; if user clicks on the help button
	GUISettingsOfElementHelp()
	{
		; find out whether the help is currently shown
		IfWinExist, ahk_id %global_GUIHelpHWND%
		{
			; help is currently shown. Hide it
			ui_closeHelp()
		}
		else
		{
			; help is currently not shown. Show it
			ui_showHelp(ElementSettings.element)
		}
		return
	}
	
	; if user cancels editing the element settings
	GUISettingsOfElementCancel()
	{
		; close the element settings gui
		ElementSettings.close()
		
		this.result := "aborted"
	}

	; user clicks on the save button
	GUISettingsOfElementSave()
	{
		; do a general update (just in case)
		ElementSettings.generalUpdate()
		
		;If editing a trigger, disable it (and enable it afterwards)
		if (ElementSettings.elementType = "trigger" and _getElementProperty(FlowID, ElementSettings.element, "enabled") = true)
		{
			tempReenablethen := true
			disableOneTrigger(FlowID, ElementSettings.element, false)
		}
		else
			tempReenablethen := false
		
		;Save the parameters
		_setElementProperty(FlowID, ElementSettings.element, "Name", ElementSettings.NameField.getValue("Name"))
		_setElementProperty(FlowID, ElementSettings.element, "StandardName", ElementSettings.NameField.getValue("StandardName"))
		
		; get all parameter values
		allParamValues := ElementSettings.getAllValues()

		; save the parameter values
		for oneID, oneValue in allParamValues
		{
			; find out whether there were some changes
			tempOldValue := _getElementProperty(FlowID, ElementSettings.element, "pars." oneID)
			if (tempOldValue != oneValue)
			{
				; change detected
				ElementSettings.changes++
				; write changed value
				_setElementProperty(FlowID, ElementSettings.element, "pars." oneID, oneValue)
			}
		}
		
		;If editing a trigger which we have disabled previously, reenable it
		if (tempReenablethen)
		{
			enableOneTrigger(FlowID, ElementSettings.element, false)
		}
		
		; close the element settings gui
		ElementSettings.close()
		
		; return count of changes
		this.result := ElementSettings.changes " Changes"
		return
	}
	
	; the following classes are a set of controls (= fields) which are used to display different parameter types
	; This class contains common methods which are used by many controls
	class field
	{
		; on creation of a field
		; parameter: informations about the parameter
		__new(parameter)
		{
			global
			local index, onepar

			; save informations about the parameter
			this.parameter := parameter
			; this variable will contain the list of all controls
			this.components := []
			; this variable will contain the enabled state of the field
			this.enabled := 1
			; this variable will contain all parameter IDs of the field
			this.parameterIds := []

			; some parameters can be a string or an object. Convert them to consistent type.
			;convert to object if it is a string
			if (parameter.id and not IsObject(parameter.id))
				parameter.id := [parameter.id] 

			;convert to object if it is a string
			if (parameter.default and not IsObject(parameter.default))
				parameter.default := [parameter.default]
			
			;convert to object if it is a string	
			if (parameter.content and not IsObject(parameter.content))
				parameter.content := [parameter.content]
			
			;Convert to string if it is object
			if (IsObject(parameter.contentID))
				parameter.contentID := parameter.contentID[1]
			
			;Convert to string if it is object
			if (IsObject(parameter.contentDefault))
				parameter.contentDefault := parameter.contentDefault[1]
					

			; add to the list fieldParIDs all parameter IDs and link them to this field
			for index, onepar in parameter.id
			{
				ElementSettings.fieldParIDs[onepar] := this
				this.parameterIds.push(onePar)
			}
			
			; repeat for content IDs
			if (parameter.contentid)
			{
				ElementSettings.fieldParIDs[parameter.contentid] := this
				this.parameterIds.push(parameter.contentid)
			}
		}
		
		; Get value of a field. 
		; If parameterID is empty, the first (or the only) parameter of the field will be retrieved
		; If parameterID is set, this function will check whether the curernt class instance has the parameterID and then get it,
		;     otherwise it will find the object which contains the parameterID and call its getvalue() function.
		getvalue(parameterID = "")
		{
			global
			local temp, tempParameterID, value, oneindex, oneid, oneField
			if (not parameterID)
			{
				; Get first parameter ID
				tempParameterID := this.parameterIDs[1]
				
				if (tempParameterID) ; if this field has a paramter ID
				{
					; get value from gui control
					GUIControlGet, temp, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%
				}
				Else
				{
					logger("a0", "cannot get value of field which has no parameter ID. (field class: " this.__Class ")", flowID)
				}
				return temp
			}
			else
			{
				; make list of all available parameter IDs of this object
				tempParameterID := this.parameter.id
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, get value
						GUIControlGet, temp, GUISettingsOfElement:, GUISettingsOfElement%oneid%
						return temp
					}
				}
				; the current object has not the requested parameter ID
				; Find field which has the requested parameter ID and call it
				foundField := ElementSettings.fieldParIDs[parameterID]
				if (foundField)
				{
					return foundField.getvalue(parameterID)
				}

				; if we are here, we did not find a field for this parameter ID
				logger("a0", "cannot get value of field, since parameter ID ''" parameterID "'' was not found. (field class: " this.__Class ")", flowID)
			}
			return 
		}
		
		; Set value of a field. 
		; If parameterID is empty, the first (or the only) parameter of the field will be set
		; If parameterID is set, this function will check whether the curernt class instance has the parameterID and then set it,
		;     otherwise it will find the object which contains the parameterID and call its setvalue() function.
		setvalue(value, parameterID = "")
		{
			global
			local foundField, tempParameterID, oneindex, oneid
			if (not parameterID)
			{
				; Get first parameter ID
				tempParameterID := this.parameterIDs[1]
				
				if (tempParameterID) ; if this field has a paramter ID
				{
					; set value in gui control
					GUIControl, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%, % value
				}
				Else
				{
					logger("a0", "cannot set value of field which has no parameter ID. (field class: " this.__Class ")", flowID)
				}
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID := this.parameter.id
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, set value
						GUIControl, GUISettingsOfElement:, GUISettingsOfElement%oneid%, % value
						return
					}
				}

				; the current object has not the requested parameter ID
				; Find field which has the requested parameter ID and call it
				foundField := ElementSettings.fieldParIDs[parameterID]
				if (foundField)
				{
					foundField.setvalue(value, parameterID)
					return
				}

				; if we are here, we did not find a field for this parameter ID
				logger("a0", "cannot set value of field, since parameter ID ''" parameterID "'' was not found. (field class: " this.__Class ")", flowID)
			}

			; update some general values (e.g. element name)
			elementSettings.generalUpdate()
		}
		
		
		; Set choices of a field (dropdown, etc)
		; If parameterID is empty, the choices for the first (or the only) parameter of the field will be set
		; If parameterID is set, this function will check whether the curernt class instance has the parameterID and then set it,
		;     otherwise it will find the object which contains the parameterID and call its setChoices() function.
		setChoices(value, parameterID = "")
		{
			global
			local foundField
			if (not parameterID)
			{
				logger("a0", "cannot set choices of current field. It is not implemented for this field type. (field class: " this.__Class ")", flowID)
			}
			else
			{
				; the current object has not the requested parameter ID
				; Find field which has the requested parameter ID and call it
				foundField := ElementSettings.fieldParIDs[parameterID]
				if (foundField)
				{
					foundField.setChoices(value, parameterID)
				}

				; if we are here, we did not find a field for this parameter ID
				logger("a0", "cannot set choices of field, since parameter ID ''" parameterID "'' was not found. (field class: " this.__Class ")", flowID)
			}
		}
		
		; Set label of a field
		; If parameterID is empty, the choices for the first (or the only) parameter of the field will be set
		; If parameterID is set, this function will check whether the curernt class instance has the parameterID and then set it,
		;     otherwise it will find the object which contains the parameterID and call its setChoices() function.
		setLabel(value, parameterID = "")
		{
			global
			local foundField
			if (not parameterID)
			{
				logger("a0", "cannot set label of current field. It is not implemented for this field type. (field class: " this.__Class ")", flowID)
			}
			else
			{
				; the current object has not the requested parameter ID
				; Find field which has the requested parameter ID and call it
				foundField := ElementSettings.fieldParIDs[parameterID]
				if (foundField)
				{
					foundField.setLabel(value, parameterID)
					return
				}

				; if we are here, we did not find a field for this parameter ID
				logger("a0", "cannot set label of field, since parameter ID ''" parameterID "'' was not found. (field class: " this.__Class ")", flowID)
			}
		}
		
		; enable a field
		; If parameterID is empty, all controls of this field will be enabled
		; If parameterID is set, this function will check whether the curernt class instance has the parameterID and then enable all controls of this field,
		;     otherwise it will find the object which contains the parameterID and call its enable() function.
		enable(parameterID = "", enOrDis = 1)
		{
			global
			local tempParameterID, index, component, oneid, oneField
			
			;if parameterID is empty, disable all components
			if (not parameterID)
			{
				;enable all components of this field
				for index, component in this.components
				{
					guicontrol, GUISettingsOfElement:enable%enOrDis%, % component
				}

				; save enabling state and check content
				if (this.enabled != enOrDis)
				{
					this.enabled := enOrDis
					this.checkContent()
				}
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID := this.parameter.id
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, enable all components
						for index, component in this.components
						{
							guicontrol, GUISettingsOfElement: enable%enOrDis%, % component
						}

						; save enabling state and check content
						if (this.enabled != enOrDis)
						{
							this.enabled := enOrDis
							this.checkContent()
						}
						return
					}
				}

				; the current object has not the requested parameter ID
				; Find field which has the requested parameter ID and call it
				foundField := ElementSettings.fieldParIDs[parameterID]
				if (foundField)
				{
					foundField.enable(parameterID, enOrDis)
				}

				; if we are here, we did not find a field for this parameter ID
				tempString := enOrDis ? "enable" : "disable"
				logger("a0", "cannot " tempString " a field, since parameter ID ''" parameterID "'' was not found. (field class: " this.__Class ")", flowID)
			}
		}

		; disable a field. Uses enable() function
		disable(parameterID = "")
		{
			this.enable(parameterID, 0)
		}

		; returns true, if parameter is in the parmeter ID list of this control
		hasParameterID(parameterID)
		{
			for oneIndex, oneParameterID in this.parameterIds
			{
				if (parameterID = oneParameterID)
					return true
			}
			return false
		}
		
		; called if user clicks on a warning picture. It shows a tooltip with the current warning text
		ClickOnWarningPic()
		{
			ToolTip, % this.warningtext, , , 11
			settimer, GUISettingsOfElementRemoveInfoTooltip, -5000
		}
	}

	; This class contains common methods which are used by controls
	;   which can have a dedicated content type or even selectable content type
	class fieldWithContentType extends ElementSettings.field
	{
		; add content type selector controls (if input type is selectable)
		addContentTypeSelectorControls()
		{
			global
			
			local tempContentTypeNum, tempAssigned, tempchecked, tempgrpStr
			local oneindex, onevalue

			; copy some paramters in local variables
			local tempParameterContentType := parameter.content
			local tempParameterContentTypeID := parameter.contentID
			local tempParameterContentTypeDefault := parameter.contentDefault

			; Is the input type selectable?
			if (parameter.content.MaxIndex() > 1)
			{
				; the input type is selectable. We will need to add some radio buttons
				if (not tempParameterContentTypeID)
				{
					; catch bug in the element implementation
					MsgBox Error creating edit field: Multiple contents should be possible but the content ID is not specified.
					logger("a0", "cannot create edit field. Multiple contents should be possible but the content ID is not specified (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
					return
				}
				
				; get the value of the content type parameter
				tempContentTypeNum := ElementSettings.elementPars[tempParameterContentTypeID]

				; Get the index of the content type
				if tempContentTypeNum is not number
				{
					for oneindex, onevalue in parameter.content
					{
						if (onevalue = tempContentTypeNum)
						{
							tempContentTypeNum := oneindex
							break
						}
					}
				}
				
				tempAssigned := false
				loop % parameter.content.maxindex()
				{
					; we need to make a new group on first iteration (required if gui contains multiple radio fields)
					if (a_index = 1)
						tempgrpStr := "Group"
					else
						tempgrpStr := ""
					
					; find the checked option
					if (a_index = tempContentTypeNum)
					{
						tempchecked := "checked"
						tempAssigned := true
					}
					else
					{
						tempchecked := ""
					}
					
					; add a radio button
					gui, add, radio, w400 x10 %tempchecked% %tempgrpStr% hwndtempHWND gGUISettingsOfElementChangeRadio vGUISettingsOfElement%tempParameterContentTypeID%%A_Index%, % this.contentTypeLangs[parameter.content[a_index]]
					this.components.push("GUISettingsOfElement" tempParameterContentTypeID a_index)
					ElementSettings.fieldHWNDs[tempHWND] := this
				}
				
				if (not tempAssigned) ;Catch if a wrong value or no was saved and set to default value.
				{
					logger("a0", "none radio button was activated. Content type value '" tempContentTypeNum "' is not in choices (field class: " this.__Class ")")
				}
			}
			else
			{
				; we have only one content type (or none)
				this.currentContentType := parameter.content[1]
			}
		}

		; Add picture, which will warn user if the content is invalid
		addErrorWarnIconControl()
		{
			global
			; copy some parameters in local variables
			local tempFirstParameterID := parameter.id[1]

			; create the control on the right side
			gui, add, picture, x394 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempFirstParameterID%
			this.components.push("GUISettingsOfElementWarningIconOf" tempFirstParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}

		; Add picture, which will show user the current content type
		addContentTypeInfoIconControl()
		{
			global
			; copy some parameters in local variables
			local tempFirstParameterID := parameter.id[1]
			
			; create the control on the left side
			gui, add, picture, x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempFirstParameterID%
			this.components.push("GUISettingsOfElementInfoIconOf" tempFirstParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}

		; get value of the field. If parameterID is content ID, return the content type
		getvalue(parameterID = "") ; override
		{
			global
			local temp, tempParameterID

			if (parameterID and parameterID = this.parameter.contentID)
			{
				; we want to have the contentID parameter. Get value from radio buttons
				loop % this.parameter.content.MaxIndex()
				{
					; get value from radio button
					GUIControlGet, temp, GUISettingsOfElement:, GUISettingsOfElement%parameterID%%a_index%
					if (temp = 1)
					{
						; the current radio button is selected.
						temp := this.parameter.content[a_index]
						break
					}
					; else continue with next radio button
				}
				return temp
			}
			else
			{
				; we want other parameter. We can reuse the base function
				return base.getvalue(parameterID)
			}
		}
		
		; set the value of the field. If parameterID is content ID, set the content type
		setvalue(value, parameterID = "") ; override
		{
			global
			if (parameterID and parameterID = this.parameter.contentID)
			{
				if not (value >= 1 and value <= this.parameter.content.MaxIndex())
				{
					; Value is not a valid index. This might be an enum value. Try to find value in choices
					loop % this.parameter.content.MaxIndex()
					{
						if (this.parameter.content[a_index] = value)
						{
							; value is one of the enumeration. We will set the corresponding index
							temp := a_index
							success := true
							break
						}
					}

					if (not success)
					{
						logger("a0", "cannot set content type value. Value '" value "' is neither a valid index nor a valid enumeration value (field class: " this.__Class ", content paramter ID: " this.parameter.contentID ")")
					}
				}
				else
				{
					; the value is a valid index. We will set it.
					temp := value
				}
				
				; set the correct radio button
				GUIControl, GUISettingsOfElement:, GUISettingsOfElement%parameterID%%temp%, 1
			}
			else
			{
				; we want to set other parameter. We can reuse the base function
				base.setvalue(value, parameterID)
			}

			;Check content after setting it
			this.checkContent()
		}
		
		; check the content of the edit field and show warning picture if there is an error
		checkContent()
		{
			global
			local tempFoundPos, tempRadioVal, tempOneParamID, tempTextInControl, tempTextInControlReplaced
			local oneindex, oneparamID
			
			; get the current content type
			if (this.parameter.ContentID)
			{
				tempRadioVal := this.getvalue(this.parameter.ContentID)
			}
			else
			{
				tempRadioVal := this.parameter.content[1]
			}
			; This value is needed to get the icon controls
			tempFirstParamID := this.parameter.id[1]
			
			; delete the warning text. If an error will be found, we will set the warning text
			This.warningText := ""
			if (this.enabled)
			{
				if (tempRadioVal = "expression" or tempRadioVal = "number")
				{
					;The content is an expression.
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl := this.getvalue(oneparamID)
						
						;Warn if there are percent signs.
						IfInString, tempTextInControl, `%
						{
							guicontrol, GUISettingsOfElement:show, GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol, GUISettingsOfElement:, GUISettingsOfElementWarningIconOf%tempFirstParamID%, %_ScriptDir%\Icons\Question mark.ico
							This.warningText := lang("Note!") " " lang("This is an expression.") " " lang("You mus not use percent signs to add a variable's content.") "`n" lang("But you can still use percent signs if the variable name or a part of it is stored in a variable.")
						}
					}
				}
				else if (tempRadioVal = "variablename")
				{
					;the content is a variable name
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl := this.getvalue(oneparamID)
						
						;Check whether the variable name is correct (it does not contain forbitten characters)
						
						;At first replace all variables in the string by the string "someVarName"
						tempTextInControlReplaced := tempTextInControl
						Loop
						{
							tempFoundPos := RegExMatch(tempTextInControlReplaced, "U).*%(.+)%.*", tempVariablesToReplace)
							if (tempFoundPos = 0)
								break
							StringReplace, tempTextInControlReplaced,tempTextInControlReplaced, `%%tempVariablesToReplace1%`%, someVarName
						}
						
						try
						{
							;now check whether the varible name is correct
							asdf%tempTextInControlReplaced% := "" 
						}
						catch
						{
							;The variable name is not valid
							guicontrol, GUISettingsOfElement:show, GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol, GUISettingsOfElement:, GUISettingsOfElementWarningIconOf%tempFirstParamID%, %_ScriptDir%\Icons\Exclamation mark.ico
							This.warningText := lang("Error!") " " lang("The variable name is not valid.") "`n"
						}
					}
				}
				
				if (this.parameter.WarnIfEmpty)
				{
					; the control must not be empty. Check that
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl := this.getvalue(oneparamID)
						if (tempTextInControl = "")
						{
							guicontrol, GUISettingsOfElement:show, GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol, GUISettingsOfElement:, GUISettingsOfElementWarningIconOf%tempFirstParamID%, %_ScriptDir%\Icons\Exclamation mark.ico
							This.warningText := lang("Error!") " " lang("This field must not be empty!") "`n"
						}
					}
				}
			}
			else
			{
				;This parameter and its controls are disabled. If so, hide all warnings.
				guicontrol, GUISettingsOfElement:hide, GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			if (not This.warningText)
			{
				;If no warning are present, hide the picture
				guicontrol, GUISettingsOfElement:hide, GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			; do a general update after that
			ElementSettings.GeneralUpdate()
		}
		
		;Show hint if user clicks on the info-picture
		clickOnInfoPic()
		{
			global
			local tempRadioVal
			
			; get the current content type
			if (this.parameter.ContentID)
			{
				tempRadioVal := this.getvalue(this.parameter.ContentID)
			}
			else
			{
				tempRadioVal := this.parameter.content[1]
			}
			
			; show a tooltip which describes the current content type
			if (tempRadioVal = "Expression")
			{
				ToolTip, % lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)`nStringContainingHello " " StringContainingWorld" ,,, 11
			}
			if (tempRadioVal = "Number")
			{
				ToolTip, % lang("This field contains an expression which must result to a number") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth" ,,, 11
			}
			if (tempRadioVal = "String")
			{
				ToolTip, % lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,, 11
			}
			if (tempRadioVal = "RawString")
			{
				ToolTip, % lang("This field contains a raw string") "`n" lang("You can't insert content of a variable here") "`n" lang("Examples") ":`nHello World" ,,, 11
			}
			if (tempRadioVal = "VariableName") 
			{
				ToolTip, % lang("This field contains a variable name") "`n" lang("Examples") ":`nVarname`nEntry1`nEntry%a_index%" ,,, 11
			}

			; disable the tooltip automatically after a while
			settimer, GUISettingsOfElementRemoveInfoTooltip, -5000
		}
		
		;User has changed the radio button. Show the correct image
		updateContentTypePicture()
		{
			global
			local temp, tempGUIControl, tempRadioID, tempRadioVal

			; get the current content type
			if (this.parameter.ContentID)
			{
				tempRadioVal := this.getvalue(this.parameter.ContentID)
			}
			else
			{
				tempRadioVal := this.parameter.content[1]
			}
			;This value is needed to get the icon controls
			tempFirstParamID := this.parameter.id[1]
			
			; update the icon picture depending on the current content type
			if (tempRadioVal = "string" or tempRadioVal = "rawstring") 
			{
				guicontrol, GUISettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%, %_ScriptDir%\Icons\String.ico
			}
			else if (tempRadioVal = "expression" or tempRadioVal = "number") 
			{
				guicontrol, GUISettingsOfElement:, GUISettingsOfElementInfoIconOf%tempFirstParamID%, %_ScriptDir%\Icons\Expression.ico
			}
			else if (tempRadioVal = "variableName") 
			{
				guicontrol, GUISettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%, %_ScriptDir%\Icons\VariableName.ico
			}
			
			; since user changed the content type, we need to check the content
			this.checkcontent()
		}
	}
	
	; field which contains the element name
	; this field will be created for every element and there can only be one field of this class
	class name extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)
			local tempchecked, temptext, tempParGray, tempHWND
			local tempParameterID := parameter.id

			; save this object to a varaible, so it can be found from outside.
			ElementSettings.NameField := this
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; add the checkbox for the parameter "StandardName"
			tempchecked := _getElementProperty(FlowID, ElementSettings.element, "StandardName")
			gui,add,checkbox, x10 hwndtempHWND checked%tempchecked% vGUISettingsOfElementStandardName gGUISettingsOfElementCheckStandardName, % lang("Standard_name")
			this.components.push("GUISettingsOfElementStandardName")
			ElementSettings.fieldHWNDs[tempHWND] := this

			; add the checkbox for the parameter "name"
			gui,add,edit,w400 x10 Multi r5 hwndtempHWND vGUISettingsOfElementName gGUISettingsOfElementGeneralUpdate,% ElementSettings.elementName
			this.components.push("GUISettingsOfElementName")
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
		
		; change the name of the element
		; p_CurrentPar: all parameters of the element, since the name will be generated out of those parameters
		updateName(p_CurrentPars)
		{
			global
			local Newname, setElementClass

			; skip this action, if the element settings window is currently initialized
			if (ElementSettings.initializing = true)
				return

			; check the paraemter StandardName
			if (this.getvalue("StandardName") = 1)
			{
				; the default name is enabled. We will disable the name field and generate the name
				this.disable("Name")
				setElementClass := ElementSettings.elementClass
				Newname := Element_GenerateName_%setElementClass%({flowID: FlowID, ElementID: ElementSettings.element}, p_CurrentPars) 
				; the element function may return some linefeeds. We will replace them.
				StringReplace, Newname, Newname, `n, %a_space%-%a_space%, all
				this.setvalue(Newname, "Name")
			}
			else
			{
				; the default name is disabled. We will enable the name field, so the user can edit it
				this.enable("Name")
			}
		}

		; enable or disable the name field. Never disable the "StandardName" checkbox
		enable(parameterID = "", enOrDis = 1) ; override
		{
			global
			local tempParameterID, index, component, oneid, oneField
			
			;if parameterID is empty, disable all components
			if (not parameterID)
			{
				; enable the name field
				guicontrol, GUISettingsOfElement: enable%enOrDis%, GUISettingsOfElementName
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID := this.parameter.id
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						; if so, enable the name field
						guicontrol, GUISettingsOfElement: enable%enOrDis%, GUISettingsOfElementName
						return
					}
				}
			}
		}
	}

	; field which contains a label
	class label extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempYPos
			local tempParameterID := parameter.labelid

			; modify the style depending on the parameter property "small"
			if (parameter.size = "small")
			{
				gui, font, s8 cDefault wbold
				tempYPos := ""
			}
			else
			{
				gui, font, s10 cnavy wbold
				tempYPos := "Y+15"
			}

			; do we have a label ID?
			if (tempParameterID)
			{
				; we have a label ID, it will allow the use of "setLabel" function 
				gui, add, text, x10 w400 %tempYPos% vGUISettingsOfElement%tempParameterID%, % parameter.label
				this.components.push("GUISettingsOfElement" tempParameterID)
			}
			else
			{
				; we don't have a label ID, we won't be able to use setLabel() function. This is usual case, since most labels are static.
				gui, add, text, x10 w400 %tempYPos%, % parameter.label
			}
		}
		
		; Set label value.
		; If parameterID is empty and this field has a label ID, the label of this field will be used.
		; If parameterID is set, this function will check whether the current class instance has the parameterID and then set it,
		;     otherwise it will find the object which contains the parameterID and call its setLabel() function.
		setLabel(value, parameterID = "") ; override
		{
			global
			if (not parameterID)
			{
				; paraemter ID is empty. Use the first parameter ID
				parameterID := this.parameterIds[1]
				if (not parameterID)
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ")")
					return
				}
			}
			Else
			{
				; parameter ID is set. Check whether it exists in the parameter list of this field
				if (not this.hasParameterID(parameterID))
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
					return
				}
			}

			; change label
			GUIControl, GUISettingsOfElement:, GUISettingsOfElement%parameterID%, % value
			return
		}
	}

	; field which contains a checkbox
	class checkbox extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)
			
			local tempChecked, temptext, tempParGray, tempHWND

			; copy some paramters in local variables
			local tempParameterID := this.parameterIDs[1]
			
			; get the parametr properties
			tempChecked := ElementSettings.elementPars[tempParameterID] 
			temptext := parameter.label
			if (parameter.gray)
				tempParGray := "check3"
			else
				tempParGray := ""

			; create the gui elements
			gui, font, s8 cDefault wnorm
			gui, add, checkbox, w400 x10 %tempParGray% checked%tempChecked% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, %temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
		
		; change the label of the checkbox
		setLabel(value, parameterID = "") ; override
		{
			global
			if (not parameterID)
			{
				; paraemter ID is empty. Use the first parameter ID
				parameterID := this.parameterIds[1]
				if (not parameterID)
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ")")
					return
				}
			}
			Else
			{
				; parameter ID is set. Check whether it exists in the parameter list of this field
				if (not this.hasParameterID(parameterID))
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
					return
				}
			}
			
			; change label
			GUIControl, GUISettingsOfElement:text, GUISettingsOfElement%parameterID%, % value
			return
		}
	}
	
	; field which contains some radio buttons
	class radio extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempAssigned, tempMakeNewGroup, tempChecked, temp, tempHWND
			local hasEnum

			; copy some paramters in local variables
			local tempParameterID := this.parameterIDs[1]
			
			; set font style
			gui, font, s8 cDefault wnorm

			; get value
			temp := ElementSettings.elementPars[tempParameterID] 
			tempAssigned := false
			for tempindex, tempRadioLabel in parameter.choices
			{
				; we need to make a new group on first iteration (required if gui contains multiple radio fields)
				if (a_index = 1)
					tempMakeNewGroup := "Group"
				else
					tempMakeNewGroup := ""
				
				; find the checked option
				if ((temp = a_index) or (temp = parameter.Enum[a_index]))
				{
					tempChecked := "checked"
					tempAssigned := true
				}
				else
					tempChecked := ""
				
				; add a radio button
				gui, add, radio, w400 x10 %tempChecked% %tempMakeNewGroup% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%%a_index% , % tempRadioLabel
				this.components.push("GUISettingsOfElement" tempParameterID a_index)
				ElementSettings.fieldHWNDs[tempHWND] := this
			}
			if (tempAssigned = false) ;Catch if a wrong value was saved and set to default value. 
			{
				logger("a0", "none radio button was activated. Value '" temp "' is not in choices (field class: " this.__Class ")")
			}
		}
		
		; get the value of the radio field.
		; if the parameter type is enum, it will return the enum value. Else it will return the index.
		getvalue(parameterID = "") ; override
		{
			global
			local temp
			; Get first parameter ID
			local tempParameterID := this.parameterIDs[1]
			
			; this field has multiple radio button controls. Find the selected one.
			loop % this.parameter.choices.MaxIndex()
			{
				; get value from radio button
				guicontrolget, temp, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%%a_index%
				if (temp = 1)
				{
					; the current radio button is selected.
					if (this.parameter.result = "enum")
					{
						; the result type is "enum" we will return the enumeration value
						temp := this.parameter.Enum[a_index]
					}
					else
					{
						; We will return the index
						temp := A_Index
					}
					break
				}
				; else continue with next radio button
			}
			
			return temp
		}

		; set the value of radio field
		setvalue(value, parameterID = "") ; override
		{
			global
			local temp
			; Get first parameter ID
			local tempParameterID := this.parameterIDs[1]

			if not (value >= 1 and value <= this.parameter.choices.MaxIndex())
			{
				; Value is not a valid index. This might be an enum value. Check whether the enumeration is enabled
				local success := false
				if (IsObject(this.parameter.Enum))
				{
					; we have an enumeration. Try to find value in choices
					loop % this.parameter.choices.MaxIndex()
					{
						if (this.parameter.Enum[a_index] = value)
						{
							; value is one of the enumeration. We will set the corresponding index
							temp := a_index
							success := true
							break
						}
					}
				}

				if (not success)
				{
					logger("a0", "cannot set value. Value '" value "' is neither a valid index nor a valid enumeration value (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
				}
			}
			else
			{
				; the value is a valid index. We will set it.
				temp := value
			}

			; set the correct radio button
			GUIControl, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%%temp%, 1
			return temp
		}
		
		; change the label of a radio button
		setLabel(value, parameterID = "") ; override
		{
			global
			if (not parameterID)
			{
				; paraemter ID is empty. Use the first parameter ID
				parameterID := this.parameterIds[1]
				if (not parameterID)
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ")")
					return
				}
			}
			Else
			{
				; parameter ID is set. Check whether it exists in the parameter list of this field
				if (not this.hasParameterID(parameterID))
				{
					logger("a0", "cannot set label. Parameter ID '" parameterID "' is not in list (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
					return
				}
			}
			
			; change label
			GUIControl,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
			return
		}
	}
	
	; field which contains one or multiple edit controls.
	class edit extends ElementSettings.fieldWithContentType
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local temp, temptext, tempIsMulti, tempXpos,tempEditwidth, tempHWND, tempContentTypeID, tempContentTypeNum, tempFirstParameterID, tempchecked1, tempchecked2, tempassigned, tempContentDefault
			local tempwAvailable, tempw
			local oneindex, onevalue

			; copy some paramters in local variables
			local tempParameterID := parameter.id
			local tempFirstParameterID := parameter.id[1]
			local tempParameterdefault := parameter.default
			
			; prepare some strings for the content type radio
			this.contentTypeLangs := {string: lang("This is a string"), rawString: lang("This is a raw string"), expression: lang("This is an expression"), VarName: lang("This is a variable name")}
			this.currentContentType := ""
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; add content type selector (if input type is selectable)
			this.addContentTypeSelectorControls()
			
			;The info icon tells user which content type it is
			this.addContentTypeInfoIconControl()
			
			; Add the edit control(s)
			loop % parameter.id.MaxIndex()
			{
				tempOneParameterID := parameter.id[a_index]

				; calculate the width of the control. It depends on the count of IDs
				tempwAvailable := 360
				tempw := (tempwAvailable - (4 * (parameter.id.MaxIndex() -1))) / parameter.id.MaxIndex()

				; create the controls
				temptext := ElementSettings.elementPars[tempOneParameterID]
				gui, add, edit, X+4 w%tempw% %tempIsMulti% r1 hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%, %temptext%
				this.components.push("GUISettingsOfElement" tempOneParameterID)
				ElementSettings.fieldHWNDs[tempHWND] := this
				
				if (parameter.id.MaxIndex() = 1 and not parameter.contentID and parameter.content[1] = "expression")
				{
					;If we have a single expression, it may have some arrow keys
					if (parameter.useupdown)
					{
						if (parameter.range)
							gui, add, updown, % "range" parameter.range
						else
							gui, add, updown
						guicontrol, GUISettingsOfElement:, GUISettingsOfElement%tempOneParameterID%, %temptext%
					}
				}
			}
			
			; Add picture, which will warn user if the content is invalid
			this.addErrorWarnIconControl()
			
			; update the content type icon
			this.updateContentTypePicture()
		}
	}
	
	; field which contains one multiline edit control.
	class multilineEdit extends ElementSettings.fieldWithContentType
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local temp, temptext, tempParGray, tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			local tempParameterRows := parameter.rows
			; set default value if not set in parameters
			if not tempParameterRows
				tempParameterRows := 5

			; create the gui elements
			gui,font,s8 cDefault wnorm

			; add content type selector (if input type is selectable)
			this.addContentTypeSelectorControls()
			
			;The info icon tells user which content type it is
			this.addContentTypeInfoIconControl()
			
			; create the control
			temptext := ElementSettings.elementPars[tempParameterID]
			gui, add, edit, w360 X+4 multi r%tempParameterRows% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID%, %temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
			
			; Add picture, which will warn user if the content is invalid
			this.addErrorWarnIconControl()
		}
	}
	
	; field which contains a slider. It may also be a combination of an edit control and a slider.
	class slider extends ElementSettings.fieldWithContentType
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			local temp := ElementSettings.elementPars[tempParameterID] 
			local tempParameterOptions := parameter.options
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			if (parameter.allowExpression)
			{
				; expressions are allowed. We have to show an edit control where user may enter an expression.

				; a slider can only be a number. We will show an expression icon
				this.parameter.content := ["expression"]
				this.addContentTypeInfoIconControl()
				this.updateContentTypePicture()

				; create the edit control
				gui, add, edit, X+6 w190 hwndtempHWND gGUISettingsOfElementSliderChangeEdit vGUISettingsOfElement%tempParameterID%, %temp%
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND] := this

				; create the slider control
				gui, add, slider, w180 X+10 %tempParameterOptions%  hwndtempHWND gGUISettingsOfElementSliderChangeSlide vGUISettingsOfElementSlideOf%tempParameterID%, % temp
				this.components.push("GUISettingsOfElementSlideOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND] := this
			}
			else
			{
				; expressions are not allowed. We don't need an edit control.

				; create the slider control
				gui, add, slider, w400 x10 %tempParameterOptions% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, % temp
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND] := this
			}
		}
		
		; called if user changes something in the edit field
		sliderChangeEdit()
		{
			global
			local temp
			
			; copy some parameters in local variables
			local tempParameterID := this.parameter.id[1]

			; get the value and set the slide value
			temp := this.getValue()
			guicontrol, GUISettingsOfElement:, GUISettingsOfElementSlideOf%tempParameterID%, %temp%

			; do other tasks
			this.checkContent()
		}

		; called if user moves the slider
		sliderChangeSlide()
		{
			global
			local temp

			; copy some parameters in local variables
			local tempParameterID := this.parameter.id[1]

			if (this.parameter.allowExpression)
			{
				; if we have a slider and an edit control, write the number from slider to the edit control
				guicontrolget, temp, GUISettingsOfElement:, GUISettingsOfElementSlideOf%tempParameterID%
				this.setValue(temp)
			}

			; do other tasks
			this.checkContent()
		}
	}
	
	; field which contains a dropdown.
	class DropDown extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			
			if (parameter.result != "number" and parameter.result != "string" and parameter.result != "enum")
			{
				logger("a0", "Parameter 'result' ''" parameter.result "'' is unset or has unsupported value. (field class: " this.__Class ")", flowID)
				return
			}

			; reuse base new() function
			base.__new(parameter)

			local temp, temptoChoose,tempAltSumbit,tempChoises,tempAllChoices, tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			local tempValue := ElementSettings.elementPars[tempParameterID] 
			local tempChoises := parameter.choices
			local tempEnums := parameter.enum
			
			; decide, whether we will need altSubmit
			if (parameter.result = "number" or parameter.result = "enum")
			{
				; the return value of the dropDown should be the selected index or the enum value. We will need altsubmit
				temptoChoose := tempValue
				tempAltSumbit := "AltSubmit"
			}
			else
			{
				; the return value of the dropDown should be the string
				tempAltSumbit := ""
			}
			
			;loop through all choices. Find which one to select. Make a selection list which is suitable for the gui,add command
			local tempAllChoices := ""
			for tempIndex, TempOneChoice in tempChoises
			{
				; find out whether the current value should be selected
				if (parameter.result = "string")
				{
					if (TempOneChoice = tempValue)
						temptoChoose := A_Index
				}
				else
				{
					if (tempValue = A_Index or tempValue = tempEnums[A_Index])
						temptoChoose := A_Index
				}

				; Add the current choise to the string
				tempAllChoices .= "|" TempOneChoice
			}
			StringTrimLeft, tempAllChoices, tempAllChoices, 1
			
			; create the gui elements
			gui, font, s8 cDefault wnorm

			; add the dropdown control
			gui, add, DropDownList, w400 x10 %tempAltSumbit% choose%temptoChoose% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, % tempAllChoices
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}

		; get the value of the dropdown
		getvalue(parameterID = "") ; override
		{
			global
			local temp
			
			; reuse the base function
			temp := base.getvalue(parameterID)

			; if we should return the enum value as result, convert the index to enum string 
			if (this.parameter.result = "enum")
				temp := this.parameter.Enum[temp]
			
			return temp
		}

		; set the value of the dropdown
		setvalue(value, parameterID = "") ; override
		{
			global

			; copy some paramters in local variables
			local tempParameterID := this.parameter.id[1]

			; decide how to set the value depending on the result type
			if (parameter.result = "number")
			{
				; select the value with given index
				GUIControl, GUISettingsOfElement:choose, GUISettingsOfElement%tempParameterID%, value
			}
			else if (parameter.result = "enum")
			{
				; find the enum value index
				loop % this.parameter.choices.MaxIndex()
				{
					if (this.parameter.Enum[a_index] = value)
					{
						value := a_index
						break
					}
				}
				; select the value with found index
				GUIControl, GUISettingsOfElement:choose, GUISettingsOfElement%tempParameterID%, value
			}
			else if (parameter.result = "string")
			{
				; select the value with given string
				GUIControl, GUISettingsOfElement:chooseString, GUISettingsOfElement%tempParameterID%, value
			}
		}
	}
	
	; field which contains a combobox.
	class ComboBox extends ElementSettings.fieldWithContentType
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local temp, temptoChoose,tempAltSumbit,tempHWND
			
			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]

			; get the current value
			local tempValue := ElementSettings.elementPars[tempParameterID] 

			; the choices can be set after the control was created. We will save the initial value
			this.par_choices := parameter.choices
			
			; decide, whether we will need altSubmit
			if (parameter.result = "number")
			{
				; the return value of the combobox should be the selected index. We will need altsubmit
				tempAltSumbit := "AltSubmit"
			}
			else
			{
				; the return value of the dropDown should be the string
				tempAltSumbit := ""
			}

			;loop through all choices. Make a selection list which is suitable for the gui,add command
			local tempAllChoices := ""
			for tempIndex, TempOneChoice in this.par_choices
			{
				tempAllChoices .= "|" TempOneChoice
			}
			StringTrimLeft, tempAllChoices, tempAllChoices, 1
			
			; create the gui elements
			gui, font, s8 cDefault wnorm

			; add content type selector (if input type is selectable)
			this.addContentTypeSelectorControls()
			
			;The info icon tells user which content type it is
			this.addContentTypeInfoIconControl()

			; create the control
			gui, add, ComboBox, X+4 w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID%, % tempAllChoices
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this

			; Add picture, which will warn user if the content is invalid
			this.addErrorWarnIconControl()
			
			; update the content type icon
			this.updateContentTypePicture()

			; set the value
			this.setvalue(tempValue)
		}
		
		; set the value of the combobox
		setvalue(value, parameterID = "")
		{
			global
			local tempLabelChoice, tempindexChoice, somethingChosen

			; copy some paramters in local variables
			local tempParameterID := this.parameter.id[1]

			if (parameterID = tempParameterID or not parameterID)
			{
				; we want to set the value of the control.
				; Since the value can be the index of a choice, we need special implementation

				if (parameter.result = "number")
				{
					; the result type is "number", so probably the value is an index of one choice
					if (value > 0 and value <= this.par_choices.MaxIndex())
					{
						; the value is a valid index. We will set it.
						GUIControl, GUISettingsOfElement:choose, GUISettingsOfElement%tempParameterID%, % value
					}
					else
					{
						; the value is not a valid index. We will set the string
						GUIControl, GUISettingsOfElement:text, GUISettingsOfElement%tempParameterID%, % value
					}
				}
				Else
				{
					; the result type is not "number", so we will set the string
					GUIControl, GUISettingsOfElement:text, GUISettingsOfElement%tempParameterID%, % value
				}
				
				;Check content after setting it
				this.checkContent()
			}
			else
			{
				; reuse the base function
				base.setvalue(value, parameterID)
			}
		}
		
		; change the available choices of the combobox
		setChoices(value)
		{
			global

			; copy some paramters in local variables
			local tempParameterID := this.parameter.id[1]
			
			; the value contains an array of choices. We need to convert it to delimited string
			tempAllChoices := ""
			for tempIndex, TempOneChoice in value
			{
				tempAllChoices .= "|" TempOneChoice
			}

			; keep the choices in variable
			this.par_choices := value
			
			; set the choices in control
			GUIControl, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%, % tempAllChoices
			return
		}
	}
	
	; field which contains a hotkey.
	class Hotkey extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempValue, tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			tempValue := ElementSettings.elementPars[tempParameterID]

			; this variable helps us to prevent that the glabels of both controls run in circles
			this.hotkeyControlValue := tempValue
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; add edit field, where use can enter any hotkey definition
			gui, add, edit, w300 x10 hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID%, %tempValue%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this

			; add hotkey field, where use can quickier define hotkeys
			gui, add, hotkey, w90 X+10 hwndtempHWND gGUISettingsOfElementHotkey vGUISettingsOfElement%tempParameterID%hotkey, %tempValue%
			this.components.push("GUISettingsOfElementHotkey" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
		
		; update the hotkey control if value has changed
		checkContent()
		{
			global
			; copy some parameters in local variables
			local tempParameterID := this.parameter.id[1]

			; get the value
			local tempValue := this.getvalue()

			; set the value in the hotkey control
			if (this.hotkeyControlValue != tempValue)
			{
				this.hotkeyControlValue := tempValue
				GUIControl, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%hotkey, % tempValue
			}
		}

		; update the value in controls
		setvalue(value, parameterID = "") ; override
		{
			; reuse the base function
			base.setvalue(value)

			; check the changed content
			this.checkContent()
		}

		; react if user changes the value in the hotkey field
		changeHotkey()
		{
			global
			local temp

			; copy some parameters in local variables
			local tempParameterID := this.parameter.id[1]

			; get value from hotkey control
			GUIControlGet, temp, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%hotkey
			this.hotkeyControlValue := temp

			; set hotkey in the edit control
			this.setValue(temp)
		}
	}
	
	; field which contains a button.
	class Button extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local temp, tempHWND
			
			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			
			; create the gui elements
			gui, font, s8 cDefault wnorm

			; add the button control
			gui, add, button, w400 x10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElement%tempParameterID%, % parameter.label
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
		
		; react if user clicks on the button
		clickOnButton()
		{
			global
			logger("a3", "Element Settings: Evaluating g-label of button: " this.parameter.goto)
			
			; copy some paramters in local variables
			local templabel := this.parameter.goto

			; check whether the goto parameter points to a valid label
			if (islabel(templabel))
			{
				; the goto parameter is a label. Gosub this label
				gosub, % templabel
			}
			else 
			{
				; the goto parameter is not a label. check whether the goto parameter points to a valid function
				local countpars := isfunc(templabel)
				if (countpars)
				{
					; the goto parameter is a function. Check its parameter count
					if (countpars = 1) ;No mandantory parameters
					{
						; the function has no parameters. Call it.
						%templabel%()
					}
					else if (countpars = 2) ;One mandantory parameter
					{
						; the function has one mandantory parameter. Pass the environment variable
						%templabel%({flowID: FlowID, elementID: ElementSettings.element})
					}
					else
					{
						logger("a0", "Parameter 'goto' ''" this.parameter.goto "'' points to a function which has too many parameters. (field class: " this.__Class ")", flowID)
					}
				}
				else
				{
					logger("a0", "Parameter 'goto' ''" this.parameter.goto "'' does not point to any valid label or function. (field class: " this.__Class ")", flowID)
				}
			}
		}
	}
	
	; field which contains a file path.
	class file extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempHWND
			
			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]

			; get the current value
			tempValue := ElementSettings.elementPars[tempParameterID] 
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; create an edit control
			gui, add, edit, w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, %tempValue%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
			
			; create a button control, which will open the file select dialog
			gui, add, button, w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%, ...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}

		; react if user clicks on the file select button
		clickOnButton()
		{
			global
			local tempfile, tempGUIControl
			
			; open the file select dialog
			FileSelectFile, tempfile, % this.parameter.options, % this.getvalue() ,% this.parameter.prompt, % this.parameter.filter
			
			if not errorlevel
			{
				; user has selected a file. Update the value
				this.setvalue(tempfile)
			}
		}
	}
	
	; field which contains a folder path.
	class folder extends ElementSettings.field
	{
		__new(parameter)
		{
			global

			; reuse base new() function
			base.__new(parameter)

			local tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			
			; get the current value
			tempValue := ElementSettings.elementPars[tempParameterID]

			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; create an edit control
			gui, add, edit, w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, %temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this

			; create a button control, which will open the folder select dialog
			gui, add, button, w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%, ...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
		
		; react if user clicks on the folder select button
		clickOnButton()
		{
			global
			local tempfile
			
			; open the folder select dialog
			FileSelectFolder, tempfile, % "*" this.getvalue(), this.parameter.options, % this.parameter.prompt
			
			if not errorlevel
			{
				; user has selected a folder. Update the value
				this.setvalue(tempfile)
			}
		}
	}
	
	; field which allows user to select weekdays.
	class weekdays extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local temp, tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]

			; get the current value
			tempValue := ElementSettings.elementPars[tempParameterID] 
			
			; create the gui elements
			gui, font, s8 cDefault wnorm
			
			; create an checkboxes for each weekday
			gui, add, checkbox, w45 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%2, % lang("Mon (Short for Monday")
			this.components.push("GUISettingsOfElement" tempParameterID "2")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%3, % lang("Tue (Short for Tuesday")
			this.components.push("GUISettingsOfElement" tempParameterID "3")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%4, % lang("Wed (Short for Wednesday")
			this.components.push("GUISettingsOfElement" tempParameterID "4")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%5, % lang("Thu (Short for Thursday")
			this.components.push("GUISettingsOfElement" tempParameterID "5")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%6, % lang("Fri (Short for Friday")
			this.components.push("GUISettingsOfElement" tempParameterID "6")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%7, % lang("Sat (Short for Saturday")
			this.components.push("GUISettingsOfElement" tempParameterID "7")
			ElementSettings.fieldHWNDs[tempHWND] := this
			gui, add, checkbox, w45 X+10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%1, % lang("Sun (Short for Sunday") ;Sunday is 1
			this.components.push("GUISettingsOfElement" tempParameterID "1")
			ElementSettings.fieldHWNDs[tempHWND] := this
			
			; check checkboxes with selected weekdays
			loop 7 ; loop through all weekdays
			{
				IfInString, tempValue, %a_index%
				{
					; weekday is in tempValue. Select the checkbox
					guicontrol, , GUISettingsOfElement%tempParameterID%%a_index%, 1
				}
			}
		}
		
		; get selected weekdays
		getvalue(parameterID = "") ; override
		{
			global

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]

			; Prepare result value
			local tempResult := ""
			loop 7 ; loop through all weekdays
			{
				; get the checkbox value
				GUIControlGet, tempValue, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%%a_index%
				if (tempValue = 1)
				{
					; value is selected. Append the index to the result value
					tempResult .= A_Index
				}
			}
			return tempResult
		}
		
		; set selected weekdays
		setvalue(value, parameterID = "")
		{
			global
			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]

			; check checkboxes with selected weekdays
			loop 7 ; loop through all weekdays
			{
				; Select the checkbox if weekday is in value. Unselect otherwise
				guicontrol, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%%a_index%, % (InStr(value, a_index) != 0)
			}
		}
	}
	
	; field which allows user to select date and / or time.
	class DateAndTime extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			; reuse base new() function
			base.__new(parameter)

			local tempHWND

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			local tempFormat := parameter.format

			; convert the tempFormat if it has a specific value
			if (tempFormat = "Time")
			{
				tempFormat := "Time"
			}
			else if (tempFormat = "Date")
			{
				tempFormat := "LongDate"
			}
			else if (tempFormat = "DateTime")
			{
				tempFormat := % "'" lang("Date") ":' " lang("MM/dd/yy") "   '" lang("Time") ":' " lang("HH:mm:ss")
			}
			
			; get the current value
			tempValue := ElementSettings.elementPars[tempParameterID] 
			; set to current time, if current value is empty
			if (tempValue = "")
			{
				tempValue := a_now
			}

			; create the gui elements
			gui, font, s8 cDefault wnorm

			; create an datetime control
			gui, add, DateTime, w400 x10 choose%temp% gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID% ,% tempFormat
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
		}
	}
	
	; field which contains a dropdown.
	class listbox extends ElementSettings.field
	{
		__new(parameter)
		{
			global

			; reuse base new() function
			base.__new(parameter)

			local tempHWND, tempSort, tempMulti, tempChosenNumbers, tempAltSubmit, tempChoicesString

			; copy some paramters in local variables
			local tempParameterID := parameter.id[1]
			
			local tempChosen := ElementSettings.elementPars[tempParameterID] 
			local tempChoices := parameter.choices

			; the choices can be set after the control was created. We will save the initial value
			this.par_choices := tempChoices

			;loop through all choices. Make a selection list which is suitable for the gui,add command
			local tempAllChoices := ""
			for tempIndex, TempOneChoice in this.par_choices
			{
				tempAllChoices .= "|" TempOneChoice
			}
			StringTrimLeft, tempAllChoices, tempAllChoices, 1
			
			; decide whether we need the multi keyword
			local tempMulti := ""
			if (parameter.multi)
				tempMulti :="multi"

			; decide whether we need the sort keyword
			local tempSort := ""
			if (parameter.Sort)
				tempSort :="Sort"

			; decide whether we need the altSubmit keyword
			tempAltSubmit := ""
			if (parameter.result != "number")
			{
				tempAltSubmit:="altSubmit"
			}
			
			; create the gui elements
			gui, font, s8 cDefault wnorm

			; add the listbox control
			gui, add, listbox, w400 x10 %tempMulti% %tempSort% %tempAltSubmit% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%, %tempAllChoices%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND] := this
			
			; set the value
			this.setvalue(tempChosen)
		}
		
		; get value of the listbox
		getvalue(parameterID = "") ; override
		{
			global
			local tempChosen

			; copy some paramters in local variables
			local tempParameterID := this.parameter.id[1]
			
			; get the chosen value
			GUIControlGet, tempChosen, GUISettingsOfElement:, GUISettingsOfElement%tempParameterID%
			
			; convert the pipe delimited string to array
			local tempChosenObj := Object()
			loop, parse, tempChosen, |
			{
				tempChosenObj.push(A_LoopField)
			}

			return tempChosenObj
		}
		
		; set value of the listbox
		setvalue(value, parameterID = "") ; override
		{
			global
			local tempChosenNumbers, tempChoices, tempChosenStrings, tempChosen

			; copy some paramters in local variables
			local tempParameterID := this.parameter.id[1]
		
			; first deselect all entries
			GuiControl, GUISettingsOfElement:Choose, GUISettingsOfElement%tempParameterID%, 0

			if (this.par_result = "string")
			{
				; we need to select all strings in list "value"
				local found := false
				for tempindexChosen, tempLabelChosen in value
				{
					for tempindexChoice, tempLabelChoice in this.choices
					{
						if (tempLabelChoice = tempLabelChosen)
						{
							GUIControl, GUISettingsOfElement:Choose, GUISettingsOfElement%tempParameterID%, % tempindexChoice
							found := true
						}
					}
				}

				if not found
				{
					logger("a0", "cannot set value. Value '" value "' is not in list (field class: " this.__Class ", first paramter ID: " this.parameterIds[1] ")")
				}
			}
			else
			{
				; we need to select all indices in list "value"
				for tempindexChosen, tempNumberChosen in value
				{
					GUIControl, GUISettingsOfElement:Choose, GUISettingsOfElement%tempParameterID%, % tempNumberChosen
				}
			}

			; update some general values (e.g. element name)
			elementSettings.generalUpdate()
		}
	}
	


	;Get all values which are currently edited.
	getAllValues()
	{
		global
		local oneFieldIndex, oneField, oneParameterIndex, oneParameterID

		; prepare return value
		local tempPars := Object()

		; loop through all fields
		for oneFieldIndex, oneField in this.fields
		{
			; loop through all parameter IDs in the field
			for oneParameterIndex, oneParameterID in oneField.parameterIds
			{
				; get the parameter value from the field
				tempPars[oneParameterID] := oneField.getValue(oneParameterID)
			}
		}

		return tempPars
	}
	
	
	
	;Update the name field, check settings
	; firstCall: if set, the call x_FirstCallOfCheckSettings() of the element api will return true
	generalUpdate(firstCall = False)
	{
		global

		; prevent multiple general updates at once (part 1)
		if (ElementSettings.generalUpdateRunning)
		{
			return
		}
		ElementSettings.generalUpdateRunning := True

		; remove tooltip (if any) todo: why?
		GUISettingsOfElementRemoveInfoTooltip()
		
		; save the firstCall property. x_FirstCallOfCheckSettings() will return true
		_setElementProperty(FlowID, ElementSettings.element, "FirstCallOfCheckSettings", firstCall)

		; get all parameter values
		allParamValues := ElementSettings.getAllValues()

		; let the element function Element_CheckSettings_xxx check the settings
		setElementClass := ElementSettings.elementClass
		Element_CheckSettings_%setElementClass%({FlowID: FlowID, ElementID: ElementSettings.element}, allParamValues)
		
		; update the element name
		ElementSettings.NameField.updatename(allParamValues)
		
		; prevent multiple general updates at once (part 2)
		ElementSettings.generalUpdateRunning := False
	}
	
	; disable the element settings gui
	disable()
	{
		global
		
		gui, GUISettingsOfElement: +disabled
	}

	; enable the element setting gui
	enable()
	{
		global
		
		gui, GUISettingsOfElement: -disabled
		WinActivate, ahk_id %global_SettingWindowHWND%
	}
	
	; Close element settings gui
	close()
	{
		global
		
		; close help (if shown)
		ui_closeHelp() 
		
		; destroy the element settings gui
		gui, GUISettingsOfElement: destroy
		gui, GUISettingsOfElementParent: destroy
		
		; remove any tooltip (if shown)
		GUISettingsOfElementRemoveInfoTooltip()

		; disable task timer
		settimer, GUISettingsOfElementTaskTimer, off
		
		; enable editor gui
		EditGUIEnable()

		; delete some variables
		this.fields := ""
		this.fieldHWNDs := ""
		this.fieldParIDs := ""
		this.ElementID := ""
		this.ElementType := ""
		this.ElementClass := ""
		this.ElementPars := ""
		this.NameField := ""
	}
}


; removes any tooltip (if shown)
GUISettingsOfElementRemoveInfoTooltip()
{
	ToolTip,,,,11
}

;Called when the GUI is resized by user
GUISettingsOfElementParentSize(GuiHwnd, EventInfo, Width, Height)
{
	global
	
	If (EventInfo <> 1) ;if not minimized
	{
		; faster execution
		SetWinDelay, 0

		; Sometimes for some reason the width and height parameters are not correct. therefore get the gui size again
		GetClientSize(global_SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH)

		; move buttons save and cancel
		guicontrol, GUISettingsOfElementParent: move, ButtonSave, % "y" ElSetingGUIH - 40
		guicontrol, GUISettingsOfElementParent: move, ButtonCancel, % "y" ElSetingGUIH - 40

		; change size of the inner scrollable gui
		winmove, % "ahk_id " global_SettingWindowHWND, , 0, 30, , % ElSetingGUIH - 90
	}
}


; forward some glabel calls
GUISettingsOfElementSelectType()
{
	ElementSettings.GUISettingsOfElementSelectType()
}
GUISettingsOfElementHelp()
{
	ElementSettings.GUISettingsOfElementHelp()
}
GUISettingsOfElementParentClose()
{
	ElementSettings.GUISettingsOfElementCancel()
}
GUISettingsOfElementParentEscape()
{
	ElementSettings.GUISettingsOfElementCancel()
}
GUISettingsOfElementCancel()
{
	ElementSettings.GUISettingsOfElementCancel()
}
GUISettingsOfElementSave()
{
	ElementSettings.GUISettingsOfElementSave()
}
GUISettingsOfElementChangeRadio(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("updateContentTypePicture", CtrlHwnd)
}
GUISettingsOfElementCheckContent(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("CheckContent", CtrlHwnd)
}
GUISettingsOfElementCheckStandardName(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("GeneralUpdate", CtrlHwnd)
}
GUISettingsOfElementGeneralUpdate(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("GeneralUpdate", CtrlHwnd)
}
GUISettingsOfElementClickOnWarningPic(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("ClickOnWarningPic", CtrlHwnd)
}
GUISettingsOfElementClickOnInfoPic(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("ClickOnInfoPic", CtrlHwnd)
}
GUISettingsOfElementSliderChangeEdit(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("SliderChangeEdit", CtrlHwnd)
}
GUISettingsOfElementSliderChangeSlide(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("SliderChangeSlide", CtrlHwnd)
}	
GUISettingsOfElementHotkey(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("ChangeHotkey", CtrlHwnd)
}
GUISettingsOfElementButton(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	GUISettingsOfElementAddTask("ClickOnButton", CtrlHwnd)
}

; ensure a quick return time on user input, to ensure that we do not miss something
; fill the task which results from the user input in a list
GUISettingsOfElementAddTask(task, hwnd)
{
	if (not task or not hwnd)
		throw exception("GUISettingsOfElementAddTask: task or hand is empty")

	; check whether the task already exist in list. We do not need duplicates
	for oneIndex, oneTask in ElementSettings.tasks
	{
		if (oneTask.task = task and oneTask.hwnd = hwnd)
			return
	}

	; add the task to the list
	ElementSettings.tasks.push({task: task, hwnd: hwnd})

	; set timer to react on the user input
	settimer, GUISettingsOfElementTaskTimer, 1
}

; timer function where the user input is processed
GUISettingsOfElementTaskTimer()
{
	; get a task from the list
	oneTask := ElementSettings.tasks.pop()

	if (oneTask)
	{
		; we got a task. We can now perform the task
		if (oneTask.task = "CheckContent")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].checkcontent()
		}
		else if (oneTask.task = "updateContentTypePicture")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].updateContentTypePicture()
		}
		else if (oneTask.task = "GeneralUpdate")
		{
			ElementSettings.GeneralUpdate()
		}
		else if (oneTask.task = "ClickOnWarningPic")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].ClickOnWarningPic()
		}
		else if (oneTask.task = "ClickOnInfoPic")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].ClickOnInfoPic()
		}
		else if (oneTask.task = "SliderChangeEdit")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].SliderChangeEdit()
		}
		else if (oneTask.task = "SliderChangeSlide")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].SliderChangeSlide()
		}
		else if (oneTask.task = "ChangeHotkey")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].ChangeHotkey()
		}
		else if (oneTask.task = "ClickOnButton")
		{
			ElementSettings.fieldHWNDs[oneTask.hwnd].ClickOnButton()
		}
		Else
		{
			throw exception("GUISettingsOfElementTaskTimer: unknown task '" oneTask.task "'")
		}
	}
	Else
	{
		; the task list is empty, we can stop the timer.
		settimer, GUISettingsOfElementTaskTimer, off
	}
}