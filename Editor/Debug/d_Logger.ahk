FileCreateDir,Log

logger(LogLevel,LoggingText)
{
	global 
	
	static LogCount
	static NextTidyOnLogCount
	local timestamp
	local temp
	local lastfield
	local state
	local shouldLog:=false
	LogCount++
	;~ ToolTip,%LogLevel% - %DebugLogLevel%
	state=1
	
	Loop, parse, LogLevel
	{
		
		If state=1
		{
			
			if A_LoopField=a
			{
				
				lastfield=a
				state=2
			}
			else if A_LoopField=f
			{
				lastfield=f
				state=2
			}
		}
		else If state=2
		{
			;~ MsgBox %A_LoopField%
			if A_LoopField is number
			{
				if lastfield=a
				{
					
					if (A_LoopField <= DebugLogLevelApp)
						shouldLog:=true
				}
				else if lastfield=f
				{
					if (A_LoopField <= DebugLogLevelFlow)
						shouldLog:=true
				}
			}
			state=1
		}
		if shouldLog
			break
	}
	
	
	If shouldLog
	{
		FormatTime,timestamp,a_now,yyyy MM dd HH:mm:ss
		DebugLogContent.="`n--- " timestamp " " LoggingText
		if (flowSettings.LogToFile=true)
		{
			
			FileAppend,`n--- %timestamp% %LoggingText%,% "Log\Log " flowSettings.Name ".txt",UTF-8
			
		}
	}
	if (LogCount > NextTidyOnLogCount)
	{
		NextTidyOnLogCount+=20
		StringRight,DebugLogContent,DebugLogContent,10000 ;Leave a limited count of characters in the log
		
		FileGetSize,temp,Log.txt,K
		if temp>100
			FileMove,"Log\Log " flowSettings.Name ".txt","Log\Log " flowSettings.Name " Old.txt",1
	}
}


showlog()
{
	global 
	local temph:=A_ScreenHeight*0.7
	local tempw:=A_ScreenWidth*0.8
	gui,log:add,edit, h%temph% w%tempw% ReadOnly vGuiLogTextField, %DebugLogContent%
	gui,log:add,button,w%tempw% h30 Y+10 xp gGuiLogClose default,% lang("Close")
	gui,log:show,,% lang("Log of flow %1%",flowSettings.Name)
	DebugLogContentOld:=DebugLogContent
	SetTimer,refreshLogGUI,100
	
	return
	
	logguiclose:
	GuiLogClose:
	gui,log:destroy
	SetTimer,refreshLogGUI,off
	return
	
	refreshLogGUI:
	if (DebugLogContentOld != DebugLogContent)
	{
		DebugLogContentOld:=DebugLogContent
		GuiControl,log:,GuiLogTextField,%DebugLogContent%
	}
	
	return
	
}