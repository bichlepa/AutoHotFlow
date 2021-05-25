; list of all built in variables which also exist in AHK
global global_AllBuiltInVars:=" A_Space A_Tab A_YYYY A_Year A_MM A_Mon A_DD A_MDay A_MMMM A_MMM A_DDDD A_DDD A_WDay A_YDay A_Hour A_Min A_Sec A_MSec A_TickCount A_TimeIdle A_TimeIdlePhysical A_Temp A_OSVersion A_Is64bitOS A_PtrSize A_Language A_ComputerName A_UserName A_ScriptDir A_WinDir A_ProgramFiles A_AppData A_AppDataCommon A_Desktop A_DesktopCommon A_StartMenu A_StartMenuCommon A_Programs A_ProgramsCommon A_Startup A_StartupCommon A_MyDocuments A_IsAdmin A_ScreenWidth A_ScreenHeight A_ScreenDPI A_IPAddress1 A_IPAddress2 A_IPAddress3 A_IPAddress4 A_Cursor A_CaretX A_CaretY a_now A_NowUTC a_linefeed "
; list of all custom built in variables which do not exist in AHK or have different value
global global_AllCustomBuiltInVars:=" A_YWeek a_lf a_workingdir A_LanguageName a_NowString "

; create variable folder, if it does not exist
if not fileexist(_WorkingDir "\Variables")
	FileCreateDir, % _WorkingDir "\Variables"

; set a static variable which is visible inside in all instances of a flow. It will be saved in file.
; p_hidden: optional, must contain false if used
StaticVariable_Set(Environment, p_Name, p_Value, p_hidden = False)
{
	_EnterCriticalSection()
	
	if (p_hidden)
		throw exception("unexpected error! It is not possible to set a hidden static variable!")
	
	; calculate path of the variable
	path := _WorkingDir "\Variables\" Environment.flowID

	; create directory for static variable (if it not exists yet)
	FileCreateDir, %path%

	; delete old variable files, if exist
	FileDelete, % path "\" p_Name ".ahfvd"
	FileDelete, % path "\" p_Name ".ahfvar"

	; write metadata of variable in a file
	content := {name: p_Name}
	if isobject(p_value)
		content.type :="object"
	else
		content.type :="normal"
	FileAppend, % Jxon_Dump(content, 2), % path "\" p_Name ".ahfvd"
	
	; write variable content in a file
	if isobject(p_value)
	{
		FileAppend, % Jxon_Dump(p_Value), % path "\" p_Name ".ahfvar"
	}
	else
	{
		FileAppend, % p_Value, % path "\" p_Name ".ahfvar"
	}
	
	_LeaveCriticalSection()
}

; set a global variable which is visible inside in all instances of all flows. It will be saved in file.
; p_hidden: optional, must contain false if used
GlobalVariable_Set(Environment, p_Name, p_Value, p_hidden = False)
{
	_EnterCriticalSection()
	
	if (p_hidden)
		throw exception("unexpected error! It is not possible to set a hidden global variable!")
	
	; calculate path of the variable
	path := _WorkingDir "\Variables"
	
	; delete old variable files, if exist
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
	
	; write metadata of variable in a file
	content := {name: p_Name}
	if isobject(p_value)
		content.type :="object"
	else
		content.type :="normal"
	FileAppend, % Jxon_Dump(content, 2), % path "\" p_Name ".ahfvd"
	
	; write variable content in a file
	if isobject(p_value)
	{
		FileAppend, % Jxon_Dump(p_Value, 2), % path "\" p_Name ".ahfvar"
	}
	else
	{
		FileAppend, % p_Value, % path "\" p_Name ".ahfvar"
	}
	
	_LeaveCriticalSection()
}


; get a static variable
StaticVariable_Get(Environment, p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	
	if (p_hidden)
		throw exception("unexpected error! There are no hidden static variables!")
	
	; calculate path of the variable
	path := _WorkingDir "\Variables\" Environment.flowID

	; read metadata of variable from file
	fileread, metaData, % path "\" p_Name ".ahfvd"
	metaData := Jxon_Load(metaData)
	if (not metaData.type)
	{
		logger("f0", "error getting static variable type of " p_Name)
	}
	else 
	{
		; read variable content from file
		FileRead,varcontent, % path "\" p_Name ".ahfvar"
		if (metaData.type = "object")
		{
			retval := Jxon_Load(varcontent)
		}
		else
		{
			retval := varcontent
		}
	}
	
	_LeaveCriticalSection()
	
	return retval
}

; get a global variable
GlobalVariable_Get(Environment,p_Name, p_hidden = False)
{
	_EnterCriticalSection()
	
	if (p_hidden)
		throw exception("unexpected error! There are no hidden global variables!")
	
	; calculate path of the variable
	path := _WorkingDir "\Variables"

	; read metadata of variable from file
	fileread, metaData, % path "\" p_Name ".ahfvd"
	metaData := Jxon_Load(metaData)

	if (not metaData.type)
	{
		logger("f0", "error getting global variable type of " p_Name)
	}
	else 
	{
		; read variable content from file
		FileRead,varcontent, % path "\" p_Name ".ahfvar"
		if (metaData.type = "object")
		{
			retval:= Jxon_Load(varcontent)
		}
		else
		{
			retval:= varcontent
		}
	}
	
	_LeaveCriticalSection()
	
	return retval
}

; get a built-in variable
BuiltInVariable_Get(Environment, p_Name, p_hidden = False)
{
	if (p_hidden)
		throw exception("unexpected error! There are no hidden built-in variables!")

	;If no thread and loop variable found, try to find a built in variable if (p_Name="A_YWeek") ;Separate the week.
	if (p_Name = "A_YWeek") 
	{
		;Separate the week.
		StringRight, tempvalue, A_YWeek, 2
		return tempvalue
	}
	else if (p_Name = "A_LanguageName") 
	{
		tempvalue:= ;GetLanguageNameFromCode(A_Language) ;;TODO: Uncomment
		
		return tempvalue
	}
	else if (p_Name = "a_workingdir")
	{
		tempvalue := _getSettings("WorkingDir")
		return tempvalue
	}
	else if (p_Name = "a_NowString")
	{
		FormatTime, tempvalue, %a_Now%
		return tempvalue
	}
	else if (p_Name = "a_lf")
	{
		return "`n"
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
	else If InStr(global_AllBuiltInVars," " p_Name " ")
	{
		; it is a built-in variable that is identical to the built in AHK variable. Get it.
		tempvar := %p_Name%
		return tempvar
	}
}

; delete static variable 
StaticVariable_Delete(Environment, p_Name)
{
	_EnterCriticalSection()
	
	; calculate path of the variable
	path := _WorkingDir "\Variables\" Environment.flowID
	
	; delete variable files, if exist
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
	
	_LeaveCriticalSection()
}

; delete global variable 
GlobalVariable_Delete(Environment, p_Name)
{
	_EnterCriticalSection()
	
	; calculate path of the variable
	path := _WorkingDir "\Variables"
	
	; delete variable files, if exist
	FileDelete,% path "\" p_Name ".ahfvd"
	FileDelete,% path "\" p_Name ".ahfvar"
	
	_LeaveCriticalSection()
}

; get list of all static variables of current flow
Var_GetListOfStaticVars(environment)
{
	_EnterCriticalSection()
	
	; prepare list, which will contain the variable names
	retobject := Object()

	; calculate path of the variables
	path := _WorkingDir "\Variables\" Environment.flowID

	; find all files with variable metadata in folder and add the names to list
	loop, files, %path%\*.ahfvd
	{
		StringReplace, varname, a_loopfilename, .ahfvd
		retobject.push(varname)
	}
	
	_LeaveCriticalSection()
	
	return retobject
}

; get list of all global variables
Var_GetListOfGlobalVars(environment)
{
	_EnterCriticalSection()
	
	; prepare list, which will contain the variable names
	retobject := Object()
	
	; calculate path of the variables
	path := _WorkingDir "\Variables"

	; find all files with variable metadata in folder and add the names to list
	loop, files, %path%\*.ahfvd
	{
		StringReplace, varname, a_loopfilename, .ahfvd
		retobject.push(varname)
	}
	
	_LeaveCriticalSection()
	
	return retobject
}

; get list of all global and static variables of a flow
; This functino will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_GetListOfAllVars_Common(environment)
{
	_EnterCriticalSection()
	
	; prepare list, which will contain the variable names
	retobject := Object()

	; get all static variables
	tempVarsList := Var_GetListOfStaticVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	; get all global variables
	tempVarsList := Var_GetListOfGlobalVars(environment)
	for index, varname in tempVarsList
	{
		retobject.push(varname)
	}
	
	_LeaveCriticalSection()
	
	return retobject
}

; get destination of a variable.
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_RetrieveDestination_Common(p_Name,p_Location,p_log=true)
{
	if (substr(p_Name, 1, 2) = "A_") ;If variable name begins with A_
	{
		; thread, or loop variables cannot be set outside the execution of an element
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
		; we cannot set instance variable outside the execution of an element
		return "error_noPermission"
	}
}

; get the location of a variable
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_GetLocation_Common(Environment, p_Name, p_hidden=False)
{
	if (not p_hidden)
	{
		if (substr(p_Name, 1, 2) = "A_") ;If variable name begins with A_
		{
			; search for a build-in variable with that name (with same name as in AHK)
			ifinstring, global_AllBuiltInVars, %A_Space%%p_Name%%A_Space%
			{
				return "BuiltIn"
			}
			; search for a custom build-in variable with that name (which does not exist in AHK or has different value)
			else ifinstring,global_AllCustomBuiltInVars, %A_Space%%p_Name%%A_Space%
			{
				return "BuiltIn"
			}
		}
		else if (substr(p_Name, 1, 7) = "global_")  ;If variable is global
		{
			; search for a global variable with that name
			if fileexist(_WorkingDir "\Variables\" p_Name ".ahfvd")
			{
				return "global"
			}
		}
		else if (substr(p_Name, 1, 7) = "static_") ;If variable is static
		{
			; search for a static variable with that name
			if fileexist(_WorkingDir "\Variables\"  Environment.flowID "\" p_Name ".ahfvd")
			{		
				return "static"
			}
		}
	}
	else
	{
		logger("f0", "Cannot get location of hidden variable '" p_Name "' outside a running execution.", Environment.flowID)
	}
}

; set a variable
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_Set_Common(Environment, p_Name, p_Value, p_Destination="", p_hidden=False)
{
	; check variable name
	res := Var_CheckName(p_Name, true)
	if (res = "empty")
	{
		logger("f0","Setting a variable failed. Its name is empty.", Environment.flowID)
		return
	}
	else if (res = "ForbiddenCharacter")
	{
		logger("f0","Setting variable '" p_Name "' failed. It contains forbidden characters.", Environment.flowID)
		return
	}
	; else variable name is valid
	
	; get the destination of the variable (and also check whether it is allowed to set it)
	destination := Var_RetrieveDestination_Common(p_Name, p_Destination)

	if (destination and not instr(destination, "error_"))
	{
		; it is allowed to set the variable and we can set it
		if not (isfunc(destination "Variable_Set"))
		{
			throw exception("function ''" destination "Variable_Set' does not exist")
		}

		%destination%Variable_Set(environment, p_Name, p_Value, p_hidden)
	}
	else
	{
		; there was an error or destination is 
		if (destination = "error_noPermission")
		{
			logger("f0","Setting variable '" p_Name "' failed. No permission.", Environment.flowID)
		}
		else
		{
			throw exception("destination variable returned by Var_RetrieveDestination_Common() is empty")
		}
	}
	;~ d(_execution.instances[Environment.InstanceID].InstanceVars,"instance vars set " p_Name)
}


; get value of a variable
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_Get_Common(environment, p_Name, p_hidden = False)
{
	if (isobject(p_Name))
	{
		throw exception("p_Name is an object")
	}
	
	; get the location of the variable and check whether it exists
	varLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	
	if (varLocation)
	{
		; variable exists. Get the value
		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}
		
		logger("f3","Retrieving " varLocation " variable '" p_Name "'", Environment.flowID)
		tempVar := %varLocation%Variable_Get(environment, p_Name, p_hidden)
		return tempVar
	}
	else
	{
		logger("f0","Retrieving variable '" p_Name "' failed. It does not exist or is neither global nor static", Environment.flowID)
	}
}

; get type of a variable. If variable exists, it returns "object" or "normal": If variable does not exist or is empty, it returns nothing.
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_GetType_Common(Environment, p_Name, p_hidden = False)
{
	; first find the location of variable (and so check whether it exist)
	varLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	if (varLocation)
	{
		; variable exists

		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}
		
		; get variable value
		variable := %varLocation%Variable_Get(Environment, p_Name, p_hidden)
		
		; check the type of variable
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

; delete a variable
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_Delete_Common(Environment, p_Name, p_hidden = False)
{
	; first find the location of variable (and so check whether it exist)
	varLocation := Var_GetLocation_Common(Environment, p_Name, p_hidden)
	if (varLocation)
	{
		; variable exists

		if not (isfunc(varLocation "Variable_Get"))
		{
			throw exception("function ''" varLocation "Variable_Get' does not exist")
		}

		; delete variable
		%varLocation%Variable_Delete(Environment, p_Name, p_hidden)
	}
}


; check variable name
; if tellWhy is false, the function will return true if valid and false if invalid
; if tellWhy is true, the function will return "Empty", "ForbiddenCharacter", "StartsWithNumber" or "OK"
Var_CheckName(p_Name, tellWhy = false)
{
	;Check whether the variable name is empty
	if p_Name=
	{
		; name is empty
		if tellWhy
			return "Empty"
		else
			return false
	}

	; check whether the variable starts with a number
	firstChar := substr(p_name, 1, 1)
	if firstChar is number
	{
		if tellWhy
			return "StartsWithNumber"
		else
			return false
	}

	;Check whether the variable name is valid and has no prohibited characters
	try
	{
		; try to set a variable with this name. Append asdf to make sure, we do not overwrite any existing variable
		asdf%p_Name% := 1
	}
	catch
	{
		if tellWhy
			return "ForbiddenCharacter"
		else
			return false
	}
	if tellWhy
		return "OK"
	else
		return true
}


; replace variables inside a string which are encased with percent signs
; pars: if it contains "ConvertObjectToString": if value of variable is an object, it will be converted to string
; This function will be called outside the execution of an element, therefore no access to thread, loop and instance variables.
Var_replaceVariables_Common(environment, p_String, pars = "")
{
	; copy string
	tempstring := p_String

	; start endless loop where we replace all occurrences
	Loop
	{
		; find first variable name in the string which is encased in percent signs. Write found variable name
		tempFoundPos := RegExMatch(tempstring, "SU).*%(.+)%.*", tempFoundVarName)
		
		; break, if we didn't find a string
		if (tempFoundPos = 0)
			break

		; get the value of the variable
		tempVarValue := Var_Get_Common(environment, tempFoundVarName1)

		; if value is an object
		if isobject(tempVarValue)
		{
			; if requested, convert the value to string
			IfInString, pars, ConvertObjectToString
				tempVarValue := Jxon_Dump(tempVarValue)
		}
		
		; replace the found variable in string
		StringReplace, tempstring, tempstring, `%%tempFoundVarName1%`%, % tempVarValue
	}

	return tempstring 
}
