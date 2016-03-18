/* Prototypes
Element_New(p_type,p_elementID)
Element_SetType(p_elementID,p_elementType)
Element_setParameterDefaults(p_elementID)
Element_Remove(p_elementID)
MarkOne(p_ID,false)
UnmarkEverything()
MarkEverything()
Connection_New(p_elementID)
Connection_Remove(p_elementID)
Trigger_New(p_ElementID,p_TriggerID)
trigger_Remove(p_TriggerID)
Trigger_setParameterDefaults(p_triggerID)
TriggerContainer_UpdateName(p_ElementID)
GetListContainingElement(p_ElementID)
*/


globalcounter=0

;Create arrays
allElements:=CriticalObject()
allConnections:=CriticalObject()
allTriggers:=CriticalObject()
markedElements:=CriticalObject()

;Creates a new element and puts it in the array "allelements"
Element_New(p_type="",p_elementID="")
{
	global globalcounter
	global allElements
	global GridX, Gridy
	global mainTriggerContainer
	
	tempElement:=CriticalObject()
	;~ tempElement:=[]
	
	if (p_elementID="")
		tempElement.ID:="element" . format("{1:010u}",++globalcounter) 
	else
		tempElement.ID:=p_elementID
	
	;~ d(p_elementID "--" tempElement.ID)
	
	tempElement.ClickPriority:=500
	;~ d(p_elementID "--" tempElement.ID "--" tempElement.ClickPriority)
	tempElement.par:=[]
	
	tempElement.marked:=false
	tempElement.state:="idle"
	
	;Assign default position, although it is commonly not needed (except when creating the trigger container)
	tempElement.x:=GridX * 9
	tempElement.y:=Gridy * 5
	
	;Save the main trigger ID in order to find it globally.
	if (p_type="trigger")
		mainTriggerContainer:=p_ElementID
	 
	allElements[tempElement.id]:=tempElement
	
	Element_SetType(tempElement.ID,p_type)
	
	return tempElement.ID
}

;Sets the element type. It could later be possible to change the element type (e.g. change from type "action" to type "condition")
Element_SetType(p_elementID,p_elementType)
{
	global allElements
	allElements[p_elementID].type:=p_elementType 
	
	if (p_elementType="Trigger")
	{
		allElements[p_elementID].triggers:=new CriticalObject()
		allElements[p_elementID].name:=""
	}
	else
		allElements[p_elementID].name:="Νew Соntainȩr"
	
	if (p_elementType="Loop")
	{
		allElements[p_elementID].heightOfVerticalBar:=150
	}
}


;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
Element_setParameterDefaults(p_elementID)
{
	global allelements
	
	elementType:=allElements[p_elementID].type
	elementSubType:=allElements[p_elementID].subtype
	
	parameters:=%elementType%%elementSubType%_getParameters()
	;~ MsgBox % strobj(parameters) "`n" elementType "`n" elementSubType
	for index, parameter in parameters
	{
		
		if not IsObject(parameter.id)
			parameterID:=[parameter.id]
		else
			parameterID:=parameter.id
		if not IsObject(parameter.default)
			parameterdefault:=[parameter.default]
		else
			parameterdefault:=parameter.default
	
		if (parameterID[1]="" or parameter.type="label" or parameter.type="SmallLabel") ;If this is only a label for the edit fielt etc. Do nothing
			continue
		
		;~ MsgBox % strobj(parameter)
		;Certain types of control consist of multiple controls and thus contain multiple parameters.
		for index2, oneID in parameterID
		{
			;~ MsgBox % oneID "  -  " index2 " - " parameterdefault[index2]
			if (allElements[p_elementID].par[oneID]="")
			{
				tempContent:=parameterdefault[index2]
				
				StringReplace, tempContent, tempContent, |¶,`n, All
				allElements[p_elementID].par[oneID]:=tempContent
			}
			
		}
		
	
	}
	
	
}

;Removes the element. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Element_Remove(p_elementID)
{
	global allElements
	global allConnections
	global markedElements
	
	;If the element is a connection, call function to delete connection
	IfInString,p_elementID,connection
	{
		Connection_Remove(p_elementID)
		return
	}
	
	
	if allElements[p_elementID].type="trigger" ;The trigger container cannot be removed
		return
	
	;remove the element from list of all elements
	for forID, forElement in allElements
	{
		if (forID=p_elementID)
		{
			allElements.delete(forID)
			break
		}
	}
	
	;If the element is marked, unmark it
	for forID, forElement in markedElements
	{
		if (forID=p_elementID)
		{
			UnmarkEverything() ;Unmark all elements
			break
		}
	}
	
	;remove the connections which end or start at the element ;TODO: if removing an element with only one connection from and one connection to the element, keep one connection
	copyAllConnections:=allConnections.clone()
	for forID, forElement in copyAllConnections
	{
		if ((forElement.from=p_elementID) or (forElement.to=p_elementID))
		{
			Connection_Remove(forID)
		}
	}
	
}

;mark an element or connection. If parameter additional is true, mark it additionally to others
MarkOne(p_ID,additional:=false)
{
	global markedElements
	global markedElement
	global allConnections
	global allElements
	;~ ToolTip,% p_id " - " additional
	if (p_ID="")
		return
	tempList:=GetListContainingElement(p_ID)
	
	
	if (additional=false)
	{
		markedElementsClone:=markedElements.clone() 
		for forID, forID2 in markedElementsClone ;unmark all elements
		{
			tempList2:=GetListContainingElement(forID)
			tempList2[forID].marked:=false
			markedElements.delete(forID)
		}
		tempList[p_ID].marked:=true ;mark the element
		markedElements[p_ID]:=p_ID
	}
	else ;if (additional=true)
	{
		;~ if (tempList[p_ID].marked=true)
			;~ tempList[p_ID].marked:=false
		;~ else
			tempList[p_ID].marked:=true
		markedElements[p_ID]:=p_ID
	}
	
	
	if (markedElements.count()=1)
	{
		for forID, forID2 in markedElements
		{
			markedElement:=forID
		}
	}
	else
		markedElement:=""
	;~ ToolTip("-" p_ID "-" tempList[p_ID].marked "-" markedElement )
	ui_UpdateStatusbartext()
}

;Unmark all elements and connections
UnmarkEverything()
{
	global markedElements 
	global markedElement
	global allElements 
	global allConnections 
	
	;remove all marked elements
	markedElementsClone:=markedElements.clone() 
	for forID, forElement in markedElementsClone
	{
		markedElements.delete(forID)
	} 
	
	for forID, forElement in allElements ;Add all marked elements into array
	{
		allElements[forID].marked:=false
	}
	for forID, forElement in allConnections ;Add all marked elements into array
	{
		allConnections[forID].marked:=false
	}
	markedElement:=""
	ui_UpdateStatusbartext()
	
}

MarkEverything()
{
	global markedElement
	global markedElements 
	global allElements 
	global allConnections 
	
	;remove all marked elements
	markedElementsClone:=markedElements.clone() 
	for forID, forElement in markedElementsClone
	{
		markedElements.delete(forID)
	} 
	
	for forID, forElement in allElements ;Add all marked elements into array
	{
		allElements[forID].marked:=true
		markedElements[forID]:=forID
	}
	for forID, forElement in allConnections ;Add all marked elements into array
	{
		allElements[forID].marked:=true
		markedElements[forID]:=forID
	}
	
	if (markedElements.count()=1)
	{
		for forID, forID2 in markedElements
		{
			markedElement:=forID
		}
	}
	else
		markedElement:=""
	
	ui_UpdateStatusbartext()	
}


Connection_New(p_elementID="")
{
	global globalcounter
	global allConnections
	
	tempElement:=CriticalObject()
	
	if (p_elementID="")
		tempElement.ID:="connection" . format("{1:010u}",++globalcounter) 
	else
		tempElement.ID:=p_elementID
	
	tempElement.ConnectionType:="normal"
	tempElement.ClickPriority:=500
	
	tempElement.marked:=false
	tempElement.state:="idle"
	tempElement.type:="Connection"
	
	allConnections[tempElement.id]:=tempElement
	
	return tempElement.ID
}


;Removes the connection. It will be deleted from list of all elements and all connections which start or ends there will be deleted, too
Connection_Remove(p_elementID)
{
	global allConnections
	global markedElements
	
	;remove the element from list of all connections
	for forID, forElement in allConnections
	{
		if (forID=p_elementID)
		{
			allConnections.delete(forID)
			break
		}
	}
	
	;If the element is marked, unmark it
	for forID, forElement in markedElements
	{
		if (forID=p_elementID)
		{
			UnmarkEverything() ;Unmark all elements
			break
		}
	}
	
	
}


;Create a new trigger. Put the trigger in the list of all triggers and also put the trigger ID in the list of triggers in the trigger container
Trigger_New(p_ElementID,p_TriggerID)
{
	global globalcounter
	global allTriggers
	global allElements
	
	tempTrigger:=CriticalObject()
	tempTrigger.name:="Νew Triggȩr"
	tempTrigger.type:= "trigger"
	tempTrigger.active:=false
	
	if (p_TriggerID="")
		tempTrigger.ID:="trigger" . format("{1:010u}",++globalcounter) 
	else
		tempTrigger.ID:=p_TriggerID
	
	tempTrigger.ContainerID:=p_ElementID
	tempTrigger.par:=[]
	
	
	allElements[p_ElementID].triggers[tempTrigger.ID]:=tempTrigger.ID
	
	allTriggers[tempTrigger.id]:=tempTrigger
	return tempTrigger.ID
}

trigger_Remove(p_TriggerID)
{
	global allElements
	global allTriggers
	
	allElements[allTriggers[p_TriggerID].ContainerID].delete(p_TriggerID)
	allTriggers.delete(p_TriggerID)
}

Trigger_setParameterDefaults(p_triggerID)
{
	Element_setParameterDefaults(p_triggerID)
}

TriggerContainer_UpdateName(p_ElementID)
{
	global allTriggers, allelements
	tempName:=""
	for forID, forID2 in p_ElementID.triggers
	{
		tempName:=allTriggers[forID].name "; ●"
	}
	allelements[p_ElementID].name:=substr(tempName,1,-3)
	
}

GetListContainingElement(p_ElementID)
{
	global 
	if allElements.HasKey(p_ElementID)
		return allElements
	else if allConnections.HasKey(p_ElementID)
		return allConnections
	else if allTriggers.HasKey(p_ElementID)
		return allTriggers
	
}
