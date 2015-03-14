r_EnableFlow()
{
	global
	if alreadyenabling=true ;Prevent that e.g. it tries to enable twice or disable and enable at same time. This may happen if user clicks on the enable button quickly
		return
	alreadyenabling=true

	if (triggersEnabled=true)
	{
		
		for tempindex, temptrigger in allTriggers
		{
			tempName:=%temptrigger%subType
			DisableTrigger%tempName%(temptrigger)
			
		}
		triggersEnabled:=false
		r_TellThatFlowIsDisabled()
		
	}
	else
	{
		
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

r_TellThatFlowIsDisabled()
{
	global
	try Menu, MyMenu,Rename,% lang("Disable"),% lang("Enable") ;Show enable when disabled
	try menu, tray, rename,% lang("Disable"),% lang("Enable")
	ControlSetText,edit1,disabled|%flowName%,CommandWindowOfManager ;Tell the manager that this flow is disabled
	if (nowrunning!=true)
		menu tray,icon,Icons\disabled.ico
	
}
r_TellThatFlowIsEnabled()
{
	global
	try Menu, MyMenu,Rename,% lang("Enable"),% lang("Disable") ;Show disable when enabled
	try menu, tray, rename, % lang("Enable"),% lang("Disable")
	ControlSetText,edit1,enabled|%flowName%,CommandWindowOfManager ;Tell the manager that this flow is enabled
	if (nowrunning!=true)
		menu tray,icon,Icons\enabled.ico
}