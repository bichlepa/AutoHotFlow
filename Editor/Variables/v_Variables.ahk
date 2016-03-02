


class variable
{
	static AllBuiltInVars:="-A_Space-A_Tab-A_YYYY-A_Year-A_MM-A_Mon-A_DD-A_MDay-A_MMMM-A_MMM-A_DDDD-A_DDD-A_WDay-A_YDay-A_Hour-A_Min-A_Sec-A_MSec-A_TickCount-A_TimeIdle-A_TimeIdlePhysical-A_Temp-A_OSVersion-A_Is64bitOS-A_PtrSize-A_Language-A_ComputerName-A_UserName-A_ScriptDir-A_WinDir-A_ProgramFiles-A_AppData-A_AppDataCommon-A_Desktop-A_DesktopCommon-A_StartMenu-A_StartMenuCommon-A_Programs-A_ProgramsCommon-A_Startup-A_StartupCommon-A_MyDocuments-A_IsAdmin-A_ScreenWidth-A_ScreenHeight-A_ScreenDPI-A_IPAddress1-A_IPAddress2-A_IPAddress3-A_IPAddress4-A_Cursor-A_CaretX-A_CaretY-----" ;a_now and a_nowutc not included, they will be treated specially

	
	retrieveDestination(varName,type,location)
	{
		;Check whether the variable name is valid
		res:=this.nameIsValid(varName,true)
		if (res="empty")
		{
			logger("f0","Setting a variable failed. Its name is empty.")
			return 0
		}
		else if (res="ForbiddenCharacter")
		{
			logger("f0","Setting variable '" name "' failed. It contains forbidden characters.")
			return 0
		}
		
		
		if (substr(varName,1,2)="A_") ;If variable name begins with A_
		{
			if (location!="Thread" and location!="loop")
			{
				logger("f0","Setting built in variable '" name "' failed. No permission given.")
				return 0
			}
			else ;The variable is either a thread variable or a loop variable
				return "thread"
		}
		else if (location="Thread" or location="loop")
		{
			logger("f0","Setting built in variable '" name "' failed. It does not start with 'A_'.")
			return 0
			
		}
		else if (substr(name,1,7)="global_")  ;If variable is global
		{
			return "global"
		}
		else if (substr(name,1,7)="static_") ;If variable is static
		{
			return "static"
		}
		else
		{
			return "local"
		}
	}
	
	set(thread,varName,value,type="normal",location="") ;Set a variable
	{
		destination:=variable.retrieveDestination(varName,type,location)
		;~ MsgBox +++ %destination%
		if destination=thread
		{
			thread.vars[varName]:=new this.threadVariable(varName,value,type)
			;~ MsgBox % "üüü" strobj(thread.vars)
		}
		if destination=loop
		{
			thread.loopvars[varName]:=new this.loopVariable(varName,value,type)
			;~ MsgBox % "üüü" strobj(this.vars)
		}
		if destination=local
		{
			thread.instance.vars[varName]:=new this.localVariable(varName,value,type)
		}
		
	}
	
	get(p_thread,name,ContentType="AsIs") 
	{
		;~ MsgBox ghiohiodfähiodfjklnsdklfjnoöuifb %name%
		if (name="")
		{
			logger("f0","Retrieving variable failed. The name is empty")
		}
		else if (substr(name,1,2)="A_") ; if variable is a built in variable or a thread variable
		{
			;~ MsgBox asfh  %name%
			if (p_thread.vars.HasKey(name)) ;Try to find a thread variable
			{
				logger("f3","Retrieving thread variable '" name "'")
				tempvalue:=p_thread.vars[name].value
				;~ MsgBox ag e %tempvalue%
				return tempvalue
			}
			else if (p_thread.loopvars.HasKey(name)) ;Try to find a loop variable
			{
				logger("f3","Retrieving loop variable '" name "'")
				tempvalue:=p_thread.loopvars[name].value
				return tempvalue
			}
			;If no thread and loop variable found, try to find a built in variable
			else if (name="a_now" || name="A_NowUTC")
			{
				
				if (VariableType="Normal")
				{
					tempvalue:=this.convertVariable(name,"date")
					
					return tempvalue
				}
				else
				{
					tempvalue:=%name%
					;~ MsgBox %tempvalue%
					return tempvalue
				}
			}
			else if (name="A_YWeek") ;Separate the week.
			{
				StringRight,tempvalue,A_YWeek,2
				return tempvalue
			}
			else if (name="A_LanguageName") 
			{
				tempvalue:= ;GetLanguageNameFromCode(A_Language) ;;TODO: Uncomment
				
				return tempvalue
			}
			else if (name="a_workingdir")
			{
				tempvalue:=flowSettings.WorkingDir
				return tempvalue
			}
			;~ else if (name="a_triggertime")
			;~ {
				;~ tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
				;~ if VariableType=Normal
					;~ return this.convertVariable(tempvalue,"date","`n") 
				;~ else
				;~ {
					;~ return tempvalue
				;~ }
			;~ }
			else if (name="a_linefeed" or name="a_lf")
			{
				return "`n"
			}
			;~ else if (name="a_CPULoad")
			;~ {
				;~ return CPULoad()
			;~ }
			;~ else if (name="a_MemoryUsage")
			;~ {
				;~ return MemoryLoad()
			;~ }
			;~ else if (name="a_OSInstallDate")
			;~ {
				;~ if VariableType=Normal
					;~ return convertVariable(OSInstallDate(),"date","`n") 
				;~ else
				;~ {
					;~ return OSInstallDate()
				;~ }
			;~ }
			else If InStr(this.AllBuiltInVars,"-" name "-")
			{
				tempvalue:=%name%
				return tempvalue
			}
			else
			{
				logger("f0","Retrieving variable '" name "' failed. It does not exist")
			}
				
				
		}
		else ;If this is a local variable
		{
			;~ d(p_thread.instance.vars,name)
			if (p_thread.instance.vars.HasKey(name)) ;Try to find a local variable
			{
				logger("f3","Retrieving local variable '" name "'")
				tempvalue:=p_thread.instance.vars[name].value
				;~ MsgBox ag e %tempvalue% - %name%
				return tempvalue
			}
			else
			{
				logger("f0","Retrieving local variable '" name "' failed. It does not exist")
			}
		}
		
		
	}
	
	class threadVariable
	{
		static type:="thread"
		__New(name,value,type){
			;~ MsgBox asdge
			this.name:=name
			this.value:=value
			this.type:=type
		}
		
	}
	class loopVariable
	{
		static type:="loop"
		__New(name,value,type){
			this.name:=name
			this.value:=value
			this.type:=type
		}
		
	}

	class localVariable
	{
		static type:="local"
		__New(name,value,type){
			this.name:=name
			this.value:=value
			this.type:=type
		}
		
	}

	class staticVariable
	{
		static type:="static"
		__New(){
			
		}
		
	}

	class globalVariable
	{
		static type:="global"
		__New(){
			
		}
		
	}
	
	;Convert variable content to string.
	convertVariable(content,type,delimiters="▬")
	{
		local tempName
		local tempvalue
		if type=date
		{
			FormatTime,content,% content
		}
		if type=list
		{
			if IsObject(content)
			{
				for tempName, tempvalue in content
				{
					
					if a_index!=1
						content.=delimiters tempvalue
					else
						content:=tempvalue
					
				}
			}
			else
				MsgBox Internal Error. A list should be exported but it is not an object
		}
		return content
	}
	
	
	nameIsValid(varName, tellWhy=false) ;Return 1 if valid. 0 if not
	{
		;Check whether the variable name is not empty
		if varName=
		{
			logger("f0","Setting a variable failed. Its name is empty.")
			if tellWhy
				return "Empty"
			else
				return 0
		}
		;Check whether the variable name is valid and has no prohibited characters
		try
			asdf%varName%:=1 
		catch
		{
			logger("f0","Setting variable '" name "' failed. Name is invalid.")
			if tellWhy
				return "ForbiddenCharacter"
			else
				return 0
		}
		if tellWhy
			return "OK"
		else
			return 1
	}
	
	replaceVariables(p_thread,p_String,p_variableType="asis")
	{
		;~ MsgBox sergr %p_String%
		tempstring:=p_String
		Loop
		{
			tempFoundPos:=RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
			if tempFoundPos=0
				break
			StringReplace,tempstring,tempstring,`%%tempFoundVarName1%`%,% this.get(p_thread,tempFoundVarName1,p_variableType)
			;~ MsgBox % "reerhes#-" tempstring "-#-" tempFoundVarName1 "-#-" this.get(p_thread,tempFoundVarName1,p_variableType)
			;~ MsgBox %tempVariablesToReplace1%
		}
		return tempstring 
	}
	
	evaluateExpression(p_thread,p_String)
	{
		this.replaceVariables(p_Thread,p_String)
		return v_EvaluateExpression(this,p_Thread,p_String)
	}
}


