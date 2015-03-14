;load global settings
iniread,translationto,settings.ini,common,translatingto
iniread,developing,settings.ini,common,developing
iniread,LastExecutionTime,settings.ini,common,LastExecutionTime

if LastExecutionTime=
	LastExecutionTime:=2000

iniwrite,%a_now%,settings.ini,common,LastExecutionTime
if uilang=error
{
	if A_Language=0407
		uilang=de
	else
		uilang=en
}

loadSavedFlows()
{
	global
	local filenameNoExt
	local FileFullPath
	local tempflowName
	local tempflowcategory
	local tempflowenabled
	local tempflowid
	local tempflowenabled
	;Load existing Flows
	loop Saved Flows\*.ini
	{
		StringTrimRight,filenameNoExt,A_LoopFileName,4
		iniread, tempflowName,%A_LoopFileFullPath%,general,name
		
		if (filenameNoExt!=tempflowName)
		{
			;MsgBox %tempflowName%
			FileMove,Saved Flows\%filenameNoExt%.ini,Saved Flows\%tempflowName%.ini
			if not errorlevel
			{
				;MsgBox  Saved Flows\%filenameNoExt%.ini - Saved Flows\%tempflowName%.ini
				FileFullPath=Saved Flows\%tempflowName%.ini
			}
			else
				FileFullPath:=A_LoopFileFullPath
		}
		else
			FileFullPath:=A_LoopFileFullPath
		
		iniread, tempflowcategory,%FileFullPath%,general,category,%a_space% 
		iniread, tempflowenabled,%FileFullPath%,general,enabled,false
		
		;MsgBox %FileFullPath% - %tempflowcategory%
		
		if tempflowcategory=
			tempflowcategory:=lang("uncategorized")
		
		tempflowid:=IDOf(NewFlow(tempflowName,tempflowcategory,tempflowenabled))
		%tempflowid%ini:=FileFullPath
		%tempflowid%enabled:=tempflowenabled
		if (tempflowenabled="true") ;Enable flow
		{
			;Decide whether the application has been started after a reboot. This would start the trigger "Startup".
			LastStartupTime:=a_now
			Envadd, LastStartupTime,% -(A_TickCount/1000),Seconds
			;FormatTime,LastStartupTime2,% LastStartupTime
			;FormatTime,LastExecutionTime2,% LastExecutionTime
			
			EnvSub, LastStartupTime,% LastExecutionTime,Seconds
			;FormatTime,LastStartupTime3,LastStartupTime
			;MsgBox % LastStartupTime2 "`n" LastExecutionTime2 "`n" LastStartupTime3 "`n" LastStartupTime
			if (LastStartupTime>0 )
				enableFlow(tempflowid,"Startup")
			else
				enableFlow(tempflowid)
			
		}
	}
}

SaveFlow(ID)
{
	global
	IniWrite,% %ID%name,% %ID%ini,general,name
	IniWrite,% %ID%category,% %ID%ini,general,category
	if shuttingDown<>true ;Do not save if it is shutting down and disabling the flows
		IniWrite,% %ID%enabled,% %ID%ini,general,enabled
	
	
}


