;Needed translations:
temp:=lang("Trigger")
temp:=lang("Action")
temp:=lang("Condition")
temp:=lang("Loop")


ui_settingsOfElement(ElementID,PreviousSubType="")
{
	global
	local temp
	local temptext
	local tempIsDefault
	local tempAssigned
	local tempReenablethen
	local tempXpos
	local tempYpos
	local tempHeight
	

	PreviousSubType2:=PreviousSubType ;This variable will contain anything when user has changed the subtype of the element. The subtype will be restored if user cancels
	
	NowResultEditingElement=
	;MsgBox %ElementID%
	setElementID:=ElementID
	setElementType:=%setElementID%Type
	setElementsubType:=%setElementID%subType
	;Check whether the action-, condition- or trigger type is set. It is unset when a new element is added
	if %setElementID%Type=Action
	{
		if %setElementID%subType=
		{
			ui_selectElementType(%setElementID%Type,setElementID)
			return
		}
	}
	else if %setElementID%Type=Condition
	{
		if %setElementID%subType=
		{
			ui_selectElementType(%setElementID%Type,setElementID)
			return
		}
	}
	else if %setElementID%Type=Loop
	{
		if %setElementID%subType=
		{
			ui_selectElementType(%setElementID%Type,setElementID)
			return
		}
	}
	else if %setElementID%Type=Trigger
	{
		if setElementID=trigger
		{
			TempTriggerCount=0 
			tempTriggers=
			tempTriggerNames=
			for TempTriggerCount, temptrigger in allTriggers
			{
				tempTriggers=%tempTriggers%%temptrigger%|
				tempTriggerNames:=tempTriggerNames %temptrigger%name "|"
			}
			StringTrimRight,tempTriggers,tempTriggers,1
			StringTrimRight,tempTriggerNames,tempTriggerNames,1
			StringSplit,tempTriggers,tempTriggers,|
			StringSplit,tempTriggerNames,tempTriggerNames,|
			
			if TempTriggerCount=0
			{
				setElementID:=e_NewTrigger()
				ui_selectElementType(%setElementID%Type,setElementID)
				return
			}
			;~ else if TempTriggerCount =1
			;~ {
				;~ ui_settingsOfElement(tempTriggers)
				;~ return
			;~ }
			else
			{
				
				ui_DisableMainGUI()
				gui,4:default
				;~ gui,+owner
				gui,+hwndSettingsHWND
				gui,add,text,w300,% lang("Select_a_trigger")
				gui,add,ListBox,w400 h500 vGuiTriggerChoose gGuiTriggerChoose AltSubmit choose1,%temptriggerNames%
				gui,add,button,w100 h30 gGuiTriggerOK default,% lang("OK")
				gui,add,button,w90 h30 X+10 gGuiTriggerNew,% lang("New_Trigger")
				gui,add,button,w90 X+10 h30 gGuiTriggerDelete,% lang("Delete_Trigger")
				gui,add,button,w90 X+10 h30 yp gGuiTriggerCancel,% lang("Cancel")
				
				ui_GetMainGUIPos()

				gui,show,hide
				;Put the window in the center of the main window
				wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
				tempXpos:=round(MainGUIX+MainGUIWidth/2- tempWidth/2)
				tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
				
				gui,show,x%tempXpos% y%tempYpos%
				
				return
				GuiTriggerChoose:
				if A_GuiEvent !=DoubleClick 
					return
				GuiTriggerOK:
				gui,submit
				
				
				
				;MsgBox %tempElementID%--- %A_EventInfo%
				gui,destroy
				ui_EnableMainGUI()
				WinActivate,·AutoHotFlow·
				ui_settingsOfElement(tempTriggers%GuiTriggerChoose%)
				return
				GuiTriggerNew:
				gui,4:default
				gui,destroy
				ui_EnableMainGUI()
				setElementID:=e_NewTrigger()
				ui_selectElementType(%setElementID%Type,setElementID)
				
				return
				GuiTriggerDelete:
				gui,4:default
				gui,submit
				
				if (%setElementID%type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
				{
					tempReenablethen:=true
					r_EnableFlow()
				}
				else
					tempReenablethen:=false
				
				e_removeTrigger(e_TriggerNumbertoID(GuiTriggerChoose))
				saved=no
				gui,destroy
				ui_EnableMainGUI()
				e_UpdateTriggerName()
				
				if (tempReenablethen)
					r_EnableFlow()
				
				ui_settingsOfElement("trigger")
				return
				
				
				GuiTriggerCancel:
				4GuiClose:
				gui,4:default
				gui,destroy
				ui_EnableMainGUI()
				return
			}
		}
		
	}
	else if %setElementID%Type=Connection
	{
		
		tempNewType:=ui_selectConnectionType(setElementID)
		if (tempNewType !="aborted")
			%setElementID%ConnectionType:=tempNewType
		
		ui_draw()
		return tempNewType
	}
	else 
	{
		MsgBox,,Internal error, Element Type unknown
		NowResultEditingElement=ok
		ui_EnableMainGUI()
		return
	}
	ui_DisableMainGUI()
	gui,SettingsOfElement:default
	
	;~ gui,font,s8 cDefault wnorm
	;~ gui,add,button,w370 x10 gGUISettingsOfElementSelectType,% lang("%1%_type:_%2%",lang(setElementType),getname%setElementType%%setElementsubType%())
	;~ gui,add,button,w20 x10 X+10 yp gGUISettingsOfElementHelp,?
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w400,Name
	gui,font,s8 cDefault wnorm
	gui,add,checkbox, x10 vGUISettingsOfElementCheckStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
	gui,add,edit,w400 x10 Multi r5 vGUISettingsOfElementEditName gGUISettingsOfElementUpdateName,% %setElementID%name
	gui,+hwndSettingsGUIHWND
	
	openingElementSettingsWindow:=true ;Allows some elements to initialize their parameter list. (such as in "play sound": find all system sound)
	try
		parametersToEdit:=getParameters%setElementType%%setElementsubType%(true)
	catch
		parametersToEdit:=getParameters%setElementType%%setElementsubType%()
	;MsgBox,% parametersToEdit
	for index, parameter in parametersToEdit
	{
		if isobject(parameter.id)
		{
			for tempParIndex, tempParValue in parameter.id
				tempParameterID%a_index%:=parameter.id[tempParIndex]
			if parameter.id.MaxIndex()=1
				tempParameterID:=parameter.id[1]
			else
				tempParameterID=
		}
		else
			tempParameterID:=parameter.id
		
		;~ if isobject(parameter.default)
		;~ {
			;~ for tempParIndex, tempParValue in parameter.default
				;~ tempParameterDefault%a_index%:=parameter.default[tempParIndex]
		;~ }
		;~ else
			;~ tempParameterDefault:=parameter.default
		
		if (parameter.type="Label")
		{
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
				gui,add,text,x10 w400 %tempYPos% vGUISettingsOfElement%setElementID%%tempParameterID% ,% parameter.label
			}
			else
			{
				gui,add,text,x10 w400 %tempYPos%,% parameter.label
			}
		}
		else if (parameter.type="Edit")
		{
			gui,font,s8 cDefault wnorm
			
			
			if ( tempParameterID) ;if only one edit
			{
				
				temptext:=%setElementID%%tempParameterID% ;get the saved parameter
				
				if parameter.multiline
					tempIsMulti=h100 multi
				else
					tempIsMulti=r1
				
				gui,add,picture,x394 w16 h16 gGUISettingsOfElementClickOnWarningPic vGUISettingsOfElementWarningIconOf%setElementID%%tempParameterID%
				GUISettingsOfElementWarnIfEmpty%setElementID%%tempParameterID%:=parameter.WarnIfEmpty
				
				if (parameter.content="Expression")
				{
					gui,add,picture,x10 yp w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\expression.ico
					
						gui,add,edit,X+4 w360 %tempIsMulti% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementCheckContent vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
					if parameter.useupdown
					{
						
						if parameter.range
							gui,add,updown,% "range" parameter.range
						else
							gui,add,updown
						guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
					}
					
					GUISettingsOfElementContentType%setElementID%%tempParameterID%=Expression
				}
				else if (parameter.content="String")
				{
					gui,add,picture,x10 yp w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\string.ico
					gui,add,edit,X+4 w360 %tempIsMulti% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementCheckContent vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
					
					GUISettingsOfElementContentType%setElementID%%tempParameterID%=String
				}
				else if (parameter.content="VariableName")
				{
					gui,add,picture,x10 yp w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\VariableName.ico
					gui,add,edit,X+4 w360 %tempIsMulti% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementCheckContent vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
					
					GUISettingsOfElementContentType%setElementID%%tempParameterID%=VariableName
				}
				else if (parameter.content="StringOrExpression")
				{
					
					tempContentTypePar:=parameter.contentParID
					
					if %setElementID%%tempContentTypePar%=1 ;String
						gui,add,picture,x10 yp w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\string.ico
					else
						gui,add,picture,x10 yp w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\expression.ico
					gui,add,edit,X+4 w360 %tempIsMulti% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementCheckContent vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
					
					GUISettingsOfElementContentType%setElementID%%tempParameterID%=StringOrExpression
					GUISettingsOfElementContentTypeOf%setElementID%%tempContentTypePar%:=tempParameterID
					GUISettingsOfElementContentTypeRadio%setElementID%%tempParameterID%:=tempContentTypePar
				}
				else
				{
					gui,add,edit,x10 yp w380 %tempIsMulti% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementCheckContent vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
				}
				GUISettingsOfElementCheckContent(GUISettingsOfElementEditHWND%setElementID%%tempParameterID%)
			}
			else ;If multiple edits in one line
			{
				
			
				;~ MsgBox %tempEditwidth%
				for tempIndex, tempOneParameterID in parameter.id
				{
					temp:=%setElementID%%tempOneParameterID% ;get the saved parameter
					;~ if (temp="") ;if nothing is saved
						;~ temptext:=parameter.default[tempIndex] ;load default parameter
					;~ else
						temptext=%temp% ;set the saved parameter as text
					
					
					if tempIndex=1
					{
						tempEditwidth:= round((380 - (10 * (parameter.id.MaxIndex()-1)))/parameter.id.MaxIndex())
						tempXpos:="X+4"
						if (parameter.content="Expression")
						{
							gui,add,picture,x10 w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempOneParameterID%,icons\expression.ico
							tempXpos:="X+4"
						}
						else if (parameter.content="String")
						{
							gui,add,picture,x10 w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempOneParameterID%,icons\string.ico
							tempXpos:="X+4"
						}
						else if (parameter.content="VariableName")
						{
							gui,add,picture,x10 w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempOneParameterID%,icons\VariableName.ico
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
					gui,add,edit,%tempXpos% w%tempEditwidth% hwndGUISettingsOfElementEditHWND%setElementID%%tempParameterID% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempOneParameterID%,%temptext%
					
					if (parameter.content="Expression")
					{
						GUISettingsOfElementContentType%setElementID%%tempOneParameterID%=Expression
					}
					else if (parameter.content="String")
					{
						GUISettingsOfElementContentType%setElementID%%tempOneParameterID%=String
					}
					else if (parameter.content="VariableName")
					{
						GUISettingsOfElementContentType%setElementID%%tempOneParameterID%=VariableName
					}
					GUISettingsOfElementCheckContent(GUISettingsOfElementEditHWND%setElementID%%tempParameterID%)
				}
				
			}
		}
		else if (parameter.type="VariableName")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% ;get the saved parameter
			
			;~ if (temp="") ;if nothing is saved
				;~ temptext:=parameter.default ;load default parameter
			;~ else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,x10 r1 w400  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
			TrayTip,%setElementsubType%, variable name will ich nicht haben
		}
		else if (parameter.type="Checkbox")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			temptext:=parameter.label
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
			;~ }
			if parameter.gray
				tempParGray=check3
			else
				tempParGray=
			gui,add,checkbox,w400 x10 %tempParGray% checked%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
			
		}
		else if (parameter.type="Radio")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
				;~ tempIsDefault:=true
			;~ }
			;~ else
				tempIsDefault:=false
			
			
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
					
				
				
				gui,add,radio, w400 x10 %tempChecked% %tempMakeNewGroup% gGUISettingsOfElementClickOnRadio vGUISettingsOfElement%setElementID%%tempParameterID%%a_index% ,% tempRadioLabel
				
				
				
				
				
			}
			if (tempAssigned=false and tempIsDefault=false)
			{
				temp:=parameter.default
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%%temp%,1
			}
			
		}
		else if (parameter.type="Slider")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			
			tempParameterOptions:=parameter.options
			if (parameter.allowExpression=true)
			{
				gui,add,picture,x10 w16 h16 gGUISettingsOfElementClickOnInfoPic vGUISettingsOfElementInfoIconOf%setElementID%%tempParameterID%,icons\expression.ico
				gui,add,edit,X+6 w190 gGUISettingsOfElementSliderChangeEdit vGUISettingsOfElement%setElementID%%tempParameterID%,%temp%
				gui,add,slider, w180 X+10 %tempParameterOptions%  gGUISettingsOfElementSliderChangeSlide vGUISettingsOfElementSlideOf%setElementID%%tempParameterID% ,% temp
				
				GUISettingsOfElementContentType%setElementID%%tempParameterID%=Expression
			}
			else
				gui,add,slider, w400 x10 %tempParameterOptions%  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID% ,% temp
			
		}
		else if (parameter.type="DropDown")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
				;~ temp:=parameter.default
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
			gui,add,DropDownList, w400 x10 %tempAltSumbit% choose%temptoChoose% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID% ,% tempAllChoices
			
		}
		else if (parameter.type="ComboBox")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
				;~ temp:=parameter.default
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
			gui,add,ComboBox, w400 x10 %tempAltSumbit% choose%temptoChoose% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID% ,% tempAllChoices
			guicontrol,text,GUISettingsOfElement%setElementID%%tempParameterID%,% temp
			
		}
		else if (parameter.type="Hotkey")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
			;~ }
			gui,add,edit,w300 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temp%
			gui,add,hotkey,w90 X+10 gGUISettingsOfElementHotkey vGUISettingsOfElement%setElementID%%tempParameterID%hotkey,%temp%
			
		}
		else if (parameter.type="Button")
		{
			gui,font,s8 cDefault wnorm
			tempGoto:=parameter.goto
			gui,add,button,w400 x10  g%tempGoto% vGUISettingsOfElement%setElementID%%tempParameterID%,% parameter.label
		}
		else if (parameter.type="File")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
			;~ }
			GUISettingsOfElement%setElementID%%tempParameterID%Prompt:=parameter.label
			GUISettingsOfElement%setElementID%%tempParameterID%Options:=parameter.options
			GUISettingsOfElement%setElementID%%tempParameterID%Filter:=parameter.filter
			gui,add,edit,w370 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temp%
			gui,add,button,w20 X+10  gGUISettingsOfElementSelectFile vGUISettingsOfElementbuttonSelectFile_%setElementID%_%tempParameterID%,...
			
		}
		else if (parameter.type="Folder")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
			;~ }
			GUISettingsOfElement%setElementID%%tempParameterID%Prompt:=parameter4
			GUISettingsOfElement%setElementID%%tempParameterID%Options:=parameter5
			GUISettingsOfElement%setElementID%%tempParameterID%Filter:=parameter6
			gui,add,edit,w370 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temp%
			gui,add,button,w20 X+10  gGUISettingsOfElementSelectFolder vGUISettingsOfElementbuttonSelectFile_%setElementID%_%tempParameterID%,...
			;~ gui,add,button,w20 X+10 gGUISettingsOfElementSelectFolderHelp,?
		}
		else if (parameter.type="weekdays")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			
			;~ if temp=
			;~ {
				;~ temp:=parameter.default
			;~ }
			gui,add,checkbox,w45 x10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%2,% lang("Mon (Short for Monday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%3,% lang("Tue (Short for Tuesday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%4,% lang("Wed (Short for Wednesday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%5,% lang("Thu (Short for Thursday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%6,% lang("Fri (Short for Friday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%7,% lang("Sat (Short for Saturday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%tempParameterID%1,% lang("Sun (Short for Sunday") ;Sunday is 1
			IfInString,temp,1
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%1,1
			IfInString,temp,2
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%2,1
			IfInString,temp,3
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%3,1
			IfInString,temp,4
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%4,1
			IfInString,temp,5
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%5,1
			IfInString,temp,6
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%6,1
			IfInString,temp,7
				guicontrol,,GUISettingsOfElement%setElementID%%tempParameterID%7,1
			GUISettingsOfElement%setElementID%%tempParameterID%:=temp
		}
		else if (parameter.type="TimeOfDay")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			temptext=%parameter4%
			if temp=
			{
				;~ if parameter2=
					temp=%a_now%
				;~ else
					;~ temp=parameter.default
			}
			gui,add,DateTime,w400 x10 choose%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID% ,time
			
		}
		else if (parameter.type="DateAndTime")
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			temptext=%parameter4%
			if temp=
			{
				;~ if parameter2=
					temp=%a_now%
				;~ else
					;~ temp=%parameter2%
			}
			gui,add,DateTime,w400 x10 choose%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID% ,% "'" lang("Date") ":' " lang("MM/dd/yy") " '" lang("Time") ":' " lang("HH:mm:ss")
			
		}
		
		else if (parameter.type="Number")
		{
			TrayTip,%setElementsubType%, nummer will ich nicht haben
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%tempParameterID% 
			;~ if (temp="")
				;~ temptext=%parameter2%
			;~ else
				temptext=%temp%
			gui,add,edit,w400 x10 number gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempParameterID%,%temptext%
			
		}
		
		
	}
	
	gui,submit,nohide
	if (%ElementID%StandardName==true or %ElementID%StandardName=="")
	{
		GuiControl,,GUISettingsOfElementCheckStandardName,1
		GuiControl,Disable,GUISettingsOfElementEditName
		GUISettingsOfElementUpdateName()
	}
	
	;~ gui,add,button,w145 x10 h30 gGUISettingsOfElementSave default,% lang("Save")
	;~ gui,add,button,w145 h30 yp X+10 gGUISettingsOfElementCancel,% lang("Cancel")
	
	gui +hwndSettingWindowHWND
	SG2 := New ScrollGUI(SettingWindowHWND,600, A_ScreenHeight*0.8, " ",2,2)
	
	
	; Create the main window (parent)
	Gui, GUISettingsOfElementParent:New
	Gui, GUISettingsOfElementParent:Margin, 0, 20
	Gui, % SG2.HWND . ": -Caption +ParentGUISettingsOfElementParent +LastFound"
	Gui, % SG2.HWND . ":Show", Hide  y25
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
	
	;add buttons
	gui,font,s8 cDefault wnorm
	gui, GUISettingsOfElementParent:add,button, w370 x10 y10 gGUISettingsOfElementSelectType h20,% lang("%1%_type:_%2%",lang(setElementType),getname%setElementType%%setElementsubType%())
	gui, GUISettingsOfElementParent:add,button, w20 X+10 yp h20 gGUISettingsOfElementHelp vGUISettingsOfElementHelp,?
	;~ guicontrol,focus,GUISettingsOfElementHelp
	Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementSave vButtonSave w145 x10 h30 y%YsettingsButtoPos%,% lang("Save")
	Gui, GUISettingsOfElementParent:Add, Button, gGUISettingsOfElementCancel vButtonCancel default w145 h30 yp X+10,% lang("Cancel")
	;Make GUI autosizing
	Gui, GUISettingsOfElementParent:Show, hide w%WsettingsParent%
	Gui, GUISettingsOfElementParent:Show, hide w%WsettingsParent%,% lang("Settings") " - " lang(%ElementID%type) " - " lang(%ElementID%subtype) ;Needed twice, otherwise the width is not correct
	; Show ScrollGUI1
	;~ Return
	
	;Calculate position to show the settings window in the middle of the main window
	ui_GetMainGUIPos() 
	tempHeight:=round(MainGUIHeight-100) ;This will be the max height. If child gui is larger, it must be scrolled
	WinGetPos,ElSetingGUIX,ElSetingGUIY,ElSetingGUIW,ElSetingGUIH,ahk_id %SettingWindowParentHWND%
	tempXpos:=round(MainGUIX+MainGUIWidth/2- ElSetingGUIW/2)
	tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
	;move Parent window
	gui,GUISettingsOfElementParent:show,% "x" tempXpos " y" tempYpos " h" tempHeight " hide" 
	
	;~ SetWinDelay,0
	;~ Gui, % SG2.HWND . ":Show", Hide  y40
	;Make ScrollGUI autosize 
	SG2.Show("", "x0 y40 h" tempHeight " hide ")
	
	;position lower buttons
	GetClientSize(SettingWindowParentHWND, ElSetingGUIW, ElSetingGUIH)
	guicontrol, GUISettingsOfElementParent:move,ButtonSave,% "y" ElSetingGUIH-40
	guicontrol, GUISettingsOfElementParent:move,ButtonCancel,% "y" ElSetingGUIH-40
	;Position the Scroll gui
	wingetpos,,,ElSetingGUIW,ElSetingGUIH,ahk_id %SettingWindowParentHWND%
	WinMove,ahk_id %SettingWindowParentHWND%,,,,% ElSetingGUIW,% ElSetingGUIH+1 ;make the autosize function trigger, which resizes and moves the scrollgui
	
	;show gui
	SG2.Show() 
	gui,GUISettingsOfElementParent:show
	
	openingElementSettingsWindow:=false
	return
	

	
	GUISettingsOfElementSelectType:
	gui,SettingsOfElement:destroy
	SG2.Destroy()
	gui,GUISettingsOfElementParent:destroy
	ui_closeHelp()
	
	ui_EnableMainGUI()
	if PreviousSubType2
		ui_selectElementType(%setElementID%Type,setElementID,PreviousSubType2)
	else
		ui_selectElementType(%setElementID%Type,setElementID,%setElementID%SubType)
	

	return
	
	GUISettingsOfElementHelp:
	;~ MsgBox %setElementType% %setElementsubType%
	
	IfWinExist,ahk_id %GUIHelpHWND%
		ui_closeHelp()
	else
		;~ showHelpFor%setElementType%%setElementsubType%()
	;~ IfWinExist,ahk_id %GUIHelpHWND%
		;~ ui_closeHelp()
	;~ else
		;~ ui_showHelp("index")
		ui_showHelp(%setElementID%Type "\" %setElementID%subtype)
	return
	GUISettingsOfElementCheckStandardName:
	gui,SettingsOfElement:default
	gui,submit,nohide
	
	if GUISettingsOfElementCheckStandardName=1
	{
		GuiControl,Disable,GUISettingsOfElementEditName
		GUISettingsOfElementUpdateName()
	}
	else
		GuiControl,Enable,GUISettingsOfElementEditName
	
	
	return
	
	GUISettingsOfElementSelectFile:
	StringSplit,tempguicontrol,a_guicontrol,_
	;MsgBox %tempguicontrol1% %tempguicontrol2% %tempguicontrol3%
	FileSelectFile,tempfile,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%Options,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%prompt,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%filter
	
	if not errorlevel
		guicontrol,,GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%,% tempfile
	return
	
	GUISettingsOfElementSelectFolder:
	StringSplit,tempguicontrol,a_guicontrol,_
	;MsgBox %tempguicontrol1% %tempguicontrol2% %tempguicontrol3%
	FileSelectFolder,tempfile,% "*" GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%Options,% GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%prompt
	
	if not errorlevel
		guicontrol,,GUISettingsOfElement%tempguicontrol2%%tempguicontrol3%,% tempfile
	return

	GUISettingsOfElementHotkey:
	gui,SettingsOfElement:default
	gui,submit,nohide
	StringTrimRight,tempHotkeyCotrol,a_guicontrol,6
	
	guicontrol,,%tempHotkeyCotrol%,% %a_guicontrol%
	return
	
	GUISettingsOfElementWeekdays:
	gui,SettingsOfElement:default
	gui,submit,nohide
	StringTrimRight,tempGUICotrol,a_guicontrol,1
	
	tempGUICotrolText=
	loop 7
	{
		if (%tempGUICotrol%%a_index%=1)
		{
			
			tempGUICotrolText.=A_Index
			;MsgBox % setElementID parameter3 "=" %setElementID%%parameter3%
		}
		
	}
	;MsgBox % tempGUICotrol "=" tempGUICotrolText
	%tempGUICotrol%:=tempGUICotrolText
	
	GUISettingsOfElementUpdateName()
	return
	
	GUISettingsOfElementSliderChangeEdit:
	gui,SettingsOfElement:default
	gui,submit,nohide
	
	StringTrimleft,tempGUICotrol,a_guicontrol,20
	;~ MsgBox % GUISettingsOfElement tempGUICotrol
	guicontrol,,% "GUISettingsOfElementSlideOf" tempGUICotrol,% %a_guicontrol%
	return
	GUISettingsOfElementSliderChangeSlide:
	
	gui,SettingsOfElement:default
	gui,submit,nohide
	
	StringTrimleft,tempGUICotrol,a_guicontrol,27
	guicontrol,,% "GUISettingsOfElement" tempGUICotrol,% %a_guicontrol%
	return
	
	
	

	
	
	
	
	SettingsOfElementParentClose:
	SettingsOfElementParentEscape:
	GUISettingsOfElementCancel:
	;~ ToolTip %a_thislabel%
	if (%selElementID%name="Νew Соntainȩr") ;Do not translate!
	{
		if %selElementID%Type=trigger
			e_removeTrigger(selElementID)
		else
		{
			
			NowResultEditingElement=aborted
			
		}
		ui_draw()
		gui,SettingsOfElement:default
	}
	
	
	if PreviousSubType2
		%selElementID%SubType:=PreviousSubType2
	
	ui_closeHelp()
	
	gui,SettingsOfElement:destroy
	SG2.Destroy()
	gui,GUISettingsOfElementParent:destroy
	
	GUISettingsOfElementRemoveInfoTooltip()
	
	ui_EnableMainGUI()
	return
	
	
	
	GUISettingsOfElementSave:
	GUISettingsOfElementUpdateName()
	gui,SettingsOfElement:submit
	if (%setElementID%type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
	{
		tempReenablethen:=true
		r_EnableFlow()
	}
	else
		tempReenablethen:=false
	
	
	%setElementID%Name:=GUISettingsOfElementEditName
	%setElementID%StandardName:=GUISettingsOfElementCheckStandardName
	
	for index, parameter in parametersToEdit
	{
		if not IsObject(parameter.id)
			parameterID:=[parameter.id]
		else
			parameterID:=parameter.id
		
		if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label for the edit fielt etc. Do nothing
			continue
		;~ MsgBox % strobj(parameterID)
		
		if (parameter.type="Radio")
		{
			tempOneParID:=parameterID[1]
			loop % parameter.choices.MaxIndex()
			{
				if (GUISettingsOfElement%setElementID%%tempOneParID%%a_index%=1)
				{
					
					%setElementID%%tempOneParID%:=A_Index
					break
				}
			}
		}
		else if (parameter.type="weekdays")
		{
			tempOneParID:=parameterID[1]
			%setElementID%%tempOneParID%=
			loop 7
			{
				if (GUISettingsOfElement%setElementID%%tempOneParID%%a_index%=1)
				{
					
					%setElementID%%tempOneParID%.=A_Index
					
				}
			}
		}
		else
		{
			;Certain types of control consist of multiple controls and thus contain multiple parameters.
			for index2, oneID in parameterID
			{
				tempOneParID:=parameterID[index2]
				%setElementID%%tempOneParID%:=GUISettingsOfElement%setElementID%%tempOneParID%
				
			}
		}
		
		
		
	}
	
	ui_closeHelp()
	SG2.Destroy()
	gui,SettingsOfElement:destroy
	gui,GUISettingsOfElementParent:destroy
	GUISettingsOfElementRemoveInfoTooltip()
	
	ui_EnableMainGUI()
	saved=no
	
	NowResultEditingElement=OK
	
	if (tempReenablethen)
		r_EnableFlow()
	
	if (setElementType="Trigger")
	{
		e_UpdateTriggerName()
		ui_draw()
		
	}
	
	ui_draw()
	return
	
	
	
	
	
	
}

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


GUISettingsOfElementClickOnRadio(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	local tempEnabled
	local tempControlName
	local tempValue
	local tempOneParamID
	local tempToSetParamID
	guicontrolget,tempEnabled,enabled,%CtrlHwnd%
	guicontrolget,tempControlName,name,%CtrlHwnd%
	;~ guicontrolget,tempValue,,%CtrlHwnd%
	StringReplace,tempOneParamID,tempControlName,GUISettingsOfElement%setElementID%
	stringright,tempValue,tempOneParamID,1
	StringTrimRight,tempOneParamID,tempOneParamID,1
	
	if (GUISettingsOfElementContentTypeOf%setElementID%%tempOneParamID%!="")
	{
		
		tempToSetParamID:=GUISettingsOfElementContentTypeOf%setElementID%%tempOneParamID%
		;~ MsgBox % tempToSetParamID " .- " tempValue
		if tempValue=1 ;String
		{
			guicontrol,,GUISettingsOfElementInfoIconOf%setElementID%%tempToSetParamID%,Icons\String.ico
			
		}
		else ;Expression
		{
			guicontrol,,GUISettingsOfElementInfoIconOf%setElementID%%tempToSetParamID%,Icons\Expression.ico
			
		}
	}
	
	GUISettingsOfElementUpdateName()
}

GUISettingsOfElementCheckContent(CtrlHwnd, GuiEvent="", EventInfo="", ErrorLevell="")
{
	global
	gui,SettingsOfElement:default
	gui,submit,nohide
	
	local tempEnabled
	local tempControlName
	local tempTextInControl
	local tempOneParamID
	local tempFoundPos
	
	local thiscontrol:=A_GuiControl
	if thiscontrol=
		thiscontrol:=
	;~ MsgBox %tempOneParamID%
	guicontrolget,tempEnabled,enabled,%CtrlHwnd%
	guicontrolget,tempControlName,name,%CtrlHwnd%
	
	StringReplace,tempOneParamID,tempControlName,GUISettingsOfElement%setElementID%
	;~ MsgBox %tempEnabled% - %tempControlName% - %tempOneParamID%
	GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%:=
	if tempEnabled
	{
		guicontrolget,tempTextInControl,,%CtrlHwnd%
		;~ MsgBox % strobj(parametersToEdit[tempOneParamID]) " - " tempOneParamID
		if (GUISettingsOfElementContentType%setElementID%%tempOneParamID%="Expression")
		{
			
			;~ MsgBox %tempTextInControl%
			IfInString,tempTextInControl,`%
			{
				guicontrol,show,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%
				guicontrol,,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%,Icons\Question mark.ico
				GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%:=lang("Note!") " " lang("This is an expression.") " " lang("You musn't use percent signs to add a variable's content.") "`n"
			}
		}
		else if (GUISettingsOfElementContentType%setElementID%%tempOneParamID%="variablename")
		{
			Loop
			{
				tempFoundPos:=RegExMatch(tempTextInControl, "U).*%(.+)%.*", tempVariablesToReplace)
				if tempFoundPos=0
					break
				StringReplace,tempTextInControl,tempTextInControl,`%%tempVariablesToReplace1%`%,someVarName
				;~ MsgBox %tempVariablesToReplace1%
			}
			;~ MsgBox %tempTextInControl%
			
			try
				asdf%tempTextInControl%:=1 
			catch
			{
				guicontrol,show,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%
				guicontrol,,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%,Icons\Exclamation mark.ico
				GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%:=lang("Error!") " " lang("The variable name is not valid.") "`n"
				
			}
			
		}
		
		if GUISettingsOfElementWarnIfEmpty%setElementID%%tempOneParamID%
		{
			if tempTextInControl=
			{
				guicontrol,show,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%
				guicontrol,,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%,Icons\Exclamation mark.ico
				GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%:=lang("Error!") " " lang("This field mustn't be empty!") "`n"
				
			}
			
		}
	}
	
	
	
	if (GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%="" and !openingElementSettingsWindow)
		guicontrol,hide,GUISettingsOfElementWarningIconOf%setElementID%%tempOneParamID%
	;~ MsgBox %setElementID%%tempOneParamID%
	GUISettingsOfElementUpdateName()
	return
}




GUISettingsOfElementUpdateName()
{
	global
	GUISettingsOfElementRemoveInfoTooltip()
	gui,SettingsOfElement:default
	gui,submit,nohide
	
	
	CheckSettings%setElementType%%setElementsubType%(setElementID)
	
	if GUISettingsOfElementCheckStandardName!=1
	{
		
		return
	}
	
	
	Newname:=GenerateName%setElementType%%setElementsubType%(setElementID)
	StringReplace,Newname,Newname,`n,%a_space%-%a_space%,all
	guicontrol,,GUISettingsOfElementEditName,%Newname%
}

GUISettingsOfElementClickOnWarningPic()
{
	StringReplace,tempOneParamID,A_GuiControl,GUISettingsOfElementWarningIconOf%setElementID%
	ToolTip,% GUISettingsOfElementWarningTextFor%setElementID%%tempOneParamID%,,,11
	settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
	return
}
GUISettingsOfElementRemoveInfoTooltip()
{
	ToolTip,,,,11
	return
}
GUISettingsOfElementClickOnInfoPic()
{
	global
	local tempOneParamID
	local tempRadioID
	gui,SettingsOfElement:default
	gui,submit,nohide
	StringReplace,tempOneParamID,A_GuiControl,GUISettingsOfElementInfoIconOf%setElementID%
	;~ MsgBox %tempOneParamID%
	;~ MsgBox % GUISettingsOfElementContentType%setElementID%%tempOneParamID%
	if GUISettingsOfElementContentType%setElementID%%tempOneParamID%=Expression
	{
		
		ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)" ,,,11
	}
	if GUISettingsOfElementContentType%setElementID%%tempOneParamID%=String
	{
		
		ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
	}
	if GUISettingsOfElementContentType%setElementID%%tempOneParamID%=VariableName
	{
		
		ToolTip,% lang("This field contains a variable name") "`n" lang("Examples") ":`nVarname`nEntry1`nEntry%a_index%" ,,,11
	}
	if GUISettingsOfElementContentType%setElementID%%tempOneParamID%=StringOrExpression
	{
		tempRadioID:=GUISettingsOfElementContentTypeRadio%setElementID%%tempOneParamID%
		;~ MsgBox %tempRadioID%
		;~ MsgBox % GUISettingsOfElement%setElementID%%tempRadioID%1
		;~ MsgBox % GUISettingsOfElement%setElementID%%tempRadioID%2
		if (GUISettingsOfElement%setElementID%%tempRadioID%1)
			ToolTip,% lang("This field contains a string") "`n" lang("Examples") ":`nHello World`nMy name is %A_UserName%`nToday's date is %A_Now%" ,,,11
		else if (GUISettingsOfElement%setElementID%%tempRadioID%2)
			ToolTip,% lang("This field contains an expression") "`n" lang("Examples") ":`n5`n5+3*6`nA_ScreenWidth`n(a=4) or (b=1)" ,,,11
	}
	settimer,GUISettingsOfElementRemoveInfoTooltip,-5000
	return
}
	
	
	
GUISettingsOfElementButton()
{
	;~ MsgBox, %a_guicontrol%`n%A_gui%`n%A_guiEvent%`n%A_EventInfo%
	gui,submit,nohide
	RegExMatch(a_guicontrol, "GUISettingsOfElementbutton_(.+)_(.+)_(.+)", tempButton) ;Find out witch button was pressed
	tempSetWhat:=tempButton1
	tempSetID:=tempButton2
	tempSetPar:=tempButton3
	
	
	GUISettingsOfElementUpdateName()
	return
}














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
ui_selectElementType(type,setElementID,PreviousSubType="")
{
	global
	
	PreviousSubType2:=PreviousSubType ;make it global
	
	NowResultEditingElement=
	selElementType:=type 
	selElementID:=setElementID
	if type=condition
	{
		tempElements:=IniAllConditions
		tempElementNames:=IniAllConditionNames
		tempElementCategories:=IniAllConditionCategories
	}
	else if type=trigger
	{
		tempElements:=IniAllTriggers
		tempElementNames:=IniAllTriggerNames
		tempElementCategories:=IniAllTriggerCategories
	}
	else if type=action
	{
		tempElements:=IniAllActions
		tempElementNames:=IniAllActionNames
		tempElementCategories:=IniAllActionCategories
	}
	else if type=loop
	{
		tempElements:=IniAllLoops
		tempElementNames:=IniAllLoopNames
		tempElementCategories:=IniAllLoopCategories
	}
	else
	{
		MsgBox,Internal Error: Unknown element type: %type%
		return
	}
	StringSplit,tempElements,tempElements,|
	StringSplit,tempElementNames,tempElementNames,|
	
	ui_DisableMainGUI()
	gui,3:default
	
	gui,destroy
	gui,font,s12
	gui,add,text,,% lang("Which_%1% should be created?", lang(selElementType))
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
		tempElementCategory:=getcategory%selElementType%%tempAnElement%()
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
			tempTV:=TV_Add(getname%selElementType%%a_loopfield%(),tempcategoryTV)
			TVnum%tempTV%:=tempAnElementIndex
			TVID%tempTV%:=selElementID
			TVSubType%tempTV%:=tempElements%tempAnElementIndex%
			if (%selElementID%SubType=tempAnElement) ;Select the current element type, if any
				TV_Modify(tempTV) 
		}
		
	}
	
	
	;Put the window in the center of the main window
	gui,+hwndSettingsHWND
	gui,show,hide
	ui_GetMainGUIPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(MainGUIX+MainGUIWidth/2- tempWidth/2)
	tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
	
	gui,show,x%tempXpos% y%tempYpos%
	
	;~ MsgBox
	return

	3guiclose:
	GuiElementChooseCancel:
	gui,3:default
	ui_EnableMainGUI()
	gui,destroy
	if (%selElementID%SubType="" and %selElementID%Type!="Trigger")
	{
		
		NowResultEditingElement=aborted
		ui_draw()
	}
	else if (%selElementID%Type="Trigger" and %selElementID%SubType="")
	{
		
		e_removeTrigger(selElementID)
		ui_draw()
		
	}
	gui,MainGUI:default
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
	gui,MainGUI:default
	ui_EnableMainGUI()
	
	
	
	
	;MsgBox,%selElementID% %GuiElementChoose%
	
	%GuiElementChoosedID%subType:=TVsubType%GuiElementChoosedTV%
	;%GuiElementChoosedID%name:="¦ new element" ;Do not translate!
	NowResultEditingElement=OK
	
	e_setUnsetDefaults(GuiElementChoosedID)
	ui_settingsOfElement(GuiElementChoosedID,PreviousSubType2)

	return 
	
}

ui_selectConnectionType(tempNewID)
{
	global 
	temp_from:=%tempNewID%from
	ConnectionType:=%tempNewID%ConnectionType
	temp_fromType:=%temp_from%type
	;~ if temp_fromType=
		;~ temp_fromType=Condition
	
	ui_DisableMainGUI()
	gui, 7:default


	gui,font,s12
	gui,add,text,,% lang("Select_Connection_type")
		
	
	if (temp_fromType="Condition")
	{
		if (ConnectionType="exception")
		{
			gui,add,Button,w100 h50 gGuiConnectionChooseTrue vGuiConnectionChooseTrue ,% lang("Yes")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseFalse vGuiConnectionChooseFalse,% lang("No")
			gui,add,Button,w100 h50 X+10 gGuiConnectionChooseException vGuiConnectionChooseException default,% lang("Exception")
		}
		else if (ConnectionType="no")
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
		if (ConnectionType="exception")
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
	gui,show,hide
	ui_GetMainGUIPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(MainGUIX+MainGUIWidth/2- tempWidth/2)
	tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
	
	gui,show,x%tempXpos% y%tempYpos%
	
	NowConnectionChoosed=
	Loop
	{
		sleep,10
		if (NowConnectionChoosed)
			return NowConnectionChoosed
	}
	
	return
	
	
	7guiclose:
	GuiConnectionChooseCancel:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowConnectionChoosed:="aborted"
	return 
	
	GuiConnectionChooseTrue:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowConnectionChoosed:="yes"
	return
	
	GuiConnectionChooseFalse:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowConnectionChoosed:="no"
	return 
	
	GuiConnectionChooseException:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowConnectionChoosed:="exception"
	return 
	
	GuiConnectionChooseNormal:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowConnectionChoosed:="normal"
	return 
	
	
}

ui_selectContainerType(tempNewID="")
{
	global 
	
	
	ui_DisableMainGUI()
	gui, 8:default
	

	gui,font,s12
	gui,add,text,,% lang("Select_element_type")
		
	
	if (tempNewID%type%="Action" or tempNewID%type%="")
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
	gui,show,hide
	ui_GetMainGUIPos()
	wingetpos,,,tempWidth,tempHeight,ahk_id %SettingsHWND%
	tempXpos:=round(MainGUIX+MainGUIWidth/2- tempWidth/2)
	tempYpos:=round(MainGUIY+MainGUIHeight/2- tempHeight/2)
	
	gui,show,x%tempXpos% y%tempYpos%
	
	NowTypeChoosed=
	Loop
	{
		sleep,10
		if (NowTypeChoosed)
			return NowTypeChoosed
	}
	
	return
	
	
	8guiclose:
	GuiElementTypeChooseCancel:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowTypeChoosed:="aborted"
	return 
	
	GuiElementTypeChooseAction:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowTypeChoosed:="action"
	return
	
	GuiElementTypeChooseCondition:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowTypeChoosed:="condition"
	return
	
	GuiElementTypeChooseLoop:
	gui,destroy
	ui_EnableMainGUI()
	gui,MainGUI:default
	NowTypeChoosed:="loop"
	return 
	
	
	
	
}



