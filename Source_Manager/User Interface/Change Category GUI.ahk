changeFlowCategory_GUI(par_selectedID)
{
	global
	local tempCategory
	local tempCategoryList
	
	changeFlowCategory_FlowID := par_selectedID
	changeFlowCategory_Finished := "no"
	
	Disable_Manager_GUI()
	tempCategoryList=
	for count, tempCategory in _share.allCategories
	{
		tempCategoryList:=tempCategoryList tempCategory.name "|"
	}
	
	gui,font,s10
	gui,changeCategory:add,text,xm ym ,% lang("Where_should_%1%_be_moved?",_Flows[par_selectedID].name)
	gui,changeCategory:add,ListBox, xm Y+10 vChangeCategoryList gChangeCategoryList w300 h300 , % tempCategoryList
	
	gui,changeCategory:add,edit, xm Y+10 w200 vChangeCategoryNewName
	gui,changeCategory:add,Button,yp X+10 w90 gChangeCategoryNew vChangeCategoryNew,% lang("New")
	
	gui,changeCategory:add,Button, xm Y+20 w145 gChangeCategoryOK vChangeCategoryOK default Disabled,% lang("OK")
	gui,changeCategory:add,Button, yp X+10 w145 X+10 yp gChangeCategoryCancel,% lang("Cancel")
	gui,changeCategory:show
	
	return
	
	ChangeCategoryList:
	if A_GuiEvent = DoubleClick 
	{
		if (ChangeCategoryList != "")
			goto ChangeCategoryOK
	}
	
	gui,changeCategory:submit,nohide
	;MsgBox,% ChangeCategoryList
	if (ChangeCategoryList != "")
		GuiControl, changeCategory:enable, ChangeCategoryOK
	else
		GuiControl, changeCategory:disable, ChangeCategoryOK
	return
	
	
	ChangeCategoryOK:
	gui, changeCategory:Submit, nohide
	;~ d(FlowIDbyName(ChangeCategoryList, "Category"))
	API_Main_ChangeFlowCategory(changeFlowCategory_FlowID, FlowIDbyName(ChangeCategoryList, "Category"))

	gui, changeCategory:destroy
	Enable_Manager_GUI()
	return
	
	ChangeCategoryNew:
	gui, changeCategory:Submit, nohide
	
	if ChangeCategoryNewName
	{
		newcategoryid:=API_Main_NewCategory(ChangeCategoryNewName)
		API_Main_ChangeFlowCategory(changeFlowCategory_FlowID, newcategoryid)
		gui, changeCategory:destroy
		Enable_Manager_GUI()
	}
	return

	changeCategoryguiclose:
	ChangeCategoryCancel:
	gui, changeCategory:destroy
	Enable_Manager_GUI()
	return
}

