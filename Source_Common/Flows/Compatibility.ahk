FlowCompabilityVersionOfApp:=10 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.


;Check the element class before its settings are loaded
LoadFlowCheckCompabilityClass(p_FlowID, p_ElementID, p_section)
{
	global
	
	if FlowCompabilityVersion<11 ; AutoHotFlow v1.0 release
	{
		elementClass := _getElementProperty(p_FlowID, p_ElementID, "class")

		if (elementClass="Action_Get_Monitor_Settings")
		{
			_setElementProperty(p_FlowID, p_ElementID, "class", "Action_Get_Screen_Settings")
		}
		if (elementClass="Action_Set_Monitor_Settings")
		{
			_setElementProperty(p_FlowID, p_ElementID, "class", "Action_Set_Screen_Settings")
		}
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}

;Check the element settings after they were loaded
LoadFlowCheckCompabilityElement(p_FlowID, p_ElementID, p_section, FlowCompabilityVersion)
{
	global
	
	local temp
	static lastlist
	
	if (FlowCompabilityVersionOfApp > FlowCompabilityVersion)
	{
		logger("a2","Flow has format version " FlowCompabilityVersion ". Current version is " FlowCompabilityVersionOfApp ". Trying to keep compability.")

		IfInString, p_ElementID ,element
			element := _getElement(p_FlowID, p_ElementID)
		else IfInString,tempSection,connection
			element := _getConnection(p_FlowID, p_ElementID)
		else
			return

		if FlowCompabilityVersion<1 ; 2015,06
		{
			if (element.type="action" and element.subtype="Date_Calculation") 
			{
				element.pars.Unit+=1 ;Added option milliseconds
				element.pars.VarValue:=Element.Varname ;Output and input variable separated
				element.pars.Operation:=1 ;Added option calculate time difference 
			}
		}
		if FlowCompabilityVersion<2 ; 2015,06
		{
			if (element.type="action" and element.subtype="Get_control_text") 
			{
				
				element.pars.Varname:="t_Text" ;The variable name can now be specified
				
			}
			
			if (element.type="action" and element.subtype="Get_mouse_position") 
			{
				
				element.pars.Varnamey:="t_posx" ;The variable name can now be specified
				element.pars.Varnamex:="t_posx" ;The variable name can now be specified
			}
			if (element.type="action" and element.subtype="Get_Volume") 
			{
				
				element.pars.Varname:="t_volume" ;The variable name can now be specified
			}
			if (element.type="action" and element.subtype="Input_box") 
			{
				
				element.pars.Varname:="t_input" ;The variable name can now be specified
			}
			if (element.type="action" and element.subtype="Set_Volume") 
			{
				if (element.pars.Relatively) ;This option was deleted, a new option Action can be set between three states instead
					element.pars.Action:=3
				else
					element.pars.Action:=2
			}
			if (element.type="action" and element.subtype="Sleep") 
			{
				
				element.pars.Unit:=1 ;The unit is only milliseconds
			}
			if (element.type="action" and element.subtype="tooltip") 
			{
				
				element.pars.Unit:=1 ;The unit is only milliseconds
			}
			
			if (element.type="condition" and element.subtype="file_exists" and element.CompatibilityComment="WasFolderExists") 
			{
				element.pars.file:=RIni_GetKeyValue("IniFile", p_section, "folder", "") ;Conditions FolderExists and FileExists were combined to FileExists
			}
			if (element.type="trigger" and element.subtype="Periodic_timer") 
			{
				
				element.pars.Unit:=2 ;The only unit was seconds
			}
			
		}
		
		if FlowCompabilityVersion<3 ; 2015,08,09
		{
			if (element.type="action" and element.subtype="Read_from_ini") 
			{
				if (element.pars.Action=2)
				element.pars.Action:=3
			}
			
		}
		if FlowCompabilityVersion<4 ; 2015,08,15
		{
			if (element.type="action" and element.subtype="Set_Clipboard") 
			{
				temp:=RIni_GetKeyValue("IniFile", p_section, "varname", "") 
				if temp
				{
					element.pars.text:=temp
					element.pars.expression:=2
					
				}
			}
			
		}
		if FlowCompabilityVersion<5 ; 2015,08,28
		{
			if (element.type="action" and element.subtype="Play_Sound") 
			{
				temp:=RIni_GetKeyValue("IniFile", p_section, "WhitchSound", "") 
				if temp
				{
					if temp<6
					{
						element.pars.WhichSound:=1
						
						if temp=2
							element.pars.systemSound:="Windows Foreground.wav"
						else
							element.pars.systemSound:="Windows Background.wav"
					}
					else if temp=6
						element.pars.WhichSound:=2
					
				}
			}
			
		}
		if FlowCompabilityVersion<6 ; 2015,09,01
		{
			if (element.type="action" and element.subtype="Input_Box") 
			{
				temp:=RIni_GetKeyValue("IniFile", p_section, "text", "") 
				element.pars.message:=temp
				element.pars.IsTimeout:=0
				element.pars.OnlyNumbers:=0 
				element.pars.MaskUserInput:=0 
				element.pars.MultilineEdit:=0 
				element.pars.ShowCancelButton:=0 
				element.pars.IfDismiss:=2 ;Exception if dismiss
				
			}
			if (element.type="condition" and element.subtype="Confirmation_Dialog") 
			{
				temp:=RIni_GetKeyValue("IniFile", p_section, "question", "") 
				element.pars.message:=temp
				element.pars.IsTimeout:=0
				element.pars.ShowCancelButton:=0 
				element.pars.IfDismiss:=3 ;Exception if dismiss
				
			}
			if (element.type="action" and element.subtype="Message_Box") 
			{
				temp:=RIni_GetKeyValue("IniFile", p_section, "text", "") 
				element.pars.message:=temp
				element.pars.IsTimeout:=0
				element.pars.IfDismiss:=2 ;Exception if dismiss
				
			}
			
		}
		if FlowCompabilityVersion<11 ; AutoHotFlow v1.0 release
		{
			if (element.class="action_New_List") 
			{
				if not (element.pars.Expression)
					element.pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "IsExpression", 1) 
				if not (element.pars.WhichPosition)
					element.pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 1) 
			}
			if (element.class="action_Add_To_list") 
			{
				if not (element.pars.Expression)
					element.pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "IsExpression", 1) 
				if not (element.pars.WhichPosition)
					element.pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 1) 
			}
			if (element.class="Action_Get_Index_Of_Element_In_List") 
			{
				if not (element.pars.Expression)
					element.pars.IsExpression:=RIni_GetKeyValue("IniFile", p_section, "isExpressionSearchContent", 1) 
			}
			if (element.class="action_kill_window") 
			{
				element.class :="action_close_window"
				element.WinCloseMethod :=2 ;Kill method
			}
			if (element.class="action_copy_variable")
			{
				element.class:="action_new_variable"
				element.pars.VarValue:=RIni_GetKeyValue("IniFile", p_section, "OldVarname", "") 
				element.pars.expression:="string"
			}
			if (element.class="action_Recycle_file")
			{
				element.class:="action_Delete_file"
				element.file:=RIni_GetKeyValue("IniFile", p_section, "file", "") 
			}
			if (element.class="Action_Download_File")
			{
				if (element.pars.isexpression=1)
					element.pars.isexpression := "rawString"
				else if (element.pars.expression=2)
					element.pars.isexpression := "string"
				else if (element.pars.expression=3)
					element.pars.isexpression := "expression"
			}
			else
			{
				;All elements with the parameter expression. The selection results now to an enum instead of number 1 or 2.
				if (element.pars.expression=1)
					element.pars.expression := "string"
				else if (element.pars.expression=2)
					element.pars.expression := "expression"
				if (element.pars.isExpression=1)
					element.pars.isExpression := "string"
				else if (element.pars.isExpression=2)
					element.pars.isExpression := "expression"
				if (element.pars.ExpressionPos=1)
					element.pars.ExpressionPos := "string"
				else if (element.pars.ExpressionPos=2)
					element.pars.ExpressionPos := "expression"
				if (element.pars.ExpressionFrom=1)
					element.pars.ExpressionFrom := "string"
				else if (element.pars.ExpressionFrom=2)
					element.pars.ExpressionFrom := "expression"
				if (element.pars.ExpressionTo=1)
					element.pars.ExpressionTo := "string"
				else if (element.pars.ExpressionTo=2)
					element.pars.ExpressionTo := "expression"
			}
			if (element.class="Action_Change_character_case")
			{
				if (element.pars.CharCase=1)
					element.pars.CharCase := "upper"
				else if (element.pars.CharCase=2)
					element.pars.CharCase := "lower"
				else if (element.pars.CharCase=3)
					element.pars.CharCase := "firstUP"
			}
			if (element.class="Action_Change_character_case")
			{
				tempenum:= ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]
				if (element.pars.Button>= 1 and element.pars.Button<=tempenum.MaxIndex())
				{
					element.pars.Button:=tempenum[element.pars.Button]
				}
			}
			if (element.class="Action_Click")
			{
				tempenum:= ["Input", "Event", "Play"]
				if (element.pars.SendMode>= 1 and element.pars.SendMode<=tempenum.MaxIndex())
				{
					element.pars.SendMode:=tempenum[element.pars.SendMode]
				}
				tempenum:= ["Screen", "Window", "Client", "Relative"]
				if (element.pars.CoordMode>= 1 and element.pars.CoordMode<=tempenum.MaxIndex())
				{
					element.pars.CoordMode:=tempenum[element.pars.CoordMode]
				}
				tempenum:= ["Click", "D", "U"]
				if (element.pars.DownUp>= 1 and element.pars.DownUp<=tempenum.MaxIndex())
				{
					element.pars.DownUp:=tempenum[element.pars.DownUp]
				}
			}
			if (element.class="Action_Move_Mouse")
			{
				tempenum:= ["Input", "Event", "Play"]
				if (element.pars.SendMode>= 1 and element.pars.SendMode<=tempenum.MaxIndex())
				{
					element.pars.SendMode:=tempenum[element.pars.SendMode]
				}
				tempenum:= ["Screen", "Window", "Client", "Relative"]
				if (element.pars.CoordMode>= 1 and element.pars.CoordMode<=tempenum.MaxIndex())
				{
					element.pars.CoordMode:=tempenum[element.pars.CoordMode]
				}
			}
			if (element.class="Action_Move_Window")
			{
				tempenum:= ["Maximize", "Minimize", "Restore", "Move"]
				if (element.pars.WinMoveEvent>= 1 and element.pars.WinMoveEvent<=tempenum.MaxIndex())
				{
					element.pars.WinMoveEvent:=tempenum[element.pars.WinMoveEvent]
				}
			}
			if (element.class="Action_New_List")
			{
				tempenum:= ["Empty", "One", "Multiple"]
				if (element.pars.InitialContent>= 1 and element.pars.InitialContent<=tempenum.MaxIndex())
				{
					element.pars.InitialContent:=tempenum[element.pars.InitialContent]
				}
				tempenum:= ["First", "Specified"]
				if (element.pars.WhichPosition>= 1 and element.pars.WhichPosition<=tempenum.MaxIndex())
				{
					element.pars.WhichPosition:=tempenum[element.pars.WhichPosition]
				}
			}
			if (element.class="Action_Add_to_list")
			{
				tempenum:= ["One", "Multiple"]
				if (element.pars.NumberOfElements>= 1 and element.pars.NumberOfElements<=tempenum.MaxIndex())
				{
					element.pars.NumberOfElements:=tempenum[element.pars.NumberOfElements]
				}
				tempenum:= ["First", "Last", "Specified"]
				if (element.pars.WhichPosition>= 1 and element.pars.WhichPosition<=tempenum.MaxIndex())
				{
					element.pars.WhichPosition:=tempenum[element.pars.WhichPosition]
				}
			}
			if (element.class="Action_Get_From_List")
			{
				tempenum:= ["First", "Last", "Random", "Specified"]
				if (element.pars.WhichPosition>= 1 and element.pars.WhichPosition<=tempenum.MaxIndex())
				{
					element.pars.WhichPosition:=tempenum[element.pars.WhichPosition]
				}
			}
			if (element.class="Action_Get_Index_Of_Element_In_List")
			{
				tempenum:= ["First", "Last", "Random", "Specified"]
				if (element.pars.WhichPosition>= 1 and element.pars.WhichPosition<=tempenum.MaxIndex())
				{
					element.pars.WhichPosition:=tempenum[element.pars.WhichPosition]
				}
			}
			if (element.class="Action_Enbale_Flow")
			{
				tempenum:= ["Any", "Default", "Specific"]
				if (element.pars.WhichTrigger>= 1 and element.pars.WhichTrigger<=tempenum.MaxIndex())
				{
					element.pars.WhichTrigger:=tempenum[element.pars.WhichTrigger]
				}
				tempenum:= ["Enable", "Disable"]
				if (element.pars.Enable>= 1 and element.pars.Enable<=tempenum.MaxIndex())
				{
					element.pars.Enable:=tempenum[element.pars.Enable]
				}
			}
			if (element.class="Condition_Flow_Enabled")
			{
				tempenum:= ["Any", "Default", "Specific"]
				if (element.pars.WhichTrigger>= 1 and element.pars.WhichTrigger<=tempenum.MaxIndex())
				{
					element.pars.WhichTrigger:=tempenum[element.pars.WhichTrigger]
				}
			}
			if (element.class="Action_Sleep")
			{
				tempenum:= ["Milliseconds", "Seconds", "Minutes"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
			}
			if (element.class="Action_Tooltip")
			{
				tempenum:= ["Milliseconds", "Seconds", "Minutes"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
			}
			if (element.class="Trigger_Hotkey")
			{
				tempenum:= ["Everywhere", "WindowIsActive", "WindowExists"]
				if (element.pars.UseWindow>= 1 and element.pars.UseWindow<=tempenum.MaxIndex())
				{
					element.pars.UseWindow:=tempenum[element.pars.UseWindow]
				}
			}
			if (element.class="Action_Delete_From_Ini")
			{
				tempenum:= ["DeleteKey", "DeleteSection"]
				if (element.pars.Action>= 1 and element.pars.Action<=tempenum.MaxIndex())
				{
					element.pars.Action:=tempenum[element.pars.Action]
				}
			}
			if (element.class="Action_Delete_From_List")
			{
				if not (element.pars.WhichPosition)
					element.pars.WhichPosition:=RIni_GetKeyValue("IniFile", p_section, "WhitchPosition", 2) 
				tempenum:= ["DeleteKey", "DeleteSection"]
				if (element.pars.WhichPosition>= 1 and element.pars.WhichPosition<=tempenum.MaxIndex())
				{
					element.pars.WhichPosition:=tempenum[element.pars.WhichPosition]
				}
			}
			if (element.class="Action_Eject_Drive")
			{
				tempenum:= ["ejectDrive", "RetractTray"]
				if (element.pars.WhatDo>= 1 and element.pars.WhatDo<=tempenum.MaxIndex())
				{
					element.pars.WhatDo:=tempenum[element.pars.WhatDo]
				}
				tempenum:= ["LibraryEjectByScan", "DeviceIoControl", "builtIn"]
				if (element.pars.Method>= 1 and element.pars.Method<=tempenum.MaxIndex())
				{
					element.pars.Method:=tempenum[element.pars.Method]
				}
			}
			if (element.class="Action_Empty_Recycle_Bin")
			{
				tempenum:= ["All", "Specified"]
				if (element.pars.AllDrives>= 1 and element.pars.AllDrives<=tempenum.MaxIndex())
				{
					element.pars.AllDrives:=tempenum[element.pars.AllDrives]
				}
				element.DriveLetter:=RIni_GetKeyValue("IniFile", p_section, "drive", "") 
			}
			if (element.class="Action_Get_Drive_Information")
			{
				tempenum:= ["Label", "Type", "Status", "StatusCD", "Capacity", "FreeSpace", "FileSystem", "Serial"]
				if (element.pars.WhichInformation>= 1 and element.pars.WhichInformation<=tempenum.MaxIndex())
				{
					element.pars.WhichInformation:=tempenum[element.pars.WhichInformation]
				}
			}
			if (element.class="Action_Get_File_Size")
			{
				tempenum:= ["Bytes", "Kilobytes", "Megabytes"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
			}
			if (element.class="Action_Get_Control_Text")
			{
				tempenum:= ["Text", "Class", "ID"]
				if (element.pars.IdentifyControlBy>= 1 and element.pars.IdentifyControlBy<=tempenum.MaxIndex())
				{
					element.pars.IdentifyControlBy:=tempenum[element.pars.IdentifyControlBy]
				}
			}
			if (element.class="Action_Get_File_Time")
			{
				tempenum:= ["Modification", "Creation", "Access"]
				if (element.pars.TimeType>= 1 and element.pars.TimeType<=tempenum.MaxIndex())
				{
					element.pars.TimeType:=tempenum[element.pars.TimeType]
				}
			}
			if (element.class="Action_Get_File_Time")
			{
				tempenum:= ["One", "Multiple"]
				if (element.pars.NumberOfElements>= 1 and element.pars.NumberOfElements<=tempenum.MaxIndex())
				{
					element.pars.NumberOfElements:=tempenum[element.pars.NumberOfElements]
				}
			}
			if (element.class="Action_Get_mouse_position" )
			{
				tempenum:= ["Screen", "Window", "Client"]
				if (element.pars.CoordMode>= 1 and element.pars.CoordMode<=tempenum.MaxIndex())
				{
					element.pars.CoordMode:=tempenum[element.pars.CoordMode]
				}
			}
			if (element.class="Action_Get_pixel_color")
			{
				tempenum:= ["Screen", "Window", "Client"]
				if (element.pars.CoordMode>= 1 and element.pars.CoordMode<=tempenum.MaxIndex())
				{
					element.pars.CoordMode:=tempenum[element.pars.CoordMode]
				}
				tempenum:= ["Default", "Alt", "Slow"]
				if (element.pars.Method>= 1 and element.pars.Method<=tempenum.MaxIndex())
				{
					element.pars.Method:=tempenum[element.pars.Method]
				}
				if (not element.pars.Xpos)
					element.pars.Xpos:=RIni_GetKeyValue("IniFile", p_section, "CoordinateX", 10) 
				if (not element.pars.Ypos)
					element.pars.Ypos:=RIni_GetKeyValue("IniFile", p_section, "CoordinateY", 20) 
			}
			if (element.class="Action_HTTP_Request")
			{
				tempenum:= ["automatic", "custom"]
				if (element.pars.WhichContentType>= 1 and element.pars.WhichContentType<=tempenum.MaxIndex())
				{
					element.pars.WhichContentType:=tempenum[element.pars.WhichContentType]
				}
				if (element.pars.WhichContentLength>= 1 and element.pars.WhichContentLength<=tempenum.MaxIndex())
				{
					element.pars.WhichContentLength:=tempenum[element.pars.WhichContentLength]
				}
				if (element.pars.WhichMethod>= 1 and element.pars.WhichMethod<=tempenum.MaxIndex())
				{
					element.pars.WhichMethod:=tempenum[element.pars.WhichMethod]
				}
				if (element.pars.WhichUserAgent>= 1 and element.pars.WhichUserAgent<=tempenum.MaxIndex())
				{
					element.pars.WhichUserAgent:=tempenum[element.pars.WhichUserAgent]
				}
				tempenum:= ["none", "automatic", "custom"]
				if (element.pars.WhichContentMD5>= 1 and element.pars.WhichContentMD5<=tempenum.MaxIndex())
				{
					element.pars.WhichContentMD5:=tempenum[element.pars.WhichContentMD5]
				}
				if (element.pars.WhichProxy>= 1 and element.pars.WhichProxy<=tempenum.MaxIndex())
				{
					element.pars.WhichProxy:=tempenum[element.pars.WhichProxy]
				}
				tempenum:= ["Variable", "File"]
				if (element.pars.WhereToPutResponseData>= 1 and element.pars.WhereToPutResponseData<=tempenum.MaxIndex())
				{
					element.pars.WhereToPutResponseData:=tempenum[element.pars.WhereToPutResponseData]
				}
				tempenum:= ["utf-8", "definedCharset", "definedCodepage"]
				if (element.pars.WhichCodepage>= 1 and element.pars.WhichCodepage<=tempenum.MaxIndex())
				{
					element.pars.WhichCodepage:=tempenum[element.pars.WhichCodepage]
				}
				tempenum:= ["NoUpload", "Specified", "File"]
				if (element.pars.WhereToGetPostData>= 1 and element.pars.WhereToGetPostData<=tempenum.MaxIndex())
				{
					element.pars.WhereToGetPostData:=tempenum[element.pars.WhereToGetPostData]
				}
			}
			if (element.class="Action_Input_Box")
			{
				tempenum:= ["NoTimeout", "Timeout"]
				if (element.pars.IsTimeout>= 1 and element.pars.IsTimeout<=tempenum.MaxIndex())
				{
					element.pars.IsTimeout:=tempenum[element.pars.IsTimeout]
				}
				tempenum:= ["Seconds", "Minutes", "Hours"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
				tempenum:= ["Normal", "Exception"]
				if (element.pars.OnTimeout>= 1 and element.pars.OnTimeout<=tempenum.MaxIndex())
				{
					element.pars.OnTimeout:=tempenum[element.pars.OnTimeout]
				}
				if (element.pars.IfDismiss>= 1 and element.pars.IfDismiss<=tempenum.MaxIndex())
				{
					element.pars.IfDismiss:=tempenum[element.pars.IfDismiss]
				}
			}
			if (element.class="Action_Message_Box")
			{
				tempenum:= ["NoTimeout", "Timeout"]
				if (element.pars.IsTimeout>= 1 and element.pars.IsTimeout<=tempenum.MaxIndex())
				{
					element.pars.IsTimeout:=tempenum[element.pars.IsTimeout]
				}
				tempenum:= ["Seconds", "Minutes", "Hours"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
				tempenum:= ["Normal", "Exception"]
				if (element.pars.OnTimeout>= 1 and element.pars.OnTimeout<=tempenum.MaxIndex())
				{
					element.pars.OnTimeout:=tempenum[element.pars.OnTimeout]
				}
				if (element.pars.IfDismiss>= 1 and element.pars.IfDismiss<=tempenum.MaxIndex())
				{
					element.pars.IfDismiss:=tempenum[element.pars.IfDismiss]
				}
			}
			if (element.class="Action_List_Drives")
			{
				tempenum:= ["Normal", "Exception"]
				if (element.pars.IfNothingFound>= 1 and element.pars.IfNothingFound<=tempenum.MaxIndex())
				{
					element.pars.IfNothingFound:=tempenum[element.pars.IfNothingFound]
				}
				tempenum:= ["list", "string"]
				if (element.pars.OutputType>= 1 and element.pars.OutputType<=tempenum.MaxIndex())
				{
					element.pars.OutputType:=tempenum[element.pars.OutputType]
				}
				tempenum:= ["all", "filter"]
				if (element.pars.WhetherDriveTypeFilter>= 1 and element.pars.WhetherDriveTypeFilter<=tempenum.MaxIndex())
				{
					element.pars.WhetherDriveTypeFilter:=tempenum[element.pars.WhetherDriveTypeFilter]
				}
			}
			if (element.class="Action_Minimize_All_Windows")
			{
				tempenum:= ["Minimize", "Undo"]
				if (element.pars.WinMinimizeAllEvent>= 1 and element.pars.WinMinimizeAllEvent<=tempenum.MaxIndex())
				{
					element.pars.WinMinimizeAllEvent:=tempenum[element.pars.WinMinimizeAllEvent]
				}
			}
			if (element.class="Action_New_Date")
			{
				tempenum:= ["Current", "Specified"]
				if (element.pars.WhichDate>= 1 and element.pars.WhichDate<=tempenum.MaxIndex())
				{
					element.pars.WhichDate:=tempenum[element.pars.WhichDate]
				}
			}
			if (element.class="Action_Play_Sound")
			{
				tempenum:= ["SystemSound", "SoundFile"]
				if (element.pars.WhichSound>= 1 and element.pars.WhichSound<=tempenum.MaxIndex())
				{
					element.pars.WhichSound:=tempenum[element.pars.WhichSound]
				}
			}
			if (element.class="Action_Read_From_File")
			{
				tempenum:= ["ANSI", "UTF-8", "UTF-16"]
				if (element.pars.Encoding>= 1 and element.pars.Encoding<=tempenum.MaxIndex())
				{
					element.pars.Encoding:=tempenum[element.pars.Encoding]
				}
			}
			if (element.class="Action_Write_To_File")
			{
				tempenum:= ["ANSI", "UTF-8", "UTF-16"]
				if (element.pars.Encoding>= 1 and element.pars.Encoding<=tempenum.MaxIndex())
				{
					element.pars.Encoding:=tempenum[element.pars.Encoding]
				}
				tempenum:= ["Append", "Overwrite"]
				if (element.pars.Overwrite>= 1 and element.pars.Overwrite<=tempenum.MaxIndex())
				{
					element.pars.Overwrite:=tempenum[element.pars.Overwrite]
				}
			}
			if (element.class="Action_Read_From_Ini")
			{
				tempenum:= ["Key", "EntireSection", "SectionNames"]
				if (element.pars.Action>= 1 and element.pars.Action<=tempenum.MaxIndex())
				{
					element.pars.Action:=tempenum[element.pars.Action]
				}
				tempenum:= ["Default", "Exception"]
				if (element.pars.WhenError>= 1 and element.pars.WhenError<=tempenum.MaxIndex())
				{
					element.pars.WhenError:=tempenum[element.pars.WhenError]
				}
			}
			if (element.class="Action_Screenshot")
			{
				tempenum:= ["Screen", "Region", "Window"]
				if (element.pars.WhichRegion>= 1 and element.pars.WhichRegion<=tempenum.MaxIndex())
				{
					element.pars.WhichRegion:=tempenum[element.pars.WhichRegion]
				}
				tempenum:= ["Gdip_FromScreen", "Gdip_FromHWND", "Gdip_FromScreenCoordinates"]
				if (element.pars.Method>= 1 and element.pars.Method<=tempenum.MaxIndex())
				{
					element.pars.Method:=tempenum[element.pars.Method]
				}
			}
			if (element.class="Action_Search_Image")
			{
				tempenum:= ["Screen", "Window", "Client"]
				if (element.pars.CoordMode>= 1 and element.pars.CoordMode<=tempenum.MaxIndex())
				{
					element.pars.CoordMode:=tempenum[element.pars.CoordMode]
				}
				tempenum:= ["widthManually", "heightManually"]
				if (element.pars.WhichSizeSet>= 1 and element.pars.WhichSizeSet<=tempenum.MaxIndex())
				{
					element.pars.WhichSizeSet:=tempenum[element.pars.WhichSizeSet]
				}
			}
			if (element.class="Action_Search_In_A_String")
			{
				tempenum:= ["FromLeft", "FromRight"]
				if (element.pars.LeftOrRight>= 1 and element.pars.LeftOrRight<=tempenum.MaxIndex())
				{
					element.pars.LeftOrRight:=tempenum[element.pars.LeftOrRight]
				}
				tempenum:= ["CaseInsensitive", "CaseSensitive"]
				if (element.pars.CaseSensitive>= 1 and element.pars.CaseSensitive<=tempenum.MaxIndex())
				{
					element.pars.CaseSensitive:=tempenum[element.pars.CaseSensitive]
				}
			}
			if (element.class="Action_Send_Keystrokes")
			{
				tempenum:= ["Input", "Event", "Play"]
				if (element.pars.SendMode>= 1 and element.pars.SendMode<=tempenum.MaxIndex())
				{
					element.pars.SendMode:=tempenum[element.pars.SendMode]
				}
			}
			if (element.class="Action_Set_file_attributes")
			{
				tempenum:= ["Files", "FilesAndFolders", "Folders"]
				if (element.pars.OperateOnWhat>= 1 and element.pars.OperateOnWhat<=tempenum.MaxIndex())
				{
					element.pars.OperateOnWhat:=tempenum[element.pars.OperateOnWhat]
				}
			}
			if (element.class="Action_Set_file_time")
			{
				tempenum:= ["Files", "FilesAndFolders", "Folders"]
				if (element.pars.OperateOnWhat>= 1 and element.pars.OperateOnWhat<=tempenum.MaxIndex())
				{
					element.pars.OperateOnWhat:=tempenum[element.pars.OperateOnWhat]
				}
				tempenum:= ["Modification", "Creation", "Access"]
				if (element.pars.TimeType>= 1 and element.pars.TimeType<=tempenum.MaxIndex())
				{
					element.pars.TimeType:=tempenum[element.pars.TimeType]
				}
			}
			if (element.class="Action_Set_Lock_Key")
			{
				tempenum:= ["CapsLock", "NumLock", "ScrollLock"]
				if (element.pars.WhichKey>= 1 and element.pars.WhichKey<=tempenum.MaxIndex())
				{
					element.pars.WhichKey:=tempenum[element.pars.WhichKey]
				}
				tempenum:= ["On", "Off", "Toggle", "AlwaysOn", "AlwaysOff"]
				if (element.pars.Status>= 1 and element.pars.Status<=tempenum.MaxIndex())
				{
					element.pars.Status:=tempenum[element.pars.Status]
				}
			}
			if (element.class="Action_Set_Process_Priority")
			{
				tempenum:= ["Low", "BelowNormal", "Normal", "AboveNormal", "High", "Realtime"]
				if (element.pars.Priority>= 1 and element.pars.Priority<=tempenum.MaxIndex())
				{
					element.pars.Priority:=tempenum[element.pars.Priority]
				}
			}
			if (element.class="Action_Set_Process_Priority")
			{
				tempenum:= ["Mute", "Absolute", "Relative"]
				if (element.pars.Action>= 1 and element.pars.Action<=tempenum.MaxIndex())
				{
					element.pars.Action:=tempenum[element.pars.Action]
				}
				tempenum:= ["On", "Off", "Toggle"]
				if (element.pars.Mute>= 1 and element.pars.Mute<=tempenum.MaxIndex())
				{
					element.pars.Mute:=tempenum[element.pars.Mute]
				}
			}
			if (element.class="Action_Substring")
			{
				tempenum:= ["FromLeft", "FromRight", "Position"]
				if (element.pars.WhereToBegin>= 1 and element.pars.WhereToBegin<=tempenum.MaxIndex())
				{
					element.pars.WhereToBegin:=tempenum[element.pars.WhereToBegin]
				}
				tempenum:= ["GoLeft", "GoRight"]
				if (element.pars.LeftOrRight>= 1 and element.pars.LeftOrRight<=tempenum.MaxIndex())
				{
					element.pars.LeftOrRight:=tempenum[element.pars.LeftOrRight]
				}
			}
			if (element.class="Action_Trigonometry")
			{
				tempenum:= ["Sine", "Cosine", "Tangent", "Arcsine", "Arccosine", "Arctangent"]
				if (element.pars.Operation>= 1 and element.pars.Operation<=tempenum.MaxIndex())
				{
					element.pars.Operation:=tempenum[element.pars.Operation]
				}
				tempenum:= ["Radian", "Degree"]
				if (element.pars.Unit>= 1 and element.pars.Unit<=tempenum.MaxIndex())
				{
					element.pars.Unit:=tempenum[element.pars.Unit]
				}
			}
			if (element.class="Action_Trim_a_string")
			{
				tempenum:= ["Number", "Specified"]
				if (element.pars.TrimWhat>= 1 and element.pars.TrimWhat<=tempenum.MaxIndex())
				{
					element.pars.TrimWhat:=tempenum[element.pars.TrimWhat]
				}
				tempenum:= ["SpacesAndTabs", "Specified"]
				if (element.pars.SpacesAndTabs>= 1 and element.pars.SpacesAndTabs<=tempenum.MaxIndex())
				{
					element.pars.SpacesAndTabs:=tempenum[element.pars.SpacesAndTabs]
				}
			}
			if (element.class="Condition_File_Has_Attribute")
			{
				tempenum:= ["N", "R", "A", "S", "H", "D", "O", "C", "T"]
				if (element.pars.Attribute>= 1 and element.pars.Attribute<=tempenum.MaxIndex())
				{
					element.pars.Attribute:=tempenum[element.pars.Attribute]
				}
			}
			if (element.class="Condition_List_Contains_Element")
			{
				tempenum:= ["Key", "Content"]
				if (element.pars.SearchWhat>= 1 and element.pars.SearchWhat<=tempenum.MaxIndex())
				{
					element.pars.SearchWhat:=tempenum[element.pars.SearchWhat]
				}
			}
			if (element.class="Condition_String_Contains_Text")
			{
				tempenum:= ["Start", "End", "Anywhere"]
				if (element.pars.WhereToBegin>= 1 and element.pars.WhereToBegin<=tempenum.MaxIndex())
				{
					element.pars.WhereToBegin:=tempenum[element.pars.WhereToBegin]
				}
				tempenum:= ["CaseInsensitive", "CaseSensitive"]
				if (element.pars.CaseSensitive>= 1 and element.pars.CaseSensitive<=tempenum.MaxIndex())
				{
					element.pars.CaseSensitive:=tempenum[element.pars.CaseSensitive]
				}
			}
			if (element.class="Loop_Loop_Through_Files")
			{
				tempenum:= ["Files", "FilesAndFolders", "Folders"]
				if (element.pars.OperateOnWhat>= 1 and element.pars.OperateOnWhat<=tempenum.MaxIndex())
				{
					element.pars.OperateOnWhat:=tempenum[element.pars.OperateOnWhat]
				}
			}
		}
		IfInString, p_ElementID ,element
			_setElement(p_FlowID, p_ElementID, element)
		else IfInString,tempSection,connection
			_setConnection(p_FlowID, p_ElementID, element)
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}


LoadFlowCheckCompabilityFlow(p_FlowID, p_FlowCompabilityVersion)
{
	
}