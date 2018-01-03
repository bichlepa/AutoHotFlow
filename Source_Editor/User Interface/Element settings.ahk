;Needed translations:
temp:=lang("Trigger")
temp:=lang("Action")
temp:=lang("Condition")
temp:=lang("Loop")


class ElementSettings
{
	;Open GUI for settings parameters of an element.
	open(p_ID,wait="", alreadyChangedSomething = 0)
	{
		global
		local temp, tempYPos, tempXPos, tempEditwidth, tempIsDefault, tempAssigned, tempChecked, tempMakeNewGroup, temptoChoose, tempAltSumbit, tempChoises, tempAllChoices, tempParameterOptions, tempres, tempelement
		;~ MsgBox agews
		;~ MsgBox % strobj(newElement)
		GUISettingsOfElementObject:=this
		static NowResultEditingElement, somethingchanged, temponeValue
		;~ static setElement, setElementID, setElementType, setElementsubType
		static Parameterwait
		this.element:=p_ID
		setElement:=flowObj.allElements[p_ID]
		setElementID:=setElement.id
		setElementType:=setElement.Type
		setElementClass:=setElement.Class
		Parameterwait:=wait
		;~ MsgBox % strobj(setElement)
		
		
		NowResultEditingElement:=""
		
		
		
		
		static varsToDelete:=[] ;TODO: maybe unnecessary
		ElementSettingsFields:={} ;global. contains the fields which will be shown in the GUI. Each field is a bunch of controls
		ElementSettingsFieldHWNDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		ElementSettingsFieldParIDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		
		EditGUIDisable()
		
		;block general update
		generalUpdateRunning:=true
		
		;Create a scrollable Child GUI will almost all controls
		gui,SettingsOfElement:default
		gui +hwndSettingWindowHWND
		gui +vscroll
		gui,-DPIScale
		CurrentlyActiveWindowHWND:=SettingWindowHWND
		
		;Get the parameter list
		parametersToEdit:=Element_getParametrizationDetails(setElementClass, {flowID: flowobj.id, elementID: setElementID, updateOnEdit: true})
		parametersList:=Element_getParameters(setElementClass, {flowID: flowobj.id, elementID: setElementID})
		;~ d(parametersList,"element settings")
		;All elements have the parameter "name" and "StandardName"
		ElementSettingsFields.push(new this.label({label: lang("name (name)")}))
		ElementSettingsFields.push(new this.name({id: ["name", "StandardName"]}))
		
		
		;Loop through all parameters
		for index, parameter in parametersToEdit
		{
			;Add one or a group of controls. This is done dynamically, dependent on the parameters
			if (parameter.type="Label")
			{
				ElementSettingsFields.push(new this.label(parameter))
			}
			else if (parameter.type="Edit")
			{
				ElementSettingsFields.push(new this.edit(parameter))
			}
			else if (parameter.type="multilineEdit")
			{
				ElementSettingsFields.push(new this.multilineEdit(parameter))
			}
			else if (parameter.type="Checkbox")
			{
				ElementSettingsFields.push(new this.checkbox(parameter))
			}
			else if (parameter.type="Radio")
			{
				ElementSettingsFields.push(new this.radio(parameter))
			}
			else if (parameter.type="Slider")
			{
				ElementSettingsFields.push(new this.slider(parameter))
			}
			else if (parameter.type="DropDown")
			{
				ElementSettingsFields.push(new this.DropDown(parameter))
			}
			else if (parameter.type="ComboBox")
			{
				ElementSettingsFields.push(new this.ComboBox(parameter))
			}
			else if (parameter.type="Hotkey")
			{
				ElementSettingsFields.push(new this.Hotkey(parameter))
			}
			else if (parameter.type="Button")
			{
				ElementSettingsFields.push(new this.Button(parameter))
			}
			else if (parameter.type="File")
			{
				ElementSettingsFields.push(new this.file(parameter))
			}
			else if (parameter.type="Folder")
			{
				ElementSettingsFields.push(new this.folder(parameter))
			}
			else if (parameter.type="weekdays")
			{
				ElementSettingsFields.push(new this.weekdays(parameter))
			}
			else if (parameter.type="TimeOfDay")
			{
				ElementSettingsFields.push(new this.TimeOfDay(parameter))
			}
			else if (parameter.type="DateAndTime")
			{
				ElementSettingsFields.push(new this.DateAndTime(parameter))
			}
			else if (parameter.type="listbox")
			{
				ElementSettingsFields.push(new this.listbox(parameter))
			}
			
		}
		
		
		
		
		; Create the parent window which contains some always visible controls (which are not scrolled away)
		Gui, GUISettingsOfElementParent:New
		gui, GUISettingsOfElementParent:-DPIScale
		Gui, GUISettingsOfElementParent:Margin, 0, 20
		gui,GUISettingsOfElementParent:+resize
		gui,GUISettingsOfElementParent:+hwndSettingWindowParentHWND
		gui,GUISettingsOfElementParent:+LabelSettingsOfElementParent
		
		;Make the child window appear inside the parent window
		Gui, SettingsOfElement:-Caption
		Gui, SettingsOfElement:+parentGUISettingsOfElementParent
		gui, SettingsOfElement:show,x0 y20
		
		
		;Get the size of the child window
		WinGetPos, , , WsettingsChild, HsettingsChild,% "ahk_id " SettingWindowHWND
		Winmove,% "ahk_id " SettingWindowHWND, ,, , % WsettingsChild + 10, % HsettingsChild
		WinGetPos, , , WsettingsChild, HsettingsChild,% "ahk_id " SettingWindowHWND
		
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
		gui, GUISettingsOfElementParent:add,button, w370 x10 y10 gGUISettingsOfElementSelectType h20,% lang("%1%_type:_%2%",lang(setElementType),Element_getName_%setElementClass%())
		gui, GUISettingsOfElementParent:add,button, w20 X+10 yp h20 gGUISettingsOfElementHelp vGUISettingsOfElementHelp,?
		;~ guicontrol,focus,GUISettingsOfElementHelp
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementSave vButtonSave w145 x10 h30 y%YsettingsButtoPos%,% lang("Save")
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementCancel vButtonCancel default w145 h30 yp X+10,% lang("Cancel")
		;Make GUI autosizing
		Gui, GUISettingsOfElementParent:Show, hide w%WSettingsParent%,% lang("Settings") " - " lang(setElementType) " - " Element_getName_%setElementClass%()
		
		_share.hwnds["ElementSettingsChild" flowobj.id] :=SettingWindowHWND
		_share.hwnds["ElementSettingsParent" flowobj.id] :=SettingWindowParentHWND
		
		;Calculate position to show the settings window in the middle of the main window
		pos:=EditGUIGetPos()
		tempHeight:=round(pos.h-100) ;This will be the max height. If child gui is larger, it must be scrolled
		DetectHiddenWindows,on
		WinGetPos,ElSetingGUIX,ElSetingGUIY,ElSetingGUIW,ElSetingGUIH,ahk_id %SettingWindowParentHWND%
		if (ElSetingGUIH < tempHeight)
			tempHeight := ElSetingGUIH
		tempXpos:=round(pos.x+pos.w/2- ElSetingGUIW/2)
		tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
		
		;move Parent window
		gui,GUISettingsOfElementParent:show,% "x" tempXpos " y" tempYpos " h" tempHeight " hide" 
		
		
		;position lower buttons
		wingetpos,,,ElSetingGUIW,ElSetingGUIH, ahk_id %SettingWindowParentHWND%
		WinMove,ahk_id %SettingWindowParentHWND%,,,,% ElSetingGUIW,% ElSetingGUIH+1 ;make the autosize function trigger, which resizes and moves the scrollgui
		
		
		
		CurrentlyActiveWindowHWND:=SettingWindowParentHWND
		
		openingElementSettingsWindow:=false
		
		
		gui,GUISettingsOfElementParent:show
		
		;release general update
		generalUpdateRunning:=false
		this.generalUpdate(True)
		
		if (wait=1 or wait="wait") ;Wait until user closes the window
		{
			Loop
			{
				if (NowResultEditingElement="") ;This variable will be set when user closes the window
					sleep 100
				else 
					break
			}
		}
		return NowResultEditingElement
		
		
		;If user wants to change the subtype of the element
		GUISettingsOfElementSelectType:
		gui,SettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		ui_closeHelp() 
		EditGUIEnable()
		
		tempres:=selectSubType(setElement.id, "wait")
		if tempres!=aborted
		{
			NowResultEditingElement:= ElementSettings.open(setelement.id,Parameterwait, true)
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
			ui_showHelp(setElement.type "\" setElement.class)
		return
		
		
		
		
		
		SettingsOfElementParentClose:
		SettingsOfElementParentEscape:
		GUISettingsOfElementCancel:
		;~ ToolTip %a_thislabel%
		if (setElement.name="Νew Соntainȩr" or setElement.name="Νew Triggȩr") ;Delete the element if it was newly created
		{
			setElement.remove()
		}
		
		if (element.previousSubType) ;restore previous subtype of element if it was changed recently
		{
			setElement.SubType:=element.previousSubType
			element.previousSubType:=""
		}
		
		ui_closeHelp() 
		
		gui,SettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		NowResultEditingElement:="aborted"
		GUISettingsOfElementObject.close()
		return
		
		
		
		GUISettingsOfElementSave:
		GUISettingsOfElementobject.generalUpdate()
		;~ gui,SettingsOfElement:submit
		if (setElement.type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
		{
			tempReenablethen:=true
			;r_EnableFlow() ;TODO ;Disable flow
		}
		else
			tempReenablethen:=false
		
		;Save the parameters
		somethingchanged:=alreadyChangedSomething ;will be incremented if a change will be detected
		setElement.Name:=ElementSettingsNameField.getValue("Name")
		setElement.StandardName:=ElementSettingsNameField.getValue("StandardName")
		;~ MsgBox % strobj(parametersToEdit)
		for ElementSaveindex, parameter in parametersToEdit
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
				temponeValue:=ElementSettingsFieldParIDs[tempOneParID].getValue(tempOneParID)
				if (setElement.pars[tempOneParID]!=temponeValue)
					somethingchanged++
				setElement.pars[tempOneParID]:=temponeValue
				
				;~ MsgBox,1,, % tempOneParID "`n`n" ElementSaveindex  "-" ElementSaveindex2 "`n`n" strobj(ElementSettingsFieldParIDs[tempOneParID]) "`n`n" strobj(setElement)
				;~ IfMsgBox cancel
					;~ MsgBox % strobj(ElementSettingsFieldParIDs)
			
			}
			
			
			
		}
		temponeValue:=""
		
		ui_closeHelp() 
		gui,SettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		

		NowResultEditingElement:=somethingchanged " Changes"
		
		;if (tempReenablethen) ;TODO
			;r_EnableFlow()
		
		
		
		API_Main_Draw()
		GUISettingsOfElementObject.close()
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
					ElementSettingsFieldParIDs[onepar]:=this
				}
			}
			else if (parameter.id!="")
				ElementSettingsFieldParIDs[parameter.id]:=this
			if (isobject(parameter.contentid))
			{
				for index, onepar in parameter.contentid
				{
					ElementSettingsFieldParIDs[onepar]:=this
				}
			}
			else if (parameter.contentid!="")
				ElementSettingsFieldParIDs[parameter.contentid]:=this
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
				GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
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
						GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%oneid%
						return temp
					}
				}
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettingsFields
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
				GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
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
						GUIControl,SettingsOfElement:,GUISettingsOfElement%oneid%,% value
						return
					}
				}
				;Find object which has the requested parameter ID and call it
				for oneIndex, oneField in ElementSettingsFields
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
				for oneIndex, oneField in ElementSettingsFields
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
		
		setText(Text,index="")
		{
			global
			local tempParameterID:=this.parameter.id
			guicontrol,SettingsOfElement:text,GUISettingsOfElement%tempParameterID%%index%,% Text
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
					guicontrol,SettingsOfElement:enable%enOrDis%,% component
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
							guicontrol,SettingsOfElement:enable%enOrDis%,% component
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
				for oneIndex, oneField in ElementSettingsFields
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
			tempchecked:=setElement["StandardName"] 
			;~ temptext:=setElement.pars["Name"] 
			
			gui,add,checkbox, x10 hwndtempHWND checked%tempchecked% vGUISettingsOfElementStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
			this.components.push("GUISettingsOfElementStandardName")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,edit,w400 x10 Multi r5 hwndtempHWND vGUISettingsOfElementName gGUISettingsOfElementGeneralUpdate,% setElement.name
			this.components.push("GUISettingsOfElementName")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElementCheckStandardName")
			varsToDelete.push("GUISettingsOfElementEditName")
			
		}
		
		
		updateName(p_CurrentPars)
		{
			global
			local Newname
			if (openingElementSettingsWindow=true)
				return
			if (this.getvalue("StandardName")=1)
			{
				this.disable("Name")
				Newname:=Element_GenerateName_%setElementClass%(setElement, p_CurrentPars) 
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
				varsToDelete.push("GUISettingsOfElement" tempParameterID)
				this.components.push("GUISettingsOfElement" tempParameterID)
			}
			else
			{
				gui,add,text,x10 w400 %tempYPos%,% parameter.label
			}
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
			temp:=setElement.pars[parameter.id] 
			temptext:=parameter.label
			if parameter.gray
				tempParGray=check3
			else
				tempParGray=
			gui,add,checkbox,w400 x10 %tempParGray% checked%temp% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
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
			temp:=setElement.pars[tempParameterID] 
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
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				varsToDelete.push("GUISettingsOfElement" tempParameterID a_index)
			}
			if (tempAssigned=false) ;Catch if a wrong value was saved and set to default value. 
			;TODO: is this a good idea? If this happens and user opens the settings window, he might erroneously thing that everything is ok.
			{
				
				temp:=parameter.default
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%%temp%,1
			}
		}
		
		getvalue()
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			
			loop % this.parameter.choices.MaxIndex()
			{
				guicontrolget,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%%a_index%
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
			GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%%temp%,1
			return temp
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
				
				tempContentTypeNum:=setElement.pars[tempParameterContentTypeID] ;get the saved parameter
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
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					varsToDelete.push("GUISettingsOfElement" tempParameterContentTypeID a_index)
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
			ElementSettingsFieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			
			;The info icon tells user which conent type it is
			tempselectedContentType:=parameter.content[1]
			gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempFirstParameterID%,%_ScriptDir%\icons\%tempselectedContentType%.ico
			this.components.push("GUISettingsOfElementInfoIconOf" tempFirstParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			
			loop % parameter.id.MaxIndex()
			{
				tempOneParameterID:=parameter.id[a_index]
				;Add the edit control(s)
				tempwAvailable:=360
				tempw:=(tempwAvailable - (4 * (parameter.id.MaxIndex() -1)) ) / parameter.id.MaxIndex()
				temptext:=setElement.pars[tempOneParameterID]
				
				gui,add,edit,X+4 w%tempw% %tempIsMulti% r1 hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
				this.components.push("GUISettingsOfElement" tempOneParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				if (parameter.id.MaxIndex() = 1 and tempParameterContentType[1] = "expression")
				{
					;If this a single expression, user may want to add arrow keys
					if (parameter.useupdown)
					{
						if (parameter.range)
							gui,add,updown,% "range" parameter.range
						else
							gui,add,updown
						guicontrol,SettingsOfElement:,GUISettingsOfElement%tempOneParameterID%,%temptext%
					}
				}
				
				varsToDelete.push("GUISettingsOfElement" tempOneParameterID)
			}
			
			this.changeRadio()
			
			varsToDelete.push("GUISettingsOfElementInfoIconOf" tempFirstParameterID, "GUISettingsOfElementWarningIconOf" tempOneParameterID)
			
			
		}
		
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if (parameterID and parameterID=this.parameter.contentID)
			{
				loop % this.parameter.content.MaxIndex()
				{
					GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%parameterID%%a_index%
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
				GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
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
				GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
				return
			}
			else if (parameterID=this.parameter.contentID)
			{
				if value is number
				{
					GUIControl,SettingsOfElement:,GUISettingsOfElement%parameterID%%value%,% 1
				}
				else
				{
					loop % this.parameter.content.MaxIndex()
					{
						if (value := this.parameter.content[a_index])
						{
							GUIControl,SettingsOfElement:,GUISettingsOfElement%parameterID%%a_index%,% 1
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
						GUIControl,SettingsOfElement:,GUISettingsOfElement%oneid%,% value
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
							guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Question mark.ico
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
							guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
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
							guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempFirstParamID%
							guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
							This.warningText:=lang("Error!") " " lang("This field must not be empty!") "`n"
						}
					}
				}
			}
			else
			{
				;This parameter and its controls are disabled. If so, hide all warnings.
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			if (This.warningText="" and !openingElementSettingsWindow)
			{
				;If no warning are present, hide the picture
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempFirstParamID%
			}
			
			GUISettingsOfElementObject.GeneralUpdate()
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
			;~ GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempContentTypeID%1
			
			if (tempRadioVal="string" or tempRadioVal="rawstring") 
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\String.ico
			}
			else if (tempRadioVal="expression" or tempRadioVal="number") 
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\Expression.ico
			}
			else if (tempRadioVal="variableName") 
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempFirstParamID%,%_ScriptDir%\Icons\VariableName.ico
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
			temp:=setElement.pars[parameter.id] 
			temptext:=setElement.pars[tempParameterID]
			
			gui,font,s8 cDefault wnorm
			gui,add,edit,w380 x10 multi r%tempParameterRows% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID%,%temptext%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			;Add picture, which will warn user if the entry is obviously invalid
			gui,add,picture,X+4 w16 hp hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempParameterID%
			guicontrol,move,GUISettingsOfElementWarningIconOf%tempParameterID%, h16 ;Workaround. Otherwise the next control would be overlapped with the multiline edit field
			this.components.push("GUISettingsOfElementWarningIconOf" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID, "GUISettingsOfElementWarningIconOf" tempParameterID)
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
						guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempParamID%
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("This field must not be empty!") "`n"
					}
					
				}
			}
			else
			{
				;This parameter and its controls are disabled. If so, hide all warnings.
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempParamID%
			}
			
			if (This.warningText="" and !openingElementSettingsWindow)
			{
				;If no warning are present, hide the picture
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempParamID%
			}
			
			GUISettingsOfElementObject.GeneralUpdate()
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
			temp:=setElement.pars[tempParameterID] 
			
			tempParameterOptions:=parameter.options
			if (parameter.allowExpression=true)
			{
				gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				gui,add,edit,X+6 w190 hwndtempHWND gGUISettingsOfElementSliderChangeEdit vGUISettingsOfElement%tempParameterID%,%temp%
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				gui,add,slider, w180 X+10 %tempParameterOptions%  hwndtempHWND gGUISettingsOfElementSliderChangeSlide vGUISettingsOfElementSlideOf%tempParameterID% ,% temp
				this.components.push("GUISettingsOfElementSlideOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				this.contentType:="Expression"
			}
			else
			{
				gui,add,slider, w400 x10 %tempParameterOptions% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID% ,% temp
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
			}
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
			varsToDelete.push("GUISettingsOfElementInfoIconOf" tempParameterID)
			varsToDelete.push("GUISettingsOfElementSlideOf" tempParameterID)
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
			temp:=setElement.pars[tempParameterID] 
			
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
			ElementSettingsFieldHWNDs[tempHWND]:=this
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
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
			GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%%value%,1
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
			tempChosen:=setElement.pars[tempParameterID] 
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
			ElementSettingsFieldHWNDs[tempHWND]:=this
			this.warnIfEmpty:=parameter.WarnIfEmpty
			
			if (parameter.content="Expression")
			{
				;The info icon tells user which conent type it is
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("vGUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				this.ContentType:="Expression"
				;~ GUISettingsOfElementContentType%tempParameterID%=Expression
			}
			else if (parameter.content="Number")
			{
				;The info icon tells user which conent type it is
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\expression.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("vGUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				this.ContentType:="Number"
				;~ GUISettingsOfElementContentType%tempParameterID%=Expression
			}
			else if (parameter.content="String")
			{
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\string.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				this.ContentType:="String"
				;~ GUISettingsOfElementContentType%tempParameterID%=String
			}
			else if (parameter.content="VariableName")
			{
				gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,%_ScriptDir%\icons\VariableName.ico
				this.components.push("GUISettingsOfElementInfoIconOf" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				gui,add,ComboBox, X+4 yp w360 hwndtempHWND %tempAltSumbit% gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				this.ContentType:="VariableName"
				;~ GUISettingsOfElementContentType%tempParameterID%=VariableName
			}
			else ;Text field without specified content type and without info icon
			{
				gui,add,ComboBox, x10 yp w380 hwndtempHWND %tempAltSumbit%  gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
				this.components.push("GUISettingsOfElement" tempParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
			}
			
			this.setvalue(tempChosen)
			;~ guicontrol,SettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% temptoChooseText
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID, "GUISettingsOfElementContentTypeRadio" tempParameterID, "GUISettingsOfElementInfoIconOf" tempParameterID, "GUISettingsOfElementWarningIconOf" tempParameterID)
			
		}
		
		getvalue()
		{
			global
			local temp
			local tempParameterID:=this.parameter.id
			
			
			guicontrolget,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
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
							GUIControl,SettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempindexChoice
							somethingChosen:=true
							break
						}
					}
					if (somethingChosen!=true)
						GUIControl,SettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
				}
				else
				{
					;~ ToolTip value %value%
					if (value > 0 and value <= this.par_choices.MaxIndex())
						GUIControl,SettingsOfElement:choose,GUISettingsOfElement%tempParameterID%,% value
					else
					{
						GUIControl,SettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% value
					}
				}
				
				;Check content after setting
				this.checkContent()
			}
			else
			{
				for oneIndex, oneField in ElementSettingsFields
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
			
			GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%,% tempAllChoices
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
						guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Question mark.ico
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
						guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("The variable name is not valid.") "`n"
					}
				}
				
				if (this.WarnIfEmpty)
				{
					if tempTextInControl=
					{
						guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,%_ScriptDir%\Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("This field mustn't be empty!") "`n"
					}
				}
			}
			;~ ToolTip(This.warningText)
			if (This.warningText="" and !openingElementSettingsWindow)
			{
				
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempOneParamID%
			}
			GUISettingsOfElementObject.GeneralUpdate()
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
			temp:=setElement.pars[tempParameterID] 
			
			gui,add,edit,w300 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,hotkey,w90 X+10 hwndtempHWND gGUISettingsOfElementHotkey vGUISettingsOfElement%tempParameterID%hotkey,%temp%
			this.components.push("GUISettingsOfElementHotkey" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
			varsToDelete.push("GUISettingsOfElementHotkey" tempParameterID)
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
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
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
						%templabel%({flowID: flowobj.id, elementID: setElementID})
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
			temp:=setElement.pars[tempParameterID] 
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			gui,add,button,w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%,...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElementbutton" tempParameterID)
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
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
			temp:=setElement.pars[tempParameterID] 
			
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempParameterID%,%temp%
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,button,w20 X+10 hwndtempHWND gGUISettingsOfElementButton vGUISettingsOfElementbutton%tempParameterID%,...
			this.components.push("GUISettingsOfElementbutton" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElementbuttonSelectFile__" tempParameterID)
			varsToDelete.push("GUISettingsOfElement" tempParameterID "Prompt")
			varsToDelete.push("GUISettingsOfElement" tempParameterID "Options")
			varsToDelete.push("GUISettingsOfElement" tempParameterID "Filter")
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
			temp:=setElement.pars[tempParameterID] 
			
			gui,add,checkbox,w45 x10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%2,% lang("Mon (Short for Monday")
			this.components.push("GUISettingsOfElement" tempParameterID "2")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%3,% lang("Tue (Short for Tuesday")
			this.components.push("GUISettingsOfElement" tempParameterID "3")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%4,% lang("Wed (Short for Wednesday")
			this.components.push("GUISettingsOfElement" tempParameterID "4")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%5,% lang("Thu (Short for Thursday")
			this.components.push("GUISettingsOfElement" tempParameterID "5")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%6,% lang("Fri (Short for Friday")
			this.components.push("GUISettingsOfElement" tempParameterID "6")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%7,% lang("Sat (Short for Saturday")
			this.components.push("GUISettingsOfElement" tempParameterID "7")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%1,% lang("Sun (Short for Sunday") ;Sunday is 1
			this.components.push("GUISettingsOfElement" tempParameterID "1")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
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
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
			varsToDelete.push("GUISettingsOfElement" tempParameterID1)
			varsToDelete.push("GUISettingsOfElement" tempParameterID2)
			varsToDelete.push("GUISettingsOfElement" tempParameterID3)
			varsToDelete.push("GUISettingsOfElement" tempParameterID4)
			varsToDelete.push("GUISettingsOfElement" tempParameterID5)
			varsToDelete.push("GUISettingsOfElement" tempParameterID6)
			varsToDelete.push("GUISettingsOfElement" tempParameterID7)
		}
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if parameterID=
				tempParameterID:=this.parameter.id
			else
				tempParameterID:=parameterID
			GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
			
			temp:=""
			loop 7
			{
				if (GUISettingsOfElement%tempParameterID%%a_index%=1)
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
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%1,1
			IfInString,value,2
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%2,1
			IfInString,value,3
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%3,1
			IfInString,value,4
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%4,1
			IfInString,value,5
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%5,1
			IfInString,value,6
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%6,1
			IfInString,value,7
				guicontrol,SettingsOfElement:,GUISettingsOfElement%tempParameterID%7,1
			
			return
		}
		
		changeweekdays() ;TODO remove if no more action necessary
		{
			this.udpatename()
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
			tempChosen:=setElement.pars[tempParameterID] 
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
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
			
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
			
			GUIControlGet,tempChosen,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
			
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
							GUIControl,SettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempindexChoice
						}
					}
				}
			}
			else
			{
				for tempindexChosen, tempNumberChosen in value
				{
					GUIControl,SettingsOfElement:Choose,GUISettingsOfElement%tempParameterID%,% tempNumberChosen
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
		for ElementSaveindex, parameter in parametersToEdit
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
				temponeValue:=ElementSettingsFieldParIDs[tempOneParID].getValue(tempOneParID)
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
		if (generalUpdateRunning)
		{
			return
		}
		generalUpdateRunning:=True
		GUISettingsOfElementRemoveInfoTooltip()
		;~ ToolTip updakljö
		allParamValues:=GUISettingsOfElementObject.getAllValues()
		setelement.FirstCallOfCheckSettings:=firstCall
		Element_CheckSettings_%setElementClass%(setElement, allParamValues) 
		ElementSettingsNameField.updatename(allParamValues)
		generalUpdateRunning:=False
	}
	
	
	
	
	

	disable()
	{
		global
		
		gui,SettingsOfElement:+disabled
	}

	enable()
	{
		global
		
		gui,SettingsOfElement:-disabled
		WinActivate, ahk_id %SettingWindowHWND%
	}

	
	
	
	;Delete some variables on exit
	close()
	{
		global
		GUISettingsOfElementObject:=""
		ElementSettingsFields:=""
		ElementSettingsFieldHWNDs:=""
		ElementSettingsFieldParIDs:=""
		setElementID:=""
		setElementType:=""
		setElementClass:=""
		setElement:=""
		ElementSettingsNameField:=""
		EditGUIEnable()
	}



	
}





;Called when the GUI is resized by user
SettingsOfElementParentSize(GuiHwnd, EventInfo, Width, Height)
{
	global
	
	If (EventInfo <> 1) ;if not minimized
	{
		;~ GuiHwnd+=0
		SetWinDelay,0
		GetClientSize(SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH) ;Sometimes for any reason the width and height parameters are not correct. therefore get the gui size again
		guicontrol, GUISettingsOfElementParent:move,ButtonSave,% "y" ElSetingGUIH-40
		guicontrol, GUISettingsOfElementParent:move,ButtonCancel,% "y" ElSetingGUIH-40
		winmove,% "ahk_id " SettingWindowHWND,  , 0, 30,  ,% ElSetingGUIH-90
		;~ if not a_iscompiled
			;~ ToolTip %GuiHwnd% %Width% %Height% - %ElSetingGUIW% %ElSetingGUIH% - %SettingWindowHWND% %SettingWindowParentHWND%
	}
	Return
}


;This and following functions will be called if user changes some value
GUISettingsOfElementChangeRadio(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].ChangeRadio()
	
	return
}

GUISettingsOfElementCheckContent(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].checkcontent()
	
	return
}


GUISettingsOfElementCheckStandardName(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	GUISettingsOfElementObject.GeneralUpdate()
	;~ ElementSettingsFieldHWNDs[CtrlHwnd].UpdateName()
}

GUISettingsOfElementGeneralUpdate(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	GUISettingsOfElementObject.GeneralUpdate()
	return
}

GUISettingsOfElementClickOnWarningPic(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].ClickOnWarningPic()
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
	ElementSettingsFieldHWNDs[CtrlHwnd].ClickOnInfoPic()
	
	return
}


GUISettingsOfElementSliderChangeEdit(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].SliderChangeEdit()
	return
}


GUISettingsOfElementSliderChangeSlide(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].SliderChangeSlide()
	return
}

	
GUISettingsOfElementHotkey(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].ChangeHotkey()
	return
}

GUISettingsOfElementButton(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].ClickOnButton()
	return
	
	
}
GUISettingsOfElementWeekdays(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].ChangeWeekdays()
	return
	
	
}

