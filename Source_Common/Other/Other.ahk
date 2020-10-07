; Returns the path of AHF
GetAhfPath()
{
	if fileexist(_ScriptDir "\AutoHotFlow.exe")
	{
		return _ScriptDir "\AutoHotFlow.exe"
	}
	else if fileexist(_ScriptDir "\AutoHotFlow.ahk")
	{
		return _ScriptDir "\AutoHotFlow.ahk"
	}
	else
	{
		logger("a0", "Can't find AutoHotflow.exe")
		return
	}
}