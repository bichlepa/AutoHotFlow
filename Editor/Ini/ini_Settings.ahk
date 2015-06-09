
ini_ReadSettings()
{
	global

	;Read settings
	iniread,translationto,settings.ini,common,translatingto
	;iniread,developing,settings.ini,common,developing



	iniread,INIOnStartLoadFile,settings.ini,common,LoadFileOnStart,%a_space%


}

ini_GetElementInformations()
{
	global
	
	;Retrieve informations about all elements
	IniAllActionCategories=|
	IniAllConditionCategories=|
	IniAllTriggerCategories=|
	IniAllLoopCategories=|
	
	loop,parse, iniAllActions,|
	{
		
		tempname:=getnameAction%a_loopfield%()
		if tempname!=
		{
			
			IniAllActionNames=%IniAllActionNames%%tempname%|
		}
		tempCategory:=getCategoryAction%a_loopfield%()
		Loop parse,tempCategory,|
		{
			IfNotInString,IniAllActionCategories,|%A_LoopField%|
				IniAllActionCategories=%IniAllActionCategories%%A_LoopField%|
		}
	}
	StringTrimRight,IniAllActionNames,IniAllActionNames,1
	StringTrimRight,IniAllActionCategories,IniAllActionCategories,1
	StringTrimLeft,IniAllActionCategories,IniAllActionCategories,1
	StringSplit,IniAllActionNames,IniAllActionNames,|

	loop,parse, iniAllConditions,|
	{
		tempname:=getnameCondition%a_loopfield%()
		if tempname!=
		{
			IniAllConditionNames=%IniAllConditionNames%%tempname%|
		}
		tempCategory:=getCategoryCondition%a_loopfield%()
		Loop parse,tempCategory,|
		{
			IfNotInString,IniAllConditionCategories,|%A_LoopField%|
				IniAllConditionCategories=%IniAllConditionCategories%%A_LoopField%|
		}

	}
	StringTrimRight,IniAllConditionNames,IniAllConditionNames,1
	StringTrimRight,IniAllConditionCategories,IniAllConditionCategories,1
	StringTrimLeft,IniAllConditionCategories,IniAllConditionCategories,1
	StringSplit,IniAllConditionNames,IniAllConditionNames,|

	loop,parse, iniAllTriggers,|
	{
		tempname:=getnameTrigger%a_loopfield%()
		if tempname!=
		{
			IniAllTriggerNames=%IniAllTriggerNames%%tempname%|
		}
		
		tempCategory:=getCategoryTrigger%a_loopfield%()
		Loop parse,tempCategory,|
		{
			IfNotInString,IniAllTriggerCategories,|%A_LoopField%|
				IniAllTriggerCategories=%IniAllTriggerCategories%%A_LoopField%|
		}
	}
	StringTrimRight,IniAllTriggerNames,IniAllTriggerNames,1
	StringSplit,IniAllTriggerNames,IniAllTriggerNames,|
	StringTrimRight,IniAllTriggerCategories,IniAllTriggerCategories,1
	StringTrimLeft,IniAllTriggerCategories,IniAllTriggerCategories,1

	loop,parse, iniAllLoops,|
	{
		tempname:=getnameLoop%a_loopfield%()
		if tempname!=
		{
			IniAllLoopNames=%IniAllLoopNames%%tempname%|
		}
		
		tempCategory:=getCategoryLoop%a_loopfield%()
		Loop parse,tempCategory,|
		{
			IfNotInString,IniAllLoopCategories,|%A_LoopField%|
				IniAllLoopCategories=%IniAllLoopCategories%%A_LoopField%|
		}
	}
	StringTrimRight,IniAllLoopNames,IniAllLoopNames,1
	StringSplit,IniAllLoopNames,IniAllLoopNames,|
	StringTrimRight,IniAllLoopCategories,IniAllLoopCategories,1
	StringTrimLeft,IniAllLoopCategories,IniAllLoopCategories,1

}
