NewCategory(Newname,new="")
{
	global
	tempNewname:=Newname
	
	if new=new
	{
		Loop
		{
			tempfound=false
			tempindex:=a_index
			for tempcount,tempitem in allItems
			{
				if (%tempitem%name=tempNewname and %tempitem%type="category")
				{
					tempNewname:=Newname " " tempindex
					tempfound=true
					
				}
				;MsgBox,%tempcategoryexist% 
			}
			if tempfound=false
				break
		}
	}
	else
	{
		for tempcount,tempitem in allItems
		{
			if (%tempitem%name=tempNewname and %tempitem%type="category")
			{
				
				return TVOf(tempItem)
				
			}
			;MsgBox,%tempcategoryexist% 
		}
	}
	
	tempNewCategory:="item" IDCount2
	allItems.insert(tempNewCategory)
	%tempNewCategory%Name:=tempNewname
	%tempNewCategory%Type=Category
	%tempNewCategory%TV:=TV_Add(%tempNewCategory%Name,"","icon4")
	tempTVNumber:=%tempNewCategory%TV
	%tempTVNumber%ID:=tempNewCategory
	;TV_Modify(%tempNewCategory%TV)
	IDCount2++
	return tempTVNumber
}

NewFlow(NewName,Categoryname="",enabled="false",CreateNewFile=false)
{
	global
	
	if Category=
		Category=lang("Uncategorized")
	
	tempCategoryID:=IDOfName(Categoryname,"category")
	if (tempCategoryID="")
	{
		tempCategoryTV:=NewCategory(Categoryname)
		tempCategoryID:=IDOf(tempCategoryTV)
	}
	else
		tempCategoryTV:=TVOf(tempCategoryID)

	
	tempNewFlow=item%IDCount2%
	allItems.insert(tempNewFlow)
	%tempNewFlow%Name:=NewName
	%tempNewFlow%Type=Flow
	%tempNewFlow%category:=%tempCategoryID%name
	%tempNewFlow%enabled:=enabled
	
	if (CreateNewFile=true)
	{
		%tempNewFlow%ini:="Saved Flows\" %tempNewFlow%Name ".ini"
		
		Loop ;Create a new file but do not overwrite existing file. Change file name if necessary.
		{
			if FileExist(%tempNewFlow%ini)
			{
				%tempNewFlow%ini:= "Saved Flows\" %tempNewFlow%Name a_index ".ini"
				%tempNewFlow%Name:=NewName " " a_index
			}
			else
			{
				SaveFlow(tempNewFlow)
				break
			}
			
		}
	}
	
	tempTVNumber:= TV_Add(%tempNewFlow%name,tempCategoryTV,"Icon1")
	
	
	%tempNewFlow%TV:=tempTVNumber
	%tempTVNumber%id:=tempNewFlow
	TV_Modify(Category,"expand")
	
	;TV_Modify(tempTVNumber)
	IDCount2++
	return tempTVNumber
}

MoveFlow(ID,TO)
{
	global
	
	%ID%category:=TO
	TV_Delete(%ID%TV)
	
	tempTVNumber:= TV_Add(%ID%name,TVOf(IDOfName(TO,"category")))
	
	%ID%TV:=tempTVNumber
	%tempTVNumber%id:=ID
	updateIcon(ID)
	SaveFlow(ID)
	
}



enableFlow(ID,options="")
{
	global
	if options=Startup
	{
		ControlSetText,edit1,enable|startup,CommandWindowOfEditor,% "Ѻ" nameOf(ID) "Ѻ" ;Try to send the command to the command window of the editor, if it is already open
		if errorlevel
			run,% editorpath  " enableFlow """ %ID%ini " "" ""startup""" 
		
	}
	else
	{
		ControlSetText,edit1,enable,CommandWindowOfEditor,% "Ѻ" nameOf(ID) "Ѻ" ;Try to send the command to the command window of the editor, if it is already open
		if errorlevel
			run,% editorpath  " enableFlow """ %ID%ini " """
	}
	
}

disableFlow(ID)
{
	global
	ControlSetText,edit1,disable,CommandWindowOfEditor,% "Ѻ" nameOf(ID) "Ѻ" ;Send the command to the Editor.
	
}






TVOf(tempItem)
{
	global
	
	if !(tempItem>1 and tempitem<10000000000000000)
	{
		tempItem:= %tempItem%TV
		
	}

	return (tempItem)
}

IDOf(tempItem)
{
	global
	
	if (tempItem>1 and tempitem<10000000000000000)
	{
		tempItem:= %tempItem%ID
	}
	return (tempItem)
}
TypeOf(tempItem)
{
	global
	if (tempItem>1 and tempitem<10000000000000000)
	{
		tempItem:= IDOf(tempItem)
	}
	return (%tempItem%type)
}
NameOf(tempItem)
{
	global
	
	if (tempItem>1 and tempitem<10000000000000000)
	{
		tempItem:= IDOf(tempItem)
	}
	return (%tempItem%name)
}

IDOfName(tempname,Type="") ;Returns the id by name
{
	global
	for count, tempitem in allItems
	{
		if %tempitem%name=%tempname%
		{
			if type=flow
			{
				if %tempitem%type=Flow
				return tempitem
			}
			else if type=Category
			{
				if %tempitem%type=Category
				return tempitem
			}
			else
				return tempitem
		}
		
	}
	return 
}







DisableMainGUI()
{
	global
	gui,1:+disabled
	
}
EnableMainGUI()
{
	global
	gui,1:-disabled
	WinActivate,•AutoHotFlow•
}

updateIcon(tempItem)
{
	global
	gui,1:default
	tempID:=IDOf(tempItem)
	tempTV:=TVOf(tempItem)
	if %tempID%running=true
		TV_Modify(tempTV,"icon3")
	else if %tempID%enabled=true
		TV_Modify(tempTV,"icon2")
	else
		TV_Modify(tempTV,"icon1")
	
	;ToolTip(tempID "--" tempTV "..." )
}




setGlobalVariable(var,value,noSave="")
{
	global
	
	globalVariables.insert(var,value)
	
	IfNotInString,allGlobalVariableNames,%var%
		allGlobalVariableNames=%allGlobalVariableNames%%var%|
	if !(noSave="noSave")
	{
		IniWrite,%value%,settings.ini,global Variables,%var%
		IniWrite,%allGlobalVariableNames%,settings.ini,global Variables,allVariableƝames
		
	}
	
}

getGlobalVariable(var)
{
	global
	
	return globalVariables[var]
	
}

deleteGlobalVariable(var)
{
	global
	globalVariables.remove(var)
	
}




removeUncategorizedCategoryIfPossible()
{
	global
	if (IDOfName(lang("uncategorized"),"Category")!="")
	{
		tempfound=false ;Delete the category uncategorized if there are no more flows
		for count, tempItem in allItems 
		{
			;debug()
			if (%tempItem%category=lang("uncategorized"))
			{
				tempfound=true
			}
		}
		if tempfound=false
		{
		tempUncategorizedTV:=TVOf(IDOfName(lang("uncategorized","Category")))
		TV_Delete(tempUncategorizedTV) ;Delete the category
			for count, tempItem in allItems
			{
				if (tempItem=idof(tempUncategorizedTV))
				{
					
					allItems.Remove(count,count)
					break
				}
			}
		}
	}


}




goto,Jumpoverthoselabels

removetooltip:
ToolTip
return

Jumpoverthoselabels:
temp=

ToolTip(text,duration=1000)
{
	global
	
	ToolTip_text:=text
	ToolTip_duration:=duration
	ToolTip,%ToolTip_text%
	SetTimer,Tooltip_follow_mouse,10
	
	SetTimer,Tooltip_RemoveTooltip,-%ToolTip_duration%
	
	return
	Tooltip_follow_mouse:
	ToolTip,%ToolTip_text%
	return
	Tooltip_RemoveTooltip:
	SetTimer,Tooltip_follow_mouse,off
	ToolTip
	return
	
}

debug()
{
	global
	loop 100
	{
		if AllItems%A_Index%!=
			AllItems%A_Index%=
		if globalVariables%A_Index%!=
			globalVariables%A_Index%=
		
	}
	for count, temp in AllItems
	{
		AllItems%count%:=temp
	}
	for count, temp in globalVariables
	{
		globalVariables%count%:=temp
	}
	
	MsgBox,debugging
}


