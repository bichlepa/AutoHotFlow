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
		parametersToEdit:=Element_getParametrizationDetails_%setElementClass%({flowID: flowobj.id, elementID: setElementID})
		
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
						this.enabled:=enOrDis
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
			
			gui,font,s8 cDefault wnorm
			temp:=setElement.pars[tempParameterID] 
			tempAssigned:=false
			for tempindex, tempRadioLabel in parameter.choices
			{
				if a_index=1
					tempMakeNewGroup=Group
				else
					tempMakeNewGroup=
				
				if (temp=a_index)
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
					temp:=A_Index
					break
				}
			}
			
			return temp
		}
		setvalue(value)
		{
			global
			local tempParameterID:=this.parameter.id
			GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%%value%,1
			return temp
		}
		
		
	}
	
	class edit extends ElementSettings.field
	{
		__new(parameter)
		{
			global
			base.__new(parameter)
			local temp, temptext, tempIsMulti, tempXpos,tempEditwidth, tempHWND, tempContentTypeID, tempContentTypeNum, tempOneParameterID, tempchecked1, tempchecked2, tempassigned
			if (not IsObject(parameter.id))
				parameter.id:=[parameter.id]
			local tempParameterID:=parameter.id
		
			
			gui,font,s8 cDefault wnorm
			
			if (tempParameterID.MaxIndex()=1 or parameter.content="StringOrExpression") ;if only one edit
			{
				tempOneParameterID:=tempParameterID[1]
				tempContentTypeID:=tempParameterID[2]
				
				temptext:=setElement.pars[tempOneParameterID] ;get the saved parameter
				
				if parameter.multiline
					tempIsMulti=h100 multi
				else
					tempIsMulti=r1
				
				if (parameter.content="StringOrExpression") ;Add two radios to select the element type
				{
					tempContentTypeNum:=setElement.pars[tempContentTypeID] ;get the saved parameter
					tempassigned:=false
					if tempContentTypeNum=1
					{
						tempchecked1=checked
						tempassigned:=true
					}
					else
						tempchecked1=
					if tempContentTypeNum=2
					{
						tempchecked2=checked
						tempassigned:=true
					}
					else
						tempchecked2=
					
					gui,add,radio, w400 x10 %tempchecked1% Group hwndtempHWND gGUISettingsOfElementChangeRadio vGUISettingsOfElement%tempContentTypeID%1 ,% lang("This is a value")
					this.components.push("GUISettingsOfElement" tempContentTypeID "1")
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					gui,add,radio, w400 x10 %tempChecked2% hwndtempHWND gGUISettingsOfElementChangeRadio vGUISettingsOfElement%tempContentTypeID%2 ,% lang("This is a variable name or expression")
					this.components.push("GUISettingsOfElement" tempContentTypeID "2")
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					if (tempAssigned=false) ;Catch if a wrong value was saved and set to default value.
					{
						temp:=parameter.default[2]
						guicontrol,SettingsOfElement:,GUISettingsOfElement%tempContentTypeID%%temp%,1
					}
					
					varsToDelete.push("GUISettingsOfElement" tempContentTypeID "1")
					varsToDelete.push("GUISettingsOfElement" tempContentTypeID "2")
				}
				
				;Add picture, which will warn user if the entry is obviously invalid
				gui,add,picture,x394 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempOneParameterID%
				this.components.push("GUISettingsOfElementWarningIconOf" tempOneParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				this.warnIfEmpty:=parameter.WarnIfEmpty
				
				if (parameter.content="Expression")
				{
					;The info icon tells user which conent type it is
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\expression.ico
					this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					gui,add,edit,X+4 w360 %tempIsMulti% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("vGUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					if parameter.useupdown
					{
						if parameter.range
							gui,add,updown,% "range" parameter.range
						else
							gui,add,updown
						guicontrol,SettingsOfElement:,GUISettingsOfElement%tempOneParameterID%,%temptext%
					}
					this.ContentType:="Expression"
					;~ GUISettingsOfElementContentType%tempOneParameterID%=Expression
				}
				else if (parameter.content="String")
				{
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\string.ico
					this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					gui,add,edit,X+4 w360 %tempIsMulti% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("GUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					this.ContentType:="String"
					;~ GUISettingsOfElementContentType%tempOneParameterID%=String
				}
				else if (parameter.content="VariableName")
				{
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\VariableName.ico
					this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					gui,add,edit,X+4 w360 %tempIsMulti% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("GUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					this.ContentType:="VariableName"
					;~ GUISettingsOfElementContentType%tempOneParameterID%=VariableName
				}
				else if (parameter.content="StringOrExpression")
				{
					
					
					if (tempContentTypeNum=1) 
						gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\string.ico
					else ;If content is expression
						gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\expression.ico
					this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					gui,add,edit,X+4 w360 %tempIsMulti% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("GUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					this.ContentType:="StringOrExpression"
				}
				else ;Text field without specified content type and without info icon
				{
					gui,add,edit,x10 yp w380 %tempIsMulti% hwndtempHWND gGUISettingsOfElementCheckContent vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("GUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
				}
				
				this.checkContent()
				
				varsToDelete.push("GUISettingsOfElement" tempOneParameterID, "GUISettingsOfElementContentTypeRadio" tempOneParameterID, "GUISettingsOfElementInfoIconOf" tempOneParameterID, "GUISettingsOfElementWarningIconOf" tempOneParameterID)
				
				
			}
			else ;If multiple edits in one line
			{
				;~ MsgBox %tempEditwidth%
				for tempIndex, tempOneParameterID in parameter.id
				{
					temptext:=setElement.pars[tempOneParameterID] ;get the saved parameter
					
					
					if tempIndex=1
					{
						tempEditwidth:= round((380 - (10 * (parameter.id.MaxIndex()-1)))/parameter.id.MaxIndex())
						tempXpos:="X+4"
						if (parameter.content="Expression")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\expression.ico
							this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
							ElementSettingsFieldHWNDs[tempHWND]:=this
							tempXpos:="X+4"
						}
						else if (parameter.content="String")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\string.ico
							this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
							ElementSettingsFieldHWNDs[tempHWND]:=this
							tempXpos:="X+4"
						}
						else if (parameter.content="VariableName")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,%_ScriptDir%\icons\VariableName.ico
							this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
							ElementSettingsFieldHWNDs[tempHWND]:=this
							tempXpos:="X+4"
						}
						else
						{
							tempEditwidth:= round((400 - (10 * (parameter.id.MaxIndex()-1)))/parameter.id.MaxIndex())
							tempXpos:="x10"
						}
					}
					else
						tempXpos:="X+10"
					;~ MsgBox %tempXpos%
					gui,add,edit,%tempXpos% w%tempEditwidth% hwndtempHWND gGUISettingsOfElementGeneralUpdate vGUISettingsOfElement%tempOneParameterID%,%temptext%
					this.components.push("GUISettingsOfElement" tempOneParameterID)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					this.ContentType:=this.parameter.content
					
					varsToDelete.push("GUISettingsOfElement" tempOneParameterID)
					varsToDelete.push("GUISettingsOfElementContentType" tempOneParameterID)
					varsToDelete.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
				}
				
			}
		}
		
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if (parameterID!="" and parameterID=this.parameter.id[2] and this.parameter.content = "StringOrExpression")
			{
				loop 2
				{
					GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%parameterID%%a_index%
					if temp=1
					{
						temp:=a_index
						break
					}
				}
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
				;~ MsgBox -++-- %parameterID%
				;~ MsgBox % "..." temp
				return temp
			}
			
		}
		
		checkContent()
		{
			global
			local tempFoundPos, tempRadioVal, tempOneParamID, tempTextInControl, tempTextInControlReplaced
			
			tempRadioID:=this.parameter.id[2]
			;~ GUIControlGet,tempRadioVal2,SettingsOfElement:,GUISettingsOfElement%tempRadioID%2
			tempRadioVal:=this.getvalue(tempRadioID)
			tempOneParamID:=this.parameter.id[1]
			if tempOneParamID=
				MsgBox error! tempOneParamID is empty. Code: 7625893756
			
			This.warningText:=""
			if (this.enabled)
			{
				tempTextInControl:=this.getvalue(tempOneParamID)
				;~ MsgBox % tempTextInControl "`n" this.ContentType
				if (this.ContentType="Expression" or (this.ContentType="StringOrExpression" and tempRadioVal=2))
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
			else
			{
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempOneParamID%
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
			local temp, tempOneParamID, tempRadioID
			tempOneParamID:=this.parameter.id[1]
			tempRadioID:=this.parameter.id[2]
			
			if (this.contenttype="Expression")
			{
				ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)" ,,,11
			}
			if (this.contenttype="String")
			{
				ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
			}
			if (this.contenttype="VariableName") 
			{
				ToolTip,% lang("This field contains a variable name") "`n" lang("Examples") ":`nVarname`nEntry1`nEntry%a_index%" ,,,11
			}
			if (this.contenttype="StringOrExpression") 
			{
				GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempRadioID%1
				if (temp=1)
					ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
				else
					ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)" ,,,11
			}
			settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
		}
		
		
		changeRadio()
		{
			global
			local temp, tempGUIControl, tempContentTypeID
			tempGUIControl:=this.parameter.id[1]
			tempContentTypeID:=this.parameter.id[2]
			
			temp:=this.getvalue(tempContentTypeID)
			;~ GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempContentTypeID%1
			
			if temp=1 ;String
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempGUIControl%,%_ScriptDir%\Icons\String.ico
				
			}
			else ;Expression
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempGUIControl%,%_ScriptDir%\Icons\Expression.ico
				
			}
			
			
			GUISettingsOfElementObject.GeneralUpdate()
			this.checkcontent()
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
				this.components.push("vGUISettingsOfElement" tempParameterID)
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
			this.setValue(temp,"SlideOf" tempGUIControl)
			this.udpatename()
		}
		sliderChangeSlide()
		{
			global
			local temp, tempGUIControl
			tempGUIControl:=this.parameter.id
			temp:=this.getValue("SlideOf" tempGUIControl)
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
			
			if (parameter.result != "number" and parameter.result != "string")
				MsgBox unexpected error: the parameter "result" of "DropDown" is unset or has unsupported value
			
			if (parameter.result="number")
			{
				temptoChoose:=temp
				tempAltSumbit=AltSubmit
			}
			else
				tempAltSumbit=
			tempChoises:=parameter.choices
			
			;loop through all choices. Find which one to select. Make a selection list which is capable for the gui,add command
			tempAllChoices=
			for tempIndex, TempOneChoice in tempChoises
			{
				if (parameter.result="string")
				{
					if (TempOneChoice=temp)
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
					ToolTip value %value%
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
				if (this.ContentType="Expression")
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
			
			if (this.contenttype="Expression")
			{
				ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)" ,,,11
			}
			if (this.contenttype="String")
			{
				ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
			}
			if (this.contenttype="VariableName") 
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
			
			
			;Certain types of control consist of multiple controls and thus contain multiple parameters.
			for ElementSaveindex2, oneID in parameterID
			{
				tempOneParID:=parameterID[ElementSaveindex2]
				temponeValue:=ElementSettingsFieldParIDs[tempOneParID].getValue(tempOneParID)
				tempPars[tempOneParID]:=temponeValue
				
			
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

