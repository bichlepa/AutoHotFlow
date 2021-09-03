; Opens the gui, where the user can change the category of a flow
changeFlowCategory_GUI(par_selectedID)
{
	global
	
	; Store the flow ID in global variable
	changeFlowCategory_FlowID := par_selectedID
	
	; disable manager gui
	Disable_Manager_GUI()

	; Get all categories and write them in a list for the gui
	local tempCategoryList
	for count, tempCategory in _getShared("allCategories")
	{
		tempCategoryList:=tempCategoryList tempCategory.name "|"
	}
	
	; build the gui
	gui,font,s10
	gui,changeCategory:add,text,xm ym ,% lang("Where_should_%1%_be_moved?", _getFlowProperty(par_selectedID, "name"))
	gui,changeCategory:add,ListBox, xm Y+10 vChangeCategoryList gChangeCategoryList w300 h300 , % tempCategoryList
	
	gui,changeCategory:add,edit, xm Y+10 w200 vChangeCategoryNewName
	gui,changeCategory:add,Button,yp X+10 w90 gChangeCategoryNew vChangeCategoryNew,% lang("New")
	
	gui,changeCategory:add,Button, xm Y+20 w145 gChangeCategoryOK vChangeCategoryOK default Disabled,% lang("OK")
	gui,changeCategory:add,Button, yp X+10 w145 X+10 yp gChangeCategoryCancel,% lang("Cancel")
	gui,changeCategory:show
	
	return
	
	; user clicked on the category list
	ChangeCategoryList:
	if A_GuiEvent = DoubleClick 
	{
		; if user makes a double click, take that category and close the gui
		if (ChangeCategoryList != "")
			goto ChangeCategoryOK
	}
	
	; get user input from gui
	gui,changeCategory:submit,nohide

	; if user has selected a category, enable OK button, otherwise disable it
	if (ChangeCategoryList != "")
		GuiControl, changeCategory:enable, ChangeCategoryOK
	else
		GuiControl, changeCategory:disable, ChangeCategoryOK
	return
	
	; user clicked on ok (or did a double click on a category)
	ChangeCategoryOK:
	; get user input from gui
	gui, changeCategory:Submit, nohide
	
	; Change the flow category
	ChangeFlowCategory(changeFlowCategory_FlowID, _getCategoryIdByName(ChangeCategoryList))

	; destroy the gui
	gui, changeCategory:destroy

	; Update treeview
	TreeView_manager_Refill()
	TreeView_manager_Select("Flow", changeFlowCategory_FlowID)

	; enable manager gui
	Enable_Manager_GUI()
	return
	
	; user clicked on the new button
	ChangeCategoryNew:
	; get user input from gui
	gui, changeCategory:Submit, nohide
	
	; if name is empty, do nothing
	if ChangeCategoryNewName
	{
		; Create new category with given name
		newcategoryid:=NewCategory(ChangeCategoryNewName)

		; Change the flow category
		ChangeFlowCategory(changeFlowCategory_FlowID, newcategoryid)
		
		; destroy the gui
		gui, changeCategory:destroy

		; Update treeview
		TreeView_manager_Refill()
		TreeView_manager_Select("Flow", changeFlowCategory_FlowID)

		; enable manager gui
		Enable_Manager_GUI()
	}
	return

	; user closed the gui
	changeCategoryguiclose:
	ChangeCategoryCancel:

	; destroy the gui
	gui, changeCategory:destroy
	
	; enable manager gui
	Enable_Manager_GUI()
	return
}

