FlowCompabilityVersionOfApp:=10 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.


;Check the element class before its settings are loaded
LoadFlowCheckCompabilityClass(p_List,p_ElementID,p_section)
{
	global
	
	if FlowCompabilityVersion<11 ; AutoHotFlow v1.0 release
	{
		if (p_List[p_ElementID].class="Action_Get_Monitor_Settings")
		{
			p_List[p_ElementID].class="Action_Get_Screen_Settings"
		}
		if (p_List[p_ElementID].class="Action_Set_Monitor_Settings")
		{
			p_List[p_ElementID].class="Action_Set_Screen_Settings"
		}
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}

;Check the element settings after they were loaded
LoadFlowCheckCompability(p_List,p_ElementID,p_section,FlowCompabilityVersion)
{
	global
	
	local temp
	static lastlist
	
	if (lastlist!= p_List)
	{
		lastlist := p_List
		if (FlowCompabilityVersionOfApp > FlowCompabilityVersion)
		{
			logger("a2","Flow has format version " FlowCompabilityVersion ". Current version is " FlowCompabilityVersionOfApp ". Trying to keep compability.")
		}
	}
	
	if FlowCompabilityVersion<1 ; 2015,06
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Date_Calculation") 
		{
			p_List[p_ElementID].pars.Unit+=1 ;Added option milliseconds
			p_List[p_ElementID].pars.VarValue:=Element.Varname ;Output and input variable separated
			p_List[p_ElementID].pars.Operation:=1 ;Added option calculate time difference 
		}
	}
	if FlowCompabilityVersion<2 ; 2015,06
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Get_control_text") 
		{
			
			p_List[p_ElementID].pars.Varname:="t_Text" ;The variable name can now be specified
			
		}
		
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Get_mouse_position") 
		{
			
			p_List[p_ElementID].pars.Varnamey:="t_posx" ;The variable name can now be specified
			p_List[p_ElementID].pars.Varnamex:="t_posx" ;The variable name can now be specified
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Get_Volume") 
		{
			
			p_List[p_ElementID].pars.Varname:="t_volume" ;The variable name can now be specified
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Input_box") 
		{
			
			p_List[p_ElementID].pars.Varname:="t_input" ;The variable name can now be specified
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Set_Volume") 
		{
			if (p_List[p_ElementID].pars.Relatively) ;This option was deleted, a new option Action can be set between three states instead
				p_List[p_ElementID].pars.Action:=3
			else
				p_List[p_ElementID].pars.Action:=2
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Sleep") 
		{
			
			p_List[p_ElementID].pars.Unit:=1 ;The unit is only milliseconds
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="tooltip") 
		{
			
			p_List[p_ElementID].pars.Unit:=1 ;The unit is only milliseconds
		}
		
		if (p_List[p_ElementID].type="condition" and p_List[p_ElementID].subtype="file_exists" and p_List[p_ElementID].CompatibilityComment="WasFolderExists") 
		{
			p_List[p_ElementID].pars.file:=RIni_GetKeyValue("IniFile", p_section, "folder", "") ;Conditions FolderExists and FileExists were combined to FileExists
		}
		if (p_List[p_ElementID].type="trigger" and p_List[p_ElementID].subtype="Periodic_timer") 
		{
			
			p_List[p_ElementID].pars.Unit:=2 ;The only unit was seconds
		}
		
	}
	
	if FlowCompabilityVersion<3 ; 2015,08,09
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Read_from_ini") 
		{
			if (p_List[p_ElementID].pars.Action=2)
			p_List[p_ElementID].pars.Action:=3
		}
		
	}
	if FlowCompabilityVersion<4 ; 2015,08,15
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Set_Clipboard") 
		{
			temp:=RIni_GetKeyValue("IniFile", p_section, "varname", "") 
			if temp
			{
				p_List[p_ElementID].pars.text:=temp
				p_List[p_ElementID].pars.expression:=2
				
			}
		}
		
	}
	if FlowCompabilityVersion<5 ; 2015,08,28
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Play_Sound") 
		{
			temp:=RIni_GetKeyValue("IniFile", p_section, "WhitchSound", "") 
			if temp
			{
				if temp<6
				{
					p_List[p_ElementID].pars.WhichSound:=1
					
					if temp=2
						p_List[p_ElementID].pars.systemSound:="Windows Foreground.wav"
					else
						p_List[p_ElementID].pars.systemSound:="Windows Background.wav"
				}
				else if temp=6
					p_List[p_ElementID].pars.WhichSound:=2
				
			}
		}
		
	}
	if FlowCompabilityVersion<6 ; 2015,09,01
	{
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Input_Box") 
		{
			temp:=RIni_GetKeyValue("IniFile", p_section, "text", "") 
			p_List[p_ElementID].pars.message:=temp
			p_List[p_ElementID].pars.IsTimeout:=0
			p_List[p_ElementID].pars.OnlyNumbers:=0 
			p_List[p_ElementID].pars.MaskUserInput:=0 
			p_List[p_ElementID].pars.MultilineEdit:=0 
			p_List[p_ElementID].pars.ShowCancelButton:=0 
			p_List[p_ElementID].pars.IfDismiss:=2 ;Exception if dismiss
			
		}
		if (p_List[p_ElementID].type="condition" and p_List[p_ElementID].subtype="Confirmation_Dialog") 
		{
			temp:=RIni_GetKeyValue("IniFile", p_section, "question", "") 
			p_List[p_ElementID].pars.message:=temp
			p_List[p_ElementID].pars.IsTimeout:=0
			p_List[p_ElementID].pars.ShowCancelButton:=0 
			p_List[p_ElementID].pars.IfDismiss:=3 ;Exception if dismiss
			
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Message_Box") 
		{
			temp:=RIni_GetKeyValue("IniFile", p_section, "text", "") 
			p_List[p_ElementID].pars.message:=temp
			p_List[p_ElementID].pars.IsTimeout:=0
			p_List[p_ElementID].pars.IfDismiss:=2 ;Exception if dismiss
			
		}
		
	}
	if FlowCompabilityVersion<11 ; AutoHotFlow v1.0 release
	{
		if (p_List[p_ElementID].class="action_New_List") 
		{
			if not (p_List[p_ElementID].pars.Expression)
				p_List[p_ElementID].pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "IsExpression", 1) 
			if not (p_List[p_ElementID].pars.WhichPosition)
				p_List[p_ElementID].pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 1) 
		}
		if (p_List[p_ElementID].class="action_Add_To_list") 
		{
			if not (p_List[p_ElementID].pars.Expression)
				p_List[p_ElementID].pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "IsExpression", 1) 
			if not (p_List[p_ElementID].pars.WhichPosition)
				p_List[p_ElementID].pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 1) 
		}
		if (p_List[p_ElementID].class="Action_Get_Index_Of_Element_In_List") 
		{
			if not (p_List[p_ElementID].pars.Expression)
				p_List[p_ElementID].pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "isExpressionSearchContent", 1) 
		}
		if (p_List[p_ElementID].class="action_kill_window") 
		{
			p_List[p_ElementID].class :="action_close_window"
			p_List[p_ElementID].WinCloseMethod :=2 ;Kill method
		}
		if (p_List[p_ElementID].class="action_copy_variable")
		{
			p_List[p_ElementID].class="action_new_variable"
			p_List[p_ElementID].pars.VarValue:=RIni_GetKeyValue("IniFile", p_section, "OldVarname", "") 
			p_List[p_ElementID].pars.expression:="string"
		}
		if (p_List[p_ElementID].class="action_Recycle_file")
		{
			p_List[p_ElementID].class="action_Delete_file"
			p_List[p_ElementID].file:=RIni_GetKeyValue("IniFile", p_section, "file", "") 
		}
		if (p_List[p_ElementID].class="Action_Download_File")
		{
			if (p_List[p_ElementID].pars.isexpression=1)
				p_List[p_ElementID].pars.isexpression := "rawString"
			else if (p_List[p_ElementID].pars.expression=2)
				p_List[p_ElementID].pars.isexpression := "string"
			else if (p_List[p_ElementID].pars.expression=3)
				p_List[p_ElementID].pars.isexpression := "expression"
		}
		else
		{
			;All elements with the parameter expression. The selection results now to an enum instead of number 1 or 2.
			if (p_List[p_ElementID].pars.expression=1)
				p_List[p_ElementID].pars.expression := "string"
			else if (p_List[p_ElementID].pars.expression=2)
				p_List[p_ElementID].pars.expression := "expression"
			if (p_List[p_ElementID].pars.isExpression=1)
				p_List[p_ElementID].pars.isExpression := "string"
			else if (p_List[p_ElementID].pars.isExpression=2)
				p_List[p_ElementID].pars.isExpression := "expression"
			if (p_List[p_ElementID].pars.ExpressionPos=1)
				p_List[p_ElementID].pars.ExpressionPos := "string"
			else if (p_List[p_ElementID].pars.ExpressionPos=2)
				p_List[p_ElementID].pars.ExpressionPos := "expression"
			if (p_List[p_ElementID].pars.ExpressionFrom=1)
				p_List[p_ElementID].pars.ExpressionFrom := "string"
			else if (p_List[p_ElementID].pars.ExpressionFrom=2)
				p_List[p_ElementID].pars.ExpressionFrom := "expression"
			if (p_List[p_ElementID].pars.ExpressionTo=1)
				p_List[p_ElementID].pars.ExpressionTo := "string"
			else if (p_List[p_ElementID].pars.ExpressionTo=2)
				p_List[p_ElementID].pars.ExpressionTo := "expression"
		}
		if (p_List[p_ElementID].class="Action_Change_character_case")
		{
			if (p_List[p_ElementID].pars.CharCase=1)
				p_List[p_ElementID].pars.CharCase := "upper"
			else if (p_List[p_ElementID].pars.CharCase=2)
				p_List[p_ElementID].pars.CharCase := "lower"
			else if (p_List[p_ElementID].pars.CharCase=3)
				p_List[p_ElementID].pars.CharCase := "firstUP"
		}
		if (p_List[p_ElementID].class="Action_Change_character_case")
		{
			tempenum:= ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]
			if (p_List[p_ElementID].pars.Button>= 1 and p_List[p_ElementID].pars.Button<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Button:=tempenum[p_List[p_ElementID].pars.Button]
			}
		}
		if (p_List[p_ElementID].class="Action_Click")
		{
			tempenum:= ["Input", "Event", "Play"]
			if (p_List[p_ElementID].pars.SendMode>= 1 and p_List[p_ElementID].pars.SendMode<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.SendMode:=tempenum[p_List[p_ElementID].pars.SendMode]
			}
			tempenum:= ["Screen", "Window", "Cilent", "Relative"]
			if (p_List[p_ElementID].pars.CoordMode>= 1 and p_List[p_ElementID].pars.CoordMode<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.CoordMode:=tempenum[p_List[p_ElementID].pars.CoordMode]
			}
			tempenum:= ["Click", "D", "U"]
			if (p_List[p_ElementID].pars.DownUp>= 1 and p_List[p_ElementID].pars.DownUp<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.DownUp:=tempenum[p_List[p_ElementID].pars.DownUp]
			}
		}
		if (p_List[p_ElementID].class="Action_Move_Window")
		{
			tempenum:= ["Maximize", "Minimize", "Restore", "Move"]
			if (p_List[p_ElementID].pars.WinMoveEvent>= 1 and p_List[p_ElementID].pars.WinMoveEvent<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WinMoveEvent:=tempenum[p_List[p_ElementID].pars.WinMoveEvent]
			}
		}
		if (p_List[p_ElementID].class="Action_New_List")
		{
			tempenum:= ["Empty", "One", "Multiple"]
			if (p_List[p_ElementID].pars.InitialContent>= 1 and p_List[p_ElementID].pars.InitialContent<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.InitialContent:=tempenum[p_List[p_ElementID].pars.InitialContent]
			}
			tempenum:= ["First", "Specified"]
			if (p_List[p_ElementID].pars.WhichPosition>= 1 and p_List[p_ElementID].pars.WhichPosition<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichPosition:=tempenum[p_List[p_ElementID].pars.WhichPosition]
			}
		}
		if (p_List[p_ElementID].class="Action_Add_to_list")
		{
			tempenum:= ["One", "Multiple"]
			if (p_List[p_ElementID].pars.NumberOfElements>= 1 and p_List[p_ElementID].pars.NumberOfElements<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.NumberOfElements:=tempenum[p_List[p_ElementID].pars.NumberOfElements]
			}
			tempenum:= ["First", "Last", "Specified"]
			if (p_List[p_ElementID].pars.WhichPosition>= 1 and p_List[p_ElementID].pars.WhichPosition<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichPosition:=tempenum[p_List[p_ElementID].pars.WhichPosition]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_From_List")
		{
			tempenum:= ["First", "Last", "Random", "Specified"]
			if (p_List[p_ElementID].pars.WhichPosition>= 1 and p_List[p_ElementID].pars.WhichPosition<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichPosition:=tempenum[p_List[p_ElementID].pars.WhichPosition]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_Index_Of_Element_In_List")
		{
			tempenum:= ["First", "Last", "Random", "Specified"]
			if (p_List[p_ElementID].pars.WhichPosition>= 1 and p_List[p_ElementID].pars.WhichPosition<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichPosition:=tempenum[p_List[p_ElementID].pars.WhichPosition]
			}
		}
		if (p_List[p_ElementID].class="Action_Enbale_Flow")
		{
			tempenum:= ["Any", "Default", "Specific"]
			if (p_List[p_ElementID].pars.WhichTrigger>= 1 and p_List[p_ElementID].pars.WhichTrigger<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichTrigger:=tempenum[p_List[p_ElementID].pars.WhichTrigger]
			}
			tempenum:= ["Enable", "Disable"]
			if (p_List[p_ElementID].pars.Enable>= 1 and p_List[p_ElementID].pars.Enable<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Enable:=tempenum[p_List[p_ElementID].pars.Enable]
			}
		}
		if (p_List[p_ElementID].class="Condition_Flow_Enabled")
		{
			tempenum:= ["Any", "Default", "Specific"]
			if (p_List[p_ElementID].pars.WhichTrigger>= 1 and p_List[p_ElementID].pars.WhichTrigger<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichTrigger:=tempenum[p_List[p_ElementID].pars.WhichTrigger]
			}
		}
		if (p_List[p_ElementID].class="Action_Sleep")
		{
			tempenum:= ["Milliseconds", "Seconds", "Minutes"]
			if (p_List[p_ElementID].pars.Unit>= 1 and p_List[p_ElementID].pars.Unit<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Unit:=tempenum[p_List[p_ElementID].pars.Unit]
			}
		}
		if (p_List[p_ElementID].class="Action_Tooltip")
		{
			tempenum:= ["Milliseconds", "Seconds", "Minutes"]
			if (p_List[p_ElementID].pars.Unit>= 1 and p_List[p_ElementID].pars.Unit<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Unit:=tempenum[p_List[p_ElementID].pars.Unit]
			}
		}
		if (p_List[p_ElementID].class="Trigger_Hotkey")
		{
			tempenum:= ["Everywhere", "WindowIsActive", "WindowExists"]
			if (p_List[p_ElementID].pars.UseWindow>= 1 and p_List[p_ElementID].pars.UseWindow<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.UseWindow:=tempenum[p_List[p_ElementID].pars.UseWindow]
			}
		}
		if (p_List[p_ElementID].class="Action_Delete_From_Ini")
		{
			tempenum:= ["DeleteKey", "DeleteSection"]
			if (p_List[p_ElementID].pars.Action>= 1 and p_List[p_ElementID].pars.Action<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Action:=tempenum[p_List[p_ElementID].pars.Action]
			}
		}
		if (p_List[p_ElementID].class="Action_Delete_From_List")
		{
			if not (p_List[p_ElementID].pars.WhichPosition)
				p_List[p_ElementID].pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 2) 
			tempenum:= ["DeleteKey", "DeleteSection"]
			if (p_List[p_ElementID].pars.WhichPosition>= 1 and p_List[p_ElementID].pars.WhichPosition<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichPosition:=tempenum[p_List[p_ElementID].pars.WhichPosition]
			}
		}
		if (p_List[p_ElementID].class="Action_Eject_Drive")
		{
			tempenum:= ["ejectDrive", "RetractTray"]
			if (p_List[p_ElementID].pars.WhatDo>= 1 and p_List[p_ElementID].pars.WhatDo<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhatDo:=tempenum[p_List[p_ElementID].pars.WhatDo]
			}
			tempenum:= ["LibraryEjectByScan", "DeviceIoControl", "builtIn"]
			if (p_List[p_ElementID].pars.Method>= 1 and p_List[p_ElementID].pars.Method<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Method:=tempenum[p_List[p_ElementID].pars.Method]
			}
		}
		if (p_List[p_ElementID].class="Action_Empty_Recycle_Bin")
		{
			tempenum:= ["All", "Specified"]
			if (p_List[p_ElementID].pars.AllDrives>= 1 and p_List[p_ElementID].pars.AllDrives<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.AllDrives:=tempenum[p_List[p_ElementID].pars.AllDrives]
			}
			p_List[p_ElementID].DriveLetter:=RIni_GetKeyValue("IniFile", p_section, "drive", "") 
		}
		if (p_List[p_ElementID].class="Action_Get_Drive_Information")
		{
			tempenum:= ["Label", "Type", "Status", "StatusCD", "Capacity", "FreeSpace", "FileSystem", "Serial"]
			if (p_List[p_ElementID].pars.WhichInformation>= 1 and p_List[p_ElementID].pars.WhichInformation<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichInformation:=tempenum[p_List[p_ElementID].pars.WhichInformation]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_File_Size")
		{
			tempenum:= ["Bytes", "Kilobytes", "Megabytes"]
			if (p_List[p_ElementID].pars.Unit>= 1 and p_List[p_ElementID].pars.Unit<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Unit:=tempenum[p_List[p_ElementID].pars.Unit]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_Control_Text")
		{
			tempenum:= ["Text", "Class", "ID"]
			if (p_List[p_ElementID].pars.IdentifyControlBy>= 1 and p_List[p_ElementID].pars.IdentifyControlBy<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.IdentifyControlBy:=tempenum[p_List[p_ElementID].pars.IdentifyControlBy]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_File_Time")
		{
			tempenum:= ["Modification", "Creation", "Access"]
			if (p_List[p_ElementID].pars.TimeType>= 1 and p_List[p_ElementID].pars.TimeType<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.TimeType:=tempenum[p_List[p_ElementID].pars.TimeType]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_File_Time")
		{
			tempenum:= ["One", "Multiple"]
			if (p_List[p_ElementID].pars.NumberOfElements>= 1 and p_List[p_ElementID].pars.NumberOfElements<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.NumberOfElements:=tempenum[p_List[p_ElementID].pars.NumberOfElements]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_mouse_position" )
		{
			tempenum:= ["Screen", "Window", "Cilent"]
			if (p_List[p_ElementID].pars.CoordMode>= 1 and p_List[p_ElementID].pars.CoordMode<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.CoordMode:=tempenum[p_List[p_ElementID].pars.CoordMode]
			}
		}
		if (p_List[p_ElementID].class="Action_Get_pixel_color")
		{
			tempenum:= ["Screen", "Window", "Cilent"]
			if (p_List[p_ElementID].pars.CoordMode>= 1 and p_List[p_ElementID].pars.CoordMode<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.CoordMode:=tempenum[p_List[p_ElementID].pars.CoordMode]
			}
			tempenum:= ["Default", "Alt", "Slow"]
			if (p_List[p_ElementID].pars.Method>= 1 and p_List[p_ElementID].pars.Method<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.Method:=tempenum[p_List[p_ElementID].pars.Method]
			}
			if (not p_List[p_ElementID].pars.Xpos)
				p_List[p_ElementID].pars.Xpos:=RIni_GetKeyValue("IniFile", p_section, "CoordinateX", 10) 
			if (not p_List[p_ElementID].pars.Ypos)
				p_List[p_ElementID].pars.Ypos:=RIni_GetKeyValue("IniFile", p_section, "CoordinateY", 20) 
		}
		if (p_List[p_ElementID].class="Action_HTTP_Request")
		{
			tempenum:= ["automatic", "custom"]
			if (p_List[p_ElementID].pars.WhichContentType>= 1 and p_List[p_ElementID].pars.WhichContentType<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichContentType:=tempenum[p_List[p_ElementID].pars.WhichContentType]
			}
			if (p_List[p_ElementID].pars.WhichContentLength>= 1 and p_List[p_ElementID].pars.WhichContentLength<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichContentLength:=tempenum[p_List[p_ElementID].pars.WhichContentLength]
			}
			if (p_List[p_ElementID].pars.WhichMethod>= 1 and p_List[p_ElementID].pars.WhichMethod<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichMethod:=tempenum[p_List[p_ElementID].pars.WhichMethod]
			}
			if (p_List[p_ElementID].pars.WhichUserAgent>= 1 and p_List[p_ElementID].pars.WhichUserAgent<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichUserAgent:=tempenum[p_List[p_ElementID].pars.WhichUserAgent]
			}
			tempenum:= ["none", "automatic", "custom"]
			if (p_List[p_ElementID].pars.WhichContentMD5>= 1 and p_List[p_ElementID].pars.WhichContentMD5<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichContentMD5:=tempenum[p_List[p_ElementID].pars.WhichContentMD5]
			}
			if (p_List[p_ElementID].pars.WhichProxy>= 1 and p_List[p_ElementID].pars.WhichProxy<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichProxy:=tempenum[p_List[p_ElementID].pars.WhichProxy]
			}
			tempenum:= ["Variable", "File"]
			if (p_List[p_ElementID].pars.WhereToPutResponseData>= 1 and p_List[p_ElementID].pars.WhereToPutResponseData<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhereToPutResponseData:=tempenum[p_List[p_ElementID].pars.WhereToPutResponseData]
			}
			tempenum:= ["utf-8", "definedCharset", "definedCodepage"]
			if (p_List[p_ElementID].pars.WhichCodepage>= 1 and p_List[p_ElementID].pars.WhichCodepage<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhichCodepage:=tempenum[p_List[p_ElementID].pars.WhichCodepage]
			}
			tempenum:= ["NoUpload", "Specified", "File"]
			if (p_List[p_ElementID].pars.WhereToGetPostData>= 1 and p_List[p_ElementID].pars.WhereToGetPostData<=tempenum.MaxIndex())
			{
				p_List[p_ElementID].pars.WhereToGetPostData:=tempenum[p_List[p_ElementID].pars.WhereToGetPostData]
			}
		}
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}


LoadFlowCheckCompabilityOverall(p_FlowObj, p_FlowCompabilityVersion, p_OutdatedMainTriggerContainerData)
{
	if p_FlowCompabilityVersion<7 ; 2016.11.22 
	{
		;Trigger container which can contain multiple triggers removed. Each trigger is now an element just as other elements
		for forElementID, forElement in p_FlowObj.allElements
		{
			if (forElement.type = "trigger")
			{
				forElement.x := p_OutdatedMainTriggerContainerData.x
				forElement.y := p_OutdatedMainTriggerContainerData.y
			}
		}
		copyOfAllConnection:= objfullyclone(p_FlowObj.allConnections)
		for forConnectionID, forConnection in copyOfAllConnection
		{
			if (forConnection.from = p_OutdatedMainTriggerContainerData.id)
			{
				tempCount = 0
				for forElementID, forElement in p_FlowObj.allElements
				{
					if (forElement.type = "trigger")
					{
						if (tempCount =0)
						{
							p_FlowObj.allConnections[forConnectionID].from := forElementID
						}
						else
						{
							newConnectionID := connection_new(p_FlowObj.ID)
				
							p_FlowObj.allConnections[newConnectionID].from:=forElementID
							p_FlowObj.allConnections[newConnectionID].to:=forConnection.to
							p_FlowObj.allConnections[newConnectionID].ConnectionType:=forConnection.ConnectionType
							p_FlowObj.allConnections[newConnectionID].fromPart:=forConnection.fromPart
							p_FlowObj.allConnections[newConnectionID].ToPart:=forConnection.ToPart
						}
						tempCount++
					}
				}
			}
		}
	}
}