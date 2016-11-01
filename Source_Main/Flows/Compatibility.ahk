FlowCompabilityVersionOfApp:=7 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.

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
			temp:=RIni_GetKeyValue("IniFile", tempSection, "varname", "") 
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
			temp:=RIni_GetKeyValue("IniFile", tempSection, "WhitchSound", "") 
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
			temp:=RIni_GetKeyValue("IniFile", tempSection, "text", "") 
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
			temp:=RIni_GetKeyValue("IniFile", tempSection, "question", "") 
			p_List[p_ElementID].pars.message:=temp
			p_List[p_ElementID].pars.IsTimeout:=0
			p_List[p_ElementID].pars.ShowCancelButton:=0 
			p_List[p_ElementID].pars.IfDismiss:=3 ;Exception if dismiss
			
		}
		if (p_List[p_ElementID].type="action" and p_List[p_ElementID].subtype="Message_Box") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "text", "") 
			p_List[p_ElementID].pars.message:=temp
			p_List[p_ElementID].pars.IsTimeout:=0
			p_List[p_ElementID].pars.IfDismiss:=2 ;Exception if dismiss
			
		}
		
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}



LoadFlowCheckCompabilitySubtype(p_List,p_ElementID,p_section)
{
	global
	if FlowCompabilityVersion<2 ; 2015,06
	{
		if (p_List[p_ElementID].type="condition" and p_List[p_ElementID].subtype="folder_exists") 
		{
			
			p_List[p_ElementID].subtype:="file_exists" ;File exists became File or folder exists, because they are the same.
			p_List[p_ElementID].CompatibilityComment:="WasFolderExists" ;File exists became File or folder exists, because they are the same.
		}
	}
	
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
	
}