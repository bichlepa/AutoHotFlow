FileCreateDir,Log

;Loglevels:
; a0 - a3 	Application log
; f0 - f3 	Flow log
; t0 - t3 	Multithreading log
; 0: only errors
; 1: major logs
; 2: more logs
; 3: all logs

DebugLogLevelApp:=3
DebugLogLevelFlow:=3
DebugLogLevelThread:=3
SettingFlowLogToFile:=true
logger(LogLevel,LoggingText)
{
	global 
	static LogCount
	local timestamp
	local temp
	local lastfield
	local state
	local shouldLog:=false
	_share.LogCount++
	_share.logcountAfterTidy++
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
			else if A_LoopField=t
			{
				lastfield=t
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
				else if lastfield=t
				{
					if (A_LoopField <= DebugLogLevelThread)
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
		DebugLogLastEntry:="`n--- " timestamp " ~" Global_ThisThreadID "~ " LoggingText
		_share.log.=DebugLogLastEntry
		if SettingFlowLogToFile
		{
			FileAppend,% DebugLogLastEntry,Log\Log.txt,UTF-8
		}
	}
	
	if (_share.LogCount > 50)
	{
		;~ MsgBox % _share.log
		templog:=_share.log
		stringgetpos,templogpos,templog,`n
		_share.log:=substr(templog,templogpos+2)
		;~ MsgBox % templogpos "`n" _share.log
		
		FileGetSize,temp,Log\Log.txt,K
		if temp>10000
			FileMove,Log\Log.txt,Log\Log Old.txt,1
		_share.logcountAfterTidy := 0
	}
}


showlog()
{
	global 
	local temph:=A_ScreenHeight*0.7
	local tempw:=A_ScreenWidth*0.8
	
	gui,log:destroy
	gui,log:add,edit, h%temph% w%tempw% ReadOnly vGuiLogTextField, % _share.log
	gui,log:add,button,w%tempw% h30 Y+10 xp gGuiLogClose default,% lang("Close")
	gui,log:show,,% lang("Log")
	
	DebugLogContentOld:=_share.log
	SetTimer,refreshLogGUI,1000
	
	return
	
	logguiclose:
	GuiLogClose:
	gui,log:destroy
	SetTimer,refreshLogGUI,off
	return
	
	refreshLogGUI:
	if not (DebugLogContentOld == _share.log)
	{
		DebugLogContentOld:=_share.log
		GuiControl,log:,GuiLogTextField,% _share.log
	}
	
	return
	
}