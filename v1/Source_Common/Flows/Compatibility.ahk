global FlowCompabilityVersionOfApp := 1 ;This variable contains a number which will be incremented as soon an incompability appears. This will make it possible to identify old scripts and convert them. This value will be written in any saved flows.

;Check an element after it was loaded
LoadFlowCheckCompabilityElement(p_FlowID, p_ElementID, p_AHFVersion)
{
    ; example:
    ; elementClass := x_getElementClass(p_FlowID, p_ElementID)
    ; if (elementClass = "Loop_Work_through_a_list")
    ; {
    ;     value := _getElementProperty(p_FlowID, p_ElementID, "pars.VarName")
    ;     _setElementProperty(p_FlowID, p_ElementID, "pars.VarValue", value)
    ; }
    
	oneElementPackage := _getElementProperty(p_FlowID, p_ElementID, "Package")
	oneElementPackageVersion := _getElementProperty(p_FlowID, p_ElementID, "PackageVersion")
    if (oneElementPackage and isFunc("LoadFlowCheckCompatibilityElement_Package_" oneElementPackage))
    {
        LoadFlowCheckCompatibilityElement_Package_%oneElementPackage%(p_FlowID, p_ElementID, p_AHFVersion, oneElementPackageVersion)
    }
}

;Check a connection after it was loaded
LoadFlowCheckCompabilityConnection(p_FlowID, p_ConnectionID, p_AHFVersion)
{

}

;Check the flow after it was loaded
LoadFlowCheckCompabilityFlow(p_FlowID, p_AHFVersion)
{
	
}