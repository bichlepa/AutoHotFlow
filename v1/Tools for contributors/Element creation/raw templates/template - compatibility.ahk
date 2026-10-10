LoadFlowCheckCompatibilityElement_Package_&packageName&(p_FlowID, p_ElementID, p_AHFVersion, p_PackageVersion)
{
    elementClass := x_getElementClass(p_FlowID, p_ElementID)

    ; example:
    /*
    if (p_PackageVersion <= 1.1.0)
    {
        if (elementClass = "Action_MyPackage_MyElement")
        {
            elementPars := x_getElementPars(p_FlowID, p_ElementID)
            if (elementPars.myParam = "")
            {
                x_setElementPar(p_FlowID, p_ElementID, "myParam", 0)
            }
        }
    }
    */
}