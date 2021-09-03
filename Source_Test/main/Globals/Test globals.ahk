
class main_Globals_TestSuite
{
	Begin()
	{
		init_GlobalVars()
	}
	
	Test_Vars_exist()
	{
		global
		Yunit.assert(IsObject(_flows) == true)
		Yunit.assert(IsObject(_settings) == true)
		Yunit.assert(IsObject(_execution) == true)
	}
	
}