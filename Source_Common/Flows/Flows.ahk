
FlowIDbyName(par_name,Type="") ;Returns the id by name
{
	global
	if ((type = "flow") or (type = ""))
	{
		for count, tempitem in _flows
		{
			if (tempitem.name = par_name)
			{
				;~ MsgBox % tempitem.id " - " tempitem.name
				return tempitem.id
			}
			
		}
	}
	else if ((type = "category") or (type = ""))
	{
		for count, tempitem in _share.allCategories
		{
			if (tempitem.name = par_name)
			{
				return tempitem.id
			}
			
		}
	}
	return 
}
