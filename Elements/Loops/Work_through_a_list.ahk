iniAllLoops.="Work_through_a_list|" ;Add this loop to list of all loops on initialisation

runLoopWork_through_a_list(InstanceID,ThreadID,ElementID,ElementIDInInstance,HeadOrTail)
{
	global
	local templist
	local tempUseCopiedList
	local tempFound

	if HeadOrTail=Head ;Initialize loop
	{
		templistname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname) 
		
		templist:=v_GetVariable(InstanceID,ThreadID,templistname,"list") 
		
		tempindex:=1
		v_SetVariable(InstanceID,ThreadID,"a_index",tempindex,,c_SetLoopVar)
		
		if not isobject(templist)
		{
			logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Error! Variable '" templistname "' does not contain a list.")
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("Variable '%1%' does not contain a list.",templistname))
			return
			
		}
			
		;~ MsgBox % "a list - `n" StrObj(templist)
		if %ElementID%CopyFirst=1
		{
			templist:=templist.Clone()
			v_SetVariable(InstanceID,ThreadID,"A_LoopCurrentList",templist,,c_SetLoopVar)
			v_SetVariable(InstanceID,ThreadID,"A_LoopUseCopiedList",1,,c_SetLoopVar)
			tempFound:=false
			for tempkey, tempvalue in templist
			{
				
				;~ MsgBox %InstanceID% %ThreadID% `n %tempkey% = %tempvalue%
				v_SetVariable(InstanceID,ThreadID,"a_LoopValue",tempvalue,,c_SetLoopVar)
				v_SetVariable(InstanceID,ThreadID,"a_LoopKey",tempkey,,c_SetLoopVar)
				templist.Remove(tempkey,"")
				tempFound:=true
				break
				
			}
		}
		else
		{
			v_SetVariable(InstanceID,ThreadID,"A_LoopUseCopiedList",0,,c_SetLoopVar)
			tempFound:=false
			for tempkey, tempvalue in templist
			{
				
				if (A_Index=tempindex)
				{
					;~ MsgBox %InstanceID% %ThreadID% `n %tempkey% = %tempvalue%
					v_SetVariable(InstanceID,ThreadID,"a_LoopValue",tempvalue,,c_SetLoopVar)
					v_SetVariable(InstanceID,ThreadID,"a_LoopKey",tempkey,,c_SetLoopVar)
					tempFound:=true
					break
				}
			}
		}
		
		if tempFound
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
	
		
		
	}
	else if HeadOrTail=tail ;Continue loop
	{
		tempindex:=v_GetVariable(InstanceID,ThreadID,"A_Index")
		tempindex++
		v_SetVariable(InstanceID,ThreadID,"A_Index",tempindex,,c_SetLoopVar)
		tempUseCopiedList:=v_GetVariable(InstanceID,ThreadID,"A_LoopUseCopiedList")
		if tempUseCopiedList
		{
			templist:=v_GetVariable(InstanceID,ThreadID,"A_LoopCurrentList")
			tempFound:=false
			for tempkey, tempvalue in templist
			{
				
				v_SetVariable(InstanceID,ThreadID,"a_LoopValue",tempvalue,,c_SetLoopVar)
				v_SetVariable(InstanceID,ThreadID,"a_LoopKey",tempkey,,c_SetLoopVar)
				templist.Remove(tempkey,"")
				tempFound:=true
				break
				
			}
		}
		else
		{
			templistname:=v_replaceVariables(InstanceID,ThreadID,%ElementID%Varname) 
			templist:=v_GetVariable(InstanceID,ThreadID,templistname,"list")
			tempFound:=false
			for tempkey, tempvalue in templist
			{
				if (A_Index=tempindex)
				{
					v_SetVariable(InstanceID,ThreadID,"a_LoopValue",tempvalue,,c_SetLoopVar)
					v_SetVariable(InstanceID,ThreadID,"a_LoopKey",tempkey,,c_SetLoopVar)
					tempFound:=true
					break
				}
			}
		}
		
		
		
		if tempFound
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalHead")
		else
			MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		
		
		
	
	}
	else if HeadOrTail=break ;Break loop
	{
		
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"normalTail")
		
	}
	else
	{
		logger("f0","Instance " InstanceID " - " %ElementID%type " '" %ElementID%name "': Unexpected Error! No information whether the connection lead into head or tail")
		MarkThatElementHasFinishedRunning(InstanceID,ThreadID,ElementID,ElementIDInInstance,"exception",lang("No information whether the connection lead into head or tail") )
		return
	}

	

	return
}
getNameLoopWork_through_a_list()
{
	return lang("Work_through_a_list")
}
getCategoryLoopWork_through_a_list()
{
	return lang("Variable")
}

getParametersLoopWork_through_a_list()
{
	global
	
	parametersToEdit:=Object()
	parametersToEdit.push({type: "Label", label: lang("Variable_name")})
	parametersToEdit.push({type: "Edit", id: "Varname", default: "List", content: "VariableName", WarnIfEmpty: true})
	parametersToEdit.push({type: "Label", label: lang("Performance")})
	parametersToEdit.push({type: "Checkbox", id: "CopyFirst", default: 1, label: lang("Copy list before first iteration")})

	return parametersToEdit
}

GenerateNameLoopWork_through_a_list(ID)
{
	global
	;MsgBox % %ID%text_to_show
	return lang("Work_through_a_list") ": " GUISettingsOfElement%id%Varname 
	
}


