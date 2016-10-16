goto,JumpoverTooltiplabels


removetooltip:
ToolTip
return

JumpoverTooltiplabels:
temp= ;Do nothing

ToolTip(text="",duration=1000)
{
	global
	
	ToolTip_text:=text
	ToolTip_duration:=duration
	ToolTip,%ToolTip_text%
	SetTimer,Tooltip_follow_mouse,10
	
	SetTimer,Tooltip_RemoveTooltip,-%ToolTip_duration%
	
	return
	Tooltip_follow_mouse:
	MouseGetPos,tempTooltipx,tempTooltipy
	if (tempTooltipOldx!=tempTooltipx or tempTooltipOldy!=tempTooltipy)
	{
		ToolTip,%ToolTip_text%
		tempTooltipOldx:=tempTooltipx
		tempTooltipOldy:=tempTooltipy
	}
	return
	Tooltip_RemoveTooltip:
	SetTimer,Tooltip_follow_mouse,off
	ToolTip
	return
	
}

