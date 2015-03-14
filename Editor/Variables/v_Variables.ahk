

v_replaceVariables(InstanceID,String,VariableType="asIs")
{
	
	Loop
	{
		tempFoundPos:=RegExMatch(String, "U).*%(.+)%.*", tempVariablesToReplace)
		if tempFoundPos=0
			break
		StringReplace,String,String,`%%tempVariablesToReplace1%`%,% v_getVariable(InstanceID,tempVariablesToReplace1,VariableType)
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

v_getVariable(InstanceID,name,VariableType="asIs")
{
	global
	local tempvalue
	local templeft
	local tempGlobalVariable
	
	StringLeft,templeft,name,7
	if templeft=global_
	{
		
		if fileexist("global variables\" name ".txt")
		{
			FileRead,tempvalue,global variables\%name%.txt ;read file content
			loop,parse,tempvalue,`n,`r ;Get the first line
			{
				
				if (a_loopfield="[Normal]")
				{
					
					StringTrimLeft,tempvalue,tempvalue,9 ;Remove [normal]
					
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
	else if (substr(name,1,2)="A_")
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
		else
			tempvalue:=%name%
		
		return tempvalue
		
	}
	else
	{
		tempvalue:=Instance_%InstanceID%_LocalVariables[name]
		if isobject(tempvalue)
		{
			
			if (VariableType="normal")
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
			else if templeft=↕
			{
				if VariableType=binary
					return tempvalue
				else
					return
			}
			else if templeft=└
			{
				if VariableType=Normal
					return v_exportVariable(tempvalue,"date","`n") 
				else
				{
					return tempvalue
				}
			}
			
			
		}
	}
	
	
	
}
v_setVariable(InstanceID,name,value,VariableType="Normal")
{
	global
	local tempstring
	local templeft
	local tempvalue
	
	if (substr(name,1,2)="A_")
	{
		return "ERROR"
	}
	
	;MsgBox % var "  " value
	StringLeft,templeft,name,7
	if templeft=global_
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
	else
	{
		;insert the local variable
		;The first character will contain the information about the variable type
		if VariableType=normal
			Instance_%InstanceID%_LocalVariables.insert(name,"●" value)
		else if VariableType=binary
			Instance_%InstanceID%_LocalVariables.insert(name,"↕" value)
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

v_getVariableType(InstanceID,name)
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
