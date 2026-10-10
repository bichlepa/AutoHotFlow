;This file is included by all threads which want to communicate to draw thread

; tells the draw thread that it needs to redraw the image in the editor for a flow
API_Draw_Draw(p_FlowID)
{
	logger("t3", A_ThisFunc " called from thread", _ahkThreadID)
	
	_setFlowProperty(p_FlowID, "draw.mustDraw", true)
}
