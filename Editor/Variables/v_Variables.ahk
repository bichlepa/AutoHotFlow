AllBuiltInVars:="-A_Space-A_Tab-A_YYYY-A_Year-A_MM-A_Mon-A_DD-A_MDay-A_MMMM-A_MMM-A_DDDD-A_DDD-A_WDay-A_YDay-A_Hour-A_Min-A_Sec-A_MSec-A_TickCount-A_TimeIdle-A_TimeIdlePhysical-A_Temp-A_OSVersion-A_Is64bitOS-A_PtrSize-A_Language-A_ComputerName-A_UserName-A_ScriptDir-A_WinDir-A_ProgramFiles-A_AppData-A_AppDataCommon-A_Desktop-A_DesktopCommon-A_StartMenu-A_StartMenuCommon-A_Programs-A_ProgramsCommon-A_Startup-A_StartupCommon-A_MyDocuments-A_IsAdmin-A_ScreenWidth-A_ScreenHeight-A_ScreenDPI-A_IPAddress1-A_IPAddress2-A_IPAddress3-A_IPAddress4-A_Cursor-A_CaretX-A_CaretY-----" ;a_now and a_nowutc not included

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





v_deleteLocalVariable(InstanceID,name)
{
	global
	
	Instance_%InstanceID%_LocalVariables.Remove(name)
	return value
	
}

v_getVariable(InstanceID,ThreadID,name,VariableType="asIs")
{
	global
	local tempvalue
	local templeft
	local tempGlobalVariable
	
	StringLeft,templeft,name,7
	if templeft=global_ ;If variable is global
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
					StringTrimLeft,tempvalue,tempvalue,7 ;Remove [date]
					
					if (VariableType!="Date" and VariableType!="asIs")
					{
						tempvalue:= v_exportVariable(tempvalue,"date","`n")
					}
					
					done:=true
				}
				else if a_loopfield=[list]
				{
					StringTrimLeft,tempvalue,tempvalue,7 ;Remove [list]
					
					tempvalue:=StrObj(tempvalue)
					
					if (VariableType!="list" and VariableType!="asIs")
						tempvalue:= StrObj(tempvalue)
					
					
					
					done:=true
				}
				break
			}
			if (done=false) ;It seems to be binary data
			{
				if (VariableType!="binary" and VariableType!="asIs")
					FileRead,tempvalue,*c global variables\%name%.txt
				else
					return
			}
			
			
			
			return tempvalue
			
		}
		else
			return
	}
	else if (substr(name,1,2)="A_") ; if variable is a built in variable or a thread variable
	{
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
			
		}
		else
			tempvalue:=Instance_%InstanceID%_Thread_%ThreadID%_Variables[name] 
		
		return tempvalue
		
	}
	else ; if variable is a local variable
	{
		tempvalue:=Instance_%InstanceID%_LocalVariables[name]
		if isobject(tempvalue)
		{
			
			if (VariableType="asIs" or VariableType="list")
				return tempvalue
			else
			{
				
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
					return v_exportVariable(tempvalue,"date","`n") 
				else
				{
					return tempvalue
				}
			}
			else ;Binary data
			{
				if VariableType=binary
					return tempvalue
				else
					return
			}
			
		}
	}
	
	
	
}
v_setVariable(InstanceID,ThreadID,name,value,VariableType="Normal",whetherToSetThreadVar=0)
{
	global
	local tempstring
	local templeft
	local tempvalue
	
	;Refuse setting a variable that begins with "a_". But set thread var if it is designated
	if (substr(name,1,2)="A_")
	{
		if (whetherToSetThreadVar=true)
		{
			
			
			
			Instance_%InstanceID%_Thread_%ThreadID%_Variables.insert(name,value)
			
		}
		else
			return "ERROR"
	}
	
	;MsgBox % var "  " value
	StringLeft,templeft,name,7
	if templeft=global_ ;If variable is global
	{
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
			else if variableType=binary
			{
				FileDelete,global variables\%name%.txt
				FileAppend,%value%,*global variables\%name%.txt
			}
			else if variableType=date
			{
				FileDelete,global variables\%name%.txt
				FileAppend,[Date]`n%value%,global variables\%name%.txt,UTF-8
			}
			
			
		}
		
	}
	else ;if variable is local
	{
		;insert the local variable
		;The first character will contain the information about the variable type
		if VariableType=normal
			Instance_%InstanceID%_LocalVariables.insert(name,"●" value)
		else if VariableType=binary
			Instance_%InstanceID%_LocalVariables.insert(name, value)
		else if VariableType=date
			Instance_%InstanceID%_LocalVariables.insert(name,"└" value)
		else if VariableType=list
		{
			if isobject(value)
				Instance_%InstanceID%_LocalVariables.insert(name,value)
			else
				MsgBox Internal error! A list should be created but it is not an object.
		}
		
	}
	return 
	
	
}

v_getVariableType(InstanceID,ThreadID,name)
{
	global
	local tempvalue
	local templeft
	local tempfirstline
	local done:=false
	StringLeft,templeft,name,7
	if templeft=global_
	{
		IniRead,tempvalue,Global_Variables.ini,%VariableType%,%name%,%A_Space%
	}
	else if (substr(name,1,2)="A_")
	{
		if (name="a_now" || name="A_NowUTC")
		{
			return "date"
			
		}
		else
			return "normal"
		
	}
	else
		tempvalue:=Instance_%InstanceID%_LocalVariables[name]
	
	if isobject(tempvalue)
	{
		return "list"
	}
	else
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
				return "binary"
			
			
			
		}
		else
			return
		
	}
	
}

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

;Export list to a string. It is used for saving the list in ini as global variable
v_exportList(List)
{
	return "≡savedList"
	
}
;Imports list from a string. It is used for getting the list from ini
v_importList(List)
{
	local tempObject:=Object()
	tempObject.insert("imported List")
	return tempObject
	
}


v_deleteVariable(InstanceID,name)
{
	global
	StringLeft,templeft,name,7
	if templeft=global_
		ControlSetText,edit1,DeleteGlobalVariable|%name%|,CommandWindowOfManager ;Tell the Manager to delete the variable
	else
	{
		v_deleteLocalVariable(InstanceID,name)
	}
	return 
	
}



v_WriteLocalVariablesToString(InstanceID)
{
	global
	tempReturnString=
	for tempVarName, tempVarValue in %InstanceID%_LocalVariables
	{
		tempReturnString=%tempVarName%=%tempVarValue%◘
	}
	StringTrimRight,tempReturnString,tempReturnString,1
	return tempReturnString
}


PrepareEnteringALoop(InstanceID,ThreadID,LoopElement)
{
	global
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	local temp:=%InstanceID%_Thread_%ThreadID%_Variables.clone()
	%InstanceID%_Thread_%ThreadID%_Variables:=Object()
	%InstanceID%_Thread_%ThreadID%_Variables.insert("OldLoopVars",temp)
	%InstanceID%_Thread_%ThreadID%_Variables.insert("CurrentLoop",LoopElement)
	;~ MsgBox % StrObj(temp)
	
}


PrepareLeavingALoop(InstanceID,ThreadID,LoopElement)
{
	global
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	;~ MsgBox % LoopElement " - " %InstanceID%_Thread_%ThreadID%_Variables["CurrentLoop"]
	%InstanceID%_Thread_%ThreadID%_Variables:=%InstanceID%_Thread_%ThreadID%_Variables["OldLoopVars"]
	
	;~ MsgBox % StrObj(Instance_%InstanceID%_Thread_%ThreadID%_Variables)
	
}