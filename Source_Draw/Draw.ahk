#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; faster execution
SetBatchLines -1

; The draw thread should not have an own tray icon
#NoTrayIcon

; Get working dir for AutoHotFlow from shared variable.
; It is the directory where the flows and global variables are saved
; (not to be confused with the working dir in the settings of AutoHotFlow)
global _WorkingDir := _getShared("_WorkingDir")
; Get script dir for AutoHotFlow from shared variable.
global _ScriptDir := _getShared("_ScriptDir")
; using working dir forbidden, because in other parts of the code we use the commands FileSelectFolder and FileSelectFile
; While any thread uses those commands, the working directory of the whole process is changed to the path which is shown in the dialog.
; SetWorkingDir %a_temp% working dir is only set in main thread. Otherwise it causes errors if another thread is currently including files

#Persistent

; On call of ExitApp, we will start the exit routine
OnExit,Exit
global _exiting := false

; speed up gui and changes dramatically
SetWinDelay, 0

;initialize logger
init_logger()

; Include libraries
#Include %A_ScriptDir%\..
#include Lib\gdi+\gdip.ahk
#include Lib\Object to file\String-object-file.ahk
#include Lib\ObjFullyClone\ObjFullyClone.ahk

; include language module
#include language\language.ahk ;Must be very first
;initialize languages
_language := Object()
_language.dir := _ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_getSettings("UILanguage"))

; include all the other source code
#include Source_Draw\GDIp\gdip.ahk
#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include source_Common\Other\Design.ahk

; intialize gdip
gdip_Init()

; start the draw task
SetTimer,drawTask,-100
return

; Checks all flows whether their editor gui must be redrawn
drawTask()
{
	Loop
	{
		_EnterCriticalSection()
		
		; Find a flow which editor gui must be redrawn
		somethingdrawn:= false
		flowParamsCloned:=""
		_getAllFlowIds()
		flow:=""
		for flowIndex, flowID in _getAllFlowIds()
		{
			mustDraw := _getFlowProperty(FlowID, "draw.mustDraw")
			if (mustDraw = true)
			{
				; we found a flow
				_setFlowProperty(FlowID, "draw.mustDraw", false)
				
				; get all flow properties
				flow:=_getFlow(flowID)
				break
			}
		}
		
		_LeaveCriticalSection()
		
		if flow
		{
			; redraw the editor gui
			gdip_DrawEverything(flow)
			somethingdrawn:=true
		}
		
		if (somethingdrawn = false)
		{
			; nothing to do, we can let the cpu chill a while
			SetTimer,drawTask,-10
			break
		}
	}
}

; Start the exit routine
exit:
global _exiting := true
exit



FinallyExit:
ExitApp