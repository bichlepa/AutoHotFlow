;Only called from main thread. Fills a list of all available element classes
Check_Packages()
{
	packageInfo := _getShared("packageInfo")
	for onePackageName in packageInfo
	{
		packagePath :=  _ScriptDir "\source_Elements\" onePackageName
		fileread, fileContent, % packagePath "\manifest.json"
		packageInfo[onePackageName] := Jxon_Load(fileContent)
	}
	allElementTypes := ["action", "condition", "loop", "trigger"]
	AllElementClasses := []
	AllElementClassInfos := []


	; loop through every element class
	for onePackageName, onePackage in packageInfo
	{
		for oneElementTypeIndex, oneElementType in allElementTypes
		{
			for oneElementIndex, oneElementName in onePackage[oneElementType "s"]
			{
				; get class name
				oneElementClass := oneElementType "_" substr(oneElementName, 1, -4)
				success := CheckElement(oneElementClass, oneElementType)

				if success
				{
					; write informations about the available element classes
					AllElementClasses.push(oneElementClass)
					AllElementClassInfos[oneElementClass] := {type: oneElementType, package: onePackageName, packageVersion: packageInfo[onePackageName].version}
				}
			}
		}
	}

	_setShared("allElementTypes", allElementTypes)
	_setSharedProperty("AllElementClasses", AllElementClasses)
	_setSharedProperty("AllElementClassInfos", AllElementClassInfos)
	_setShared("packageInfo", packageInfo)
}

; check whether all element funcitons are implemented
CheckElement(p_class, p_type)
{
	requiredFunctions := []
	requiredFunctions.push("Element_getName_")
	requiredFunctions.push("Element_getCategory_")
	requiredFunctions.push("Element_getElementLevel_")
	requiredFunctions.push("Element_getIconPath_")
	requiredFunctions.push("Element_getStabilityLevel_")
	requiredFunctions.push("Element_getParametrizationDetails_")
	requiredFunctions.push("Element_GenerateName_")
	requiredFunctions.push("Element_CheckSettings_")

	if (p_type = "action" or p_type = "condition" or p_type = "loop")
	{
		requiredFunctions.push("Element_run_")
		requiredFunctions.push("Element_stop_")
	}
	else if (p_type = "trigger")
	{
		requiredFunctions.push("Element_enable_")
		requiredFunctions.push("Element_postTrigger_")
		requiredFunctions.push("Element_disable_")
	}
	Else
	{
		logger("A0", "Element class " p_class " is of not supported type: " p_type, ,true)
		return
	}

	for oneindex, oneRequiredFunction in requiredFunctions
	{
		if (not isFunc(oneRequiredFunction p_class))
		{
			logger("A0", "Element class " p_class " is not fully implemented. Missing function: " oneRequiredFunction p_class "()", ,true)
			return
		}
	}
	return true
}