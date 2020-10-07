;Needed translations which we will use indirectly. Those calls will make the lang crawler to add them to the translation list.
temp := lang("Trigger")
temp := lang("Action")
temp := lang("Condition")
temp := lang("Loop")

global global_SettingWindowParentHWND
global global_global_SettingWindowHWND

class ElementSettings
{
	;Open GUI for settings parameters of an element.
	open(setElementID, wait="", alreadyChangedSomething = 0)
	{
		global
		local temp, tempYPos, tempXPos, tempEditwidth, tempIsDefault, tempAssigned, tempChecked, tempMakeNewGroup, temptoChoose, tempAltSumbit, tempChoises, tempAllChoices, tempParameterOptions, tempres, tempelement

		this.changes := alreadyChangedSomething ;will be incremented if a change will be detected

		this.element := setElementID

		; create some global variables
		this.elementType := _getElementProperty(FlowID, this.element, "type")
		this.elementClass := _getElementProperty(FlowID, this.element, "Class")
		this.elementName := _getElementProperty(FlowID, this.element, "Name")
		this.elementPars := _getElementProperty(FlowID, this.element, "pars")

		this.wait := wait
		
		NowResultEditingElement := ""
		
		this.fields:={} ;global. contains the fields which will be shown in the GUI. Each field is a bunch of controls
		this.fieldHWNDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		this.fieldParIDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		
		EditGUIDisable()
		
		;block general update
		this.initializing := true
		this.generalUpdateRunning:=true
		
		;Create a scrollable Child GUI will almost all controls
		gui,GUISettingsOfElement:default
		gui +hwndglobal_SettingWindowHWND
		gui +vscroll
		gui,-DPIScale

		global_CurrentlyActiveWindowHWND:=global_SettingWindowHWND
		
		;Get the parameter list
		this.parametersToEdit:=Element_getParametrizationDetails(this.elementClass, {flowID: FlowID, elementID: this.elementID, updateOnEdit: true})

		;All elements have the parameter "name" and "StandardName"
		this.fields.push(new this.label({label: lang("name (name)")}))
		this.fields.push(new this.name({id: ["name", "StandardName"]}))
		
		
		;Loop through all parameters
		for index, parameter in this.parametersToEdit
		{
			;Add one or a group of controls. This is done dynamically, dependent on the parameters
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
		
		
		
		
		; Create the parent window which contains some always visible controls (which are not scrolled away)
		Gui, GUISettingsOfElementParent:New
		gui, GUISettingsOfElementParent:-DPIScale
		Gui, GUISettingsOfElementParent:Margin, 0, 20
		gui,GUISettingsOfElementParent:+resize
		gui,GUISettingsOfElementParent:+hwndglobal_SettingWindowParentHWND
		gui,GUISettingsOfElementParent:+LabelGUISettingsOfElementParent
		
		;Make the child window appear inside the parent window
		Gui, GUISettingsOfElement:-Caption
		Gui, GUISettingsOfElement:+parentGUISettingsOfElementParent
		gui, GUISettingsOfElement:show,x0 y20
		
		
		;Get the size of the child window
		WinGetPos, , , WsettingsChild, HsettingsChild,% "ahk_id " global_SettingWindowHWND
		Winmove,% "ahk_id " global_SettingWindowHWND, ,, , % WsettingsChild + 10, % HsettingsChild
		WinGetPos, , , WsettingsChild, HsettingsChild,% "ahk_id " global_SettingWindowHWND
		
		;Calculate the position of controls which are outside the child window (this is temporary calculation. it will be recalculated in the size-routine)
		YsettingsButtoPos := HsettingsChild + 30
		HSettingsParent:=HsettingsChild + 90
		WSettingsParent:=WsettingsChild
		;~ MsgBox %HSettingsParent% - %WSettingsParent% , %YsettingsButtoPos%
		
		;Define minimal and maximal size of the parent window
		gui,GUISettingsOfElementParent:+minsize%WSettingsParent%x200 ;Ensure constant width.
		gui,GUISettingsOfElementParent:+maxsize%WSettingsParent%x%HSettingsParent%
		
		
		
		;add buttons
		gui,GUISettingsOfElementParent:font,s8 cDefault wnorm
		setElementClass := this.elementClass
		gui, GUISettingsOfElementParent:add,button, w370 x10 y10 gGUISettingsOfElementSelectType h20,% lang("%1%_type:_%2%",lang(this.elementType),Element_getName_%setElementClass%())
		gui, GUISettingsOfElementParent:add,button, w20 X+10 yp h20 gGUISettingsOfElementHelp vGUISettingsOfElementHelp,?
		;~ guicontrol,focus,GUISettingsOfElementHelp
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementSave vButtonSave w145 x10 h30 y%YsettingsButtoPos%,% lang("Save")
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementCancel vButtonCancel default w145 h30 yp X+10,% lang("Cancel")
		;Make GUI autosizing
		setElementClass := this.elementClass
		Gui, GUISettingsOfElementParent:Show, hide w%WSettingsParent%,% lang("Settings") " - " lang(this.elementType) " - " Element_getName_%setElementClass%()
		
		_setShared("hwnds.ElementSettingsChild" FlowID, global_SettingWindowHWND)
		_setShared("hwnds.ElementSettingsParent" FlowID, global_SettingWindowParentHWND)
		
		;Calculate position to show the settings window in the middle of the main window
		pos:=EditGUIGetPos()
		tempHeight:=round(pos.h-100) ;This will be the max height. If child gui is larger, it must be scrolled
		DetectHiddenWindows,on
		WinGetPos,ElSetingGUIX,ElSetingGUIY,ElSetingGUIW,ElSetingGUIH,ahk_id %global_SettingWindowParentHWND%
		if (ElSetingGUIH < tempHeight)
			tempHeight := ElSetingGUIH
		tempXpos:=round(pos.x+pos.w/2- ElSetingGUIW/2)
		tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
		
		;move Parent window
		gui,GUISettingsOfElementParent:show,% "x" tempXpos " y" tempYpos " h" tempHeight " hide" 
		
		
		;position lower buttons
		wingetpos,,,ElSetingGUIW,ElSetingGUIH, ahk_id %global_SettingWindowParentHWND%
		WinMove,ahk_id %global_SettingWindowParentHWND%,,,,% ElSetingGUIW,% ElSetingGUIH+1 ;make the autosize function trigger, which resizes and moves the scrollgui
		
		
		
		global_CurrentlyActiveWindowHWND:=global_SettingWindowParentHWND
		
		this.initializing:=false
		
		
		gui,GUISettingsOfElementParent:show
		
		;release general update
		this.generalUpdateRunning:=false
		this.generalUpdate(True)
		
		if (wait=1 or wait="wait") ;Wait until user closes the window
		{
			Loop
			{
				if (NowResultEditingElement="") ;This variable will be set when user closes the window
					sleep 10
				else 
					break
			}
		}
		return NowResultEditingElement
		
		
		;If user wants to change the subtype of the element
		GUISettingsOfElementSelectType:
		gui,GUISettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		ui_closeHelp() 
		EditGUIEnable()
		
		tempres:=selectSubType(ElementSettings.element, "wait")
		if tempres!=aborted
		{
			NowResultEditingElement:= ElementSettings.open(ElementSettings.element, ElementSettings.wait, true)
		}
		else 
		{
			NowResultEditingElement:="aborted"
			return
		}
		return
		
		GUISettingsOfElementHelp:
		IfWinExist,ahk_id %GUIHelpHWND%
			ui_closeHelp()
		else
			ui_showHelp(ElementSettings.element)
		return
		
		
		
		
		
		GUISettingsOfElementParentClose:
		GUISettingsOfElementParentEscape:
		GUISettingsOfElementCancel:
		;~ ToolTip %a_thislabel%
		; todo: undo of changed is not needed
		if (ElementSettings.elementName="Νew Соntainȩr" or ElementSettings.elementName="Νew Triggȩr") ;Delete the element if it was newly created
		{
			_deleteElement(FlowID, ElementSettings.element)
		}
		
		previousSubType := _getElementProperty(FlowID, ElementSettings.element, "previousSubType")
		if (element.previousSubType) ;restore previous subtype of element if it was changed recently
		{
			_setElementProperty(FlowID, ElementSettings.element, "SubType", previousSubType)
			_deleteElementProperty(FlowID, ElementSettings.element, "previousSubType")
		}
		
		ui_closeHelp() 
		
		gui,GUISettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		NowResultEditingElement:="aborted"
		ElementSettings.close()
		return
		
		
		
		GUISettingsOfElementSave:
		_EnterCriticalSection()
		
		ElementSettings.generalUpdate()
		;~ gui,GUISettingsOfElement:submit
		
		if (ElementSettings.elementType="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
		{
			tempReenablethen:=true
			;r_EnableFlow() ;TODO ;Disable flow
		}
		else
			tempReenablethen:=false
		
		;Save the parameters
		_setElementProperty(FlowID, ElementSettings.element, "Name", ElementSettingsNameField.getValue("Name"))
		_setElementProperty(FlowID, ElementSettings.element, "StandardName", ElementSettingsNameField.getValue("StandardName"))
		
		;~ MsgBox % strobj(parametersToEdit)
		for ElementSaveindex, parameter in ElementSettings.parametersToEdit
		{
			if not IsObject(parameter.id)
				parameterID:=[parameter.id]
			else
				parameterID:=parameter.id
			;~ MsgBox % strobj(parameterID)
			if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label do nothing
				continue
			;~ MsgBox % strobj(parameterID)
			
			;The edit control can also have parameter names which are specified in key "ContentID"
			if (IsObject(oneField.parameter.ContentID))
			{
				tempParameterID.push(oneField.parameter.ContentID[1])
			}
			else if (parameter.ContentID)
			{
				tempParameterID.push(oneField.parameter.ContentID)
			}
					
			
			;Certain types of control consist of multiple controls and thus contain multiple parameters.
			for ElementSaveindex2, oneID in parameterID
			{
				tempOneParID:=parameterID[ElementSaveindex2]
				temponeValue:=ElementSettings.fieldParIDs[tempOneParID].getValue(tempOneParID)
				tempOldValue := _getElementProperty(FlowID, ElementSettings.element, "pars." tempOneParID)
				if (tempOldValue!=temponeValue)
					ElementSettings.changes++

				_setElementProperty(FlowID, ElementSettings.element, "pars." tempOneParID, temponeValue)
				
			
			}
			
		}
		
		_LeaveCriticalSection()
		
		temponeValue:=""
		
		ui_closeHelp() 
		gui,GUISettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		

		NowResultEditingElement:=ElementSettings.changes " Changes"
		
		;if (tempReenablethen) ;TODO
			;r_EnableFlow()
		
		
		
		API_Draw_Draw(FlowID)
		ElementSettings.close()
		return
		
	}
	
	
	
	
	;The fields will be added to the GUI. This class contains common methods
	class field
	{
		__new(parameter)
		{
			global
			this.parameter:=parameter
			this.components:=[]
			this.enabled:=1
			if (isobject(parameter.id))
			{
				for index, onepar in parameter.id
				{
					ElementSettings.fieldParIDs[onepar]:=this
				}
			}
			else if (parameter.id!="")
				ElementSettings.fieldParIDs[parameter.id]:=this
			if (isobject(parameter.contentid))
			{
				for index, onepar in parameter.contentid
				{
					ElementSettings.fieldParIDs[onepar]:=this
				}
			}
			else if (parameter.contentid!="")
				ElementSettings.fieldParIDs[parameter.contentid]:=this
		}
		
		;Get value of a field. 
		;If parameterID is empty, the first (or the only) parameter of the field will be retrieved
		;If parameterID is set, this function will check whether the curernt object instance has the parameterID and then get it,
		;otherwise it will find the object which contains the parameterID and call its getvalue() function.
		getvalue(parameterID="")
		{
			global
			;~ d(this, "getvalue " parameterID)
			local temp, tempParameterID, value, oneindex, oneid, oneField
			if parameterID=
			{
				;Set value of first parameter it
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				;~ d(this, "getvalue 1 " tempParameterID)
				GUIControlGet,temp,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%
				return temp
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID:=this.parameter.id
				if ((not isobject(tempParameterID)) and tempParameterID != "")
					tempParameterID:=[tempParameterID]
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, get value
						;~ d(this, "getvalue 2 " parameterID)
						GUIControlGet,temp,GUISettingsOfElement:,GUISettingsOfElement%oneid%
						return temp
					}
				}
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettings.fields
				{
					;make list of all available parameter ID of oneField object
					tempParameterID:=oneField.parameter.id
					if ((not isobject(tempParameterID)) and tempParameterID != "")
						tempParameterID:=[tempParameterID]
					
					;The edit control can also have parameter names which are specified in key "ContentID"
					if (IsObject(oneField.parameter.ContentID))
					{
						tempParameterID.push(oneField.parameter.ContentID[1])
					}
					else if (parameter.ContentID)
					{
						tempParameterID.push(oneField.parameter.ContentID)
					}
					
					for oneindex, oneid in tempParameterID
					{
						if (oneid = parameterID)
						{
							;~ d(this, "getvalue call " parameterID)
							value:=onefield.getvalue(parameterID)
							return value
						}
					}
					
				}
			}
			return 
		}
		
		setvalue(value, parameterID="")
		{
			global
			;~ d(this, "setvalue " parameterID)
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				;~ d(this, "setvalue 1 " tempParameterID ": " value)
				GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
				return
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID:=this.parameter.id
				if ((not isobject(tempParameterID)) and tempParameterID != "")
					tempParameterID:=[tempParameterID]
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, set value
						;~ d(this, "setvalue 2 " parameterID)
						GUIControl,GUISettingsOfElement:,GUISettingsOfElement%oneid%,% value
						return
					}
				}
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettings.fields
				{
					;make list of all available parameter ID of oneField object
					tempParameterID:=oneField.parameter.id
					if ((not isobject(tempParameterID)) and tempParameterID != "")
					tempParameterID:=[tempParameterID]
					
					for oneindex, oneid in tempParameterID
					{
						if (oneid = parameterID)
						{
							;~ d(this, "setvalue call " parameterID)
							value:=onefield.setvalue(value, parameterID)
							return value
						}
					}
					
				}
				
			}
			
			return
		}
		
		
		setChoices(value, parameterID="")
		{
			global
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				;~ MsgBox not implemented
				;Not implemented here. must be implemented in the extended classes
			}
			else
			{
				tempParameterID:=this.parameter.id
				if not isobject(tempParameterID)
					tempParameterID:=[tempParameterID]
				
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettings.fields
				{
					;make list of all available parameter ID of oneField object
					tempParameterID:=oneField.parameter.id
					if ((not isobject(tempParameterID)) and tempParameterID != "")
						tempParameterID:=[tempParameterID]
					
					for oneindex, oneid in tempParameterID
					{
						if (oneid = parameterID)
						{
							onefield.setChoices(value, parameterID)
							return value
						}
					}
					
				}
			}
		}
		
		setLabel(value, parameterID="")
		{
			global
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				;~ MsgBox not implemented
				;Not implemented here. must be implemented in the extended classes
			}
			else
			{
				tempParameterID:=this.parameter.id
				if not isobject(tempParameterID)
					tempParameterID:=[tempParameterID]
				
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettings.fields
				{
					;make list of all available parameter ID of oneField object
					tempParameterID:=oneField.parameter.id
					if ((not isobject(tempParameterID)) and tempParameterID != "")
						tempParameterID:=[tempParameterID]
					
					for oneindex, oneid in tempParameterID
					{
						if (oneid = parameterID)
						{
							onefield.setLabel(value, parameterID)
							return value
						}
					}
					
				}
			}
		}
		
		enable(parameterID="",enOrDis=1)
		{
			global
			
			;~ d(this, "enable " parameterID)
			;if parameterID is empty, disable all components
			if parameterID=
			{
				;~ d(this, "enable 1 " parameterID)
				;enable all components
				for index, component in this.components
				{
					guicontrol,GUISettingsOfElement:enable%enOrDis%,% component
				}
				this.enabled:=enOrDis
			}
			else
			{
				;make list of all available parameter ID of this object
				tempParameterID:=this.parameter.id
				if ((not isobject(tempParameterID)) and tempParameterID != "")
					tempParameterID:=[tempParameterID]
				
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in tempParameterID
				{
					if (parameterID = oneid)
					{
						;if so, get value
						;~ d(this, "enable 2 " parameterID)
						;enable all components
						for index, component in this.components
						{
							guicontrol,GUISettingsOfElement:enable%enOrDis%,% component
						}
						if (this.enabled != enOrDis)
						{
							this.enabled:=enOrDis
							this.checkContent()
						}
						return
					}
				}
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettings.fields
				{
					;make list of all available parameter ID of oneField object
					tempParameterID:=oneField.parameter.id
					if ((not isobject(tempParameterID)) and tempParameterID != "")
						tempParameterID:=[tempParameterID]
					
					for oneindex, oneid in tempParameterID
					{
						if (oneid = parameterID)
						{
							;~ d(this, "enable call " parameterID)
							value:=onefield.enable(parameterID, enOrDis)
							return value
						}
					}
					
				}
				
			}
			
			;~ d(this, "enable end " parameterID)
		}
		disable(parameterID="")
		{
			this.enable(parameterID,0)
		}
		
		
		ClickOnWarningPic()
		{
			;~ MsgBox gaga 
			ToolTip,% this.warningtext,,,11
			settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
		}
		
	}
	
	
	class name extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local tempchecked, temptext, tempParGray, tempHWND
			local tempParameterID:=parameter.id
			ElementSettingsNameField:=this
			
			gui,font,s8 cDefault wnorm
			
			tempchecked:= _getElementProperty(FlowID, ElementSettings.element, "StandardName")
			
			gui,add,checkbox, x10 hwndtempHWND checked%tempchecked% vGUISettingsOfElementStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
			this.components.push("GUISettingsOfElementStandardName")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,edit,w400 x10 Multi r5 hwndtempHWND vGUISettingsOfElementName gGUISettingsOfElementGeneralUpdate,% ElementSettings.elementName
			this.components.push("GUISettingsOfElementName")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			
		}
		
		
		updateName(p_CurrentPars)
		{
			global
			local Newname
			if (ElementSettings.initializing=true)
				return
			if (this.getvalue("StandardName")=1)
			{
				this.disable("Name")
				setElementClass := ElementSettings.elementClass
				Newname:=Element_GenerateName_%setElementClass%({flowID: FlowID, ElementID: ElementSettings.element}, p_CurrentPars) 
				StringReplace,Newname,Newname,`n,%a_space%-%a_space%,all
				this.setvalue(Newname, "Name")
			}
			else
				this.enable("Name")
			return
			
		}
	}

	
	class label extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local tempYPos
			local tempParameterID:=parameter.id
			if (parameter.size="small")
			{
				gui,font,s8 cDefault wbold
				tempYPos=
			}
			else
			{
				gui,font,s10 cnavy wbold
				tempYPos=Y+15
			}
			if (tempParameterID!="")
			{
				gui,add,text,x10 w400 %tempYPos% vGUISettingsOfElement%tempParameterID% ,% parameter.label
				this.components.push("GUISettingsOfElement" tempParameterID)
			}
			else
			{
				gui,add,text,x10 w400 %tempYPos%,% parameter.label
			}
		}
		
		setLabel(value, parameterID="")
		{
			global
			local tempParameterID, 
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			
			GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
			return
		}
		
	}
	class checkbox extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptext, tempParGray, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[parameter.id] 
			temptext:=parameter.label
			if parameter.gray
				tempParGray=check3
			else
				tempParGray=
			gui,add,checkbox,w400 x10 %tempParGray% checked%temp% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
		}
		
		setLabel(value, parameterID="")
		{
			global
			local tempParameterID, 
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			
			GUIControl,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
			return
		}
	}
	
	class radio extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local tempAssigned, tempMakeNewGroup, tempChecked, temp, tempHWND
			local tempParameterID:=parameter.id
			local hasEnum
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			tempAssigned:=false
			for tempindex, tempRadioLabel in parameter.choices
			{
				if a_index=1
					tempMakeNewGroup=Group
				else
					tempMakeNewGroup=
				
				if (temp=a_index or temp = parameter.Enum[a_index])
				{
					tempChecked=checked
					tempAssigned:=true
				}
				else
					tempChecked=
					
				gui,add,radio, w400 x10 %tempChecked% %tempMakeNewGroup% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%%a_index% ,% tempRadioLabel
				this.components.push("GUISettingsOfElement" tempParameterID a_index)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
			}
			if (tempAssigned=false) ;Catch if a wrong value was saved and set to default value. 
			;TODO: is this a good idea? If this happens and user opens the settings window, he might erroneously thing that everything is ok.
			{
				
				temp:=parameter.default
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%%temp%,1
			}
		}
		
		getvalue()
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			
			loop % this.parameter.choices.MaxIndex()
			{
				guicontrolget,temp,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%%a_index%
				if (temp=1)
				{
					if (this.parameter.result = "enum")
					{
						temp:=this.parameter.Enum[a_index]
					}
					else
					{
						temp:=A_Index
					}
					break
				}
			}
			
			return temp
		}
		setvalue(value)
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			if not (value >= 1 and value <= this.parameter.choices.MaxIndex())
			{
				 ;This might be an enum value
				if (IsObject(this.parameter.Enum))
				{
					loop % this.parameter.choices.MaxIndex()
					{
						if (this.parameter.Enum[a_index] = value)
						{
							temp := a_index
							break
						}
					}
				}
			}
			else
			{
				temp:=A_Index
			}
			GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%%temp%,1
			return temp
		}
		
		
		setLabel(value, parameterID="")
		{
			global
			local tempParameterID, 
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			
			GUIControl,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
			return
		}
	}
	
	class edit extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptext, tempIsMulti, tempXpos,tempEditwidth, tempHWND, tempContentTypeID, tempContentTypeNum, tempFirstParameterID, tempchecked1, tempchecked2, tempassigned, tempContentDefault
			local tempwAvailable, tempw
			local oneindex, onevalue
			if (not IsObject(parameter.id)) ;convert to object if it is a string
				parameter.id:=[parameter.id] 
			local tempParameterID:=parameter.id
			local tempFirstParameterID:=parameter.id[1]
			if (not IsObject(parameter.default)) ;convert to object if it is a string
				parameter.default:=[parameter.default]
			local tempParameterdefault:=parameter.default
			if (not IsObject(parameter.content)) ;convert to object if it is a string
				parameter.content:=[parameter.content]
			local tempParameterContentType:=parameter.content
			if (IsObject(parameter.contentID)) ;Convert to string if it is object
				parameter.contentID:=parameter.contentID[1]
			local tempParameterContentTypeID:=parameter.contentID
			if (IsObject(parameter.contentDefault)) ;Convert to string if it is object
				parameter.contentDefault:=parameter.contentDefault[1]
			local tempParameterContentTypeDefault:=parameter.contentDefault
			
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			this.contentTypeLangs:={string: lang("This is a string"), rawString: lang("This is a raw string"), expression: lang("This is an expression"), VarName: lang("This is a variable name")}
			this.currentContentType:=""
			
			gui,font,s8 cDefault wnorm
			
			if (parameter.content.MaxIndex() > 1) ;If the input type is selectable
			{
				if (not parameter.contentID)
				{
					MsgBox Error creating edit field: Multiple contents should be possible but the content ID is not specified.
					return
				}
				
				tempContentTypeNum:=ElementSettings.elementPars[tempParameterContentTypeID] ;get the saved parameter
				if tempContentTypeNum is not number ;Get the index of the content type
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
				
				tempAssigned:=false
				loop % parameter.content.maxindex()
				{
					if a_index = 1
						tempgrpStr:="Group"
					else
						tempgrpStr:=""
					
					if (a_index = tempContentTypeNum)
					{
						tempchecked:="checked"
						tempAssigned:=true
					}
					else
					{
						tempchecked:=""
					}
					
					gui,add,radio, w400 x10 %tempchecked% %tempgrpStr% hwndtempHWND gGUISettingsOfElementChangeRadio vGUISettingsOfElement%tempParameterContentTypeID%%A_Index% ,% this.contentTypeLangs[parameter.content[a_index]]
					this.components.push("GUISettingsOfElement" tempParameterContentTypeID a_index)
					ElementSettings.fieldHWNDs[tempHWND]:=this
					
				}
				
				if (tempAssigned=false) ;Catch if a wrong value or no was saved and set to default value.
				{
					tempContentDefault:=parameter.contentDefault
					if not tempContentDefault
						tempContentDefault:=1
					this.setvalue(tempContentDefault,tempParameterContentTypeID)
					this.ContentType:=this.getvalue(tempParameterContentTypeID)
				}
			}
			else
			{
				this.ContentType:=parameter.content[1]
			}
			
			;Add picture, which will warn user if the entry is obviously invalid
			gui,add,picture,x394 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempFirstParameterID%
			this.components.push("GUISettingsOfElementWarningIconOf" tempFirstParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			
			;The info icon tells user which conent type it is
			tempselectedContentType:=parameter.content[1]
			gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempFirstParameterID%,%_ScriptDir%\icons\%tempselectedContentType%.ico
			this.components.push("GUISettingsOfElementInfoIconOf" tempFirstParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			
			loop % parameter.id.MaxIndex()
			{
				tempOneParameterID:=parameter.id[a_index]
				;Add the edit control(s)
				tempwAvailable:=360
				tempw:=(tempwAvailable - (4 * (parameter.id.MaxIndex() -1)) ) / parameter.id.MaxIndex()
				temptext:=ElementSettings.elementPars[tempOneParameterID]
				
				gui,add,edit,X+4 w%tempw% %tempIsMulti% r1 hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
				this.components.push("GUISettingsOfElement" tempOneParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				if (parameter.id.MaxIndex() = 1 and tempParameterContentType[1] = "expression")
				{
					;If this a single expression, user may want to add arrow keys
					if (parameter.useupdown)
					{
						if (parameter.range)
							gui,add,updown,% "range" parameter.range
						else
							gui,add,updown
						guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempOneParameterID%,%temptext%
					}
				}
			}
			
			this.changeRadio()
			
			
		}
		
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if (parameterID and parameterID=this.parameter.contentID)
			{
				loop % this.parameter.content.MaxIndex()
				{
					GUIControlGet,temp,GUISettingsOfElement:,GUISettingsOfElement%parameterID%%a_index%
					if temp=1
					{
						temp := this.parameter.content[ a_index]
						;~ d(temp ,a_index " - "  parameterID)
						break
					}
				}
				;~ d(temp ,parameterID "  return")
				return temp
			}
			else
			{
				if parameterID=
				{
					tempParameterID:=this.parameter.id
					if IsObject(tempParameterID)
						tempParameterID:=tempParameterID[1]
				}
				else
					tempParameterID:=parameterID
				GUIControlGet,temp,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%
				return temp
			}
			
		}
		
		setvalue(value, parameterID="")
		{
			global
			;~ d(this, "setvalue " parameterID)
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				;~ d(this, "setvalue 1 " tempParameterID ": " value)
				GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
				return
			}
			else if (parameterID=this.parameter.contentID)
			{
				if value is number
				{
					GUIControl,GUISettingsOfElement:,GUISettingsOfElement%parameterID%%value%,% 1
				}
				else
				{
					loop % this.parameter.content.MaxIndex()
					{
						if (value := this.parameter.content[a_index])
						{
							GUIControl,GUISettingsOfElement:,GUISettingsOfElement%parameterID%%a_index%,% 1
							break
						}
					}
				}
			}
			else
			{
				;Check whether current object has the requested parameter ID
				for oneindex, oneid in this.parameter.id
				{
					if (parameterID = oneid)
					{
						GUIControl,GUISettingsOfElement:,GUISettingsOfElement%oneid%,% value
						return
					}
				}
				
			}
			
			return
		}
		
		checkContent()
		{
			global
			local tempFoundPos, tempRadioID, tempRadioVal, tempOneParamID, tempTextInControl, tempTextInControlReplaced
			local oneindex, oneparamID
			
			if (this.parameter.ContentID)
			{
				tempRadioID:=this.parameter.ContentID
				tempRadioVal:=this.getvalue(tempRadioID)
			}
			else
			{
				tempRadioVal:=this.parameter.content[1]
			}
			tempFirstParamID:=this.parameter.id[1] ;This value is needed to get the icon controls
			
			This.warningText:=""
			if (this.enabled)
			{
				if (tempRadioVal = "expression" or tempRadioVal = "number") ;The content is an expression.
				{
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl:=this.getvalue(oneparamID)
						
						;Warn if there are percent signs.
						IfInString,tempTextInControl,`%
						{
							guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Question mark.ico
							This.warningText:=lang("Note!") " " lang("This is an expression.") " " lang("You mus not use percent signs to add a variable's content.") "`n" lang("But you can still use percent signs if the variable name or a part of it is stored in a variable.")
						}
					}
				}
				else if (tempRadioVal="variablename") ;the content is a variable name
				{
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl:=this.getvalue(oneparamID)
						
						;Check whether the variable name is correct (it does not contain forbitten characters)
						
						;At first replace all variables in the string by the string "someVarName"
						tempTextInControlReplaced:=tempTextInControl
						Loop
						{
							tempFoundPos:=RegExMatch(tempTextInControlReplaced, "U).*%(.+)%.*", tempVariablesToReplace)
							if tempFoundPos=0
								break
							StringReplace,tempTextInControlReplaced,tempTextInControlReplaced,`%%tempVariablesToReplace1%`%,someVarName
						}
						
						try
						{
							;now check whether the varible name is correct
							asdf%tempTextInControlReplaced%:="" 
						}
						catch
						{
							;The variable name is not valid
							guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
							This.warningText:=lang("Error!") " " lang("The variable name is not valid.") "`n"
						}
					}
				}
				
				;If the control must not be empty, show error
				if (this.parameter.WarnIfEmpty)
				{
					for oneindex, oneparamID in this.parameter.id
					{
						tempTextInControl:=this.getvalue(oneparamID)
						if tempTextInControl=
						{
							guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
							This.warningText:=lang("Error!") " " lang("This field must not be empty!") "`n"
						}
					}
				}
			}
			else
			{
				;This parameter and its controls are disabled. If so, hide all warnings.
				guicontrol,GUISettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			if (This.warningText="" and !ElementSettings.initializing)
			{
				;If no warning are present, hide the picture
				guicontrol,GUISettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			ElementSettings.GeneralUpdate()
		}
		
		;Show hint if user clicks on the info-picture
		clickOnInfoPic()
		{
			global
			local tempRadioID, tempRadioVal
			
			if (this.parameter.ContentID)
			{
				tempRadioID:=this.parameter.ContentID
				tempRadioVal:=this.getvalue(tempRadioID)
			}
			else
			{
				tempRadioVal:=this.parameter.content[1]
			}
			
			if (tempRadioVal="Expression")
			{
				ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)`nStringContainingHello " " StringContainingWorld" ,,,11
			}
			if (tempRadioVal="Number")
			{
				ToolTip,% lang("This field contains an expression which must result to a number") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth" ,,,11
			}
			if (tempRadioVal="String")
			{
				ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
			}
			if (tempRadioVal="RawString")
			{
				ToolTip,% lang("This field contains a raw string") "`n" lang("You can't insert content of a variable here") "`n" lang("Examples") ":`nHello World" ,,,11
			}
			if (tempRadioVal="VariableName") 
			{
				ToolTip,% lang("This field contains a variable name") "`n" lang("Examples") ":`nVarname`nEntry1`nEntry%a_index%" ,,,11
			}
			settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
		}
		
		;User has changed the radio button. Show the correct image
		changeRadio()
		{
			global
			local temp, tempGUIControl, tempRadioID, tempRadioVal
			if (this.parameter.ContentID)
			{
				tempRadioID:=this.parameter.ContentID
				tempRadioVal:=this.getvalue(tempRadioID)
			}
			else
			{
				tempRadioVal:=this.parameter.content[1]
			}
			tempFirstParamID:=this.parameter.id[1] ;This value is needed to get the icon controls
			;~ GUIControlGet,temp,GUISettingsOfElement:,GUISettingsOfElement%tempContentTypeID%1
			
			if (tempRadioVal="string" or tempRadioVal="rawstring") 
			{
				guicontrol,GUISettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\String.ico
			}
			else if (tempRadioVal="expression" or tempRadioVal="number") 
			{
				guicontrol,GUISettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Expression.ico
			}
			else if (tempRadioVal="variableName") 
			{
				guicontrol,GUISettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\VariableName.ico
			}
			
			this.checkcontent()
		}
		
	}
	
	class multilineEdit extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptext, tempParGray, tempHWND
			local tempParameterID:=parameter.id
			local tempParameterRows:=parameter.rows
			if not tempParameterRows 
				tempParameterRows:=5
			temp:=ElementSettings.elementPars[parameter.id] 
			temptext:=ElementSettings.elementPars[tempParameterID]
			
			gui,font,s8 cDefault wnorm
			gui,add,edit,w380 x10 multi r%tempParameterRows% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID%,%temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			;Add picture, which will warn user if the entry is obviously invalid
			gui,add,picture,X+4 w16 hp hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempParameterID%
			guicontrol,move,GUISettingsOfElementWarningIconOf%tempParameterID%, h16 ;Workaround. Otherwise the next control would be overlapped with the multiline edit field
			this.components.push("GUISettingsOfElementWarningIconOf" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
		}
		checkContent()
		{
			global
			local tempFoundPos, tempRadioID, tempRadioVal, tempOneParamID, tempTextInControl, tempTextInControlReplaced
			local oneindex, oneparamID
			
			tempParamID:=this.parameter.id
			
			This.warningText:=""
			if (this.enabled)
			{
				;If the control must not be empty, show error
				if (this.parameter.WarnIfEmpty)
				{
					tempTextInControl:=this.getvalue(tempParamID)
					if tempTextInControl=
					{
						guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempParamID%
						guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("This field must not be empty!") "`n"
					}
					
				}
			}
			else
			{
				;This parameter and its controls are disabled. If so, hide all warnings.
				guicontrol,GUISettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempParamID%
			}
			
			if (This.warningText="" and !ElementSettings.initializing)
			{
				;If no warning are present, hide the picture
				guicontrol,GUISettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempParamID%
			}
			
			ElementSettings.GeneralUpdate()
		}
	}
	
	class slider extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempParameterOptions, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			tempParameterOptions:=parameter.options
			if (parameter.allowExpression=true)
			{
				gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				gui,add,edit,X+6 w190 hwndtempHWND gGUISettingsOfElementSliderChangeEdit vGUISettingsOfElement%tempParameterID%,%temp%
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				gui,add,slider, w180 X+10 %tempParameterOptions%  hwndtempHWND gGUISettingsOfElementSliderChangeSlide vGUISettingsOfElementSlideOf%tempParameterID% ,% temp
				this.components.push("GUISettingsOfElementSlideOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				this.contentType:="Expression"
			}
			else
			{
				gui,add,slider, w400 x10 %tempParameterOptions% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID% ,% temp
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
			}
		}
		
		sliderChangeEdit()
		{
			global
			local temp, tempGUIControl
			tempGUIControl:=this.parameter.id
			temp:=this.getValue()
			guicontrol,,% "GUISettingsOfElementSlideOf" tempGUIControl,%temp%
			this.udpatename()
		}
		sliderChangeSlide()
		{
			global
			local temp, tempGUIControl
			tempGUIControl:=this.parameter.id
			guicontrolget,temp,,% "GUISettingsOfElementSlideOf" tempGUIControl
			this.setValue(temp)
			this.udpatename()
		}
		
	}
	
	class DropDown extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptoChoose,tempAltSumbit,tempChoises,tempAllChoices, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			if (parameter.result != "number" and parameter.result != "string" and parameter.result != "enum")
				MsgBox unexpected error: the parameter "result" of "DropDown" is unset or has unsupported value
			
			if (parameter.result="number" or parameter.result="enum")
			{
				temptoChoose:=temp
				tempAltSumbit=AltSubmit
			}
			else
				tempAltSumbit=
			tempChoises:=parameter.choices
			tempEnums:=parameter.enum
			
			;loop through all choices. Find which one to select. Make a selection list which is capable for the gui,add command
			tempAllChoices=
			for tempIndex, TempOneChoice in tempChoises
			{
				if (parameter.result="string")
				{
					if (TempOneChoice=temp)
						temptoChoose:=A_Index
				}
				else
				{
					if (temp = A_Index or temp = tempEnums[A_Index])
						temptoChoose:=A_Index
						
				}
				tempAllChoices.="|" TempOneChoice
				
			}
			
			StringTrimLeft,tempAllChoices,tempAllChoices,1
			gui,add,DropDownList, w400 x10 %tempAltSumbit% choose%temptoChoose% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
		getvalue()
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			
			temp:=base.getvalue()
			if (this.parameter.result = "enum")
				temp:=this.parameter.Enum[temp]
			
			return temp
		}
		setvalue(value)
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			if not (value >= 1 and value <= this.parameter.choices.MaxIndex())
			{
				;This might be an enum value
				if (IsObject(this.parameter.Enum))
				{
					loop % this.parameter.choices.MaxIndex()
					{
						if (this.parameter.Enum[a_index] = value)
						{
							temp := a_index
							break
						}
					}
				}
				else
				{
					temp:=value
				}
			}
			else
			{
				temp:=A_Index
			}
			GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%%value%,1
			return temp
		}
	}
	
	
	
	class ComboBox extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptoChoose,tempAltSumbit,tempChoises,tempAllChoices, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			tempChosen:=ElementSettings.elementPars[tempParameterID] 
			temptoChooseText := tempChosen
			if (parameter.result="number")
			{
				tempAltSumbit=AltSubmit
			}
			else
				tempAltSumbit=
			tempChoises:=parameter.choices
			
			;loop through all choices. Find which one to select. Make a selection list which is capable for the gui,add command
			tempAllChoices=
			for tempIndex, TempOneChoice in tempChoises
			{
				if (parameter.result="number")
				{
					if (TempOneChoice=tempChosen)
						temptoChooseText:=TempOneChoice
				}
				tempAllChoices.="|" TempOneChoice
				
			}
			StringTrimLeft,tempAllChoices,tempAllChoices,1
			this.par_result:=parameter.result
			this.par_choices:=parameter.choices
			
			;Add picture, which will warn user if the entry is obviously invalid
			gui,add,picture,x394 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempParameterID%
			this.components.push("GUISettingsOfElementWarningIconOf" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			if (parameter.content="Expression")
			{
				;The info icon tells user which conent type it is
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("vGUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				this.ContentType:="Expression"
				;~ GUISettingsOfElementContentType%tempParameterID%=Expression
			}
			else if (parameter.content="Number")
			{
				;The info icon tells user which conent type it is
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("vGUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				this.ContentType:="Number"
				;~ GUISettingsOfElementContentType%tempParameterID%=Expression
			}
			else if (parameter.content="String")
			{
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\string.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				this.ContentType:="String"
				;~ GUISettingsOfElementContentType%tempParameterID%=String
			}
			else if (parameter.content="VariableName")
			{
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\VariableName.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
				
				this.ContentType:="VariableName"
				;~ GUISettingsOfElementContentType%tempParameterID%=VariableName
			}
			else ;Text field without specified content type and without info icon
			{
				gui,add,ComboBox, x10 yp w380 hwndtempHWND %tempAltSumbit%  gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettings.fieldHWNDs[tempHWND]:=this
			}
			
			this.setvalue(tempChosen)
			;~ guicontrol,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% temptoChooseText
			
		}
		
		getvalue()
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			
			
			guicontrolget,temp,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%
			;~ ToolTip asdöfio  - %temp% - %tempParameterID%
			return temp
		}
		
		setvalue(value, parameterID="")
		{
			global
			local tempLabelChoice, tempindexChoice, somethingChosen
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
				
				
				if (this.par_result="string")
				{
					for tempindexChoice, tempLabelChoice in this.par_choices
					{
						if (tempLabelChoice = value)
						{
							GUIControl,GUISettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempindexChoice
							somethingChosen:=true
							break
						}
					}
					if (somethingChosen!=true)
						GUIControl,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
				}
				else
				{
					;~ ToolTip value %value%
					if (value > 0 and value <= this.par_choices.MaxIndex())
						GUIControl,GUISettingsOfElement:choose,GUISettingsOfElement%tempParameterID%,% value
					else
					{
						GUIControl,GUISettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
					}
				}
				
				;Check content after setting
				this.checkContent()
			}
			else
			{
				for oneIndex, oneField in ElementSettings.fields
				{
					if (oneField.parameter.id = parameterID)
						onefield.setvalue(value)
				}
			}
			
			return
		}
		
		setChoices(value, parameterID="")
		{
			global
			local tempParameterID, 
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			
			tempAllChoices=|
			for tempIndex, TempOneChoice in value
			{
				if (parameter.result="string")
				{
					if (TempOneChoice=temp)
						temptoChoose:=A_Index
				}
				if (tempAllChoices="|")
					tempAllChoices.=TempOneChoice
				else
					tempAllChoices.="|" TempOneChoice
				
			}
			this.par_choices:=value
			
			GUIControl,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%,% tempAllChoices
			return
		}
		
		checkContent()
		{
			global
			local tempFoundPos, tempRadioVal, tempOneParamID, tempTextInControl, tempTextInControlReplaced
			
			tempOneParamID:=this.parameter.id
			if tempOneParamID=
				MsgBox error! tempOneParamID is empty. Code: 561684861
			
			This.warningText:=""
			if (this.enabled)
			{
				tempTextInControl:=this.getvalue(tempOneParamID)
				;~ MsgBox % tempTextInControl "`n" this.ContentType
				if (this.ContentType="Expression" or this.ContentType="Number")
				{
					IfInString,tempTextInControl,`%
					{
						guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Question mark.ico
						This.warningText:=lang("Note!") " " lang("This is an expression.") " " lang("You musn't use percent signs to add a variable's content.") "`n"
					}
				}
				else if (this.ContentType="variablename")
				{
					tempTextInControlReplaced:=tempTextInControl
					Loop
					{
						tempFoundPos:=RegExMatch(tempTextInControlReplaced, "U).*%(.+)%.*", tempVariablesToReplace)
						if tempFoundPos=0
							break
						StringReplace,tempTextInControlReplaced,tempTextInControlReplaced,`%%tempVariablesToReplace1%`%,someVarName
					}
					;~ ToolTip( tempTextInControlReplaced " - " tempTextInControl)
					try
						asdf%tempTextInControlReplaced%:=1 
					catch
					{
						guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("The variable name is not valid.") "`n"
					}
				}
				
				if (this.WarnIfEmpty)
				{
					if tempTextInControl=
					{
						guicontrol,GUISettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,GUISettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("This field mustn't be empty!") "`n"
					}
				}
			}
			;~ ToolTip(This.warningText)
			if (This.warningText="" and !ElementSettings.initializing)
			{
				
				guicontrol,GUISettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempOneParamID%
			}
			ElementSettings.GeneralUpdate()
		}
		
		clickOnInfoPic()
		{
			global
			local temp, tempOneParamID
			tempOneParamID:=this.parameter.id
			
			if (tempRadioVal="Expression")
			{
				ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)`nStringContainingHello " " StringContainingWorld" ,,,11
			}
			if (tempRadioVal="Number")
			{
				ToolTip,% lang("This field contains an expression which must result to a number") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth" ,,,11
			}
			if (tempRadioVal="String")
			{
				ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
			}
			if (tempRadioVal="RawString")
			{
				ToolTip,% lang("This field contains a raw string") "`n" lang("You can't insert content of a variable here") "`n" lang("Examples") ":`nHello World" ,,,11
			}
			if (tempRadioVal="VariableName") 
			{
				ToolTip,% lang("This field contains a variable name") "`n" lang("Examples") ":`nVarname`nEntry1`nEntry%a_index%" ,,,11
			}
			settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
		}
	}
	
	class Hotkey extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			gui,add,edit,w300 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,hotkey,w90 X+10 hwndtempHWND gGUISettingsOfElementHotkey vGUISettingsOfElement%tempParameterID%hotkey,%temp%
			this.components.push("GUISettingsOfElementHotkey" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
		
		changeHotkey()
		{
			global
			local temp, tempGUIControl
			tempGUIControl:=this.parameter.id
			temp:=this.getValue("Hotkey" tempGUIControl)
			this.setValue(temp)
			this.udpatename()
			return
			
		}
	}
	
	class Button extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=parameter.goto
			gui,add,button,w400 x10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElement%tempParameterID%,% parameter.label
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
		
		clickOnButton()
		{
			global
			logger("a3", "Element Settings: Evaluating g-label of button: " thisgoto)
			local templabel:=this.parameter.goto
			local countpars
			if (islabel(templabel))
			{
				gosub,% templabel
			}
			else 
			{
				countpars:=isfunc(templabel)
				if (countpars)
				{
					if (countpars = 1) ;No mandantory parameters
					{
						%templabel%()
					}
					else if (countpars = 2) ;One mandantory parameters
					{
						%templabel%({flowID: FlowID, elementID: ElementSettings.element})
					}
					else
					{
						MsgBox Error on button click. Target function has too many mandantory parameters
					}
				}
				else
				{
					MsgBox Error on button click. Target label or function '%templabel%' does not exist.
				}
			}
			return
		}
	}
	
	class file extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			gui,add,button,w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%,...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
		clickOnButton()
		{
			global
			local tempfile, tempGUIControl
			tempGUIControl:=this.parameter.id
			
			FileSelectFile,tempfile,% this.parameter.options,% this.getvalue(),% this.parameter.prompt,% this.parameter.filter
			
			if not errorlevel
				this.setvalue(tempfile)
			this.udpatename()
			return
		}
	}
	
	class folder extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,button,w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%,...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
		
		clickOnButton()
		{
			global
			local tempfile, tempGUIControl
			tempGUIControl:=this.parameter.id
			
			FileSelectFolder,tempfile,% "*" this.getvalue(),this.parameter.options,% this.parameter.prompt
			
			if not errorlevel
				this.setvalue(tempfile)
			this.udpatename()
			return
			
		}
	}
	
	
	class weekdays extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			
			gui,add,checkbox,w45 x10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%2,% lang("Mon (Short for Monday")
			this.components.push("GUISettingsOfElement" tempParameterID "2")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%3,% lang("Tue (Short for Tuesday")
			this.components.push("GUISettingsOfElement" tempParameterID "3")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%4,% lang("Wed (Short for Wednesday")
			this.components.push("GUISettingsOfElement" tempParameterID "4")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%5,% lang("Thu (Short for Thursday")
			this.components.push("GUISettingsOfElement" tempParameterID "5")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%6,% lang("Fri (Short for Friday")
			this.components.push("GUISettingsOfElement" tempParameterID "6")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%7,% lang("Sat (Short for Saturday")
			this.components.push("GUISettingsOfElement" tempParameterID "7")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%1,% lang("Sun (Short for Sunday") ;Sunday is 1
			this.components.push("GUISettingsOfElement" tempParameterID "1")
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			IfInString,temp,1
				guicontrol,,GUISettingsOfElement%tempParameterID%1,1
			IfInString,temp,2
				guicontrol,,GUISettingsOfElement%tempParameterID%2,1
			IfInString,temp,3
				guicontrol,,GUISettingsOfElement%tempParameterID%3,1
			IfInString,temp,4
				guicontrol,,GUISettingsOfElement%tempParameterID%4,1
			IfInString,temp,5
				guicontrol,,GUISettingsOfElement%tempParameterID%5,1
			IfInString,temp,6
				guicontrol,,GUISettingsOfElement%tempParameterID%6,1
			IfInString,temp,7
				guicontrol,,GUISettingsOfElement%tempParameterID%7,1
			
			;~ GUISettingsOfElement%tempParameterID%:=temp
		}
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if parameterID=
				tempParameterID:=this.parameter.id
			else
				tempParameterID:=parameterID
			
			temp:=""
			loop 7
			{
				GUIControlGet,tempValue,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%%a_index%
				if (tempValue=1)
				{
					temp.=A_Index
				}
			}
			return temp
		}
		
		setvalue(value, parameterID="")
		{
			global
			local tempParameterID:=this.parameter.id
			if parameterID=
				tempParameterID:=this.parameter.id
			else
				tempParameterID:=parameterID
			
			IfInString,value,1
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%1,1
			IfInString,value,2
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%2,1
			IfInString,value,3
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%3,1
			IfInString,value,4
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%4,1
			IfInString,value,5
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%5,1
			IfInString,value,6
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%6,1
			IfInString,value,7
				guicontrol,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%7,1
			
			return
		}
		
		changeweekdays() ;TODO remove if no more action necessary
		{
			this.udpatename()
		}
		
	}
	
	class DateAndTime extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, tempHWND
			local tempParameterID:=parameter.id
			local tempFormat:=parameter.format
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
			
			gui,font,s8 cDefault wnorm
			temp:=ElementSettings.elementPars[tempParameterID] 
			if temp=
			{
				temp=%a_now%
			}
			gui,add,DateTime,w400 x10 choose%temp% gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID% ,% tempFormat
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
		}
	}
	
	class listbox extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local tempHWND, tempSort, tempMulti, tempChoices, tempChosen, tempChosenNumbers, tempAltSubmit, tempChoicesString
			local tempParameterID:=parameter.id
			
			gui,font,s8 cDefault wnorm
			tempChosen:=ElementSettings.elementPars[tempParameterID] 
			tempChoices:=parameter.choices
			this.choices:=tempChoices
			tempChoicesString:=""
			for tempindex, tempLabel in this.choices
			{
				if (tempChoicesString = "")
					tempChoicesString:=tempLabel
				else
					tempChoicesString.= "|" tempLabel
			}
			
			if (parameter.multi )
				tempMulti:="multi"
			else
				tempMulti:=""
			if (parameter.Sort )
				tempSort:="Sort"
			else
				tempSort:=""
			if (parameter.result = "string")
			{
				this.par_result:="string"
				this.choices:=tempChoices
				tempAltSubmit:=""
			}
			else
			{
				tempAltSubmit:="altSubmit"
				this.par_result:="number"
			}
			
			gui,add,listbox,w400 x10 %tempMulti% %tempSort% %tempAltSubmit% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%tempChoicesString%
			
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettings.fieldHWNDs[tempHWND]:=this
			
			this.setvalue(tempChosen)
		}
		
		getvalue(parameterID="")
		{
			global
			local tempChosen, tempChosenObj, tempChosenStrings, tempParameterID, tempChoices
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			GUIControlGet,tempChosen,GUISettingsOfElement:,GUISettingsOfElement%tempParameterID%
			
			tempChosenObj:=Object()
			loop,parse,tempChosen,|
			{
				tempChosenObj.push(A_LoopField)
			}
			;~ if (this.par_result="string")
			;~ {
				;~ tempChoices:=this.choices
				;~ tempChosenNumbers:="|" tempChosen "|" 
				
				;~ tempChosenStrings:=""
				;~ loop,parse,tempChoices,|
				;~ {
					;~ MsgBox %tempChosenNumbers% - %a_index%
					;~ IfInString, tempChosenNumbers, "|" a_index "|"
					;~ {
						;~ if (tempChosenStrings!="")
							;~ tempChosenStrings .= "|" A_LoopField
						;~ else
							;~ tempChosenStrings:=A_LoopField
					;~ }
				;~ }
				;~ d(tempChosenStrings, tempChosen)
				;~ return tempChosenStrings
			;~ }
			;~ else
			;~ {
				return tempChosenObj
			;~ }
			
		}
		
		setvalue(value, parameterID="")
		{
			global
			local tempChosenNumbers, tempChoices, tempChosenStrings, tempChosen
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			if (this.par_result="string")
			{
				for tempindexChosen, tempLabelChosen in value
				{
					for tempindexChoice, tempLabelChoice in this.choices
					{
						if (tempLabelChoice = tempLabelChosen)
						{
							GUIControl,GUISettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempindexChoice
						}
					}
				}
			}
			else
			{
				for tempindexChosen, tempNumberChosen in value
				{
					GUIControl,GUISettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempNumberChosen
				}
			}
			return
		}
		
	}
	
	
	
	;Get all values which are currently edited.
	getAllValues()
	{
		global
		local tempOneParID, temponeValue
		local tempPars:=Object()
		for ElementSaveindex, parameter in ElementSettings.parametersToEdit
		{
			;Get the keys which are specified in key "ID"
			if not IsObject(parameter.id)
				parameterID:=[parameter.id]
			else
				parameterID:=parameter.id
			;~ MsgBox % strobj(parameterID)
			if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label do nothing
				continue
			;~ MsgBox % strobj(parameterID)
			
			;The edit control can also have parameter names which are specified in key "ContentID"
			if (IsObject(parameter.ContentID))
			{
				parameterID.push(parameter.ContentID[1])
			}
			else if (parameter.ContentID)
			{
				parameterID.push(parameter.ContentID)
			}
			
			
			;Certain types of control consist of multiple controls and thus contain multiple parameters.
			for ElementSaveindex2, oneID in parameterID
			{
				tempOneParID:=parameterID[ElementSaveindex2]
				temponeValue:=ElementSettings.fieldParIDs[tempOneParID].getValue(tempOneParID)
				tempPars[tempOneParID]:=temponeValue
				;~ d(temponeValue, tempOneParID)
			
			}
			
		}
		return tempPars
	}
	
	
	
	;Update the name field, check settings
	generalUpdate(firstCall=False)
	{
		global
		if (ElementSettings.generalUpdateRunning)
		{
			return
		}
		ElementSettings.generalUpdateRunning:=True
		GUISettingsOfElementRemoveInfoTooltip()
		;~ ToolTip updakljö
		allParamValues:=ElementSettings.getAllValues()
		_setElementProperty(FlowID, ElementSettings.element, "FirstCallOfCheckSettings", firstCall) .FirstCallOfCheckSettings:=firstCall
		setElementClass := ElementSettings.elementClass
		Element_CheckSettings_%setElementClass%({FlowID: FlowID, ElementID: ElementSettings.element}, allParamValues) 
		ElementSettingsNameField.updatename(allParamValues)
		ElementSettings.generalUpdateRunning:=False
	}
	
	
	
	
	

	disable()
	{
		global
		
		gui,GUISettingsOfElement:+disabled
	}

	enable()
	{
		global
		
		gui,GUISettingsOfElement:-disabled
		WinActivate, ahk_id %global_SettingWindowHWND%
	}

	
	
	
	;Delete some variables on exit
	close()
	{
		global
		this.fields:=""
		this.fieldHWNDs:=""
		this.fieldParIDs:=""
		this.ElementID:=""
		this.ElementType:=""
		this.ElementClass:=""
		this.ElementPars:=""
		ElementSettingsNameField:=""
		EditGUIEnable()
	}



	
}





;Called when the GUI is resized by user
GUISettingsOfElementParentSize(GuiHwnd, EventInfo, Width, Height)
{
	global
	
	If (EventInfo <> 1) ;if not minimized
	{
		;~ GuiHwnd+=0
		SetWinDelay,0
		GetClientSize(global_SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH) ;Sometimes for any reason the width and height parameters are not correct. therefore get the gui size again
		guicontrol, GUISettingsOfElementParent:move,ButtonSave,% "y" ElSetingGUIH-40
		guicontrol, GUISettingsOfElementParent:move,ButtonCancel,% "y" ElSetingGUIH-40
		winmove,% "ahk_id " global_SettingWindowHWND,  , 0, 30,  ,% ElSetingGUIH-90
		;~ if not a_iscompiled
			;~ ToolTip %GuiHwnd% %Width% %Height% - %ElSetingGUIW% %ElSetingGUIH% - %global_SettingWindowHWND% %global_SettingWindowParentHWND%
	}
	Return
}


;This and following functions will be called if user changes some value
GUISettingsOfElementChangeRadio(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ChangeRadio()
	
	return
}

GUISettingsOfElementCheckContent(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].checkcontent()
	
	return
}


GUISettingsOfElementCheckStandardName(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.GeneralUpdate()
	;~ ElementSettings.fieldHWNDs[CtrlHwnd].UpdateName()
}

GUISettingsOfElementGeneralUpdate(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.GeneralUpdate()
	return
}

GUISettingsOfElementClickOnWarningPic(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ClickOnWarningPic()
	return
}
GUISettingsOfElementRemoveInfoTooltip()
{
	ToolTip,,,,11
	return
}
GUISettingsOfElementClickOnInfoPic(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ClickOnInfoPic()
	
	return
}


GUISettingsOfElementSliderChangeEdit(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].SliderChangeEdit()
	return
}


GUISettingsOfElementSliderChangeSlide(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].SliderChangeSlide()
	return
}

	
GUISettingsOfElementHotkey(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ChangeHotkey()
	return
}

GUISettingsOfElementButton(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ClickOnButton()
	return
	
	
}
GUISettingsOfElementWeekdays(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettings.fieldHWNDs[CtrlHwnd].ChangeWeekdays()
	return
	
	
}

