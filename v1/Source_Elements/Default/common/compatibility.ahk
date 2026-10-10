LoadFlowCheckCompatibilityElement_Package_Default(p_FlowID, p_ElementID, p_AHFVersion, p_PackageVersion)
{
    elementClass := x_getElementClass(p_FlowID, p_ElementID)
    if (p_PackageVersion <= 1.1.0)
    {
        if (elementClass = "Action_New_variable")
        {
            elementPars := x_getElementPars(p_FlowID, p_ElementID)
            if (elementPars.onlyIfNotExist = "")
            {
                x_setElementPar(p_FlowID, p_ElementID, "onlyIfNotExist", 0)
            }
        }
    }
}