
; initializes the logger
init_logger()
{
	if not fileexist(_WorkingDir "\Log")
		FileCreateDir, % _WorkingDir "\Log"
}

; writes a log entry
; loglevel must be one of those entries:
; a0 - a3 	Application log
; f0 - f3 	Flow log
; t0 - t3 	Multithreading log
; 0: only errors
; 1: major logs
; 2: more logs
; 3: all logs
logger(LogLevel, LoggingText, logSource="common")
{
	logCategory := substr(LogLevel,1,1)
	logSeverity := substr(LogLevel,2,1)
	if logSeverity is number
	{
		if (logCategory="a")
		{
			if (logSeverity <= _getSettings("LogLevelApp"))
				shouldLog:=true
		}
		else if (logCategory="f")
		{
			if (logSeverity <= _getSettings("LogLevelFlow"))
				shouldLog:=true
		}
		else if (logCategory="t")
		{
			if (logSeverity <= _getSettings("LogLevelThread"))
				shouldLog:=true
		}
	}

	If shouldLog
	{
		; set some shared variables
		_getAndIncrementShared("LogCount") ; this variable is used by the logger gui
		_getAndIncrementShared("logTidyCountdown", -1)

		; Append current time
		FormatTime,timestamp,a_now,yyyy MM dd HH:mm:ss
		LoggingText:="`n--- " timestamp " ~" _ahkThreadID "~" logSource "~ " LoggingText

		; add the logging text to the shared variable
		_appendToShared("log", LoggingText)
		_appendToShared("log_" logSource, LoggingText)

		if (_getSettings("logtofile"))
		{
			; Log to file. Protect file access with critical section
			_EnterCriticalSection()
			FileAppend,% LoggingText,%_WorkingDir%\Log\Log.txt,UTF-8
			FileAppend,% LoggingText,%_WorkingDir%\Log\Log_%logSource%.txt,UTF-8
			_LeaveCriticalSection()
		}
	}
	
}

; opens the gui with log entries
showlog(whichone="all")
{
	global
	; some variables used when building the gui
	GuiLogFontSize:=8
	GuiLogTextFieldRows:=0
	GuiLogButtonsHeigth:=40
	GuiLogMode:="update"
	GuiLogCategory:=whichone

	; build the gui
	gui,log:destroy
	gui,log:font,s%GuiLogFontSize%
	gui,log: add, text, xm ym w100, % lang("Log filter")
	gui,log: add, dropdownlist, xm Y+5 w100 vGuiLogCategory gGuiLogCategory
	gui,log: add, text, X+10 ym w100, % lang("View mode")
	gui,log: add, dropdownlist, xp Y+5 w100 vGuiLogViewMode gGuiLogViewMode choose1, % "" lang("Quick refresh") "|" lang("Show all logs")
	gui,log: add, button,X+10 ym h%GuiLogButtonsHeigth% gGuiLogrefresh vGuiLogrefresh, % lang("Refresh")
	gui,log:add,button, X+10 ym h%GuiLogButtonsHeigth% gGuiLogClose vGuiLogClose default,% lang("Close")
	gui,log:add,edit, xm Y+10 ReadOnly vGuiLogTextField Multi -wrap VScroll HScroll
	gui,log:+resize
	gui,log:+MinSize500x300
	
	; filter the logs if user wants to
	GuiControl,log:ChooseString,GuiLogCategory, %whichone%
	
	; we will refresh the gui regularely
	DebugLogOldCount := 0
	SetTimer,GuiLogrefreshText,100
	gosub GuiLogrefresh
	
	; find out the perfect size for the gui
	GuiLogSizeH:=A_ScreenHeight*0.7
	GuiLogSizeW:=A_ScreenWidth*0.8

	; show the gui
	gui,log:show,w%GuiLogSizeW% h%GuiLogSizeH%,% lang("Log")

	; correct the positions of the controls
	gosub LogGuiSizeinitial
	return
	
	; user resized the gui
	LogGuiSize:
	; get gui size
	GuiLogSizeW:=A_GuiWidth
	GuiLogSizeH:=A_GuiHeight

	; fall through
	LogGuiSizeinitial:
	; move controls
	GuiLogWidthText:=GuiLogSizeW - 20
	GuiLogHeightText:=GuiLogSizeH - 20-GuiLogButtonsHeigth-10
	GuiLogyText:=10+GuiLogButtonsHeigth+10
	guicontrol,log:move,GuiLogTextField,y%GuiLogyText% w%GuiLogWidthText% h%GuiLogHeightText%
	GuiLogTextFieldRows:=floor((GuiLogHeightText-10) / (GuiLogFontSize+6)) - 1

	; update the gui, in order to keep the newest entries visible
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	; user closed the gui
	logguiclose:
	GuiLogClose:

	; stop refreshing the gui
	SetTimer,GuiLogrefreshText,off

	; destroy the gui
	gui,log:destroy
	return
	
	; user changed view mode
	GuiLogViewMode:
	gui,submit, nohide
	if (GuiLogViewMode = lang("Show all logs"))
	{
		; enable all log mode
		GuiLogMode := "showall"
		SetTimer,GuiLogrefreshText,off
	}
	else
	{
		; enable quick refresh mode
		GuiLogViewMode := "update"
		SetTimer,GuiLogrefreshText,100
	}
	; update the edit field after mode change
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	; user clicked on refresh button
	GuiLogrefresh:
	;find all log categories
	GuiControlGet,GuiLogCategoryOld,log:,GuiLogCategory
	if (GuiLogCategoryOld = "")
		GuiLogCategoryOld := whichone
	GuiLogCategory:="|all"
	shareKeys := _getAllSharedKeys()
	for oneShareKeysIndex, oneShareKey in shareKeys
	{
		if (substr(oneShareKey,1,4) = "log_")
		{
			GuiLogCategory.="|" substr(oneShareKey,5)
		}
	}
	guicontrol,log:,GuiLogCategory,% GuiLogCategory
	guicontrol,log:ChooseString,GuiLogCategory,% GuiLogCategoryOld

	; refresh the log text
	gosub GuiLogrefreshText
	return
	
	; user changes the filter setting
	GuiLogCategory:

	; refresh the log text
	DebugLogOldCount:=0
	gosub GuiLogrefreshText
	return
	
	; refresh the log text
	GuiLogrefreshText:
	;Check whether the log text changed
	if not (DebugLogOldCount == _getShared("LogCount"))
	{
		; the log text probably changed

		; get the log category
		GuiControlGet,GuiLogCategory,log:,GuiLogCategory
		
		; get log, filtered or unfiltered
		if (GuiLogCategory = "all")
			DebugLogToShow:=_getShared("Log")
		else
			DebugLogToShow:=_getShared("Log_" GuiLogCategory)

		; store current counter for next check whether the log text changed
		DebugLogOldCount:=_getShared("LogCount")
		if GuiLogMode = update
		{
			; shorten the log text for faster update
			StringGetPos,pos,DebugLogToShow,`n,R%GuiLogTextFieldRows%
			if pos > -1
			{
				DebugLogToShow:= substr(DebugLogToShow,pos+2)
			}
		}
		else
		{
			; keep log text as long as it is
		}
		; show the log text in gui
		GuiControl,log:,GuiLogTextField,% DebugLogToShow
	}
	
	return	
}

; enables regular cleanup of the logger.
log_enableRegularCleanup()
{
	global
	SetTimer, log_cleanup, 1000
	_setShared("logTidyCountdown", 0)
	return
}

; clean up the logged data
log_cleanup()
{
	; the counter is decreased whenever a log entry is inserted
	if (_getShared("logTidyCountdown") <= 0)
	{
		_EnterCriticalSection()
		; find files which are too long
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
		
		; clean up too big files
		for onebigfileindex, onebigfile in log_cleanup_toobigfiles
		{
			;Rename current log file and add "_old" and overwrite the old "_old" file.
			StringTrimRight, fullpath, onebigfile, 4 ;remove extension from filename
			FileMove,%onebigfile%,%fullpath%_old.txt,1 
		}

		; check the length of the logging variables
		shareKeys := _getAllSharedKeys()
		for oneShareKeysIndex, oneShareKey in shareKeys
		{
			if (substr(oneShareKey,1,4) = "log_")
			{
				loggedText := _getShared(oneShareKey)
				; check the logged text length
				if (strlen(loggedText) > 30000)
				{
					; logged text is too long, shorten it
					loggedText := substr(loggedText,-20000)
					_setShared(oneShareKey, loggedText)
				}
			}
		}

		_LeaveCriticalSection()
		; set new countdown to prevent that the log cleanup runs too often
		_setShared("logTidyCountdown", 50)
	}
}

	