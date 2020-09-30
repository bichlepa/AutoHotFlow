#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Recommended for catching common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

loop,files,%a_scriptdir%\..\*.ahk,RF
{
	criticalSections:=Object()
	if (a_loopfilename=a_scriptname)
		continue
	FileRead,fileContent,%a_loopfilefullpath%
	{
		loop,parse,fileContent,`n,`r%a_space%%a_tab%
		{
			IfInString,a_loopfield,EnterCriticalSection(
			{
				newSection:=substr(a_loopfield,strlen("EnterCriticalSection(")+1,instr(a_loopfield,")")-strlen("EnterCriticalSection(")-1)
				; MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n%newSection% 
				for oneIndex, oneCriticalSection in criticalSections
				{
					if oneCriticalSection = newSection
					{
						MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n`nCritical Section is entered twice
					}
				}
				criticalSections.push(newSection)
			}
			IfInString,a_loopfield,LeaveCriticalSection(
			{
				newSection:=substr(a_loopfield,strlen("LeaveCriticalSection(")+1,instr(a_loopfield,")")-strlen("LeaveCriticalSection(")-1)
				if not (criticalSections.maxindex())
				{
					MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n`nCritical Section %newSection% is left but there is no active critical section.
				}
				else
				{
					lastSection:=criticalSections.pop()
					if (lastSection != newSection)
					{
						MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n`nCritical Section %newSection% is left but the last entered section is %lastSection%
					}
				}
				;~ MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n%newSection% 
			}
			
			If (substr(a_loopfield,1,strlen("return")) = "return")
			{
				; maxIndex := criticalSections.maxindex()
				; MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n%maxIndex% 
				if (criticalSections.maxindex())
				{
					activeCriticalSection:=""
					for oneIndex, oneCriticalSection in criticalSections
					{
						activeCriticalSection.=oneCriticalSection " "
					}
					MsgBox %A_LoopFileFullPath%`n%a_index%: %a_loopfield%`n`n Return called but critical section is still active: %activeCriticalSection%
				}
			}
		}
		
		
		if (criticalSections.maxindex())
		{
			activeCriticalSection:=""
			for oneIndex, oneCriticalSection in criticalSections
			{
				activeCriticalSection.=oneCriticalSection " "
			}
			MsgBox %A_LoopFileFullPath%`n`n File ended but critical section is still active: %activeCriticalSection%
		}
	}
	
}
MsgBox finished