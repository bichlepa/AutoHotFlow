ui_settingsOfElement(ElementID)
{
	global
	local temp
	local temptext
	local tempIsDefault
	local tempAssigned
	
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
			anzahlTrigger=0 
			tempTriggers=
			tempTriggerNames=
			for anzahlTrigger, temptrigger in allTriggers
			{
				tempTriggers=%tempTriggers%%temptrigger%|
				tempTriggerNames:=tempTriggerNames %temptrigger%name "|"
			}
			StringTrimRight,tempTriggers,tempTriggers,1
			StringTrimRight,tempTriggerNames,tempTriggerNames,1
			StringSplit,tempTriggers,tempTriggers,|
			StringSplit,tempTriggerNames,tempTriggerNames,|
			
			if anzahlTrigger=0
			{
				setElementID:=e_NewTrigger()
				ui_selectElementType(%setElementID%Type,setElementID)
				return
			}
			;~ else if anzahlTrigger =1
			;~ {
				;~ ui_settingsOfElement(tempTriggers)
				;~ return
			;~ }
			else
			{
				
				ui_DisableMainGUI()
				gui,4:default
				gui,+owner
				gui,add,text,w300,% lang("Select_a_trigger")
				gui,add,ListBox,w400 h500 vGuiTriggerChoose gGuiTriggerChoose AltSubmit choose1,%temptriggerNames%
				gui,add,button,w100 h30 gGuiTriggerOK default,% lang("OK")
				gui,add,button,w90 h30 X+10 gGuiTriggerNew,% lang("New_Trigger")
				gui,add,button,w90 X+10 h30 gGuiTriggerDelete,% lang("Delete_Trigger")
				gui,add,button,w90 X+10 h30 yp gGuiTriggerCancel,% lang("Cancel")
				gui,show
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
				
				e_removeTrigger(e_TriggerNumbertoID(GuiTriggerChoose))
				saved=no
				gui,destroy
				ui_EnableMainGUI()
				e_UpdateTriggerName()
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
	gui,2:default
	
	gui,font,s8 cDefault wnorm
	gui,add,button,w400 x10 gGUISettingsOfElementSelectType,% lang("%1%_type:_%2%",lang(setElementType),getname%setElementType%%setElementsubType%())
	gui,font,s10 cnavy wbold
	gui,add,text,x10 w400,Name
	gui,font,s8 cDefault wnorm
	gui,add,checkbox, x10 vGUISettingsOfElementCheckStandardName gGUISettingsOfElementCheckStandardName,% lang("Standard_name")
	gui,add,edit,w400 x10 Multi r5 vGUISettingsOfElementEditName gGUISettingsOfElementUpdateName,% %setElementID%name
	
	
	
	parametersToEdit:=getParameters%setElementType%%setElementsubType%()
	;MsgBox,% parametersToEdit
	for index, parameter in parametersToEdit
	{
		loop,10
			parameter%a_index%=
		StringSplit,parameter,parameter,|
		; parameter1: What should be set
		; parameter2: Default Value
		; parameter3: Internal parameter name
		
		if parameter1=Label
		{
			gui,font,s10 cnavy wbold
			if (parameter3!="")
			{
				gui,add,text,x10 w400 Y+15 vGUISettingsOfElement%setElementID%%parameter3% ,%parameter2%
			}
			else
			{
				gui,add,text,x10 w400 Y+15,%parameter2%
			}
		}
		else if parameter1=Text
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% ;get the saved parameter
			
			if (temp="") ;if nothing is saved
				temptext=%parameter2% ;load default parameter
			else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,x10 r1 w400  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=Text2
		{
			gui,font,s8 cDefault wnorm
			StringSplit,tempdefault,parameter2,; ;get the default parameter
			StringSplit,tempparname,parameter3,; ;get the parameter names
			
			;First edit
			temp:=%setElementID%%tempparname1% ;get the saved parameter
			
			if (temp="") ;if nothing is saved
				temptext=%tempdefault1% ;load default parameter
			else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,x10 r1 w195  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempparname1%,%temptext%
			
			;second edit
			temp:=%setElementID%%tempparname2% ;get the saved parameter
			
			if (temp="") ;if nothing is saved
				temptext=%tempdefault2% ;load default parameter
			else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,X+10 r1 w195  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%tempparname2%,%temptext%
		}
		else if parameter1=MultiLineText
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% ;get the saved parameter
			if (temp="") ;if nothing is saved
				temptext=%parameter2% ;load default parameter
			else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,w400 h100 x10 multi gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=VariableName
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% ;get the saved parameter
			
			if (temp="") ;if nothing is saved
				temptext=%parameter2% ;load default parameter
			else
				temptext=%temp% ;set the saved parameter as text
			gui,add,edit,x10 r1 w400  gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=Number
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if (temp="")
				temptext=%parameter2%
			else
				temptext=%temp%
			gui,add,edit,w400 x10 number gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=Checkbox
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			temptext=%parameter4%
			if temp=
			{
				temp=%parameter2%
			}
			gui,add,checkbox,w400 x10 checked%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=CheckboxWithGray
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			temptext=%parameter4%
			if temp=
			{
				temp=%parameter2%
			}
			gui,add,checkbox,w400 x10 check3 checked%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temptext%
			
		}
		else if parameter1=Hotkey
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
			{
				temp=%parameter2%
			}
			gui,add,edit,w300 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temp%
			gui,add,hotkey,w90 X+10 gGUISettingsOfElementHotkey vGUISettingsOfElement%setElementID%%parameter3%hotkey,%temp%
			
		}
		else if parameter1=Button
		{
			gui,font,s8 cDefault wnorm
			temp:=parameter4
			gui,add,button,w400 x10  g%parameter2% vGUISettingsOfElement%setElementID%%parameter3%,%parameter4%
		}
		else if parameter1=Radio
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
			{
				temp:=parameter2
				tempIsDefault:=true
			}
			else
				tempIsDefault:=false
			
			StringSplit,GUISettingsOfElement%setElementID%%parameter3%allRadios,parameter4,;
			tempAssigned:=false
			loop,% GUISettingsOfElement%setElementID%%parameter3%allRadios0
			{
				if a_index=1
				{
					if (temp=a_index)
					{
						gui,add,radio, w400 x10 checked Group gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%%a_index% ,% GUISettingsOfElement%setElementID%%parameter3%allRadios%a_index%
						tempAssigned:=true
					}
					else
						gui,add,radio, w400 x10 Group gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%%a_index% ,% GUISettingsOfElement%setElementID%%parameter3%allRadios%a_index%
					
				}
				else 
				{
					if (temp=a_index)
					{
						gui,add,radio, w400 x10 checked gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%%a_index%,%  GUISettingsOfElement%setElementID%%parameter3%allRadios%a_index%
						tempAssigned:=true
					}
					else
						gui,add,radio, w400 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%%a_index%,%  GUISettingsOfElement%setElementID%%parameter3%allRadios%a_index%
				}
				
				
				
			}
			if (tempAssigned=false and tempIsDefault=false)
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%%parameter2%,1
			
		}
		else if parameter1=DropDownListByName
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
				temp:=parameter2
			temptoChoose=
			
			GUISettingsOfElement%setElementID%%parameter3%allSelections=
			StringSplit,GUISettingsOfElement%setElementID%%parameter3%allSelections,parameter4,;
			loop,% GUISettingsOfElement%setElementID%%parameter3%allSelections0
			{
				if (GUISettingsOfElement%setElementID%%parameter3%allSelections%a_index%=temp)
					temptoChoose:=A_Index
				GUISettingsOfElement%setElementID%%parameter3%allSelections.="|" GUISettingsOfElement%setElementID%%parameter3%allSelections%a_index%
				
			}
			if temptoChoose=
				temptoChoose=1
			StringTrimLeft,GUISettingsOfElement%setElementID%%parameter3%allSelections,GUISettingsOfElement%setElementID%%parameter3%allSelections,1
			gui,add,DropDownList, w400 x10 choose%temptoChoose% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3% ,% GUISettingsOfElement%setElementID%%parameter3%allSelections
			
		}
		else if parameter1=DropDownList
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
				:=parameter2
			temptoChoose=
			GUISettingsOfElement%setElementID%%parameter3%allSelections=
			StringSplit,GUISettingsOfElement%setElementID%%parameter3%allSelections,parameter4,;
			loop,% GUISettingsOfElement%setElementID%%parameter3%allSelections0
			{
				if (GUISettingsOfElement%setElementID%%parameter3%allSelections%a_index%=temp)
					temptoChoose:=A_Index
				GUISettingsOfElement%setElementID%%parameter3%allSelections.="|" GUISettingsOfElement%setElementID%%parameter3%allSelections%a_index%
				
			}
			if temptoChoose=
				temptoChoose=1
			StringTrimLeft,GUISettingsOfElement%setElementID%%parameter3%allSelections,GUISettingsOfElement%setElementID%%parameter3%allSelections,1
			gui,add,DropDownList, w400 x10 AltSubmit choose%temptoChoose% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3% ,% GUISettingsOfElement%setElementID%%parameter3%allSelections
			
		}
		else if parameter1=Slider
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
				temp:=parameter2
			
			;parameter2 contains further options
			gui,add,slider, w400 x10 %parameter4% AltSubmit gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3% ,% temp
			
		}
		else if parameter1=File
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
			{
				temp=%parameter2%
			}
			GUISettingsOfElement%setElementID%%parameter3%Prompt:=parameter4
			GUISettingsOfElement%setElementID%%parameter3%Options:=parameter5
			GUISettingsOfElement%setElementID%%parameter3%Filter:=parameter6
			gui,add,edit,w370 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temp%
			gui,add,button,w20 X+10  gGUISettingsOfElementSelectFile vGUISettingsOfElementbuttonSelectFile_%setElementID%_%parameter3%,...
			
		}
		else if parameter1=Folder
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			if temp=
			{
				temp=%parameter2%
			}
			GUISettingsOfElement%setElementID%%parameter3%Prompt:=parameter4
			GUISettingsOfElement%setElementID%%parameter3%Options:=parameter5
			GUISettingsOfElement%setElementID%%parameter3%Filter:=parameter6
			gui,add,edit,w340 x10 gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3%,%temp%
			gui,add,button,w20 X+10  gGUISettingsOfElementSelectFolder vGUISettingsOfElementbuttonSelectFile_%setElementID%_%parameter3%,...
			gui,add,button,w20 X+10 gGUISettingsOfElementSelectFolderHelp,?
		}
		else if parameter1=weekdays
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			
			if temp=
			{
				temp=%parameter2%
			}
			gui,add,checkbox,w45 x10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%2,% lang("Mon (Short for Monday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%3,% lang("Tue (Short for Tuesday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%4,% lang("Wed (Short for Wednesday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%5,% lang("Thu (Short for Thursday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%6,% lang("Fri (Short for Friday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%7,% lang("Sat (Short for Saturday")
			gui,add,checkbox,w45 X+10 gGUISettingsOfElementWeekdays vGUISettingsOfElement%setElementID%%parameter3%1,% lang("Sun (Short for Sunday") ;Sunday is 1
			IfInString,temp,1
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%1,1
			IfInString,temp,2
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%2,1
			IfInString,temp,3
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%3,1
			IfInString,temp,4
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%4,1
			IfInString,temp,5
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%5,1
			IfInString,temp,6
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%6,1
			IfInString,temp,7
				guicontrol,,GUISettingsOfElement%setElementID%%parameter3%7,1
			GUISettingsOfElement%setElementID%%parameter3%:=temp
		}
		else if parameter1=TimeOfDay
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			temptext=%parameter4%
			if temp=
			{
				if parameter2=
					temp=%a_now%
				else
					temp=%parameter2%
			}
			gui,add,DateTime,w400 x10 choose%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3% ,time
			
		}
		else if parameter1=DateAndTime
		{
			gui,font,s8 cDefault wnorm
			temp:=%setElementID%%parameter3% 
			temptext=%parameter4%
			if temp=
			{
				if parameter2=
					temp=%a_now%
				else
					temp=%parameter2%
			}
			gui,add,DateTime,w400 x10 choose%temp% gGUISettingsOfElementUpdateName vGUISettingsOfElement%setElementID%%parameter3% ,% "'" lang("Date") ":' " lang("MM/dd/yy") " '" lang("Time") ":' " lang("HH:mm:ss")
			
		}
		
		
	}
	gui,submit,nohide
	if (%ElementID%StandardName==true or %ElementID%StandardName=="")
	{
		GuiControl,,GUISettingsOfElementCheckStandardName,1
		GuiControl,Disable,GUISettingsOfElementEditName
		gosub,GUISettingsOfElementUpdateName
	}
	
	gui,add,button,w145 x10 h30 gGUISettingsOfElementSave default,% lang("Save")
	gui,add,button,w145 h30 yp X+10 gGUISettingsOfElementCancel,% lang("Cancel")
	
	gui -hwndSettingWindowHWND
	SG2 := New ScrollGUI(SettingWindowHWND,600, A_ScreenHeight*0.8, "+LabelGui2 +Resize +MinSize420x100 ",2,2)
	
	SG2.Show(lang("Settings") " - " lang(%ElementID%type) " - " lang(%ElementID%subtype), "xCenter yCenter")
	
	;gui,show,,% "·AutoHotFlow· " lang("Settings") " - " lang(%ElementID%type) " - " lang(%ElementID%subtype)
	return
	
	GUISettingsOfElementSelectType:
	gui,2:default
	gui,destroy
	SG2.Destroy()
	ui_EnableMainGUI()
	ui_selectElementType(%setElementID%Type,setElementID)
	return
	
	GUISettingsOfElementCheckStandardName:
	gui,2:default
	gui,submit,nohide
	
	if GUISettingsOfElementCheckStandardName=1
	{
		GuiControl,Disable,GUISettingsOfElementEditName
		gosub,GUISettingsOfElementUpdateName
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
	gui,2:default
	gui,submit,nohide
	StringTrimRight,tempHotkeyCotrol,a_guicontrol,6
	
	guicontrol,,%tempHotkeyCotrol%,% %a_guicontrol%
	return
	
	GUISettingsOfElementWeekdays:
	gui,2:default
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
	
	gosub,GUISettingsOfElementUpdateName
	return
	
	
	GUISettingsOfElementUpdateName:
	gui,2:default
	gui,submit,nohide
	
	
	
	CheckSettings%setElementType%%setElementsubType%(setElementID)
	
	if GUISettingsOfElementCheckStandardName!=1
	{
		
		return
	}
	
	
	Newname:=GenerateName%setElementType%%setElementsubType%(setElementID)
	
	guicontrol,,GUISettingsOfElementEditName,%Newname%
	return 
	
	GUISettingsOfElementButton:
	;~ MsgBox, %a_guicontrol%`n%A_gui%`n%A_guiEvent%`n%A_EventInfo%
	gui,submit,nohide
	RegExMatch(a_guicontrol, "GUISettingsOfElementbutton_(.+)_(.+)_(.+)", tempButton) ;Find out witch button was pressed
	tempSetWhat:=tempButton1
	tempSetID:=tempButton2
	tempSetPar:=tempButton3
	
	/*
	if tempsetwhat=NewFile
	{
		FileSelectFile,tempSetPath,S34,% GUISettingsOfElement%tempSetID%%tempSetPar%,% GUISettingsOfElement%tempSetID%%tempSetPar%prompt,% "(" GUISettingsOfElement%tempSetID%%tempSetPar%Filter ")"
		if not errorlevel
		{
			stringright,tempSetPathend,tempSetPath,4
			if tempSetPathend<>.lnk
				tempSetPath=%tempSetPath%.lnk
			guicontrol,,GUISettingsOfElement%tempSetID%%tempSetPar%,%tempSetPath%
			
			
		}
	}
	*/
	gosub,GUISettingsOfElementUpdateName
	return
	
	
	
	
	
	GUISettingsOfElementSelectFolderHelp:
	MsgBox % lang("Help is not implemented yet") " :-("
	return
	
	
	
	
	Gui2Close:
	Gui2Escape:
	2guiclose:
	GUISettingsOfElementCancel:
	gui,2:default
	if (%selElementID%name="Νew Соntainȩr") ;Do not translate!
	{
		if %selElementID%Type=trigger
			e_removeTrigger(selElementID)
		else
		{
			NowResultEditingElement=aborted
			
		}
		ui_draw()
		gui,2:default
	}
	Gui,destroy
	SG2.Destroy()
	
	ui_EnableMainGUI()
	return
	
	Gui2Size:
    If (A_EventInfo <> 1)
        SG2.AdjustToParent()
	Return
	
	GUISettingsOfElementSave:
	gui,2:default
	gui,submit
	if (%setElementID%type="trigger" and triggersEnabled=true) ;When editing a trigger, disable Triggers and enable them afterwards
	{
		tempReenablethen:=true
		r_EnableFlow()
		
	}
	
	
	
	%setElementID%Name:=GUISettingsOfElementEditName
	%setElementID%StandardName:=GUISettingsOfElementCheckStandardName
	
	for index, parameter in parametersToEdit
	{
		;MsgBox %parameter%
		StringSplit,parameter,parameter,|
		if (parameter3!="" and parameter0>2)
		{
			if (parameter1="Radio")
			{
				loop 10
				{
					if (GUISettingsOfElement%setElementID%%parameter3%%a_index%=1)
					{
						
						%setElementID%%parameter3%:=A_Index
						;MsgBox % setElementID parameter3 "=" A_Index
						break
					}
					;MsgBox % setElementID parameter3 "=" A_Index
				}
			}
			else if (parameter1="weekdays")
			{
				%setElementID%%parameter3%=
				loop 7
				{
					if (GUISettingsOfElement%setElementID%%parameter3%%a_index%=1)
					{
						
						%setElementID%%parameter3%.=A_Index
						;MsgBox % setElementID parameter3 "=" %setElementID%%parameter3%
					}
					;MsgBox % setElementID parameter3 "=" A_Index
				}
			}
			else  if (parameter1="text2")
			{
				
				StringSplit,tempparname,parameter3,; ;get the parameter names
				%setElementID%%tempparname1%:=GUISettingsOfElement%setElementID%%tempparname1%
				%setElementID%%tempparname2%:=GUISettingsOfElement%setElementID%%tempparname2%
			}
			else
			{
				;MsgBox % setElementID parameter3 "=" GUISettingsOfElement%setElementID%%parameter3%
				%setElementID%%parameter3%:=GUISettingsOfElement%setElementID%%parameter3%
				;MsgBox % setElementID parameter3 "=" GUISettingsOfElement%setElementID%%parameter3%
			}
		}
		
		
	}
	
	
	SG2.Destroy()
	Gui,destroy
	
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

ui_disableElementSettingsWindow()
{
	global
	
	gui,2:+disabled
}

ui_EnableElementSettingsWindow()
{
	global
	
	gui,2:-disabled
	WinActivate,% "·AutoHotFlow· " lang("Settings")
}

ui_selectElementType(type,setElementID)
{
	global
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
	gui,font,s12
	gui,add,text,,% lang("Whitch_%1% should be created?", lang(selElementType))
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
	
	
	
	gui,show
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
	gui,1:default
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
	ui_EnableMainGUI()
	
	
	gui,1:default
	
	;MsgBox,%selElementID% %GuiElementChoose%
	
	%GuiElementChoosedID%subType:=TVsubType%GuiElementChoosedTV%
	;%GuiElementChoosedID%name:="¦ new element" ;Do not translate!
	NowResultEditingElement=OK
	ui_settingsOfElement(GuiElementChoosedID)

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
	gui,show
	
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
	gui,1:default
	NowConnectionChoosed:="aborted"
	return 
	
	GuiConnectionChooseTrue:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowConnectionChoosed:="yes"
	return
	
	GuiConnectionChooseFalse:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowConnectionChoosed:="no"
	return 
	
	GuiConnectionChooseException:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowConnectionChoosed:="exception"
	return 
	
	GuiConnectionChooseNormal:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
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
	gui,show
	
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
	gui,1:default
	NowTypeChoosed:="aborted"
	return 
	
	GuiElementTypeChooseAction:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowTypeChoosed:="action"
	return
	
	GuiElementTypeChooseCondition:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowTypeChoosed:="condition"
	return
	
	GuiElementTypeChooseLoop:
	gui,destroy
	ui_EnableMainGUI()
	gui,1:default
	NowTypeChoosed:="loop"
	return 
	
	
	
	
}



