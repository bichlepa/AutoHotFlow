


;Thanks to fincs
ObjFullyClone(obj)
{
	if IsObject(obj)
	{
		nobj := obj.Clone()
		for k,v in nobj
			if IsObject(v)
				nobj[k] := A_ThisFunc.(v)
	}
	else
		nobj := obj
	return nobj
}

ObjFullyCompare_oneDir(obj1, obj2)
{
	for k,v in obj1
	{
		if IsObject(v)
		{
			if (A_ThisFunc.(v, obj2[k]) = false)
				return false
		}
		else
		{
			if (v != obj2[k])
				return false
		}
	}
	return true
}