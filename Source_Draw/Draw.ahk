
;Here at the top there will be something like this line:
; share:=Criticalobject(1234)
;The object share contains values which are shared among this and other threads
#NoTrayIcon

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;~ #Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

SetWorkingDir %A_ScriptDir%\..  ; set working dir.
global _WorkingDir := _getShared("_WorkingDir")
global _ScriptDir := _getShared("_ScriptDir")
SetWorkingDir %a_temp%  ; using working dir forbidden.

;~ MsgBox %a_workingdir%

#Persistent
SetBatchLines -1
#SingleInstance off
CoordMode,mouse,client
;FileEncoding,UTF-8
OnExit,Exit


#Include %A_ScriptDir%\..
#include language\language.ahk ;Must be very first
;initialize languages
_language:=Object()
_language.dir:=_ScriptDir "\language" ;Directory where the translations are stored
lang_Init()
lang_setLanguage(_getSettings("UILanguage"))

#include Lib\gdi+\gdip.ahk
#include Lib\Object to file\String-object-file.ahk
#include Lib\ObjFullyClone\ObjFullyClone.ahk

#include Source_Draw\GDIp\gdip.ahk
#include source_Common\Multithreading\API Caller to Main.ahk
#include Source_Common\Multithreading\Shared Variables.ahk

#include Source_Common\Debug\Debug.ahk
#include source_Common\Debug\Logger.ahk
#include Source_Common\settings\Default values.ahk

parentAHKThread := AhkExported()

gdip_Init()
menu,tray, tip, Draw

SetTimer,drawTask,100

return
;Called by the main thread
;it prepares some values and starts a timer which calls UI_drawEverything()
Draw()
{
	global
	SetTimer,drawTask,10
}

drawTask()
{
	Loop
	{
		EnterCriticalSection(_cs_shared)
		
		somethingdrawn:= false
		flowParamsCloned:=""
		_getAllFlowIds()
		for flowIndex, flowID in _getAllFlowIds()
		{
			if (_getFlowProperty(FlowID, "draw.mustDraw") = true)
			{
				_setFlowProperty(FlowID, "draw.mustDraw", false)
				
				flow:=_getFlow(flowID)
				break
			}
		}
		
		LeaveCriticalSection(_cs_shared)
		
		if flow
		{
			gdip_DrawEverything(flow)
			somethingdrawn:=true
		}
			
		
		if (somethingdrawn = false)
		{
			SetTimer,drawTask,10
			break
		}
	}
	
}


exit:
API_Main_Thread_Stopped(_ahkThreadID "" "")
return

