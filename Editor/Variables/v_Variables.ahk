AllBuiltInVars:="-A_Space-A_Tab-A_YYYY-A_Year-A_MM-A_Mon-A_DD-A_MDay-A_MMMM-A_MMM-A_DDDD-A_DDD-A_WDay-A_YDay-A_Hour-A_Min-A_Sec-A_MSec-A_TickCount-A_TimeIdle-A_TimeIdlePhysical-A_Temp-A_OSVersion-A_Is64bitOS-A_PtrSize-A_Language-A_ComputerName-A_UserName-A_ScriptDir-A_WinDir-A_ProgramFiles-A_AppData-A_AppDataCommon-A_Desktop-A_DesktopCommon-A_StartMenu-A_StartMenuCommon-A_Programs-A_ProgramsCommon-A_Startup-A_StartupCommon-A_MyDocuments-A_IsAdmin-A_ScreenWidth-A_ScreenHeight-A_ScreenDPI-A_IPAddress1-A_IPAddress2-A_IPAddress3-A_IPAddress4-A_Cursor-A_CaretX-A_CaretY-----" ;a_now and a_nowutc not included, they will be treated specially

v_replaceVariables(InstanceID,ThreadID,String,VariableType="asIs")
{
	
	Loop
	{
		tempFoundPos:=RegExMatch(String, "U).*%(.+)%.*", tempVariablesToReplace)
		if tempFoundPos=0
			break
		StringReplace,String,String,`%%tempVariablesToReplace1%`%,% v_getVariable(InstanceID,ThreadID,tempVariablesToReplace1,VariableType)
		;~ MsgBox %tempVariablesToReplace1%
	}
	return String
}



v_getVariable(InstanceID,ThreadID,name,VariableType="asIs")
{
	global
	local tempvalue
	local templeft
	local tempGlobalVariable
	local temp
	
	logger("f3","Retrieving variable " name " as type " VariableType)
	

	if (substr(name,1,7)="global_") ;If variable is global
	{
		
		if fileexist("global variables\" name ".txt")
		{
			FileRead,tempvalue,global variables\%name%.txt ;read file content
			loop,parse,tempvalue,`n,`r ;Get the first line
			{
				
				if (a_loopfield="[Normal]")
				{
					
					StringTrimLeft,tempvalue,tempvalue,10 ;Remove [normal]
					
					done:=true
				}
				else if a_loopfield=[date]
				{
					
					StringTrimLeft,tempvalue,tempvalue,8 ;Remove [date]
					
					if (VariableType!="Date" and VariableType!="asIs")
					{
						tempvalue:= v_exportVariable(tempvalue,"date","`n")
					}
					
					done:=true
				}
				else if a_loopfield=[list]
				{
					StringTrimLeft,tempvalue,tempvalue,8 ;Remove [list]
					
					tempvalue:=StrObj(tempvalue)
					
					if (VariableType!="list" and VariableType!="asIs")
						tempvalue:= StrObj(tempvalue)
					
					
					
					done:=true
				}
				break
			}
			if (done=false) ;It seems to be binary data
			{
				
				;~ if (VariableType!="binary" and VariableType!="asIs") ;binary data disabled
				;~ {
					;~ logger("f3","Global variable " name "has no type. It is assumed to be binary. It is set.")
					;~ FileRead,tempvalue,*c global variables\%name%.txt
				;~ }
				;~ else
				;~ {
					logger("f0a0","Global variable " name "has no type. It won't be set.")
					return
				;~ }
			}
			
			
			
			return tempvalue
			
		}
		else
		{
			
		logger("f1","Global variable " name "does not exist.")
			return
		}
	}
	else if (substr(name,1,7)="static_") ;If variable is static
	{
		
		if fileexist(FolderOfStaticVariables "\" name ".txt")
		{
			FileRead,tempvalue,%FolderOfStaticVariables%\%name%.txt ;read file content
			loop,parse,tempvalue,`n,`r ;Get the first line
			{
				
				if (a_loopfield="[Normal]")
				{
					
					StringTrimLeft,tempvalue,tempvalue,10 ;Remove [normal]
					
					done:=true
				}
				else if a_loopfield=[date]
				{
					
					StringTrimLeft,tempvalue,tempvalue,8 ;Remove [date]
					
					if (VariableType!="Date" and VariableType!="asIs")
					{
						tempvalue:= v_exportVariable(tempvalue,"date","`n")
					}
					
					done:=true
				}
				else if a_loopfield=[list]
				{
					StringTrimLeft,tempvalue,tempvalue,8 ;Remove [list]
					
					tempvalue:=StrObj(tempvalue)
					
					if (VariableType!="list" and VariableType!="asIs")
						tempvalue:= StrObj(tempvalue)
					
					
					
					done:=true
				}
				break
			}
			if (done=false) ;It seems to be binary data
			{
				
				;~ if (VariableType!="binary" and VariableType!="asIs") ;binary data disabled
				;~ {
					;~ logger("f3","Global variable " name "has no type. It is assumed to be binary. It is set.")
					;~ FileRead,tempvalue,*c global variables\%name%.txt
				;~ }
				;~ else
				;~ {
					logger("f0a0","Static variable " name "has no type. It won't be set.")
					return
				;~ }
			}
			
			
			
			return tempvalue
			
		}
		else
		{
			
		logger("f1","Static variable " name "does not exist.")
			return
		}
	}
	else if (substr(name,1,2)="A_") ; if variable is a built in variable or a thread variable
	{
		tempvalue=
		
		
		if Instance_%InstanceID%_Thread_%ThreadID%_Variables.HasKey(name)
		{
			logger("f3","Retrieving built in variable " name)
			tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
			return tempvalue
		}
		if Instance_%InstanceID%_Thread_%ThreadID%_Variables.HasKey(c_loopVarsName)
		{
			
			temp:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]
			;~ MsgBox % strobj(temp)
			if temp.HasKey(name)
			{
				logger("f3","Retrieving loop variable " name)
				tempvalue:=temp[name] 
				return tempvalue
			}
		}
		logger("f3","Retrieving built in variable " name)
		if (name="a_now" || name="A_NowUTC")
		{
			
			if (VariableType="Normal")
			{
				return v_exportVariable(%name%,"date")
			}
			else
			{
				tempvalue:=%name%
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
			tempvalue:= GetLanguageNameFromCode(A_Language)
			
			return tempvalue
		}
		else if (name="a_workingdir")
		{
			return SettingWorkingDir
		}
		else if (name="a_triggertime")
		{
			tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
			if VariableType=Normal
				return v_exportVariable(tempvalue,"date","`n") 
			else
			{
				return tempvalue
			}
		}
		else if (name="a_linefeed" or name="a_lf")
		{
			return "`n"
		}
		else IfInString,AllBuiltInVars,-%name%-
		{
			tempvalue:=%name%
			return tempvalue
		} 
		
		
		
	}
	else ; if variable is a local variable
	{
		logger("f3","Retrieving local variable " name)
		tempvalue:=Instance_%InstanceID%_LocalVariables[name]
		if isobject(tempvalue)
		{
			
			if (VariableType="asIs" or VariableType="list")
			{
				logger("f3","Local variable " name " is a list. Returning the list.")
				return tempvalue
			}
			else
			{
				logger("f3","Local variable " name " is a list. Converting the list to a string.")
				return StrObj(tempvalue)
			}
			
		}
		
		{
			
			StringLeft,templeft,tempvalue,1
			StringTrimLeft,tempvalue,tempvalue,1
			
			if templeft=●
				return tempvalue
			else if templeft=└
			{
				if VariableType=Normal
				{
					logger("f3","Local variable " name " is a date. Converting the date to a string.")
					return v_exportVariable(tempvalue,"date","`n") 
				}
				else
				{
					logger("f3","Local variable " name " is a date. Returning the date.")
					return tempvalue
				}
			}
			else ;No type. Binary data disabled
			{
				;~ if VariableType=binary
				;~ {
					;~ logger("f3","Local variable " name " is binary. Returning the binary data.")
					;~ return tempvalue
				;~ }
				;~ else
				;~ {
					logger("f0a0","Local variable " name " has not type. Returning empty string.")
					return
				;~ }
			}
			
		}
	}
	
	
	
}
v_setVariable(InstanceID,ThreadID,name,value,VariableType="Normal",Permissions=0)
{
	global
	local tempstring
	local templeft
	local tempvalue
	local temp
	
	if (substr(varName,1,2)="A_" and Permissions!=c_SetBuiltInVar and Permissions!=c_SetLoopVar)
	{
		logger("f0","Setting built in variable " name " failed. No permission given.")
		return 0
	}
	
	if not v_CheckVariableName(name,Permissions)
	{
		logger("f0","Setting variable " name " failed. Variable name is not valid")
		return 0
	}
	
	;Refuse setting a variable that begins with "a_". But set thread var if it is designated
	if (substr(name,1,2)="A_")
	{
		if (Permissions=c_SetBuiltInVar)
		{
			logger("f2","Setting thread variable " name ". Permission is given.")
			Instance_%InstanceID%_Thread_%ThreadID%_Variables.insert(name,value)
		}
		else if (Permissions=c_SetLoopVar)
		{
			logger("f2","Setting loop variable " name ". Permission is given.")
			temp:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]
			if not isobject(temp)
			{
				
				temp:=Object()
			}
			temp[name]:=value
			
			Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]:=temp
			
		}
		else
		{
			logger("f0","Setting built in variable " name " failed. No permission given.")
			return 0
		}
		
	}
	else if (substr(name,1,7)="global_") ;If variable is global
	{
		logger("f3","Setting global variable " name ".")
		if isobject(value)
		{
			tempstring=[List]`n
			tempstring.=StrObj(value)
			FileDelete,global variables\%name%.txt
			FileAppend,%tempstring%,global variables\%name%.txt,UTF-8
		}
		else
		{
			;StringReplace, value, value, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			;StringReplace, value, value, `r,³¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			
			
			;The first character contains the information about the variable type
			if variableType=Normal
			{
				FileDelete,global variables\%name%.txt
				FileAppend,[Normal]`n%value%,global variables\%name%.txt,UTF-8
			}
			;~ else if variableType=binary ;binary data disabled
			;~ {
				;~ FileDelete,global variables\%name%.txt
				;~ FileAppend,%value%,*global variables\%name%.txt
			;~ }
			else if variableType=date
			{
				FileDelete,global variables\%name%.txt
				FileAppend,[Date]`n%value%,global variables\%name%.txt,UTF-8
			}
			else
			{
				logger("f0","Setting global variable " name " failed. No type specified.")
				return 0
			}
			
			
		}
		
	}
	else if (substr(name,1,7)="static_") ;If variable is static
	{
		logger("f3","Setting static variable " name ".")
		if isobject(value)
		{
			tempstring=[List]`n
			tempstring.=StrObj(value)
			FileDelete,%FolderOfStaticVariables%\%name%.txt
			FileAppend,%tempstring%,%FolderOfStaticVariables%\%name%.txt,UTF-8
		}
		else
		{
			;StringReplace, value, value, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			;StringReplace, value, value, `r,³¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			
			
			;The first character contains the information about the variable type
			if variableType=Normal
			{
				FileDelete,%FolderOfStaticVariables%\%name%.txt
				FileAppend,[Normal]`n%value%,%FolderOfStaticVariables%\%name%.txt,UTF-8
			}
			;~ else if variableType=binary ;binary data disabled
			;~ {
				;~ FileDelete,global variables\%name%.txt
				;~ FileAppend,%value%,*global variables\%name%.txt
			;~ }
			else if variableType=date
			{
				FileDelete,%FolderOfStaticVariables%\%name%.txt
				FileAppend,[Date]`n%value%,%FolderOfStaticVariables%\%name%.txt,UTF-8
			}
			else
			{
				logger("f0","Setting static variable " name " failed. No type specified.")
				return 0
			}
			
			
		}
		
	}
	else ;if variable is local
	{
		logger("f3","Setting local variable " name ".")
		;insert the local variable
		;The first character will contain the information about the variable type
		if VariableType=normal
			Instance_%InstanceID%_LocalVariables.insert(name,"●" value)
		;~ else if VariableType=binary
			;~ Instance_%InstanceID%_LocalVariables.insert(name, value)
		else if VariableType=date
		{
			
			Instance_%InstanceID%_LocalVariables.insert(name,"└" value)
		}
		else if VariableType=list
		{
			if isobject(value)
				Instance_%InstanceID%_LocalVariables.insert(name,value)
			else
			{
				logger("a0","Error! A list " name "should be created but it is not an object.")
			}
		}
		else
		{
			logger("f0","Setting local variable " name " failed. No type specified.")
			return 0
		}
		
	}
	return 1
	
	
}

v_getVariableType(InstanceID,ThreadID,name)
{
	global
	local tempvalue
	local templeft
	local tempfirstline
	local done:=false
	logger("f3","Getting variable type of " name ".")
	if (substr(name,1,7)="global_")
	{
		if fileexist("global variables\" name ".txt")
		{
			FileReadLine,tempvalue,global variables\%name%.txt,1
			
			if tempvalue=[normal]
			{
				return "normal"
			}
			else if tempvalue=[date]
			{
				return "date"
			}
			else if tempvalue=[list]
			{
				return "list"
			}
			else
				return "unknown" ;Binary type disabled
			
			
			
		}
		else
			return
	}
	else if (substr(name,1,7)="static_")
	{
		if fileexist(FolderOfStaticVariables "\" name ".txt")
		{
			FileReadLine,tempvalue,%FolderOfStaticVariables%\%name%.txt,1
			
			if tempvalue=[normal]
			{
				return "normal"
			}
			else if tempvalue=[date]
			{
				return "date"
			}
			else if tempvalue=[list]
			{
				return "list"
			}
			else
				return "unknown" ;Binary type disabled
			
			
			
		}
		else
			return
	}
	else if (substr(name,1,2)="A_")
	{
		
		if (name="a_now" || name="A_NowUTC" || name="a_triggertime")
		{
			return "date"
			
		}
		else if (name="a_loopcurrentlist")
		{
			return "list"
			
		}
		else
			return "normal"
		
	}
	else
	{
		tempvalue:=Instance_%InstanceID%_LocalVariables[name]
		
		if isobject(tempvalue)
		{
			return "list"
		}
		else
		{
			StringLeft,templeft,tempvalue,1
			StringTrimLeft,tempvalue,tempvalue,1
			
			if templeft=●
				return "normal"
			else if templeft=└
				return "date"
		}
	}
}

getVariableLocation(InstanceID,ThreadID,name)
{
	global
	if (substr(name,1,2)="a_")
	{
		
		;~ MsgBox adsgf
		if Instance_%InstanceID%_Thread_%ThreadID%_Variables.HasKey(name)
		{
			
			return "Thread"
		}
		if Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName].HasKey(name)
		{
			return "loop"
		}
	}
	else if (substr(name,1,7)="global_")
	{
		if fileexist("global variables\" name ".txt")
			return "global"
		
	}
	else if (substr(name,1,7)="static_")
	{
		if fileexist(FolderOfStaticVariables "\" name ".txt")
			return "static"
		
	}
	else ;Seems to be local
	{
		if Instance_%InstanceID%_LocalVariables.HasKey(name)
			return "local"
	}
	;~ MsgBox not found
	return
}




;Convert variable content to string.
v_exportVariable(content,type,delimiters="▬")
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

;Generate variable content from string.
v_importVariable(content,type,delimiters="▬")
{
	local result
	if type=list
	{
		result:=Object()
		loop,parse,content,%delimiters%
		{
			
			result.Insert(A_LoopField)
			
		}
		
	}
	return result
}



;Delete a variable
v_deleteVariable(InstanceID,ThreadID,name,Permission="")
{
	global
	logger("f3","Deleting variable " name ".")

	if (substr(name,1,7)= "global_")
	{
		logger("f3","Deleting global variable " name)
		FileDelete,global variables\%name%.txt
	}
	else if (substr(name,1,7)= "static_")
	{
		logger("f3","Deleting static variable " name)
		FileDelete,%FolderOfStaticVariables%\%name%.txt
	}
	else if (substr(name,1,2)= "a_")
	{
		if Instance_%InstanceID%_Thread_%ThreadID%_Variables.HasKey(name)
		{
			logger("f3","Deleting built in variable " name)
			Instance_%InstanceID%_Thread_%ThreadID%_Variables.delete(name)
			
		}
		else if Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName].HasKey(name)
		{
			logger("f3","Deleting loop variable " name)
			Instance_%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName].delete(name)
			
		}
		
		
	}
	else
	{
		logger("f3","Deleting local variable " name)
		Instance_%InstanceID%_LocalVariables.Remove(name)
	}
	
	return 
	
}

v_ImportLocalVariablesFromObject(InstanceID,ImportObject)
{
	if not isobject(ImportObject)
		return
	
	for tempName, tempValue in ImportObject
	{
		if isobject(tempValue)
			Instance_%InstanceID%_LocalVariables[tempName]:=tempValue
		else
		{
			tempfirstchar:=substr(tempValue,1,1)
			if (tempfirstchar="●" or tempfirstchar="└") 
				Instance_%InstanceID%_LocalVariables[tempName]:=tempValue
			else
				Instance_%InstanceID%_LocalVariables[tempName]:="●"tempValue ;if not type was assigned, assign type normal
		}
		
		
	}
	
}
v_ImportThreadVariablesFromObject(InstanceID,ThreadID,ImportObject)
{
	if not isobject(ImportObject)
		return
	
	for tempName, tempValue in ImportObject
	{
		Instance_%InstanceID%_Thread_%ThreadID%_Variables[tempName]:=tempValue
		
	}
	
}

v_ImportLocalVariablesFromString(InstanceID,string)
{
	global
	local temp
	local templeft
	local tempVarContent
	local tempVarName
	local temppos
	
	;~ MsgBox --- %string%
	loop, parse,string ,◘
	{
		;~ MsgBox sdf %A_LoopField%
		
		StringGetPos,temppos,A_LoopField,=
		if temppos!=
		{
			stringleft,tempVarName,A_LoopField,% temppos
			StringTrimLeft,tempVarContent,A_LoopField,% temppos+1
			
			StringLeft,templeft,tempVarContent,1
			StringTrimLeft,tempVarContent,tempVarContent,1
			
			if templeft=●
			{
				v_setVariable(InstanceID,1,tempVarName,tempVarContent,"normal")
				
			}
			else if templeft=└
			{
				;~ MsgBox fasdf %tempVarName% = %tempVarContent%
				v_setVariable(InstanceID,1,tempVarName,tempVarContent,"date")
				
			}
			else if templeft=╒
			{
				;~ StringReplace,tempVarContent,tempVarContent,◙,`n,all
				v_setVariable(InstanceID,1,tempVarName,strobj(tempVarContent) ,"list")
				
			}
			;~ else ;Binary data not supported
			;~ {
				;~ v_setVariable(InstanceID,1,tempVarName,tempVarContent,"binary")
			;~ }
		}
	}
	
	return
}

v_WriteLocalVariablesToString(InstanceID)
{
	global
	local tempReturnString
	local temp
	local templeft
	local tempVarName
	local tempVarValue
	
	for tempVarName, tempVarValue in %InstanceID%_LocalVariables
	{
		if IsObject(tempVarValue)
		{
			temp:=strobj(tempVarValue)
			;~ StringReplace,temp,temp,`n`r,◙,all
			tempReturnString.=tempVarName "=" "╒" temp "◘"
		}
		else
		{
			StringLeft,templeft,tempVarValue,1
			if (templeft!="└" and templeft !="●")
				tempReturnString.=tempVarName "=" tempVarValue "◘"
		}
	}
	StringTrimRight,tempReturnString,tempReturnString,1
	;~ MsgBox %tempReturnString%
	return tempReturnString
}


v_ImportThreadVariablesFromString(InstanceID,threadID,string)
{
	global
	local temp
	local templeft
	local tempVarContent
	local tempVarName
	local temppos
	
	;~ MsgBox --- %string%
	loop, parse,string ,◘
	{
		;~ MsgBox sdf %A_LoopField%
		
		StringGetPos,temppos,A_LoopField,=
		if temppos!=
		{
			stringleft,tempVarName,A_LoopField,% temppos
			StringTrimLeft,tempVarContent,A_LoopField,% temppos+1
			
			StringLeft,templeft,tempVarContent,1
			StringTrimLeft,tempVarContent,tempVarContent,1
			
			if templeft=●
			{
				v_setVariable(InstanceID,threadID,tempVarName,tempVarContent,"normal",c_SetBuiltInVar)
				
			}
			else if templeft=└
			{
				;~ MsgBox fasdf %tempVarName% = %tempVarContent%
				v_setVariable(InstanceID,threadID,tempVarName,tempVarContent,"date",c_SetBuiltInVar)
				
			}
			else if templeft=╒
			{
				;~ StringReplace,tempVarContent,tempVarContent,◙,`n,all
				v_setVariable(InstanceID,threadID,tempVarName,strobj(tempVarContent) ,"list",c_SetBuiltInVar)
				
			}
			;~ else ;Binary data not supported
			;~ {
				;~ v_setVariable(InstanceID,1,tempVarName,tempVarContent,"binary")
			;~ }
		}
	}
	
	return
}

;Writes a variable name and its content into sring
v_AppendAVariableToString(string,name,value,VariableType="normal")
{
	
	logger("a3","Appending variable " name ". to string")
	;insert the local variable
	;The first character will contain the information about the variable type
	if VariableType=normal
	{
		string.=name "=●" value "◘"
		
	}
	else if VariableType=date
	{
		string.=name "=└" value "◘"
	}
	else if VariableType=list
	{
		if isobject(value)
		{
			temp:=strobj(value)
			string.=name "=" "╒" temp "◘"
			
		}
		else
		{
			logger("a0","Error! A list " name "should be written to string but it is not an object.")
		}
	}
	else
	{
		logger("a0","Appending local variable " name " to string failed. No type specified.")
		return 0
	}
	;~ MsgBox %string%
	return string
	
	
}


;check whether a variable name is valid
v_CheckVariableName(varName,Permissions:="")
{
	global c_SetBuiltInVar
	global c_SetLoopVar
	
	;Try to set a variable. If ahk refuses, the variable name is invalid
	try
		asdf%varName%:=1 
	catch
	{
		;~ MsgBox fsdg %varName%
		return 0
		
	}
	
	;Check whether the variable name is not empty
	if varName=
	{
		;~ MsgBox erze
		return 0
	}
	
	;Check whether the permissions are given
	if (substr(varName,1,2)="A_" and Permissions!=c_SetBuiltInVar and Permissions!=c_SetLoopVar)
	{
		;~ MsgBox %varName% - %Permissions%
		return 0
	}
	
	return 1
	
	
}

PrepareEnteringALoop(InstanceID,ThreadID,LoopElement)
{
	global
	local temp
	local tempclone
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	;~ MsgBox % " -dfsd--" strobj(%InstanceID%_Thread_%ThreadID%_Variables)
	if %InstanceID%_Thread_%ThreadID%_Variables.HasKey(c_loopVarsName)
	{
		
		local temp:=%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]
		;~ MsgBox % " -d--" strobj(temp)
		if isobject(temp)
		{
			local tempclone:=temp.clone()
			
			temp["OldLoopVars"]:=tempclone
		}
		
	}
	else
		temp:=Object()
	
	temp["CurrentLoop"]:=LoopElement
	;~ MsgBox % " ---" strobj(temp)
	%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]:=temp
	;~ MsgBox % StrObj(temp)
	
}


PrepareLeavingALoop(InstanceID,ThreadID,LoopElement)
{
	global
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	;~ MsgBox % LoopElement " - " %InstanceID%_Thread_%ThreadID%_Variables["CurrentLoop"]
	local temp:=%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]
	local tempOld:=temp["OldLoopVars"]
	if isobject(tempOld)
		%InstanceID%_Thread_%ThreadID%_Variables[c_loopVarsName]:=tempOld
	else
		%InstanceID%_Thread_%ThreadID%_Variables.delete(c_loopVarsName)
	
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	
}