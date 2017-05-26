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
	
	gui,changeCategory:add,text,,% lang("Where_should_%1%_be_moved?",_Flows[par_selectedID].name)
	gui,changeCategory:add,ListBox,vChangeCategoryList gChangeCategoryList w200 h300 , % tempCategoryList
	
	gui,changeCategory:add,Button,w120 gChangeCategoryOK vChangeCategoryOK default Disabled,% lang("OK")
	gui,changeCategory:add,Button,w70 X+10 yp gChangeCategoryCancel,% lang("Cancel")
	gui,changeCategory:show
	
	return
	
	ChangeCategoryList:
	if A_GuiEvent = DoubleClick 
		goto ChangeCategoryOK
	
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

	changeCategoryguiclose:
	ChangeCategoryCancel:
	gui, changeCategory:destroy
	Enable_Manager_GUI()
	return
}

