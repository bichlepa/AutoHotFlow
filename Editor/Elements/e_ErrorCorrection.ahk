
;This function is called after loading a flow, or after changes like adding a flow, removing connetion ...
e_CorrectElementErrors(DescriptionWhatWasDoneBefore)
{
	global
	
	e_CorrectDoubleConnections(DescriptionWhatWasDoneBefore)
	e_CorrectConnectionsLeadingToNowhere(DescriptionWhatWasDoneBefore)
	e_CorrectEmptyContainer(DescriptionWhatWasDoneBefore)
	e_CorrectEmptyTrigger(DescriptionWhatWasDoneBefore)
}

;Seek for double connections
e_CorrectDoubleConnections(DescriptionWhatWasDoneBefore)
{
	global
	local tempIDOld
	local tempstring
	local tempstringOfAll:=Object()
	local copyofallelements:=allElements.clone()
	for count, tempID in copyofallelements
	{
		if %tempID%type=connection
		{
			tempstring:=%tempID%from "_" %tempID%to "_" %tempID%ConnectionType
			
			if not (tempstringOfAll.HasKey(tempstring))
			{
				tempstringOfAll[tempstring]:=tempID
				;~ MsgBox % tempstringOfAll[tempstring] "`n`n" StrObj(tempstringOfAll)
			}
			else
			{
				tempIDOld:=tempstringOfAll[tempstring]
				if not a_iscompiled
					MsgBox,, Error! ,% "Connections " tempIDOld " and " tempID " are identical" "`n" DescriptionWhatWasDoneBefore "`n`n" StrObj(tempstringOfAll)
				
				e_removeElement(tempID)
			}
			
		}
		
	}
	
}

;Seek for connections which lead to an unexistent element or to the mouse
e_CorrectConnectionsLeadingToNowhere(DescriptionWhatWasDoneBefore)
{
	global
	local copyofallelements:=allElements.clone()
	local result
	local tempIDContainer
	local tempIDPart
	
	for count, tempID in copyofallelements
	{
		
		if %tempID%type=connection
		{
			loop 2
			{
				
				if a_index=1
					tempIDContainer:=%tempID%from
				else
					tempIDContainer:=%tempID%to
				
				result:=false
			
				for count2, tempID2 in allElements
				{
					if (tempID2=tempIDContainer)
					{
						result:=true
						break
					}
				}
				if not result
				{
					if not a_iscompiled
						MsgBox,, Error! ,% "Connection " tempID " starts or ends at an unexistent element " tempIDContainer "`n" DescriptionWhatWasDoneBefore "`n`n" StrObj(allElements)
					e_removeElement(tempID)
					break
				}
				
				if %tempIDContainer%type=loop
				{
					;~ MsgBox loop
					if a_index=1
						tempIDPart:=%tempID%frompart
					else
						tempIDPart:=%tempID%topart
					
					if (tempIDPart!="Head" and tempIDPart!="Tail" and tempIDPart!="BREAK")
					{
						if not a_iscompiled
						MsgBox,, Error! ,% "Connection " tempID " starts or ends at a loop " tempIDContainer " but it has no information whether it leads from or to tail or head "  "`n" DescriptionWhatWasDoneBefore "`n`n" StrObj(allElements)
						e_removeElement(tempID)
						break
						
					}
				}
				
			}
			
			
			
			
			
			
			
		}
		
	}
	
}

;Seek for container which do not contain any action.
e_CorrectEmptyContainer(DescriptionWhatWasDoneBefore)
{
	global
	local copyofallelements:=allElements.clone()
	
	for count, tempID in copyofallelements
	{
		if (%tempID%type="action" or %tempID%type="condition" or %tempID%type="loop")
		{
			if %tempID%name=Νew Соntainȩr
			{
				if not a_iscompiled
					MsgBox,, Error! ,% %tempID%type " " tempID " is invalid. It is named 'Νew Соntainȩr'." "`n" DescriptionWhatWasDoneBefore 
				e_removeElement(tempID)
			}
			
			if %tempID%subtype=
			{
				if not a_iscompiled
					MsgBox,, Error! ,% %tempID%type " " tempID " is invalid. It has no subtype." "`n" DescriptionWhatWasDoneBefore 
				e_removeElement(tempID)
			}
			
			
		}
		
	}
	
}

;Seek for trigger which do not contain any action.
e_CorrectEmptyTrigger(DescriptionWhatWasDoneBefore)
{
	global
	local copyofallelements:=allTriggers.clone()
	
	for count, tempID in copyofallelements
	{
		
			if %tempID%name=
			{
				if not a_iscompiled
					MsgBox,, Error! ,% %tempID%type " " tempID " is invalid. It has no name." "`n" DescriptionWhatWasDoneBefore 
				%tempID%name=% lang("Unnamed trigger")
			}
			
			if %tempID%subtype=
			{
				if not a_iscompiled
					MsgBox,, Error! ,% %tempID%type " " tempID " is invalid. It has no subtype." "`n" DescriptionWhatWasDoneBefore 
				e_removeTrigger(tempID)
			}
			
			
		
	}
	
}