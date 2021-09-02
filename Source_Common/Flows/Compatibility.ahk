global FlowCompabilityVersionOfApp := 1 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.

;Check an element after it was loaded
LoadFlowCheckCompabilityElement(p_FlowID, p_ElementID, FlowCompabilityVersion)
{
    ; example:
    ; elementClass := x_getElementClass(p_FlowID, p_ElementID)
    ; if (elementClass = "Loop_Work_through_a_list")
    ; {
    ;     value := _getElementProperty(p_FlowID, p_ElementID, "pars.VarName")
    ;     _setElementProperty(p_FlowID, p_ElementID, "pars.VarValue", value)
    ; }
}

;Check a connection after it was loaded
LoadFlowCheckCompabilityConnection(p_FlowID, p_ConnectionID, FlowCompabilityVersion)
{

}

;Check the flow after it was loaded
LoadFlowCheckCompabilityFlow(p_FlowID, p_FlowCompabilityVersion)
{
	
}