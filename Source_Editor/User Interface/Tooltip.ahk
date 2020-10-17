
; show a tooltip which follows the mouse
ToolTip(text = "", duration = 1000)
{
	global
	
	; save tooltip and duration parameters to global variables
	ToolTip_text := text
	ToolTip_duration := duration
	Tooltip_Oldx := ""
	Tooltip_Oldy := ""

	; show tooltip
	gosub, Tooltip_follow_mouse

	; set up timer which will move the tooltip with mouse
	SetTimer, Tooltip_follow_mouse, 10
	
	; set up timer which will disable the tooltip
	SetTimer, Tooltip_RemoveTooltip, -%ToolTip_duration%
	
	return

	; timer label which will move the tooltip with mouse
	Tooltip_follow_mouse:
	; get mouse position
	MouseGetPos, tempTooltipx, tempTooltipy

	; check whether the mouse has moved
	if (Tooltip_Oldx != tempTooltipx or Tooltip_Oldy != tempTooltipy)
	{
		; mouse has moved. Recreate the tooltip.
		ToolTip, %ToolTip_text%
		Tooltip_Oldx := tempTooltipx
		Tooltip_Oldy := tempTooltipy
	}
	return

	; timer label which will remove the tooltip
	Tooltip_RemoveTooltip:
	; disable timer
	SetTimer, Tooltip_follow_mouse, off
	; hide tooltip
	ToolTip
	return
}

