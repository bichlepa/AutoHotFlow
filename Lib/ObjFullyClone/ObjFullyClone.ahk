


ObjFullyClone(obj) ;Thanks to fincs
{
	nobj := obj.Clone()
	for k,v in nobj
		if IsObject(v)
			nobj[k] = A_ThisFunc.(v)
	return nobj
}