FlowCompabilityVersionOfApp:=6 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.

i_CheckCompability(Element,tempsection)
{
	global
	
	local temp
	
	if FlowCompabilityVersion<1 ; 2015,06
	{
		
		logger("a2","Flow has elder format than version 1. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Date_Calculation") 
		{
			
			Element.Unit+=1 ;Added option milliseconds
			Element.VarValue:=Element.Varname ;Output and input variable separated
			Element.Operation:=1 ;Added option calculate time difference 
			
			
		}
	}
	if FlowCompabilityVersion<2 ; 2015,06
	{
		logger("a2","Flow has elder format than version 2. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Get_control_text") 
		{
			
			Element.Varname:="t_Text" ;The variable name can now be specified
			
		}
		
		if (Element.type="action" and Element.subtype="Get_mouse_position") 
		{
			
			Element.Varnamey:="t_posx" ;The variable name can now be specified
			Element.Varnamex:="t_posx" ;The variable name can now be specified
		}
		if (Element.type="action" and Element.subtype="Get_Volume") 
		{
			
			Element.Varname:="t_volume" ;The variable name can now be specified
		}
		if (Element.type="action" and Element.subtype="Input_box") 
		{
			
			Element.Varname:="t_input" ;The variable name can now be specified
		}
		if (Element.type="action" and Element.subtype="Set_Volume") 
		{
			if (Element.Relatively) ;This option was deleted, a new option Action can be set between three states instead
				Element.Action:=3
			else
				Element.Action:=2
		}
		if (Element.type="action" and Element.subtype="Sleep") 
		{
			
			Element.Unit:=1 ;The unit is only milliseconds
		}
		if (Element.type="action" and Element.subtype="tooltip") 
		{
			
			Element.Unit:=1 ;The unit is only milliseconds
		}
		
		if (Element.type="condition" and Element.subtype="file_exists" and Element.CompatibilityComment="WasFolderExists") 
		{
			loadElement.file:=RIni_GetKeyValue("IniFile", tempSection, "folder", "") ;Conditions FolderExists and FileExists were combined to FileExists
		}
		if (Element.type="trigger" and Element.subtype="Periodic_timer") 
		{
			
			Element.Unit:=2 ;The only unit was seconds
		}
		
	}
	
	if FlowCompabilityVersion<3 ; 2015,08,09
	{
		logger("a2","Flow has elder format than version 3. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Read_from_ini") 
		{
			if (Element.Action=2)
			Element.Action:=3
		}
		
	}
	if FlowCompabilityVersion<4 ; 2015,08,15
	{
		logger("a2","Flow has elder format than version 4. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Set_Clipboard") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "varname", "") 
			if temp
			{
				Element.text:=temp
				Element.expression:=2
				
			}
		}
		
	}
	if FlowCompabilityVersion<5 ; 2015,08,28
	{
		logger("a2","Flow has elder format than version 5. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Play_Sound") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "WhitchSound", "") 
			if temp
			{
				if temp<6
				{
					Element.WhichSound:=1
					
					if temp=2
						Element.systemSound:="Windows Foreground.wav"
					else
						Element.systemSound:="Windows Background.wav"
				}
				else if temp=6
					Element.WhichSound:=2
				
			}
		}
		
	}
	if FlowCompabilityVersion<6 ; 2015,09,01
	{
		logger("a2","Flow has elder format than version 6. Tryting to keep compability.")
		if (Element.type="action" and Element.subtype="Input_Box") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "text", "") 
			Element.message:=temp
			Element.IsTimeout:=0
			Element.OnlyNumbers:=0 
			Element.MaskUserInput:=0 
			Element.MultilineEdit:=0 
			Element.ShowCancelButton:=0 
			Element.IfDismiss:=2 ;Exception if dismiss
			
		}
		if (Element.type="condition" and Element.subtype="Confirmation_Dialog") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "question", "") 
			Element.message:=temp
			Element.IsTimeout:=0
			Element.ShowCancelButton:=0 
			Element.IfDismiss:=3 ;Exception if dismiss
			
		}
		if (Element.type="action" and Element.subtype="Message_Box") 
		{
			temp:=RIni_GetKeyValue("IniFile", tempSection, "text", "") 
			Element.message:=temp
			Element.IsTimeout:=0
			Element.IfDismiss:=2 ;Exception if dismiss
			
		}
		
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}



i_CheckCompabilitySubtype(Element,Section)
{
	global
	if FlowCompabilityVersion<2 ; 2015,06
	{
		if (Element.type="condition" and Element.subtype="folder_exists") 
		{
			
			ElementID.subtype:="file_exists" ;File exists became File or folder exists, because they are the same.
			ElementID.CompatibilityComment:="WasFolderExists" ;File exists became File or folder exists, because they are the same.
		}
	}
	
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
	
}