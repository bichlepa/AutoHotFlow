FlowCompabilityVersionOfApp:=2 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.

i_CheckCompability(ElementID,IndexInIniFile,IniFilePath)
{
	global
	
	local temp
	
	if FlowCompabilityVersion<1 ; 2015,06
	{
		
		logger("a2","Flow has elder format than version 1. Tryting to keep compability.")
		if (%ElementID%type="action" and %ElementID%subtype="Date_Calculation") 
		{
			
			%ElementID%Unit+=1 ;Added option milliseconds
			%ElementID%VarValue:=%ElementID%Varname ;Output and input variable separated
			%ElementID%Operation:=1 ;Added option calculate time difference 
			
			
		}
	}
	if FlowCompabilityVersion<2 ; 2015,06
	{
		logger("a2","Flow has elder format than version 2. Tryting to keep compability.")
		if (%ElementID%type="action" and %ElementID%subtype="Get_control_text") 
		{
			
			%ElementID%Varname=t_Text ;The variable name can now be specified
			
		}
		
		if (%ElementID%type="action" and %ElementID%subtype="Get_mouse_position") 
		{
			
			%ElementID%Varnamey=t_posx ;The variable name can now be specified
			%ElementID%Varnamex=t_posx ;The variable name can now be specified
		}
		if (%ElementID%type="action" and %ElementID%subtype="Get_Volume") 
		{
			
			%ElementID%Varname=t_volume ;The variable name can now be specified
		}
		if (%ElementID%type="action" and %ElementID%subtype="Input_box") 
		{
			
			%ElementID%Varname=t_input ;The variable name can now be specified
		}
		if (%ElementID%type="action" and %ElementID%subtype="Set_Volume") 
		{
			if %ElementID%Relatively ;This option was deleted, a new option Action can be set between three states instead
				%ElementID%Action=3
			else
				%ElementID%Action=2
		}
		if (%ElementID%type="action" and %ElementID%subtype="Sleep") 
		{
			
			%ElementID%Unit=1 ;The unit is only milliseconds
		}
		if (%ElementID%type="action" and %ElementID%subtype="tooltip") 
		{
			
			%ElementID%Unit=1 ;The unit is only milliseconds
		}
		
		if (%ElementID%type="condition" and %ElementID%subtype="file_exists" and %ElementID%CompatibilityComment="WasFolderExists") 
		{
			
			Iniread,temp,%IniFilePath%,%IndexInIniFile%,folder
			%ElementID%file:=temp ;The unit is only milliseconds
		}
		if (%ElementID%type="trigger" and %ElementID%subtype="Periodic_timer") 
		{
			
			%ElementID%Unit=2 ;The only unit was seconds
		}
		
	}
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
}



i_CheckCompabilitySubtype(ElementID,IndexInIniFile,IniFilePath)
{
	global
	if FlowCompabilityVersion<2 ; 2015,06
	{
		if (%ElementID%type="condition" and %ElementID%subtype="folder_exists") 
		{
			
			%ElementID%subtype=file_exists ;File exists became File or folder exists, because they are the same.
			%ElementID%CompatibilityComment=WasFolderExists ;File exists became File or folder exists, because they are the same.
		}
	}
	
	
	if FlowCompabilityVersion<1000000000 ; Only for test cases. On release this should be empty
	{
		
		
		
	}
	
}