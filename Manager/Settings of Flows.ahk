changeCategory(selectedID)
{
	global
	DisableMainGUI()
	tempselectedID:=selectedID
	tempCategoryList=
	for count, tempItem in allItems
	{
		if %tempItem%type=category
			tempCategoryList:=tempCategoryList %tempItem%name "|"
		
	}
	
	
	gui,2:default
	gui,add,text,,% lang("Where_should_%1%_be_moved?",%tempselectedID%name)
	gui,add,ListBox,vChangeCategoryList gChangeCategoryList w200 h300 , % tempCategoryList
	
	gui,add,Button,w120 gChangeCategoryOK vChangeCategoryOK default Disabled,% lang("OK")
	gui,add,Button,w70 X+10 yp gChangeCategoryCancel,% lang("Cancel")
	gui,show
	return
	
	ChangeCategoryList:
	gui,2:default
	if A_GuiEvent =DoubleClick 
		goto ChangeCategoryOK
	gui,submit,nohide
	;MsgBox,% ChangeCategoryList
	if (ChangeCategoryList!="")
		GuiControl,enable,ChangeCategoryOK
	else
		GuiControl,disable,ChangeCategoryOK
	return
	
	
	ChangeCategoryOK:
	gui,2:default
	gui,Submit,nohide
	
	gui,destroy
	
	
	gui,1:default
	MoveFlow(tempselectedID,ChangeCategoryList)
	removeUncategorizedCategoryIfPossible()
	EnableMainGUI()
	
	
	return

	
	2guiclose:
	ChangeCategoryCancel:
	gui,2:default
	EnableMainGUI()
	gui,destroy
	gui,1:default
	return
}

