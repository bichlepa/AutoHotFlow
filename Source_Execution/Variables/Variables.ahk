AllBuiltInVars:="-A_Space-A_Tab-A_YYYY-A_Year-A_MM-A_Mon-A_DD-A_MDay-A_MMMM-A_MMM-A_DDDD-A_DDD-A_WDay-A_YDay-A_Hour-A_Min-A_Sec-A_MSec-A_TickCount-A_TimeIdle-A_TimeIdlePhysical-A_Temp-A_OSVersion-A_Is64bitOS-A_PtrSize-A_Language-A_ComputerName-A_UserName-A_ScriptDir-A_WinDir-A_ProgramFiles-A_AppData-A_AppDataCommon-A_Desktop-A_DesktopCommon-A_StartMenu-A_StartMenuCommon-A_Programs-A_ProgramsCommon-A_Startup-A_StartupCommon-A_MyDocuments-A_IsAdmin-A_ScreenWidth-A_ScreenHeight-A_ScreenDPI-A_IPAddress1-A_IPAddress2-A_IPAddress3-A_IPAddress4-A_Cursor-A_CaretX-A_CaretY-----" ;a_now and a_nowutc not included, they will be treated specially

LoopVariable_Set(Environment,p_Name,p_Value,p_ContentType="Normal")
{
	Environment.loopvars[p_Name]:={name:p_Name,value:p_Value,type:p_ContentType}
}
ThreadVariable_Set(Environment,p_Name,p_Value,p_ContentType="Normal")
{
	Environment.threadvars[p_Name]:={name:p_Name,value:p_Value,type:p_ContentType}
	
}
InstanceVariable_Set(Environment,p_Name,p_Value,p_ContentType="Normal")
{
	global _execution
	_execution.instances[Environment.InstanceID].InstanceVars[p_Name]:={name:p_Name,value:p_Value,type:p_ContentType}
	
}

StaticVariable_Set(Environment,p_Name,p_Value,p_ContentType="Normal")
{
	;todo
}
GlobalVariable_Set(Environment,p_Name,p_Value,p_ContentType="Normal")
{
	;todo
}


LoopVariable_GetWhole(Environment,p_Name)
{
	return Environment.loopvars[p_Name]
}
ThreadVariable_GetWhole(Environment,p_Name)
{
	return Environment.threadvars[p_Name]
	
}
InstanceVariable_GetWhole(Environment,p_Name)
{
	global _execution
	return _execution.instances[Environment.InstanceID].InstanceVars[p_Name]
	
}

StaticVariable_GetWhole(Environment,p_Name)
{
	;todo
}
GlobalVariable_GetWhole(Environment,p_Name)
{
	;todo
}

BuiltInVariable_GetWhole(Environment,p_Name)
{
	;If no thread and loop variable found, try to find a built in variable
	if (p_Name="a_now" || p_Name="A_NowUTC")
	{
		tempvar:={name: p_Name, value: %p_Name%, type: "Date"}
		return tempvar
	}
	else if (p_Name="A_YWeek") ;Separate the week.
	{
		StringRight,tempvalue,A_YWeek,2
		tempvar:={name: p_Name, value: tempvalue, type: "Normal"}
		return tempvar
	}
	else if (p_Name="A_LanguageName") 
	{
		tempvalue:= ;GetLanguageNameFromCode(A_Language) ;;TODO: Uncomment
		
		return tempvalue
	}
	else if (p_Name="a_workingdir")
	{
		;~ tempvalue:=flowSettings.WorkingDir
		return tempvalue
	}
	;~ else if (name="a_triggertime")
	;~ {
		;~ tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
		;~ if p_Type=Normal
			;~ return this.convertVariable(tempvalue,"date","`n") 
		;~ else
		;~ {
			;~ return tempvalue
		;~ }
	;~ }
	else if (p_Name="a_linefeed" or p_Name="a_lf")
	{
		tempvar:={name: p_Name, value: "`n", type: "Normal"}
		return tempvar
	}
	;~ else if (p_Name="a_CPULoad")
	;~ {
		;~ return CPULoad()
	;~ }
	;~ else if (p_Name="a_MemoryUsage")
	;~ {
		;~ return MemoryLoad()
	;~ }
	;~ else if (p_Name="a_OSInstallDate")
	;~ {
		;~ if p_Type=Normal
			;~ return convertVariable(OSInstallDate(),"date","`n") 
		;~ else
		;~ {
			;~ return OSInstallDate()
		;~ }
	;~ }
	else If InStr(this.AllBuiltInVars,"-" p_Name "-")
	{
		tempvar:={name: p_Name, value: %p_Name%, type: "Normal"}
		return tempvar
	}
	;todo
}

LoopVariable_Delete(Environment,p_Name)
{
	Environment.loopvars.delete(p_Name)
}
ThreadVariable_Delete(Environment,p_Name)
{
	Environment.threadvars.delete(p_Name)
	
}
InstanceVariable_Delete(Environment,p_Name)
{
	global _execution
	_execution.instances[Environment.InstanceID].InstanceVars.delete(p_Name)
	
}

StaticVariable_Delete(Environment,p_Name)
{
	;todo
}
GlobalVariable_Delete(Environment,p_Name)
{
	;todo
}


Var_RetrieveDestination(p_Name,p_Location,p_log=true)
{
	if (substr(p_Name,1,2)="A_") ;If variable name begins with A_
	{
		if (p_Location!="Thread" and p_Location!="loop")
		{
			if (p_log=true or p_log="LOG")
				logger("f0","Setting built in variable '" p_Name "' failed. No permission given.")
			return ;No result
		}
		else ;The variable is either a thread variable or a loop variable
			return p_Location
	}
	else if (p_Location="Thread" or p_Location="loop")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting built in variable '" p_Name "' failed. It does not start with 'A_'.")
		return ;No result
		
	}
	else if (substr(p_Name,1,7)="global_")  ;If variable is global
	{
		return "global"
	}
	else if (substr(p_Name,1,7)="static_") ;If variable is static
	{
		return "static"
	}
	else
	{
		return "instance"
	}
	
	
}

Var_GetLocation(Environment, p_Name)
{
	global _execution
	if (Environment.loopvars.haskey(p_Name))
	{
		return "Loop"
	}
	else if (Environment.threadvars.haskey(p_Name))
	{
		return "Thread"
	}
	else if (_execution.instances[Environment.InstanceID].InstanceVars.haskey(p_Name))
	{
		return "instance"
	}
	;~ d(Environment, "error-  " p_name)
	;Todo: static and global variables
}

Var_Set(environment, p_Name, p_Value, p_Type, p_Destination="")
{
	global _execution
	res:=Var_CheckName(p_Name,true)
	if (res="empty")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting a variable failed. Its name is empty.")
		return ;No result
	}
	else if (res="ForbiddenCharacter")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.")
		return ;No result
	}
	
	if (p_Destination="")
		destination:=Var_RetrieveDestination(p_Name,p_Destination,"LOG")
	else
		destination:=p_Destination
	if (destination!="")
	{
		%destination%Variable_Set(environment,p_Name,p_Value,p_Type)
	}
	else
	{
		logger("f0","Setting variable '" p_Name "' failed. Cannot retrieve destination.")
	}
	;~ d(_execution.instances[Environment.InstanceID].InstanceVars,"instance vars set " p_Name)
}

Var_Get(environment, p_Name, p_Type)
{
	global _execution
	tempvalue=
	if (p_Name="")
	{
		logger("f0","Retrieving variable failed. The name is empty")
	}
	else if (substr(p_Name,1,2)="A_") ; if variable is a built in variable or a thread variable
	{
		;Try to find a loop variable
		tempVar:=LoopVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving loop variable '" p_Name "'")
			tempvalue:=tempVar.value
			if (p_Type!=tempVar.type)
			{
				tempvalue:= Var_ConvertType(tempvalue,"date",p_Type)
			}
			;~ MsgBox ag e %tempvalue%
			return tempvalue
		}
		;Try to find a thread variable
		tempVar:=ThreadVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving thread variable '" p_Name "'")
			tempvalue:=tempVar.value
			if (p_Type!=tempVar.type)
			{
				tempvalue:= Var_ConvertType(tempvalue,"date",p_Type)
			}
			return tempvalue
		}
		;Try to find a built in variable
		tempVar:=BuiltInVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving built in variable '" p_Name "'")
			tempvalue:=tempVar.value
			if (p_Type!=tempVar.type)
			{
				tempvalue:= Var_ConvertType(tempvalue,"date",p_Type)
			}
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving variable '" p_Name "' failed. It does not exist")
		}
			
			
	}
	else if (substr(p_Name,1,7)="global_") ; if variable is a global variable
	{
		tempVar:=GlobalVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving global variable '" p_Name "'")
			tempvalue:=tempVar.value
			if (p_Type!=tempVar.type)
			{
				tempvalue:= Var_ConvertType(tempvalue,"date",p_Type)
			}
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving global variable '" p_Name "' failed. It does not exist")
		}
	}
	else if (substr(p_Name,1,7)="static_") ; if variable is a static variable
	{
		tempVar:=staticVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving static variable '" p_Name "'")
			tempvalue:=tempVar.value
			if (p_Type!=tempVar.type)
			{
				tempvalue:= Var_ConvertType(tempvalue,"date",p_Type)
			}
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving static variable '" p_Name "' failed. It does not exist")
		}
	}
	else ;If this is a instance variable
	{
		tempVar:=InstanceVariable_GetWhole(environment, p_Name)
		if IsObject(tempVar)
		{
			logger("f3","Retrieving instance variable '" p_Name "'")
			tempvalue:=tempVar.value
			return tempvalue
		}
		else
		{
			logger("f0","Retrieving instance variable '" p_Name "' failed. It does not exist")
		}
	}
}

Var_GetType(Environment, p_Name)
{
	tempLocation := Var_GetLocation(Environment, p_Name)
	;~ d(tempLocation)
	if (tempLocation)
	{
		variable:=%tempLocation%Variable_GetWhole(Environment, p_Name)
		;~ d(variable)
		return variable.type
	}
	
}
Var_Delete(Environment, p_Name)
{
	tempLocation := Var_GetLocation(Environment, p_Name)
	if (tempLocation)
		%tempLocation%Variable_Delete(Environment, p_Name)
}

Var_ConvertType(p_Value,p_Contenttype,p_TargetType)
{
	if (p_TargetType="normal")
	{
		if (p_Contenttype="date")
		{
			FormatTime,result,% p_Value
		}
		else if (p_Contenttype="list")
		{
			if IsObject(p_Value)
				result:=strobj(p_Value)
			else
				result:= p_Value
			
		}
	}
	
	return result
}

Var_CheckName(p_Name, tellWhy=false) ;Return 1 if valid. 0 if not
{
	;Check whether the variable name is not empty
	if p_Name=
	{
		;~ logger("f0","Setting a variable failed. Its name is empty.")
		if tellWhy
			return "Empty"
		else
			return 0
	}
	;Check whether the variable name is valid and has no prohibited characters
	try
		asdf%p_Name%:=1 
	catch
	{
		;~ logger("f0","Setting variable '" p_Name "' failed. Name is invalid.")
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



Var_replaceVariables(environment, p_String, p_ContentType = "AsIs")
{
	tempstring:=p_String
	;~ d(environment, "replace variables: " p_String )
	Loop
	{
		tempFoundPos:=RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
		if tempFoundPos=0
			break
		StringReplace,tempstring,tempstring,`%%tempFoundVarName1%`%,% Var_Get(environment,tempFoundVarName1,p_ContentType)
		;~ MsgBox % "reerhes#-" tempstring "-#-" tempFoundVarName1 "-#-" Variable_Get(p_thread,tempFoundVarName1,p_ContentType)
		;~ MsgBox %tempVariablesToReplace1%
	}
	;~ d(environment, "replace variables result: " tempstring )
	return tempstring 
	
}

Var_GetListOfLoopVars(environment)
{
	retobject:=Object()
	for varname, varcontent in Environment.loopvars
	{
		retobject.push(varname)
	}
	return retobject
}
Var_GetListOfThreadVars(environment)
{
	retobject:=Object()
	for varname, varcontent in Environment.threadvars
	{
		retobject.push(varname)
	}
	return retobject
}
Var_GetListOfInstanceVars(environment)
{
	global _execution
	retobject:=Object()
	for varname, varcontent in _execution.instances[Environment.InstanceID].InstanceVars
	{
		retobject.push(varname)
	}
	return retobject
}
Var_GetListOfStaticVars(environment)
{

}
Var_GetListOfGlobalVars(environment)
{
	
}
Var_GetListOfAllVars(environment)
{
	retobject:=Object()
	for index, varname in Var_GetListOfLoopVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfThreadVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfInstanceVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfStaticVars(environment)
	{
		retobject.push(varname)
	}
	for index, varname in Var_GetListOfGlobalVars(environment)
	{
		retobject.push(varname)
	}
	return retobject
}