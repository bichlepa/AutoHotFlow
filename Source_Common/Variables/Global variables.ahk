AllBuiltInVars:=" A_Space A_Tab A_YYYY A_Year A_MM A_Mon A_DD A_MDay A_MMMM A_MMM A_DDDD A_DDD A_WDay A_YDay A_Hour A_Min A_Sec A_MSec A_TickCount A_TimeIdle A_TimeIdlePhysical A_Temp A_OSVersion A_Is64bitOS A_PtrSize A_Language A_ComputerName A_UserName A_ScriptDir A_WinDir A_ProgramFiles A_AppData A_AppDataCommon A_Desktop A_DesktopCommon A_StartMenu A_StartMenuCommon A_Programs A_ProgramsCommon A_Startup A_StartupCommon A_MyDocuments A_IsAdmin A_ScreenWidth A_ScreenHeight A_ScreenDPI A_IPAddress1 A_IPAddress2 A_IPAddress3 A_IPAddress4 A_Cursor A_CaretX A_CaretY a_now A_NowUTC a_linefeed "
AllCustomBuiltInVars:=" a_lf a_workingdir A_LanguageName a_NowString "

if not fileexist(_WorkingDir "\Variables")
	FileCreateDir, % _WorkingDir "\Variables"


StaticVariable_Set(Environment,p_Name,p_Value, p_hidden=False)
{
	if (p_hidden)
		MsgBox unexpected error! It is not possible to set a hidden static variable!
	
	path:=_WorkingDir "\Variables\" Environment.flowID
	FileCreateDir,%path%
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
	content:=""
	content.="[variable]`n"
	content.="name=" p_Name "`n"
	if isobject(p_value)
		content.="type=object`n"
	else
		content.="type=normal`n"
	FileAppend,%content%,% path "\" p_Name ".ahfvd", utf-16
	
	if isobject(p_value)
	{
		FileAppend,% strobj(p_Value),% path "\" p_Name ".ahfvar"
	}
	else
	{
		FileAppend,% p_Value,% path "\" p_Name ".ahfvar"
	}
	
}

GlobalVariable_Set(Environment,p_Name,p_Value, p_hidden=False)
{
	if (p_hidden)
		MsgBox unexpected error! It is not possible to set a hidden global variable!
	
	path:=_WorkingDir "\Variables"
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
	content:=""
	content.="[variable]`n"
	content.="name=" p_Name "`n"
	if isobject(p_value)
		content.="type=object`n"
	else
		content.="type=normal`n"
	FileAppend,%content%,% path "\" p_Name ".ahfvd", utf-16
	
	if isobject(p_value)
	{
		FileAppend,% strobj(p_Value),% path "\" p_Name ".ahfvar"
	}
	else
	{
		FileAppend,% p_Value,% path "\" p_Name ".ahfvar"
	}
	
}



StaticVariable_Get(Environment,p_Name, p_hidden=False)
{
	if (p_hidden)
		MsgBox unexpected error! There are no hidden static variables!
	
	path:=_WorkingDir "\Variables\" Environment.flowID
	IniRead,vartype, % path "\" p_Name ".ahfvd", variable, type,%A_Space%
	if (vartype = "")
	{
		return 
	}
	else 
	{
		FileRead,varcontent, % path "\" p_Name ".ahfvar"
		if (vartype = "object")
		{
			return strobj(varcontent)
		}
		else
		{
			return varcontent
		}
	}
}

GlobalVariable_Get(Environment,p_Name, p_hidden=False)
{
	if (p_hidden)
		MsgBox unexpected error! There are no hidden global variables!
	
	path:=_WorkingDir "\Variables"
	IniRead,vartype, % path "\" p_Name ".ahfvd", variable, type,%A_Space%
	if (vartype = "")
	{
		return 
	}
	else 
	{
		FileRead,varcontent, % path "\" p_Name ".ahfvar"
		if (vartype = "object")
		{
			return strobj(varcontent)
		}
		else
		{
			return varcontent
		}
	}
}



BuiltInVariable_Get(Environment,p_Name, p_hidden=False)
{
	global AllBuiltInVars
	if (p_hidden)
		MsgBox unexpected error! There are no hidden built-in variables!
	;If no thread and loop variable found, try to find a built in variable if (p_Name="A_YWeek") ;Separate the week.
	if (p_Name="A_YWeek") 
	{
		StringRight,tempvalue,A_YWeek,2
		return tempvalue
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
	else if (p_Name="a_NowString")
	{
		;~ tempvalue:=flowSettings.WorkingDir
		FormatTime,tempvalue,%a_Now%
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
	else if (p_Name="a_lf")
	{
		return  "`n"
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
	else If InStr(AllBuiltInVars," " p_Name " ")
	{
		tempvar:=%p_Name%
		return tempvar
	}
	;todo
}


StaticVariable_Delete(Environment,p_Name)
{
	path:=_WorkingDir "\Variables\" Environment.flowID
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
}
GlobalVariable_Delete(Environment,p_Name)
{
	path:=_WorkingDir "\Variables"
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
}

Var_GetListOfStaticVars(environment)
{
	retobject:=Object()
	path:=_WorkingDir "\Variables\" Environment.flowID
	loop, files, %path%\*.ahfvd
	{
		StringReplace, varname, a_loopfilename, .ahfvd
		retobject.push(varname)
	}
	return retobject
}
Var_GetListOfGlobalVars(environment)
{
	retobject:=Object()
	path:=_WorkingDir "\Variables"
	loop, files, %path%\*.ahfvd
	{
		StringReplace, varname, a_loopfilename, .ahfvd
		retobject.push(varname)
	}
	return retobject
}

Var_GetListOfAllVars_Common(environment)
{
	retobject:=Object()
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

Var_RetrieveDestination_Common(p_Name,p_Location,p_log=true)
{
	if (substr(p_Name,1,2)="A_") ;If variable name begins with A_
	{
		return "error_noPermission"
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



Var_GetLocation_Common(Environment, p_Name, p_hidden=False)
{
	global AllBuiltInVars, AllCustomBuiltInVars
	if (p_hidden = false)
	{
		ifinstring,AllBuiltInVars, %A_Space%%p_Name%%A_Space%
		{
			return "BuiltIn"
		}
		else ifinstring,AllCustomBuiltInVars, %A_Space%%p_Name%%A_Space%
		{
			return "BuiltIn"
		}
		else if fileexist(_WorkingDir "\Variables\" p_Name ".ahfvd")
		{		
			return "global"
		}
		else if fileexist(_WorkingDir "\Variables\"  Environment.flowID "\" p_Name ".ahfvd")
		{		
			return "static"
		}
	}
	else
	{
		if (p_hidden != true and p_hidden != "hidden")
		{
			MsgBox unexpected error while retrieving variable location of %p_Name%: The parameter p_hidden has unsupported value: %p_hiden%
		}
		else
		{
			logger("f0","Cannot get location of hidden variable '" p_Name "' outside a running execution.", Environment.flowname)
		}
	}
	;~ d(Environment, "error-  " p_name)
	;Todo: static and global variables
}


Var_Set_Common(Environment, p_Name, p_Value, p_Destination="", p_hidden=False)
{
	res:=Var_CheckName(p_Name,true)
	if (res="empty")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting a variable failed. Its name is empty.", Environment.flowname)
		return ;No result
	}
	else if (res="ForbiddenCharacter")
	{
		if (p_log=true or p_log="LOG")
			logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.", Environment.flowname)
		return ;No result
	}
	
	if (p_Destination="")
		destination:=Var_RetrieveDestination_Common(p_Name,p_Destination,"LOG")
	else
		destination:=p_Destination
	if (destination!="" and not instr(destination, "error_"))
	{
		if (destination!="static" and destination!="global")
		{
			logger("f0","Setting variable '" p_Name "' failed. Destination is neither global nor static.", Environment.flowname)
		}
		else
		{
			%destination%Variable_Set(environment,p_Name,p_Value,p_hidden)
		}
	}
	else
	{
		if (destination = "error_noPermission")
		{
			logger("f0","Setting variable '" p_Name "' failed. No permission.", Environment.flowname)
		}
		else
		{
			logger("f0","Setting variable '" p_Name "' failed. Cannot retrieve destination.", Environment.flowname)
		}
	}
	;~ d(_execution.instances[Environment.InstanceID].InstanceVars,"instance vars set " p_Name)
}


Var_Get_Common(environment, p_Name, p_hidden = False)
{
	tempvalue=
	if (p_Name="")
	{
		logger("f0","Retrieving variable failed. The name is empty", Environment.flowname)
	}
	
	tempLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	
	if (tempLocation)
	{
		logger("f3","Retrieving " tempLocation " variable '" p_Name "'", Environment.flowname)
		tempVar := %tempLocation%Variable_Get(environment, p_Name, p_hidden)
		return tempVar
	}
	else
	{
		logger("f0","Retrieving variable '" p_Name "' failed. It does not exist or is neither global nor static", Environment.flowname)
	}
}

Var_GetType_Common(Environment, p_Name, p_hidden = False)
{
	tempLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	;~ d(tempLocation)
	if (tempLocation)
	{
		variable:=%tempLocation%Variable_Get(Environment, p_Name, p_hidden)
		;~ d(variable)
		if IsObject(variable)
		{
			return "object"
		}
		else
		{
			return "normal"
		}
	}
	
}
Var_Delete_Common(Environment, p_Name, p_hidden=False)
{
	tempLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	if (tempLocation)
		%tempLocation%Variable_Delete(Environment, p_Name, p_hidden)
}




Var_CheckName(p_Name, tellWhy=false) ;Return 1 if valid. 0 if not
{
	;Check whether the variable name is not empty
	if p_Name=
	{
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


Var_replaceVariables_Common(environment, p_String, pars = "")
{
	tempstring:=p_String
	;~ d(environment, "replace variables: " p_String )
	Loop
	{
		tempFoundPos:=RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
		if tempFoundPos=0
			break
		tempVarValue:=Var_Get_Common(environment,tempFoundVarName1)
		if isobject(tempVarValue)
		{
			IfInString, pars, ConvertObjectToString
				tempVarValue := strobj(tempVarValue)
		}
		
		StringReplace,tempstring,tempstring,`%%tempFoundVarName1%`%,% tempVarValue
		;~ MsgBox % "reerhes#-" tempstring "-#-" tempFoundVarName1 "-#-" Variable_Get(p_thread,tempFoundVarName1,p_ContentType)
		;~ MsgBox %tempVariablesToReplace1%
	}
	;~ d(environment, "replace variables result: " tempstring )
	return tempstring 
	
}
