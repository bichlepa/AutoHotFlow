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
			FileAppend,% DebugLogLastEntry,%_WorkingDir%\Log\Log.txt,UTF-8
			FileAppend,% DebugLogLastEntry,%_WorkingDir%\Log\Log_%logSource%.txt,UTF-8
		}
	}
	
}


showlog()
{
	global 
	GuiLogFontSize:=10
	GuiLogTextFieldRows:=0
	GuiLogButtonsHeigth:=30
	gui,log:destroy
	gui,log:font,s%GuiLogFontSize%
	gui,log: add, dropdownlist, vGuiLogCategories gGuiLogrefreshText 
	gui,log: add, button,gGuiLogrefresh vGuiLogrefresh, % lang("Refresh")
	gui,log:add,button,gGuiLogClose vGuiLogClose default,% lang("Close")
	gui,log:add,edit, ReadOnly vGuiLogTextField Multi -wrap VScroll HScroll
	gui,log:+resize
	gui,log:+MinSize500x300
	
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
	guicontrol,log:move,GuiLogCategories,x10 y10 w200 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogrefresh,x220 y10 w100 h%GuiLogButtonsHeigth%
	guicontrol,log:move,GuiLogClose,x330 y10 w100 h%GuiLogButtonsHeigth%
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
	
	GuiLogrefresh:
	;find all log categories
	GuiControlGet,GuiLogCategoriesOld,log:,GuiLogCategories
	if (GuiLogCategoriesOld = "")
		GuiLogCategoriesOld := "all"
	GuiLogCategories:="|all"
	for onekeyfromShare, onevalueFromShare in _share
	{
		if (substr(onekeyfromShare,1,4) = "log_")
		{
			GuiLogCategories.="|" substr(onekeyfromShare,5)
		}
	}
	guicontrol,log:,GuiLogCategories,% GuiLogCategories
	guicontrol,log:ChooseString,GuiLogCategories,% GuiLogCategoriesOld
	
	GuiLogrefreshText:
	if not (DebugLogOldCount == _share.LogCount)
	{
		GuiControlGet,GuiLogCategories,log:,GuiLogCategories
		
		if (GuiLogCategories = "all")
			DebugLogToShow:=_share.Log
		else
			DebugLogToShow:=_share["Log_" GuiLogCategories]
		DebugLogOldCount:=_share.LogCount
		StringGetPos,pos,DebugLogToShow,`n,R%GuiLogTextFieldRows%
		if pos > -1
		{
			DebugLogToShow:= substr(DebugLogToShow,pos+2)
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

	