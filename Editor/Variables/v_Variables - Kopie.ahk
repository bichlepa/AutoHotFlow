

v_replaceVariables(InstanceID,String,VariableType="Normal")
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

v_getVariable(InstanceID,name,VariableType="Normal")
{
	global
	local tempvalue
	local templeft
	local tempGlobalVariable
	
	StringLeft,templeft,name,7
	if templeft=global_
	{
		IniRead,tempGlobalVariable,Global_Variables.ini,Variables,%name%,%A_Space%
		
		StringReplace, tempGlobalVariable, tempGlobalVariable, |¶,`n, All
		StringReplace, tempGlobalVariable, tempGlobalVariable, ³¶,`r, All
		if tempGlobalVariable=
			return
		
		
		
		StringLeft,templeft,tempGlobalVariable,1
		if templeft=≡
		{
			
			tempvalue:= v_importList(tempGlobalVariable)
			if IsObject(tempvalue)
			;MsgBox % "gsdg" tempvalue[1]
			if VariableType=list
				return tempvalue
			else
			{
				
				return " • " v_exportVariable(tempvalue,"list","`n • ")
			}
			
		}
		else
		{
			StringTrimLeft,tempGlobalVariable,tempGlobalVariable,1
			return tempGlobalVariable
		}
	}
	else if (substr(name,1,2)="A_")
	{
		if (name="a_now" || name="A_NowUTC")
		{
			if VariableType=Normal
			{
				return v_exportVariable(%name%,"date")
			}
			else
				return tempvalue
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
			
			if VariableType=list
				return tempvalue
			else
			{
				
				return " • " v_exportVariable(tempvalue,"list","`n • ")
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
				if VariableType=Date
					return tempvalue
				else
				{
					return v_exportVariable(tempvalue,"date","`n")
				}
			}
			
			
		}
	}
	
	
	
}
v_setVariable(InstanceID,name,value,VariableType="Normal")
{
	global
	local tempstring
	
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
			tempstring:=v_exportList(value)
			Iniwrite,%tempstring%,Global_Variables.ini,Variables,%name%
		}
		else
		{
			StringReplace, value, value, `n,|¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			StringReplace, value, value, `r,³¶, All ;Convert a linefeed to |¶. Otherwise the next lines will not be readable.
			VariableType=normal
				Iniwrite,●%value%,Global_Variables.ini,Variables,%name%
			VariableType=date
				Iniwrite,└%value%,Global_Variables.ini,Variables,%name%
		}
		
	}
	else
	{
		;The first character contains the information about the variable type
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
			
		StringLeft,templeft,tempvalue,1
		StringTrimLeft,tempvalue,tempvalue,1
		
		;The first character contains the information about the variable type
		if templeft=●
			return "normal"
		else if templeft=↕
		{
			return "binary"
			
		}
		else if templeft=└
		{
			return "Date"
			
		}
		else if templeft=≡ ;This can only occur if it is a global variable
		{
			return "List"
			
		}
			
			
		
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
