;Needed translations:
temp:=lang("Trigger")
temp:=lang("Action")
temp:=lang("Condition")
temp:=lang("Loop")

/* prototypes
selectContainerType(parelement, "wait")
selectConnectionType(parelement,"wait")
selectSubType(parElement,"wait")
ElementSettings.open(newElement,"wait")
ElementSettings.selectTrigger("wait")
*/

class ElementSettings
{
	;Open GUI for settings parameters of an element.
	open(p_ID,wait="")
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
		
		;At first check whether other settings must be opened first
		if (setElement.Type="Trigger")
		{
			if (setElement.ID="trigger")
			{
				ElementSettingsGOTOPointIfATriggerWasDeleted:
				;~ MsgBox % setElement.triggers.count()
				if (setElement.triggers.count()>0)
				{
					tempres:=this.selectTrigger("wait")
					;~ MsgBox % tempres
					if tempres=aborted
					{
						this.close()
						return tempres
					}
					if tempres=deleted
					{
						new state()
						goto ElementSettingsGOTOPointIfATriggerWasDeleted 
					}
					setElement:=ParElement
				}
				else
				{
					tempelement:=new trigger(setElement.id)
					;~ MsgBox % strobj(tempelement)
					tempres:=selectsubtype(tempelement,"wait")
					if tempres=aborted
					{
						this.close()
						return tempres
					}
					else
					{
						this.element:=flowObj.alltriggers[tempelement]
						setElement:=this.element
						setElementID:=tempelement
						setElementType:=tempelement.Type
						setElementClass:=tempelement.class
					}
				}
			}
			
		}
		NowResultEditingElement:=""
		
		
		
		
		static varsToDelete:=[] ;TODO: maybe unnecessary
		ElementSettingsFields:={} ;global. contains the fields which will be shown in the GUI. Each field is a bunch of controls
		ElementSettingsFieldHWNDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		ElementSettingsFieldParIDs:={} ;global. Contains the field hwnds and the field object. Needed for responding user input
		
		EditGUIDisable()
		gui,SettingsOfElement:default
		gui,-DPIScale
		;~ gui,font,s8 cDefault wnorm
		;~ gui,add,button,w370 x10 gGUISettingsOfElementSelectType,% lang("%1%_type:_%2%",lang(setElementType),getname%setElementType%%setElementsubType%())
		;~ gui,add,button,w20 x10 X+10 yp gGUISettingsOfElementHelp,?
		;~ gui,font,s10 cnavy wbold
		;~ gui,add,text,x10 w400,Name
		;~ gui,font,s8 cDefault wnorm
		;~ gui,add,checkbox, x10 vGUISettingsOfElementCheckStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
		;~ gui,add,edit,w400 x10 Multi r5 vGUISettingsOfElementEditName gGUISettingsOfElementUpdateName,% setElement.name
		gui,+hwndSettingsGUIHWND
		CurrentlyActiveWindowHWND:=SettingsGUIHWND
		
		
		openingElementSettingsWindow:=true ;Allows some elements to initialize their parameter list. (such as in "play sound": find all system sound)
		try
			parametersToEdit:=Element_getParametrizationDetails_%setElementClass%(true)
		catch
			parametersToEdit:=Element_getParametrizationDetails_%setElementClass%() ;TODO: all elements should accept one parameter
		
		ElementSettingsFields.push(new this.label({label: lang("name (name)")}))
		ElementSettingsFields.push(new this.name({id: ["name", "defaultname"]}))
		
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
			
		}
		
		
		
		;Create scrollable GUI
		gui +hwndSettingWindowHWND
		;~ d(instance,52345)
		SG2 := New ScrollGUI(SettingWindowHWND,600, A_ScreenHeight*0.8, "-dpiscale",2,2)
		;~ d(instance,45234)
		; Create the main window (parent)
		Gui, GUISettingsOfElementParent:New
		;~ d(instance,4849)
		gui,GUISettingsOfElementParent:-DPIScale
		;~ d(instance,13223213)
		Gui, GUISettingsOfElementParent:Margin, 0, 20
		;~ d(instance,54668)
		
		Gui, % SG2.HWND . ": -Caption +ParentGUISettingsOfElementParent +LastFound"
		Gui, % SG2.HWND . ":Show", Hide  y25
		;~ d(instance,1891)
		WinGetPos, , , WsettingsParent, HsettingsParent,% "ahk_id " SG2.HWND
		;~ W := Round(W * (96 / A_ScreenDPI))
		;~ H := Round(H * (96 / A_ScreenDPI))
		YsettingsButtoPos := HsettingsParent + 10
		WinGetPos, , , Wsettings, Hsettings,% "ahk_id " SG2.HGUI
		HParent:=Hsettings+90
		;Make resizeable
		gui,+hwndSettingWindowParentHWND
		gui,+LabelSettingsOfElementParent
		gui,+resize
		gui,+minsize%WsettingsParent%x200 ;Ensure constant width.
		gui,+maxsize%WsettingsParent%x%HParent%
		;~ d(instance,2634)
		;add buttons
		gui,font,s8 cDefault wnorm
		gui, GUISettingsOfElementParent:add,button, w370 x10 y10 gGUISettingsOfElementSelectType h20,% lang("%1%_type:_%2%",lang(setElementType),Element_getName_%setElementClass%())
		gui, GUISettingsOfElementParent:add,button, w20 X+10 yp h20 gGUISettingsOfElementHelp vGUISettingsOfElementHelp,?
		;~ guicontrol,focus,GUISettingsOfElementHelp
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementSave vButtonSave w145 x10 h30 y%YsettingsButtoPos%,% lang("Save")
		Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementCancel vButtonCancel default w145 h30 yp X+10,% lang("Cancel")
		;Make GUI autosizing
		Gui, GUISettingsOfElementParent:Show, hide w%WsettingsParent%
		Gui, GUISettingsOfElementParent:Show, hide w%WsettingsParent%,% lang("Settings") " - " lang(Element.type) " - " Element_getName_%setElementClass%() ;Needed twice, otherwise the width is not correct
		; Show ScrollGUI1
		;~ Return
		;~ d(instance,635)
		;Calculate position to show the settings window in the middle of the main window
		pos:=EditGUIGetPos()
		tempHeight:=round(pos.h-100) ;This will be the max height. If child gui is larger, it must be scrolled
		DetectHiddenWindows,on
		WinGetPos,ElSetingGUIX,ElSetingGUIY,ElSetingGUIW,ElSetingGUIH,ahk_id %SettingWindowParentHWND%
		tempXpos:=round(pos.x+pos.w/2- ElSetingGUIW/2)
		tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
		;move Parent window
		gui,GUISettingsOfElementParent:show,% "x" tempXpos " y" tempYpos " h" tempHeight " hide" 
		
		;~ SetWinDelay,0
		;~ Gui, % SG2.HWND . ":Show", Hide  y40
		;Make ScrollGUI autosize 
		;~ d(instance,84946516)
		SG2.Show("", "x0 y40 h" tempHeight " hide ")
		;~ d(instance,7347)
		;position lower buttons
		GetClientSize(SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH)
		guicontrol, GUISettingsOfElementParent:move,ButtonSave,% "y" ElSetingGUIH-40
		guicontrol, GUISettingsOfElementParent:move,ButtonCancel,% "y" ElSetingGUIH-40
		;Position the Scroll gui
		wingetpos,,,ElSetingGUIW,ElSetingGUIH,ahk_id %SettingWindowParentHWND%
		WinMove,ahk_id %SettingWindowParentHWND%,,,,% ElSetingGUIW,% ElSetingGUIH+1 ;make the autosize function trigger, which resizes and moves the scrollgui
		;~ d(instance,2346346)
		;show gui
		SG2.Show() 
		
		CurrentlyActiveWindowHWND:=SettingWindowParentHWND
		
		openingElementSettingsWindow:=false
		
		ElementSettingsNameField.updatename()
			
		gui,GUISettingsOfElementParent:show
		
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
		SG2.Destroy()
		gui,GUISettingsOfElementParent:destroy
		ui_closeHelp() 
		EditGUIEnable()
		
		tempres:=selectSubType(setelement, "wait")
		if tempres!=aborted
			NowResultEditingElement:= ElementSettings.open(setelement,Parameterwait)
		else 
		{
			NowResultEditingElement:="aborted"
			return
		}
		
		
		GUISettingsOfElementHelp:
		
		IfWinExist,ahk_id %GUIHelpHWND%
			ui_closeHelp()
		else
			ui_showHelp(setElement.Type "\" setElement.subtype)
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
		SG2.Destroy()
		gui,GUISettingsOfElementParent:destroy
		
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		NowResultEditingElement:="aborted"
		GUISettingsOfElementObject.close()
		return
		
		
		
		GUISettingsOfElementSave:
		GUISettingsOfElementobject.updatename()
		;~ gui,SettingsOfElement:submit
		if (setElement.type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
		{
			tempReenablethen:=true
			;r_EnableFlow() ;TODO ;Disable flow
		}
		else
			tempReenablethen:=false
		
		;Save the parameters
		somethingchanged:=0 ;will be incremented if a change will be detected
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
				if (setElement.par[tempOneParID]!=temponeValue)
					somethingchanged++
				setElement.par[tempOneParID]:=temponeValue
				
				;~ MsgBox,1,, % tempOneParID "`n`n" ElementSaveindex  "-" ElementSaveindex2 "`n`n" strobj(ElementSettingsFieldParIDs[tempOneParID]) "`n`n" strobj(setElement)
				;~ IfMsgBox cancel
					;~ MsgBox % strobj(ElementSettingsFieldParIDs)
			
			}
			
			
			
		}
		temponeValue:=""
		
		ui_closeHelp() 
		SG2.Destroy()
		gui,SettingsOfElement:destroy
		gui,GUISettingsOfElementParent:destroy
		GUISettingsOfElementRemoveInfoTooltip()
		
		EditGUIEnable()
		

		NowResultEditingElement:=somethingchanged " Changes"
		
		;if (tempReenablethen) ;TODO
			;r_EnableFlow()
		
		if (setElementType="Trigger")
		{
			maintrigger.updatename()
			API_Main_Draw()
			
		}
		
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
		
		getvalue(parameterID="")
		{
			global
			local temp, tempParameterID
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			GUIControlGet,temp,SettingsOfElement:,GUISettingsOfElement%tempParameterID%
			return temp
		}
		
		setvalue(value, parameterID="")
		{
			global
			local tempParameterID:=this.parameter.id
			if parameterID=
			{
				tempParameterID:=this.parameter.id
				if isobject(tempParameterID)
					tempParameterID:=tempParameterID[1]
			}
			else
				tempParameterID:=parameterID
			
			GUIControl,SettingsOfElement:,GUISettingsOfElement%tempParameterID%,% value
			return
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
			;~ MsgBox % strobj(this.components)
			;~ MsgBox % parameterID
			if parameterID=
			{
				for index, component in this.components
				{
					
					guicontrol,SettingsOfElement:enable%enOrDis%,% component
				}
				this.enabled:=enOrDis
			}
			else
			{
				;~ MsgBox guicontrol,SettingsOfElement:enable%enOrDis%,GUISettingsOfElement%parameterID%
				guicontrol,SettingsOfElement:enable%enOrDis%,GUISettingsOfElement%parameterID%
				this.enabled:=-1 ;Means that it is not globally enabled or disabled
			}
			
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
			;~ temptext:=setElement.par["Name"] 
			
			gui,add,checkbox, x10 hwndtempHWND checked%tempchecked% vGUISettingsOfElementStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
			this.components.push("GUISettingsOfElementStandardName")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,edit,w400 x10 Multi r5 hwndtempHWND vGUISettingsOfElementName gGUISettingsOfElementUpdateName,% setElement.name
			this.components.push("GUISettingsOfElementName")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			varsToDelete.push("GUISettingsOfElementCheckStandardName")
			varsToDelete.push("GUISettingsOfElementEditName")
			
		}
		
		updateName()
		{
			global
			local Newname
			
			if (openingElementSettingsWindow=true)
				return
			
			if (this.getvalue("StandardName")=1)
			{
				this.disable("Name")
				Newname:=Element_GenerateName_%setElementClass%(GUISettingsOfElementObject.getAllValues()) ;TODO: Parameter mit Inhalt übergeben
				StringReplace,Newname,Newname,`n,%a_space%-%a_space%,all
				this.setvalue(Newname)
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
			temp:=setElement.par[parameter.id] 
			temptext:=parameter.label
			if parameter.gray
				tempParGray=check3
			else
				tempParGray=
			gui,add,checkbox,w400 x10 %tempParGray% checked%temp% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID%,%temptext%
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
			temp:=setElement.par[tempParameterID] 
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
					
				gui,add,radio, w400 x10 %tempChecked% %tempMakeNewGroup% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID%%a_index% ,% tempRadioLabel
				this.components.push("GUISettingsOfElement" tempParameterID a_index)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				
				varsToDelete.push("GUISettingsOfElement" tempParameterID a_index)
			}
			if (tempAssigned=false) ;Catch if a wrong value was saved and set to default value.
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
				
				temptext:=setElement.par[tempOneParameterID] ;get the saved parameter
				
				if parameter.multiline
					tempIsMulti=h100 multi
				else
					tempIsMulti=r1
				
				if (parameter.content="StringOrExpression") ;Add two radios to select the element type
				{
					tempContentTypeNum:=setElement.par[tempContentTypeID] ;get the saved parameter
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
					this.components.push("GUISettingsOfElement" tempOneParameterID a_index)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					gui,add,radio, w400 x10 %tempChecked2% hwndtempHWND gGUISettingsOfElementChangeRadio vGUISettingsOfElement%tempContentTypeID%2 ,% lang("This is a variable name or expression")
					this.components.push("GUISettingsOfElement" tempOneParameterID a_index)
					ElementSettingsFieldHWNDs[tempHWND]:=this
					
					if (tempAssigned=false) ;Catch if a wrong value was saved and set to default value.
					{
						temp:=parameter.default[2]
						guicontrol,SettingsOfElement:,GUISettingsOfElement%tempContentTypeID%%temp%,1
					}
					
					varsToDelete.push("GUISettingsOfElement" tempContentTypeID "1")
					varsToDelete.push("GUISettingsOfElement" tempContentTypeID "2")
				}
				
				;Add picture, which will warn user if the etry is obviously invalid
				gui,add,picture,x394 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%tempOneParameterID%
				this.components.push("GUISettingsOfElementWarningIconOf" tempOneParameterID)
				ElementSettingsFieldHWNDs[tempHWND]:=this
				this.warnIfEmpty:=parameter.WarnIfEmpty
				
				if (parameter.content="Expression")
				{
					;The info icon tells user which conent type it is
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\expression.ico
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
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\string.ico
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
					gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\VariableName.ico
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
						gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\string.ico
					else ;If content is expression
						gui,add,picture,x10 yp w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\expression.ico
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
					temptext:=setElement.par[tempOneParameterID] ;get the saved parameter
					
					
					if tempIndex=1
					{
						tempEditwidth:= round((380 - (10 * (parameter.id.MaxIndex()-1)))/parameter.id.MaxIndex())
						tempXpos:="X+4"
						if (parameter.content="Expression")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\expression.ico
							this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
							ElementSettingsFieldHWNDs[tempHWND]:=this
							tempXpos:="X+4"
						}
						else if (parameter.content="String")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\string.ico
							this.components.push("GUISettingsOfElementInfoIconOf" tempOneParameterID)
							ElementSettingsFieldHWNDs[tempHWND]:=this
							tempXpos:="X+4"
						}
						else if (parameter.content="VariableName")
						{
							gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempOneParameterID%,icons\VariableName.ico
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
					gui,add,edit,%tempXpos% w%tempEditwidth% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempOneParameterID%,%temptext%
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
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,Icons\Question mark.ico
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
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("The variable name is not valid.") "`n"
					}
				}
				
				if (this.WarnIfEmpty)
				{
					if tempTextInControl=
					{
						guicontrol,SettingsOfElement:show,GUISettingsOfElementWarningIconOf%tempOneParamID%
						guicontrol,SettingsOfElement:,GUISettingsOfElementWarningIconOf%tempOneParamID%,Icons\Exclamation mark.ico
						This.warningText:=lang("Error!") " " lang("This field mustn't be empty!") "`n"
					}
				}
			}
			;~ ToolTip(This.warningText)
			if (This.warningText="" and !openingElementSettingsWindow)
			{
				
				guicontrol,SettingsOfElement:hide,GUISettingsOfElementWarningIconOf%tempOneParamID%
			}
			ElementSettingsNameField.updatename()
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
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempGUIControl%,Icons\String.ico
				
			}
			else ;Expression
			{
				guicontrol,SettingsOfElement:,GUISettingsOfElementInfoIconOf%tempGUIControl%,Icons\Expression.ico
				
			}
			
			
			ElementSettingsNameField.UpdateName()
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
			temp:=setElement.par[tempParameterID] 
			
			tempParameterOptions:=parameter.options
			if (parameter.allowExpression=true)
			{
				gui,add,picture,x10 w16 h16 hwndtempHWND gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%tempParameterID%,icons\expression.ico
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
				gui,add,slider, w400 x10 %tempParameterOptions% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID% ,% temp
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
			temp:=setElement.par[tempParameterID] 
			
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
				if (parameter.result="name")
				{
					if (TempOneChoice=temp)
						temptoChoose:=A_Index
				}
				tempAllChoices.="|" TempOneChoice
				
			}
			
			StringTrimLeft,tempAllChoices,tempAllChoices,1
			gui,add,DropDownList, w400 x10 %tempAltSumbit% choose%temptoChoose% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
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
			temp:=setElement.par[tempParameterID] 
			
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
				if (parameter.result="name")
				{
					if (TempOneChoice=temp)
						temptoChoose:=A_Index
				}
				tempAllChoices.="|" TempOneChoice
				
			}
			StringTrimLeft,tempAllChoices,tempAllChoices,1
			
			gui,add,ComboBox, w400 x10 %tempAltSumbit% choose%temptoChoose% hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID% ,% tempAllChoices
			this.components.push("GUISettingsOfElement" tempParameterID)
			ElementSettingsFieldHWNDs[tempHWND]:=this
			
			guicontrol,SettingsOfElement:text,GUISettingsOfElement%tempParameterID%,% temp
			
			varsToDelete.push("GUISettingsOfElement" tempParameterID)
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
			temp:=setElement.par[tempParameterID] 
			
			gui,add,edit,w300 x10 hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID%,%temp%
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
			gosub,% this.parameter.goto
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
			temp:=setElement.par[tempParameterID] 
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID%,%temp%
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
			temp:=setElement.par[tempParameterID] 
			
			
			gui,add,edit,w370 x10 hwndtempHWND gGUISettingsOfElementUpdateName vGUISettingsOfElement%tempParameterID%,%temp%
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
			temp:=setElement.par[tempParameterID] 
			
			gui,add,checkbox,w45 x10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%2,% lang("Mon (Short for Monday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "2")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%3,% lang("Tue (Short for Tuesday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "3")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%4,% lang("Wed (Short for Wednesday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "4")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%5,% lang("Thu (Short for Thursday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "5")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%6,% lang("Fri (Short for Friday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "6")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%7,% lang("Sat (Short for Saturday")
			this.components.push("GUISettingsOfElement" tempOneParameterID "7")
			ElementSettingsFieldHWNDs[tempHWND]:=this
			gui,add,checkbox,w45 X+10 hwndtempHWND gGUISettingsOfElementWeekdays vGUISettingsOfElement%tempParameterID%1,% lang("Sun (Short for Sunday") ;Sunday is 1
			this.components.push("GUISettingsOfElement" tempOneParameterID "1")
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
	
	
	
	;Update the name field
	updatename()
	{
		global
		GUISettingsOfElementRemoveInfoTooltip()
		;~ ToolTip updakljö
		;~ CheckSettings%setElementType%%setElementsubType%(setElement) ;?
		ElementSettingsNameField.updatename() ;The element 0 contains the name field
		
	}
	
	
	
	
	
	
	;When user wants to edit a trigger element, open a list with containing triggers
	selectTrigger(wait)
	{
		global flowObj
		global CurrentlyActiveWindowHWND
		global GUISettingsOfElementObject
		static NowResultEditingElement
		static GuiTriggerChoose
		setElement:=this.element
		
		
		NowResultEditingElement:=""
		
		
		
		TriggersCount:=setElement.triggers.MaxIndex()
		
		;~ MsgBox % strobj(setElement)
		
		static tempTriggers=[]
		tempTriggerNames=
		for index, temptrigger in setElement.triggers
		{
			tempTriggers[a_index]:=temptrigger
			tempTriggerNames.=temptrigger.name "|"
		}
		StringTrimRight,tempTriggerNames,tempTriggerNames,1
		StringSplit,tempTriggerNames,tempTriggerNames,|
		if (TempTriggerCount=0)
		{
			trigger:=new trigger()
			selectSubType(trigger)
			return 
		}
		else
		{
			
			EditGUIDisable()
			;~ gui,GUITrigger:default
			gui,GUITrigger:-DPIScale
			;~ gui,+owner
			gui,GUITrigger:+hwndSettingsHWND
			this.hwnd:=settingsHWND
			gui,GUITrigger:add,text,w300,% lang("Select_a_trigger")
			gui,GUITrigger:add,ListBox,w400 h500 vGuiTriggerChoose gGuiTriggerChoose AltSubmit choose1,%temptriggerNames%
			gui,GUITrigger:add,button,w100 h30 gGuiTriggerOK default,% lang("OK")
			gui,GUITrigger:add,button,w90 h30 X+10 gGuiTriggerNew,% lang("New_Trigger")
			gui,GUITrigger:add,button,w90 X+10 h30 gGuiTriggerDelete,% lang("Delete_Trigger")
			gui,GUITrigger:add,button,w90 X+10 h30 yp gGuiTriggerCancel,% lang("Cancel")
			
			pos:=EditGUIGetPos()

			gui,GUITrigger:show,hide
			;Put the window in the center of the main window
			DetectHiddenWindows,on
			wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
			tempXpos:=round(pos.x+pos.w/2- tempWidth/2)
			tempYpos:=round(pos.y+pos.h/2- tempHeight/2)
			
			gui,GUITrigger:show,x%tempXpos% y%tempYpos%
			CurrentlyActiveWindowHWND:=SettingsHWND
			
			
			if (wait=1 or wait="wait")
			{
				Loop
				{
					if (NowResultEditingElement="")
						sleep 100
					else 
						break
				}
			}
			
			
			return NowResultEditingElement
			
			GuiTriggerChoose:
			if A_GuiEvent !=DoubleClick 
				return
			
			GuiTriggerOK:
			gui,GUITrigger:submit
			
			;MsgBox %tempElementID%--- %A_EventInfo%
			gui,GUITrigger:destroy
			;~ WinActivate,·AutoHotFlow·   ;TODO: warum???
			;~ MsgBox % GuiTriggerChoose "`n" strobj(tempTriggers[GuiTriggerChoose])
			GUISettingsOfElementObject.element:=tempTriggers[GuiTriggerChoose]
			NowResultEditingElement:="OK"
			return
			
			GuiTriggerNew:
			gui,GUITrigger:destroy
			EditGUIDisable()
			triggerNNew:=new trigger(GUISettingsOfElementObject.element)
			ret:=selectSubType(triggerNNew,"wait")
			if (ret="aborted")
			{
				;~ MsgBox % strobj(GUISettingsOfElementObject.element.triggers)
				triggerNNew.remove()
				NowResultEditingElement:="aborted"
			}
			else
			{
				;~ MsgBox asgesdfawe
				GUISettingsOfElementObject.Close()
				ElementSettings.editParameters(triggerNNew)
				NowResultEditingElement:="New"
			}
			triggerNNew:=""
			return
			
			GuiTriggerDelete:
			gui,GUITrigger:submit
			
			if (setElement.type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
			{
				tempReenablethen:=true
				;r_EnableFlow() ;TODO
			}
			else
				tempReenablethen:=false
			
			tempTriggers[GuiTriggerChoose].remove() 
			tempTriggers:=[]
			
			gui,GUITrigger:destroy
			
			NowResultEditingElement:="deleted"
			GUISettingsOfElementObject.element.UpdateName()
			
			;if (tempReenablethen) ;TODO
				;r_EnableFlow()
			return
			
			
			GuiTriggerCancel:
			GUITriggerGuiClose:
			gui,GUITrigger:default
			gui,GUITrigger:destroy
			EditGUIEnable()
			NowResultEditingElement:="aborted"
			return
		}
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
		GetClientSize(SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH) ;Sometimes for some reason the width and height parameters are not correct. therefore get the gui size again
		guicontrol, GUISettingsOfElementParent:move,ButtonSave,% "y" ElSetingGUIH-40
		guicontrol, GUISettingsOfElementParent:move,ButtonCancel,% "y" ElSetingGUIH-40
		winmove,% "ahk_id " SG2.HWND,  , 0, 40,  ,% ElSetingGUIH-90
		;~ if not a_iscompiled
			;~ ToolTip %GuiHwnd% %Width% %Height% - %ElSetingGUIW% %ElSetingGUIH%
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
	ElementSettingsFieldHWNDs[CtrlHwnd].UpdateName()
}

GUISettingsOfElementUpdateName(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	ElementSettingsFieldHWNDs[CtrlHwnd].UpdateName()
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




;Select element subtype
selectSubType(p_ID,wait="")
{
	global
	setElementID:=p_ID
	setElement:=flowObj.allElements[p_ID]
	setElementType:=setElement.type 
	
	NowResultEditingElement=
	if setElementType=condition
	{
		tempElements:=IniAllConditions
		tempElementNames:=IniAllConditionNames
		tempElementCategories:=IniAllConditionCategories
	}
	else if setElementType=trigger
	{
		tempElements:=IniAllTriggers
		tempElementNames:=IniAllTriggerNames
		tempElementCategories:=IniAllTriggerCategories
	}
	else if setElementType=action
	{
		tempElements:=IniAllActions
		tempElementNames:=IniAllActionNames
		tempElementCategories:=IniAllActionCategories
	}
	else if setElementType=loop
	{
		tempElements:=IniAllLoops
		tempElementNames:=IniAllLoopNames
		tempElementCategories:=IniAllLoopCategories
	}
	else
	{
		MsgBox,Internal Error: Unknown element type: %setElementType%
		return
	}
	StringSplit,tempElements,tempElements,|
	StringSplit,tempElementNames,tempElementNames,|
	
	EditGUIDisable()
	gui,3:default
	
	gui,destroy
	gui,-dpiscale
	gui,font,s12
	gui,add,text,,% lang("Which_%1% should be created?", lang(setElementType))
	gui,add,TreeView,w400 h500 vGuiElementChoose gGuiElementChoose AltSubmit
	gui,add,Button,w250 gGuiElementChooseOK vGuiElementChooseOK default Disabled,% lang("OK")
	gui,add,Button,w140 X+10 yp gGuiElementChooseCancel,% lang("Cancel")
	
	
	
	loop, parse,tempElementCategories,| ;add all categories to the treeview
	{
		
		tempcategoryTV%a_index%:=TV_Add(A_LoopField)
	}
	loop, parse,tempElements,|
	{
		tempAnElementIndex:=a_index
		tempAnElement:=a_loopfield
		tempElementCategory:=%setElementType%%tempAnElement%.getcategory()
		;MsgBox %tempElementCategory%
		StringSplit,tempElementCategory,tempElementCategory,|
		;MsgBox %tempElementCategory1%
		loop %tempElementCategory0%
		{
			;MsgBox %tempElementCategory1%
			tempAnElementCategory:=tempElementCategory%A_Index%
			Loop parse,tempElementCategories,|
			{
				if (a_loopfield=tempAnElementCategory)
					tempcategoryTV:=tempcategoryTV%a_index%
			}
			tempTV:=TV_Add(%setElementType%%a_loopfield%.getname(),tempcategoryTV)
			TVnum%tempTV%:=tempAnElementIndex
			TVID%tempTV%:=setElementID
			TVSubType%tempTV%:=tempElements%tempAnElementIndex%
			if (setElement.SubType=tempAnElement) ;Select the current element type, if any
				TV_Modify(tempTV) 
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
	}
	
	;~ MsgBox
	return NowResultEditingElement

	3guiclose:
	GuiElementChooseCancel:
	gui,3:default
	gui,destroy
	if (setElement.SubType="" and setElement.Type!="Trigger")
	{
		setElement.remove()
		;~ API_Main_Draw()
	}
	else if (setElement.Type="Trigger" and setElement.SubType="") ;Remove trigger if it was a new one
	{
		;~ MsgBox awgagasdgfwe
		setElement.remove()
		
	}
	NowResultEditingElement=aborted
	EditGUIEnable()
	return
	GuiElementChoose:
	gui,3:default
	if A_GuiEvent =DoubleClick 
		goto GuiElementChooseOK
	GuiElementChoosedTV:=TV_GetSelection()
	gui,submit,nohide
	if TVnum%GuiElementChoosedTV%>0	
		GuiControl,enable,GuiElementChooseOK
	else
		GuiControl,disable,GuiElementChooseOK
	
	return
	GuiElementChooseOK:
	
	gui,3:default
	gui,Submit,nohide
	GuiElementChoosedTV:=TV_GetSelection()
	TV_GetText(GuiElementChoosedText, TV_GetSelection())
	GuiElementChoosedID:=TVID%GuiElementChoosedTV%
	if GuiElementChoosedID=
		return
	gui,destroy
	EditGUIEnable()
	
	
	
	;MsgBox,%setElementID% %GuiElementChoose%
	
	;%GuiElementChoosedID%name:="¦ new element" ;Do not translate!
	NowResultEditingElement:=TVsubType%GuiElementChoosedTV%
	
	GUISettingsOfElementObject.open()
	
	return 
	
}




;Select connection type
selectConnectionType(p_ID,wait="")
{
	global 
	static NowResultEditingElement, setElement, temp_from, ConnectionType
	
	NowResultEditingElement:=""
	
	setElementID:=p_ID
	setElement:=flowObj.allConnections[p_ID]
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
selectContainerType(p_ID, wait="")
{
	global 
	static NowResultEditingElement
	NowResultEditingElement:=""
	setElementID:=p_ID
	setElement:=flowObj.allElements[p_ID]
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
					setElement.type:=NowResultEditingElement
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



