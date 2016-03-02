
globalcounter=0

;Create arrays
allElements:=new ObjectwithCounter()
allConnections:=new ObjectwithCounter()
allTriggers:=new ObjectwithCounter()
markedElements:=new ObjectwithCounter()

class ObjectwithCounter
{
	count() 
	{
		return NumGet(&this + 4*A_PtrSize)
	}
}

class commonForElements
{
	__New(elementtype,elementid="")
	{
		;~ MsgBox asve
		this.marked:=false
		this.running:=0
	}
	
	markAll()
	{
		global markedElements 
		global allElements 
		global allConnections 
		global TheOnlyOneMarkedElement 
		
		markedElements:=new ObjectwithCounter() ;remove all marked elements
		for index, tempelement in allElements ;Add all marked elements into array
		{
			tempelement.marked:=true
			markedElements.push(tempelement)
		}
		for index, tempelement in allConnections ;Add all marked elements into array
		{
			tempelement.marked:=true
			markedElements.push(tempelement)
		}
		TheOnlyOneMarkedElement:=""
		ui_UpdateStatusbartext()	
		
	}
	
	mark(additional:=false)
	{
		global markedElements
		global allConnections
		global allElements
		global TheOnlyOneMarkedElement
		
		if (additional=false)
		{
			for index, tempelement in markedElements
			{
				tempelement.marked:=false
			}
			this.marked:=true
		}
		else ;if (additional=true)
		{
			;msgbox,% toMark "`n" toMark.marked
			
			if (this.marked=true)
				this.marked:=false
			else
				this.marked:=true
		}
		
		markedElements:=new ObjectwithCounter() ;remove all marked elements
		
		;Search for marked elements
		TheOnlyOneMarkedElement=
		for index, tempelement in allElements ;Add all marked elements into array
		{
			if (tempelement.marked=true)
			{
				markedElements.push(tempelement)
				TheOnlyOneMarkedElement:=tempelement
			}
			;MsgBox,% element.id "   " element.marked
		}
		for index, tempelement in allConnections ;Add all marked elements into array
		{
			if (tempelement.marked=true)
			{
				markedElements.push(tempelement)
				TheOnlyOneMarkedElement:=tempelement
			}
			;MsgBox,% element.id "   " element.marked
		}
		if (markedElements.count()!=1)
			TheOnlyOneMarkedElement=
		
		;ToolTip("-" element.id "-" element.marked "-" TheOnlyOneMarkedElement )
		ui_UpdateStatusbartext()
	}
	
	unmarkAll()
	{
		global markedElements 
		global allElements 
		global allConnections 
		global TheOnlyOneMarkedElement 
		
		markedElements:=new ObjectwithCounter() ;remove all marked elements
		for index, tempelement in allElements ;Add all marked elements into array
		{
			tempelement.marked:=false
		}
		for index, tempelement in allConnections ;Add all marked elements into array
		{
			tempelement.marked:=false
		}
		TheOnlyOneMarkedElement:=""
		ui_UpdateStatusbartext()
	}
	
	IDtoObject(ID)
	{
		global allelements
		global allConnections
		global allTriggers
		
		for index, tempelement in allelements
		{
			if (tempelement.id=id)
				return tempelement
		}
		for index, tempelement in allConnections
		{
			if (tempelement.id=id)
				return tempelement
		}
		for index, tempelement in allTriggers
		{
			if (tempelement.id=id)
				return tempelement
		}
		return
	}
	
	
	
}

class element extends commonForElements ;Such as action, trigger (container), condition, loop
{
	__New(elementtype="",elementid=""){
		base.__new(elementtype,elementid)
		;~ MsgBox % this.marked
		global globalcounter
		global allElements
		global GridX, Gridy
		
		if (elementid="")
			this.ID:="element" . format("{1:010u}",++globalcounter) 
		else
			this.ID:=elementid
		
		this.ClickPriority:=500
		this.par:=[]
		
		;Assign default position, although it is commonly not needed (except when creating the trigger container)
		this.x:=GridX * 9
		this.y:=Gridy * 5
		
		this.type:=elementtype
		
		allElements[this.id]:=this
		;~ MsgBox % "+++"  this.type "  " this.id "  " this.name
	}
	
	type[] ;When changing type, set some default values depending on element type
	{
		set
		{
			this._type:=value 
			
			if (this.type="Trigger")
			{
				this.triggers:=new ObjectwithCounter()
				this.name:=""
			}
			else
				this.name:="Νew Соntainȩr"
			
			if (this.type="Loop")
			{
				this.heightOfVerticalBar:=150
			}
		}
		get
		{
			return this._type
		}
		
	}
	
	
	;Deletes the element from list of all elements
	remove()
	{
		global allElements
		global allConnections
		global markedElements
		
		if this.type="trigger"
			return
		
		;remove the element from list of all elements
		for index, tempelement in allElements
		{
			if (tempelement=this)
			{
				allElements.delete(index)
				break
			}
		}
		
		;If the element is marked, unmark it
		for index, tempelement in markedElements
		{
			if (tempelement=this)
			{
				this.unmarkAll() ;Unmark all elements
				break
			}
		}
		
		;remove the connections which end or start at the element ;TODO: if removing an element with only one connection from and one connection to the element, keep one connection
		copyAllConnections:=allConnections.clone()
		for index, tempelement in copyAllConnections
		{
			if ((tempelement.from=this.id) or (tempelement.to=this.id))
			{
				tempelement.remove()
			}
		}
		
		
	}
	
	;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
	setUnsetDefaults()
	{
		global
		local parameter, parameters, tempContent, index, index2, oneID
		
		local elementType, elementSubType
		elementType:=this.type
		elementSubType:=this.subtype
		
		parameters:=%elementType%%elementSubType%.getParameters()
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
				if (this.par[oneID]="")
				{
					tempContent:=parameterdefault[index2]
					
					StringReplace, tempContent, tempContent, |¶,`n, All
					this.par[oneID]:=tempContent
				}
				
			}
			
		
		}
		
		
	}
	
	
	
	
	
	
	
}

class connection extends commonForElements
{
	__New(elementtype="",elementid=""){
		base.__new(elementtype,elementid)
		
		global globalcounter
		global allConnections
		
		this.marked:=false
		this.running:=0
		this.ClickPriority:=200
		
		this.ConnectionType:="normal"
		
		if (elementid="")
			this.ID:="connection" . format("{1:010u}",++globalcounter) 
		else
			this.ID:=elementid
		this.type:="Connection"
		
		allConnections[this.id]:=this
		;~ MsgBox % "+++"  this.type "  " this.id "  " this.name
	}
	
	
	;Deletes the element from list of all elements
	remove()
	{
		global allConnections
		global markedElements
		for index, tempelement in allConnections
		{
			if (tempelement=this)
			{
				allConnections.delete(index)
				break
			}
		}
		for index, tempelement in markedElements
		{
			if (tempelement=this)
			{
				this.unmarkAll()
				break
			}
		}
		
	}
	
	
	
}

class trigger extends commonForElements
{
    ;~ static type := "trigger"
    static subtype := ""
	static ID:=""
	static name:="Νew Triggȩr"
	static active:=0
	
	
	__New(TriggerContainer,elementid=""){
		global globalcounter
		global allTriggers
		allTriggers.push(this)
		if (elementid="")
			this.ID:="trigger" . format("{1:010u}",++globalcounter) 
		else
			this.ID:=elementid
		TriggerContainer.triggers.push(this)
		
		this.ContainerID:=TriggerContainer
		this.par:=[]
		
		this.refreshTriggerList()
		this.type:= "trigger"
		;~ MsgBox % "+++"  this.type "  " this.id "  " this.name
	}
	
	;Deletes the element from list of all elements
	remove()
	{
		global allElements
		global allTriggers
		for index, tempelement in allElements
		{
			if (tempelement.type="trigger")
			{
				for index, trigger in tempelement.triggers
				{
					if (trigger=this)
					{
						tempelement.triggers.delete(index)
					}
					
				}
			}
		}
		this.refreshTriggerList()
	}
	
	;Is called when the element subtype is set. All parameters that are not set yet are set to the default parameters
	setUnsetDefaults()
	{
		global
		local elementType:=this.type
		local elementSubType:=this.subtype
		local parameters
		try
			parameters:=%elementType%%elementSubType%.getParameters(true)
		catch
			parameters:=%elementType%%elementSubType%.getParameters()
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
				if this.par[oneID]=
					this.par[oneID]:=parameterdefault[index2]
				
			}
			
		
		}
		
		
	}
	
	
	IDtoObject(ID)
	{
		global alltriggers
		
		for index, ele in alltriggers
		{
			if (ele.id=id)
				return ele
		}
		return
	}
	
	refreshTriggerList()
	{
		global allElements
		global alltriggers
		for index, tempelement in allElements
		{
			if (tempelement.type="trigger")
			{
				for index, trigger in tempelement.triggers
				{
					alltriggers.push(trigger)
					
				}
			}
		}
	}
	
	
	
	UpdateName() ;only for triggers
	{
		this.name:=""
		for index, trigger in this.triggers
		{
			this.name:=trigger.name "; ●"
			
		}
		this.name:=substr(this.name,1,-3)
	}
	
}