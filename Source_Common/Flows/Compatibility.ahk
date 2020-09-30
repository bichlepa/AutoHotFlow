global FlowCompabilityVersionOfApp:=10 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.


;Check the element class before its settings are loaded
LoadFlowCheckCompabilityClass(p_FlowID, p_ElementID)
{
}

;Check the element settings after they were loaded
LoadFlowCheckCompabilityElement(p_FlowID, p_ElementID, FlowCompabilityVersion)
{
	
}

LoadFlowCheckCompabilityConnection(p_FlowID, p_ConnectionID, FlowCompabilityVersion)
{

}

LoadFlowCheckCompabilityFlow(p_FlowID, p_FlowCompabilityVersion)
{
	
}