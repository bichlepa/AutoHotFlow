FileCreateDir,Log

;Loglevels:
; a0 - a3 	Application log
; f0 - f3 	Flow log
; t0 - t3 	Multithreading log
; 0: only errors
; 1: major logs
; 2: more logs
; 3: all logs


if not fileexist(_WorkingDir "\Log")
	FileCreateDir, % _WorkingDir "\Log"

logger(LogLevel,LoggingText, logSource="common")
{
	global 
	static LogCount
	local timestamp
	local temp
	local lastfield
	local state
	local shouldLog:=false
	_share.LogCount++
	_share.logTidyCountdown--
	
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
					
					if (A_LoopField <= _settings.LogLevelApp)
						shouldLog:=true
				}
				else if lastfield=f
				{
					if (A_LoopField <= _settings.LogLevelFlow)
						shouldLog:=true
				}
				else if lastfield=t
				{
					if (A_LoopField <= _settings.LogLevelThread)
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
		DebugLogLastEntry:="`n--- " timestamp " ~" _ahkThreadID "~ " LoggingText
		_share.log.=DebugLogLastEntry
		_share["log_" logSource].=DebugLogLastEntry
		if (_settings.logtofile)
		{
			EnterCriticalSection(_cs.debug)
			FileAppend,% DebugLogLastEntry,%_WorkingDir%\Log\Log.txt,UTF-8
			FileAppend,% DebugLogLastEntry,%_WorkingDir%\Log\Log_%logSource%.txt,UTF-8
			LeaveCriticalSection(_cs.debug)
		}
	}
	
}


showlog(whichone="all")
{
	global 
	GuiLogFontSize:=8
	GuiLogTextFieldRows:=0
	GuiLogButtonsHeigth:=30
	GuiLogMode:="update"
	GuiLogCategory:=whichone
	gui,log:destroy
	gui,log:font,s%GuiLogFontSize%
	gui,log: add, dropdownlist, vGuiLogCategory gGuiLogCategory
	gui,log: add, button,gGuiLogrefresh vGuiLogrefresh, % lang("Refresh")
	gui,log:add,button,gGuiLogClose vGuiLogClose default,% lang("Close")
	gui,log:add,button,gGuiLogModeChange vGuiLogModeChange default,% lang("Show all logs")
	gui,log:add,edit, ReadOnly vGuiLogTextField Multi -wrap VScroll HScroll
	gui,log:+resize
	gui,log:+MinSize500x300
	
	GuiControl,log:ChooseString,GuiLogCategory, %whichone%
	
	DebugLogOldCount:=0
	SetTimer,GuiLogrefreshText,100
	gosub GuiLogrefresh
	;~ gui,log:show,,% lang("Log")
	
	GuiLogSizeH:=A_ScreenHeight*0.7
	GuiLogSizeW:=A_ScreenWidth*0.8
	gui,log:show,w%GuiLogSizeW% h%GuiLogSizeH%,% lang("Log")
	gosub LogGuiSizeinitial
	
	return
	
	LogGuiSize:
	GuiLogSizeW:=A_GuiWidth
	GuiLogSizeH:=A_GuiHeight
	LogGuiSizeinitial:
	GuiLogWidthText:=GuiLogSizeW - 20
	GuiLogHeightText:=GuiLogSizeH - 20-GuiLogButtonsHeigth-10
	GuiLogyText:=10+GuiLogButtonsHeigth+10
	guicontrol,log:move,GuiLogCategory,x10 y10 w200 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogrefresh,x220 y10 w100 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogClose,x330 y10 w100 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogModeChange,x440 y10 w100 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogTextField,x10 y%GuiLogyText% w%GuiLogWidthText% h%GuiLogHeightText%
	GuiLogTextFieldRows:=floor((GuiLogHeightText-10) / (GuiLogFontSize+6)) - 1
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	logguiclose:
	GuiLogClose:
	gui,log:destroy
	SetTimer,GuiLogrefreshText,off
	return
	
	GuiLogModeChange:
	if GuiLogMode = update
	{
		GuiLogMode = showall
		SetTimer,GuiLogrefreshText,off
	guicontrol,log:,GuiLogModeChange,% lang("Quick refresh")
	}
	else
	{
		GuiLogMode = update
		SetTimer,GuiLogrefreshText,100
	guicontrol,log:,GuiLogModeChange,% lang("Show all logs")
	}
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	GuiLogrefresh:
	;find all log categories
	GuiControlGet,GuiLogCategoryOld,log:,GuiLogCategory
	if (GuiLogCategoryOld = "")
		GuiLogCategoryOld := whichone
	GuiLogCategory:="|all"
	for onekeyfromShare, onevalueFromShare in _share
	{
		if (substr(onekeyfromShare,1,4) = "log_")
		{
			GuiLogCategory.="|" substr(onekeyfromShare,5)
		}
	}
	guicontrol,log:,GuiLogCategory,% GuiLogCategory
	guicontrol,log:ChooseString,GuiLogCategory,% GuiLogCategoryOld
	gosub GuiLogrefreshText
	return
	
	GuiLogCategory:
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	GuiLogrefreshText:
	if not (DebugLogOldCount == _share.LogCount)
	{
		GuiControlGet,GuiLogCategory,log:,GuiLogCategory
		
		if (GuiLogCategory = "all")
			DebugLogToShow:=_share.Log
		else
			DebugLogToShow:=_share["Log_" GuiLogCategory]
		DebugLogOldCount:=_share.LogCount
		if GuiLogMode = update
		{
			StringGetPos,pos,DebugLogToShow,`n,R%GuiLogTextFieldRows%
			if pos > -1
			{
				DebugLogToShow:= substr(DebugLogToShow,pos+2)
			}
		}
		else
		{
			
		}
		GuiControl,log:,GuiLogTextField,% DebugLogToShow
	}
	
	return
	
}


initLog()
{
	global
	SetTimer, log_cleanup, 1000
	_share.logTidyCountdown:=0
	return
}

log_cleanup()
{
	if (_share.logTidyCountdown <= 0)
	{
		;~ MsgBox % _share.log
		;~ templog:=_share.log
		;~ stringgetpos,templogpos,templog,`n,l50
		;~ _share.log:=substr(templog,templogpos+2)
		;~ MsgBox % templogpos "`n" _share.log
		
		log_cleanup_toobigfiles:=Object()
		loop, %_WorkingDir%\Log\Log*.txt
		{
			If (substr(A_LoopFileFullPath,-7) = "_old.txt")
				continue
			FileGetSize,temp,%A_LoopFileFullPath%,K
			if temp>100 ;if file size over 10 MB
			{
				log_cleanup_toobigfiles.push(A_LoopFileFullPath)
			}
		}
		
		for onebigfileindex, onebigfile in log_cleanup_toobigfiles
		{
			;Rename current log file and add "_old".
			StringTrimRight, fullpath, onebigfile, 4 ;remove .txt
			FileMove,%onebigfile%,%fullpath%_old.txt,1
		}
		_share.logTidyCountdown := 50
	}
}

	