;enable or disable flow
r_EnableFlow(options:="")
{
	
	global
	
	if alreadyenabling=true ;Prevent that e.g. it tries to enable twice or disable and enable at same time. This may happen if user clicks on the enable button quickly
		return
	alreadyenabling=true

	if (triggersEnabled=true) ;IF the flow is enabled, disable flow
	{
		Critical on
		logger("f1a1","Disabling flow.")
		for tempindex, temptrigger in allTriggers
		{
			tempName:=%temptrigger%subType
			DisableTrigger%tempName%(temptrigger)
			
		}
		triggersEnabled:=false
		Critical off
		if (options!="noTellDisabled")
		{
			r_TellThatFlowIsDisabled()
			
		}
		
	}
	else ;If the flow is disabled, enable flow
	{
		logger("f1a1","Enabling flow.")
		for tempindex, temptrigger in allTriggers
		{
			tempName:=%temptrigger%subType
			EnableTrigger%tempName%(temptrigger)
			
		}
		triggersEnabled:=true
		r_TellThatFlowIsEnabled()
		
	}
	alreadyenabling=false

}

;Tells the manager about the current flow status. Also sets the right GUI Text and changes the icon.
r_TellThatFlowIsDisabled()
{
	global
	try Menu, MyMenu,Rename,% lang("Disable"),% lang("Enable") ;Show enable when disabled
	try menu, tray, rename,% lang("Disable"),% lang("Enable")
	com_SendCommand({function: "ReportStatus",status: "disabled"},"manager") ;Send the command to the Manager.
	if (nowrunning!=true) ;Only show whether the flow is enabled if flow is not running
		menu tray,icon,Icons\disabled.ico
	
}
r_TellThatFlowIsEnabled()
{
	global
	try Menu, MyMenu,Rename,% lang("Enable"),% lang("Disable") ;Show disable when enabled
	try menu, tray, rename, % lang("Enable"),% lang("Disable")
	com_SendCommand({function: "ReportStatus",status: "enabled"},"manager") ;Send the command to the Manager.
	if (nowrunning!=true)
		menu tray,icon,Icons\enabled.ico
}

r_TellCurrentStatus()
{
	global 
	if triggersEnabled
		r_TellThatFlowIsEnabled()
	else
		r_TellThatFlowIsDisabled()
	if nowrunning
		r_TellThatFlowIsStarted()
	else
		r_TellThatFlowIsStopped()
}