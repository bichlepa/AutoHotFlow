;Create a new Trigger container
ID_Count=1

;Creates a new trigger container
;This function is called only once on startup
e_newTriggerContainer()
{
	global
	tempNewID:="trigger" 
	allElements.insert(tempNewID)
	
	
	
	%tempNewID%marked=false
	%tempNewID%running:=0
	%tempNewID%Type=Trigger
	%tempNewID%Name=Νew Соntainȩr
	ui_seekForNewElementPosition()
	%tempNewID%x=%goodNewPositionX%
	%tempNewID%y=%goodNewPositionY%
	ID_Count++
	return (tempNewID)
}

;Creates a new trigger
e_NewTrigger()
{
	global
	tempNewID:="trigger" ID_Count
	allTriggers.insert(tempNewID)
	
	
	%tempNewID%Type=Trigger
	;%tempNewID%Name=Trigger
	ID_Count++
	return (tempNewID)
}

;Creates a new action
e_NewAction()
{
	global
	tempNewID:="action" ID_Count
	
	allElements.insert(tempNewID)
	%tempNewID%marked=false
	%tempNewID%running:=0
	%tempNewID%Type=Action
	%tempNewID%Name=Νew Соntainȩr
	;ui_seekForNewElementPosition()
	;%tempNewID%x=%goodNewPositionX%
	;%tempNewID%y=%goodNewPositionY%
	ID_Count++ 

	
	return (tempNewID)
}

;Creates a new condition
e_NewCondition()
{
	global
	tempNewID:="condition" ID_Count
	allElements.insert(tempNewID)
	%tempNewID%marked=false
	%tempNewID%running:=0
	
	%tempNewID%Type=Condition
	%tempNewID%Name=Νew Соntainȩr
	;ui_seekForNewElementPosition()
	;%tempNewID%x=%goodNewPositionX%
	;%tempNewID%y=%goodNewPositionY%
	ID_Count++

	return (tempNewID)
}

;Creates a new loop. ;Not used yet
e_NewLoop()
{
	global
	tempNewID:="loop" ID_Count
	allElements.insert(tempNewID)
	%tempNewID%marked=false
	%tempNewID%running:=0
	%tempNewID%heightOfVerticalBar:=Gridy*5
	
	%tempNewID%Type=Loop
	%tempNewID%Name=Νew Соntainȩr
	;ui_seekForNewElementPosition()
	;%tempNewID%x=%goodNewPositionX%
	;%tempNewID%y=%goodNewPositionY%
	ID_Count++

	return (tempNewID)
}

;Creates a new connection
;Param 	from 	ID of the element to start
;Param 	to 		ID of the element to end
;Param 	ConnectionType 		Type of connection
e_newConnection(from,to,ConnectionType="normal")
{
	global
	tempNewID:="Connection" ID_Count
	allElements.insert(tempNewID)
	%tempNewID%from:=from
	%tempNewID%to:=to
	%tempNewID%marked=false
	%tempNewID%running:=0
	%tempNewID%Type=Connection
	%tempNewID%ConnectionType=%ConnectionType%

	
	
	

	ID_Count++
	return (tempNewID)
}




;Generates the trigger name. It is genereted from all names of all triggers.
e_UpdateTriggerName()
{
	global
	triggername=Trigger`n
	for objectCount, tempTrigger in allTriggers
	{
		triggername:= triggername "- " %tempTrigger%name "`n"
	}
	ui_draw()
}

;Remove an trigger
e_removeTrigger(id)
{
	global
	for objectCount, tempDel in allTriggers
	{
		if (tempDel=id)
			allTriggers.remove(objectCount)
	}
}

;Remove an element
e_removeElement(id)
{
	global
	
	tempObject:=Object() 
	temp=0
	if (%id%Type="Action" or %id%Type="Condition" or %id%Type="Loop") ;If an element was removed, Delete also all Connections to and from that element
	{
		for index, tempdelelement in allElements 
		{
			
			if (%tempdelelement%Type="Connection") 
			{
				
				if (%tempdelelement%to=id or %tempdelelement%from=id )
				{
					tempObject.insert(index)
					
					
					temp++
				}
			
			}
			
		}
		
		for index, tempdelelement in tempObject
		{
			allElements.remove(tempdelelement-index+1) ;Change index for further deletions. After every deletion the amount of elements decreases, so the index.
			
		}
		
	}
	
	
	;Unmark deleted elements
	for objectCount, tempdelelement in allElements
	{
		if (tempdelelement=id)
		{
			if %tempdelelement%marked =true
				countMarkedElements--
			allElements.remove(objectCount)
			
		}
	}
	
}

;retrieves the element number from the id 
;Param: ID
;Return: Number
e_ElementIDtoNumber(id)
{
	global
	for objectCount, tempEl in allElements
	{
		if (tempEl=id)
			return objectCount
	}
}

;retrieves the trigger number from the id
;Param: ID
;Return: Number
e_TriggerIDtoNumber(id)
{
	global
	for objectCount, tempEl in allTriggers
	{
		if (tempEl=id)
			return objectCount
	}
	
}

;retrieves the element id from the number 
;Param: Number
;Return: ID
e_ElementNumbertoID(num)
{
	global
	for objectCount, tempEl in allElements
	{
		if (objectCount=num)
			return tempEl
	}
}

;retrieves the trigger id from the number 
;Param: Number
;Return: ID
e_TriggerNumbertoID(num)
{
	global
	for objectCount, tempEl in allTriggers
	{
		if (objectCount=num)
			return tempEl
	}
}


e_getParameter(elementName,parName)
{
	global
	tempToReturn:=%elementName%Ƥаґ%parName%
	return tempToReturn
	
	
}
e_setParameter(elementName,parName,value)
{
	global
	%elementName%Ƥаґ%parName%:=value
	
	
}

;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
e_setUnsetDefaults(elementID)
{
	global
	local elementType:=%elementID%type
	local elementSubType:=%elementID%subtype
	local parameters
	try
		parameters:=getParameters%elementType%%elementSubType%(true)
	catch
		parameters:=getParameters%elementType%%elementSubType%()
	local parameter
	local index
	local index2
	local oneID
	
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
			if %elementID%%oneID%=
				%elementID%%oneID%:=parameterdefault[index2]
			
		}
		
	
	}
	
	
}