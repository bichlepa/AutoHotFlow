#include *i <LV>
#include _Struct.ahk

; Simple Example
WinWaitClose % "ahk_id " ObjTree({MyObject:{"Key With Object":["a","This is a test","b",2]}
					,"Another Object":{Key:["c",1,"d",2]}
					,"Empty Object":[]
					,"Another Object 2":["e",1,"f",2]})
; Example with custom ToolTip and Editable values
WinWaitClose % "ahk_id " ObjTree({MyObject:{"Key With Object":["a","This is a test","b",2]}
					,"Another Object":{Key:["c",1,"d",2]}
					,"Empty Object":[]
					,"Another Object 2":["e",1,"f",2]}
		,"My ObjTree Gui Title","-ReadOnly"
		,{MyObject:{"Key With Object":"This is a an object`nKey is a string and value is object"}
					,"Another Object":{Key:"This is an object"}
					,"Empty Object":"This object is empty"
					,"Another Object 2":"Another object"})
ExitApp


ObjTree(ByRef obj,Title="ObjTree",Options="+ReadOnly +Resize,GuiShow=w640 h480",ishwnd=-1){
	; Version 1.0.1.0
	static
	; TREEOBJ will hold all running windows and some information about them
	static TREEOBJ:={},parents:={},ReadOnly:={},ReadOnlyLevel:={},objects:={},newObj:={},hwnd:={},EditItem:={},EditKey:={},EditObject:={},TT:={},Changed:={}
				,LV_SortArrow:="LV_SortArrow",ToolTipText,EditValue,G,WM_NOTIFY:=0x4e
	
	; OnMessage WM_NOTIFY structure
	static HDR:=new _Struct("HWND hwndFrom,UINT_PTR idFrom,UINT code,LPTSTR pszText,int cchTextMax,HANDLE hItem,LPARAM lParam") ;NMTVGETINFOTIP
	static TVN_FIRST := 0xfffffe70,TVN_GETINFOTIP := TVN_FIRST - 14 - (A_IsUnicode?0:1),MenuExist:=0
	local Font:="",GuiShow:="",GuiOptions:="",TREEHWND:="",EDITHWND:="",_EditKey:="",DefaultGui:="",FocusedControl:="",Height:="",Width:="",k:="",v:="",Item:="",NewKey:=""
				,option:="",option1:="",option2:="",pos:="",thisHwnd:="",toRemove:="",object:="",TV_Child:="",TV_Item:="",TV_Text:="",TVC:="",TVP:="",LV_CurrRow:="",opt:=""
	If (ishwnd!=-1&&!IsObject(ishwnd)){
		/*
			ObjTree is also used to Monitor messages for TreeView: ObjeTree(obj=wParam,Title=lParam,Options=msg,ishwnd=hwnd)
			when ishwnd is a handle, this routine is taken
		*/
		
		; Using _Struct class we can assign new pointer to our structure
		; This way the structure is available a lot faster and less CPU is used
		HDR[]:=Title
		
		; Check if this message is relevant for our windows
		If (HDR.code!=TVN_GETINFOTIP || !TREEOBJ["_" HDR.hwndFrom])
			Return 
		
		; Set Default Gui
		Gui,% (G:=TREEOBJ["_" HDR.hwndFrom]) ":Default"
		
		; Set Default TreeView
		Gui,TreeView, ObjTreeTreeView%G%
		
		; HDR.Item contains the relevant TV_ID
		TV_GetText(TV_Text,TV_Item:=HDR.hItem)
		
		; Check if this GUI uses a ToolTip object that contains the information in same structure as the TreeView
		If ToolTipText:=TT[G] { ; Gui has own ToolTip object
			
			; following will resolve the item in ToolTip object
			object:=[TV_Text]
			While TV_Item:=TV_GetParent(TV_Item){
				TV_GetText(ToolTipText,TV_Item)
				object.Insert(ToolTipText)
			}

			; Resolve our item/value in ToolTip object
			While object.MaxIndex(){
				ToolTipText:=ToolTipText[object.Remove()]
			}
			; Item is not an object and is not empty, display value in ToolTip
			If (ToolTipText!="")
				Return HDR.pszText[""]:=&ToolTipText
		}
		
		; Gui has no ToolTip object or item could not be resolved
		; Get the value of item and display in ToolTip
		object:=parents[G,HDR.hItem]
		
		; Check if Item is an object and if so, display first 20 keys (first 50 chars) and values (first 100 chars)
		If (Parents[G,object]!=HDR.hItem){
			for key,v in object
				If ((IsObject(key)?(Chr(177) " " (&key)):key)=TV_Text)
					Return ToolTipText:=IsObject(v)?"":v,HDR.pszText[""]:=&ToolTipText
		} else { ; Item is an object, display
			ToolTipText:=""
			for key,v in object
			{
				ToolTipText.=(ToolTipText?"`n":"") SubStr(key,1,50) (StrLen(key)>50?"...":"") " = " (IsObject(v)?"[Obj] ":SubStr(v,1,100) (StrLen(v)>100?"...":""))
				If (A_Index>20){
					ToolTipText.="`n...s"
					break
				}
			}
			HDR.pszText[""]:= &ToolTipText
		}
		Return
	}
	; Function was not called by Message to the window
	; Create a new ObjTree window
	
	
	; Get the hwnd of default GUI to restore it later
	Gui,+HwndDefaultGui
	
	;find free gui starting at 30
	Loop % (G := 30) { 
	 Gui %G%:+LastFoundExist
	 If !WinExist() ;gui is free
		break
	 G++
	}
	
	; Custom ToolTip object
	; It needs to have same keys/object structure as main object
	; You can leave out keys, then their value will be show
	If IsObject(ishwnd) 
		TT[G]:=ishwnd
	else TT[G]:=""
	
	; Apply properties and Gui options
	If (Options="")
		Options:="+AlwaysOnTop +Resize,GuiShow=w640 h480"
	If RegExMatch(Options,"i)^\s*([-\+]?ReadOnly)(\d+)?\s*$",option)
		Options:="+AlwaysOnTop +Resize,GuiShow=w640 h480",ReadOnly[G]:=option1,ReadOnlyLevel[G]:=option2
	else ReadOnly[G]:="+ReadOnly"
	Loop, Parse, Options, `,, %A_Space%
	{
	 opt := Trim(SubStr(A_LoopField,1,InStr(A_LoopField,"=")-1))
	 If RegExMatch(A_LoopField,"i)([-\+]?ReadOnly)(\d+)?",option)
		ReadOnly[G]:=option1,ReadOnlyLevel[G]:=option2
	 If (InStr("Font,GuiShow,NoWait",opt))
		%opt% := SubStr(A_LoopField,InStr(A_LoopField,"=") + 1,StrLen(A_LoopField))  
	 else GuiOptions:=RegExReplace(A_LoopField,"i)[-\+]?ReadOnly\s?")
	}
	
	; Set new default Gui
	Gui,%G%:Default
	
	; Set font
	if Font
		Gui, Font, % SubStr(Font,1,Pos := InStr(Font,":") - 1), % SubStr(Font,Pos + 2,StrLen(Font)) 
	
	; Get Gui size
	RegExMatch(GuiShow,"\b[w]([0-9]+\b).*\b[h]([0-9]+\b)",size)
	
	; Get hwnd of new window
	Gui,+HwndthisHwnd
	
	; Hwnd will be required later so save it
	hWnd[G]:=thisHwnd
	
	; Apply Gui options and create Gui
	Gui,%GuiOptions% +LastFound +LabelObjTree__
	Gui,Add,Button, x0 y0 NoTab Hidden Default gObjTree_ButtonOK,Show/Expand Object
	GuiControlGet,pos,Pos
	Gui,Add,TreeView,% "xs w" (size1*0.3) " h" size2 " ys AltSubmit gObjTree_TreeView +0x800 hwndTREEHWND " ReadOnly[G] " vObjTreeTreeView" G
	Gui,Add,ListView,% "x+1 w" (size1*0.7) " h" (size2*0.5) " ys AltSubmit Checked " ReadOnly[G] " gObjTree_ListView hwndLISTHWND" G " vObjTreeListView" G,[IsObj] Key/Address|Value/Address
	Gui,Add,Edit,% "y+1 w" (size1*0.7) " h" (size2*0.5) " -wrap +HScroll gObjTree_Edit HWNDEDITHWND " ReadOnly[G]
	GuiControl,Disable,Edit1
	TREEOBJ["_" (TREEHWND+0)] := G
	Attach(TREEHWND,"w1/2 h")
	Attach(LISTHWND%G%,"w1/2 h1/2 x1/2 y0")
	Attach(EDITHWND,"w1/2 h1/2 x1/2 y1/2")
	
	; parents will hold TV_Item <> Object relation
	parents[G]:={}
	
	; Convert object to TreeView
	; Also create a clone for our object
	; Changes can be optionally saved when ObjTree is closed when -ReadOnly is used
	If (ReadOnly[G]="-ReadOnly")
		newObj[G]:=ObjTree_Clone(Objects[G]:=obj),parents[G,newObj[G]]:=0,ObjTree_Add(newObj[G],0,parents,G)
	else parents[G,obj]:=0,ObjTree_Add(Objects[G]:=obj,0,parents,G)
	
	; Create Menus to be used for all ObjTree windows (ReadOnly windows have separate Menu)
	if !MenuExist {
		Menu,ObjTree,Add,&Expand,ObjTree_ExpandSelection
		Menu,ObjTree,Add,&Collapse,ObjTree_CollapseSelection
		Menu,ObjTree,Add
		Menu,ObjTree,Add,E&xpand All,ObjTree_ExpandAll
		Menu,ObjTree,Add,C&ollapse All,ObjTree_CollapseAll
		Menu,ObjTree,Add
		Menu,ObjTree,Add,&Insert,ObjTree_Insert
		Menu,ObjTree,Add,I&nsertChild,ObjTree_InsertChild
		Menu,ObjTree,Add
		Menu,ObjTree,Add,&Delete,ObjTree_Delete
		
		Menu,ObjTreeReadOnly,Add,&Expand,ObjTree_ExpandSelection
		Menu,ObjTreeReadOnly,Add,&Collapse,ObjTree_CollapseSelection
		Menu,ObjTreeReadOnly,Add
		Menu,ObjTreeReadOnly,Add,E&xpand All,ObjTree_ExpandAll
		Menu,ObjTreeReadOnly,Add,C&ollapse All,ObjTree_CollapseAll
		
		MenuExist:=1
	}
	
	; Register to Launch this function OnMessage
	OnMessage(WM_NOTIFY,"ObjTree")
	
	; Show our Gui
	Gui,Show,%GuiShow%,%Title%
	
	; Restore Default Gui
	If DefaultGui
		Gui, %DefaultGui%:Default
	
	; Return hwnd of new ObjTree window
	Return thisHwnd
	
	; Backup current Gui number and display Menu
	ObjTree__ContextMenu:
		G:=A_Gui
		If (ReadOnly[G]!="-ReadOnly")
			Menu,ObjTreeReadOnly,Show
		else Menu,ObjTree,Show
	Return
	
	; Insert new Item, launched by Menu
	ObjTree_Insert:
		If A_Gui
			G:=A_Gui
		If (ReadOnly[G]!="-ReadOnly")
			return
		Changed[G]:=1
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		TV_Item:=TV_GetSelection()
		Loop % ReadOnlyLevel[G]
			If !(TV_Item:=TV_GetParent(TV_Item))
				Return
		EditItem[G]:=TV_GetParent(TV_Child:=TV_GetSelection())
		,EditObject[G]:=!EditItem[G]?newObj[G]:parents[G,EditItem[G]]
		,EditObject[G].Insert("")
		,Parents[G,EditItem[G]:=TV_Add(EditObject[G].MaxIndex(),EditItem[G],"Sort")]:=EditObject[G]
		,TV_Modify(EditItem[G],"Select")
		,TV_GetText(TV_Text,TV_Item)
	return
	
	; Insert new Child item, launched by Menu
	ObjTree_InsertChild:
		If A_Gui
			G:=A_Gui
		If (ReadOnly[G]!="-ReadOnly")
			return
		Changed[G]:=1
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		TV_Item:=TV_GetSelection()
		Loop % ReadOnlyLevel[G]
			If !(TV_Item:=TV_GetParent(TV_Item))
				Return
		EditItem[G]:=TV_GetParent(TV_Child:=TV_GetSelection())
		EditObject[G]:=!EditItem[G]?newObj[G]:parents[G,EditItem[G]]
		TV_GetText(_EditKey,TV_Child)
		If IsObject(EditObject[G,EditKey[G]:=_EditKey]){
			_EditKey:=EditObject[G,EditKey[G]].MaxIndex()+1
			EditObject[G,EditKey[G]].Insert(NewKey:=_EditKey?_EditKey:1,"") ;,ObjTree_Add(EditObject[G,EditKey[G]],TV_Child,parents[G])
			,Parents[G,EditItem[G]:=TV_Add(EditObject[G,EditKey[G]].MaxIndex(),TV_Child,"Sort")]:=EditObject[G,EditKey[G]]
			,ObjTree_LoadList(EditObject[G,EditKey[G]],"",G)
		} else 
			EditObject[G,EditKey[G]]:=NewKey:={1:""},parents[G,TV_Child]:=NewKey,parents[G,NewKey]:=TV_Child
			,ObjTree_Add(NewKey,TV_Child,parents,G)
		TV_Modify(TV_Child,"Expand")
		DllCall("InvalidateRect", "ptr", hwnd[G], "ptr", 0, "int", true)
	return
	
	; Delete Item, launched by Menu
	ObjTree_Delete:
		If A_Gui
			G:=A_Gui
		If (ReadOnly[G]!="-ReadOnly")
			return
		Changed[G]:=1
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		TV_Item:=TV_GetSelection()
		Loop % ReadOnlyLevel[G]
			If !(TV_Item:=TV_GetParent(TV_Item))
				Return
		EditObject[G]:=!TV_GetParent(TV_GetSelection())?newObj[G]:parents[G,TV_GetParent(TV_GetSelection())]
		TV_GetText(_EditKey,TV_Item:=TV_GetSelection())
		ObjRemove(EditObject[G],EditKey[G]:=_EditKey)
		for key in EditObject[G]
		{
			EditKey[G]:=key
			break
		}
		ObjTree_TVReload(EditObject[G],TV_Item,EditKey[G],parents,G)
		Return
	return
	
	; Close ObjTree Window
	ObjTree__Close:
		If A_Gui
			G:=A_Gui
		Gui,%G%:+OwnDialogs
		If (ReadOnly[G]="-ReadOnly" && Changed[G]){
			MsgBox,3,Save Changes,Would you like to save changes?
			IfMsgBox Cancel
				Return
			IfMsgBox Yes
			{
				toRemove:={}
				for key in Objects[G]
					toRemove[k]:=key
				for key in toRemove
					Objects[G].Remove(key)
				for key,v in newObj[G]
					Objects[G,key]:=v
			}
			newObj[G]:="",Objects[G]:="",parents[G]:="",hwnd[G]:="",TREEOBJ[G]:="",Readonly[G]:="",ReadOnlyLevel[G]:=""
		}
		Gui,%G%:Destroy
	Return
	
	; Edit control event, update value in ListView and clone of our object
	ObjTree_Edit:
		If A_Gui
			G:=A_Gui
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		If (ReadOnly[G]!="-ReadOnly"||!(EditItem[G]:=LV_GetNext(0)))
			Return
		TV_Item:=TV_GetSelection()
		Loop % ReadOnlyLevel[G]-1
			If !(TV_Item:=TV_GetParent(TV_Item)){
				LV_GetText(_EditKey,EditItem[G],2)
				ControlSetText,Edit1,% EditKey[G]:=_EditKey,% "ahk_id " hwnd[G]
				Return
			}
		EditObject[G]:=!TV_GetParent(TV_GetSelection())?newObj[G]:parents[G,TV_GetParent(TV_GetSelection())]
		LV_GetText(_EditKey,EditItem[G])
		If IsObject(EditObject[G,EditKey[G]:=_EditKey]){
			GuiControl,,Edit1
			GuiControl,Disable,Edit1
			Return
		}
		ControlGetText,EditValue,Edit1,% "ahk_id " hwnd[G]
		LV_Modify(EditItem[G],"",EditKey[G],EditValue)
		EditObject[G,EditKey[G]]:=EditValue
		Changed[G]:=1
	Return
	
	; TreeView events handling
	ObjTree_TreeView:
		If A_Gui
			G:=A_Gui
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		If (ReadOnly[G]="-ReadOnly"){
			If (A_GuiEvent=="E"||(A_GuiEvent="k"&&A_EventInfo=113)){
				If (A_GuiEvent="k")
					EditItem[G]:=TV_GetSelection()
				else EditItem[G]:=A_EventInfo
				EditObject[G]:=!TV_GetParent(EditItem[G])?newObj[G]:parents[G,TV_GetParent(EditItem[G])]
				TV_GetText(_EditKey,EditItem[G])
				EditKey[G]:=_EditKey
				Return
			} else if (EditItem[G]&&A_GuiEvent=="e"){
				TV_Item:=TV_GetSelection()
				Loop % ReadOnlyLevel[G]
					If !(TV_Item:=TV_GetParent(TV_Item))
						Return, TV_Modify(EditItem[G],"Sort",EditKey[G])
				TV_GetText(NewKey,EditItem[G])
				If (NewKey=EditKey[G])
					Return
				else if EditObject[G].HasKey(NewKey){
					Gui,%G%: +OwnDialogs
					MsgBox,4,Existing Item,The new item already exist.`nDo you want to replace it with this item?
					IfMsgBox No 
						Return TV_Modify(EditItem[G],"",EditKey[G])
					Changed[G]:=1
					EditObject[G,NewKey]:=EditObject[G,EditKey[G]],ObjRemove(EditObject[G],EditKey[G])
					return ObjTree_TVReload(EditObject[G],EditItem[G],NewKey,parents,G)
				} else {
					Changed[G]:=1
					EditObject[G,NewKey]:=EditObject[G,EditKey[G]],ObjRemove(EditObject[G],EditKey[G])
					return ObjTree_TVReload(EditObject[G],EditItem[G],NewKey,parents,G)
				}
			} else	If (A_GuiEvent="k"){ ;Key Press
				If A_EventInfo not in 45,46
					Return
				TV_Item:=TV_GetSelection()
				Loop % ReadOnlyLevel[G]
					If !(TV_Item:=TV_GetParent(TV_Item))
						Return
				If (A_EventInfo=45){ ;Insert + Shift && Insert
					Changed[G]:=1
					EditItem[G]:=TV_GetParent(TV_Child:=TV_GetSelection())
					EditObject[G]:=!EditItem[G]?newObj[G]:parents[G,EditItem[G]]
					If (GetKeyState("Shift","P")&&!ReadOnlyLevel[G])
						EditObject[G].Insert(EditKey[G]:={1:""})
						,parents[G,EditItem[G]:=TV_Add(EditObject[G].MaxIndex(),EditItem[G],"Sort")]:=EditKey[G],parents[G,EditKey[G]]:=EditItem[G]
						,ObjTree_Add(EditKey[G],EditItem[G],parents,G)
					else if (GetKeyState("CTRL","P")&&!ReadOnlyLevel[G]){
						TV_GetText(_EditKey,TV_Child)
						If IsObject(EditObject[G,EditKey[G]:=_EditKey]){
							_EditKey:=EditObject[G,EditKey[G]].MaxIndex()+1
							EditObject[G,EditKey[G]].Insert(_EditKey?_EditKey:1,"")
							,Parents[G,EditItem[G]:=TV_Add(EditObject[G,EditKey[G]].MaxIndex(),TV_Child,"Sort")]:=EditObject[G,EditKey[G]]
							,ObjTree_LoadList(EditObject[G,EditKey[G]],"",G)
						} else 
							EditObject[G,EditKey[G]]:=NewKey:={1:""},parents[G,TV_Child]:=NewKey,parents[G,NewKey]:=TV_Child
							,ObjTree_Add(NewKey,TV_Child,parents,G),TV_Modify(TV_Child,"Expand")
					} else 
						EditObject[G].Insert("")
						,parents[G,EditItem[G]:=TV_Add(EditObject[G].MaxIndex(),EditItem[G],"Sort")]:=EditObject[G]
				} else if (A_EventInfo=46) { ;Delete
					Changed[G]:=1
					EditObject[G]:=!TV_GetParent(TV_GetSelection())?newObj[G]:parents[G,TV_GetParent(TV_GetSelection())]
					TV_GetText(_EditKey,TV_Item:=TV_GetSelection())
					ObjRemove(EditObject[G],EditKey[G]:=_EditKey)
					for key in EditObject[G]
					{
						EditKey[G]:=key
						break
					}
					return ObjTree_TVReload(EditObject[G],TV_Item,EditKey[G],parents,G)
				}
				EditKey[G]:="",EditObject[G]:="",EditItem[G]:=""
				GuiControl, +Redraw, ObjTreeTreeView
				DllCall("InvalidateRect", "ptr", hwnd[G], "ptr", 0, "int", true)
				Return
			}
		} else if A_GuiEvent in k,E,e
			Return
		if (A_EventInfo=0)
			Return
		If (A_GuiEvent="-"){
			TV_Modify(A_EventInfo,"-Expand")
			Return
		}
		TV_GetText(TV_Text,A_EventInfo)
		TV_Modify(A_EventInfo,"Select")
		If parents[G].HasKey(A_EventInfo)
			ObjTree_LoadList(parents[G,A_EventInfo],TV_Text,G)
		else
			ObjTree_LoadList(parents[G,TV_GetParent(A_EventInfo)],TV_Text,G)
	Return
	
	; ListView events handling
	ObjTree_ListView:
		If A_Gui
			G:=A_Gui
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		If (ReadOnly[G]="-ReadOnly"){
			If (A_GuiEvent=="E"){
				LV_GetText(_EditKey,A_EventInfo),EditKey[G]:=_EditKey,EditItem[G]:=TV_GetSelection()
				EditObject[G]:=!TV_GetParent(EditItem[G])?newObj[G]:parents[G,TV_GetParent(TV_GetSelection())]
			} else If (A_GuiEvent=="e"){
				TV_Item:=TV_GetSelection()
				Loop % ReadOnlyLevel[G]
					If !(TV_Item:=TV_GetParent(TV_Item)){
						LV_Modify(A_EventInfo,"",EditKey[G])
						Return
					}
				LV_GetText(NewKey,A_EventInfo)
				If (NewKey=EditKey[G])
					Return
				else if EditObject[G].HasKey(NewKey) {
					Gui,%G%: +OwnDialogs
					MsgBox,4,Existing Item,The new item already exist.`nDo you want to replace it with this item?
					IfMsgBox No
					{
						LV_Modify(A_EventInfo,"",EditKey[G])
						Return
					}
					Changed[G]:=1
					EditObject[G,NewKey]:=EditObject[G,EditKey[G]],ObjRemove(EditObject[G],EditKey[G])
					return ObjTree_TVReload(EditObject[G],EditItem[G],NewKey,parents,G)
				} else {
					Changed[G]:=1
					EditObject[G,NewKey]:=EditObject[G,EditKey[G]],ObjRemove(EditObject[G],EditKey[G])
					ObjTree_TVReload(EditObject[G],EditItem[G],NewKey,parents,G)
					return
				}
			}
		}
		If (A_GuiEvent = "ColClick"){
			Return ,IsFunc(LV_SortArrow)?LV_SortArrow.(LISTHWND%G%, A_EventInfo):""
		} else if (A_GuiEvent="k" && A_EventInfo=8){
			If TV_GetParent(TV_GetSelection())
				TV_Modify(TV_GetParent(TV_GetSelection()))
			return
		} else if (A_GuiEvent="Normal"){
			GuiControl,,Edit1
			GuiControl,Disable,Edit1
			TV_Item:=TV_GetSelection()
			If !(TV_Child:=TV_GetChild(TV_Item))
				TV_Item:=TV_GetParent(TV_Item),TV_Child:=TV_GetChild(TV_Item)
			If (!TV_GetNext(TV_Child) && TV_GetChild(TV_Child) && TV_GetText(TVP,TV_Child) && TV_GetText(TVC,TV_GetParent(TV_Child)) && TVC=TVP)
				If TV_GetParent(TV_Child)
					TV_Child:=TV_GetParent(0)
				else
					TV_Child:=TV_GetNext()
			If !TV_Child
				TV_Child:=TV_GetSelection()
			LV_GetText(LV_Item,A_EventInfo,1)
			While (TV_GetText(TV_Item,TV_Child) && TV_Item!=LV_Item)
				TV_Child:=TV_GetNext(TV_Child)
			If !TV_Child
				Return
			; If (parents[G,parents[G,TV_Child]]!=TV_Child)
				; If !(TV_Child:=parents[G,parents[G,TV_Child]])
					; TV_Child:=TV_GetNext()
			TV_Modify(TV_Child,"Select Expand")
			for key,v in parents[G,TV_Child]
				If (key=LV_Item || (Chr(177) " " (&key))=LV_Item){
					GuiControl,,Edit1,% parents[G,TV_Child,key]
					GuiControl,Enable,Edit1
					Break
				}
			Return
		} else if (A_GuiEvent!="DoubleClick" && !(A_GuiEvent="I" && ErrorLevel="C"))
			Return
	
	; Hidden Default Button
	; Used when Enter is pressed but also used by TreeView and ListView
	ObjTree_ButtonOK:
		If A_Gui
			G:=A_Gui
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		If (A_ThisLabel="ObjTree_ButtonOK"){
			GuiControlGet, FocusedControl, FocusV
			if (FocusedControl = "ObjTreeListView"){
				Item:=LV_GetNext(0)
			} else if (FocusedControl = "ObjTreeTreeView"){
				TV_Modify(TV_GetSelection(),"Expand")
				Return 
			}
			If !Item
				Return
		} else Item:=A_EventInfo
		TV_Item:=TV_GetSelection()
		If !(TV_Child:=TV_GetChild(TV_Item))
			TV_Item:=TV_GetParent(TV_Item),TV_Child:=TV_GetChild(TV_Item)
		If (!TV_GetNext(TV_Child) && TV_GetChild(TV_Child) && TV_GetText(TVP,TV_Child) && TV_GetText(TVC,TV_GetParent(TV_Child)) && TVC=TVP)
			If TV_GetParent(TV_Child)
				TV_Child:=TV_GetParent(0)
			else
				TV_Child:=TV_GetNext()
		If !TV_Child
			TV_Child:=TV_GetSelection()
		LV_GetText(LV_Item,Item,1)
		While (TV_GetText(TV_Item,TV_Child) && TV_Item!=LV_Item)
			TV_Child:=TV_GetNext(TV_Child)
		If (A_GuiEvent="I" && ErrorLevel="C"){
			If (parents[G,parents[G,TV_Child]]=TV_Child){
				If (ErrorLevel=="c")
					LV_Modify(Item,"Check")
			} else If (Errorlevel=="C")
				LV_Modify(Item,"-Check")
		} else if (TV_Child)
			TV_Modify(TV_Child,"Select Expand")
	Return
	
	ObjTree_ExpandAll:
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		ObjTree_Expand(TV_GetNext())
	Return
	ObjTree_ExpandSelection:
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		ObjTree_Expand(TV_GetSelection(),1)
	Return
	ObjTree_CollapseAll:
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		ObjTree_Expand(TV_GetNext(),0,1)
		TV_Modify(TV_GetNext())
	Return
	ObjTree_CollapseSelection:
		Gui,%G%:Default
		Gui,TreeView, ObjTreeTreeView%G%
		Gui,ListView, ObjTreeListView%G%
		ObjTree_Expand(TV_GetSelection(),1,1)
	Return
}
ObjTree_Expand(TV_Item,OnlyOneItem=0,Collapse=0){
	Loop {
		If !TV_GetChild(TV_Item)
			TV_Modify(TV_GetParent(TV_Item),(Collapse?"-":"") "Expand")
		else TV_Modify(TV_Item,(Collapse?"-":"") "Expand")
		If (TV_Child:=TV_GetChild(TV_Item))
			ObjTree_Expand(TV_Child,0,Collapse)
	} Until (OnlyOneItem || (!TV_Item:=TV_GetNext(TV_Item)))
}
ObjTree_Add(obj,parent,ByRef p,G){
	k:="",v:=""
	for k,v in obj
	{
		If (IsObject(v) && !p[G].Haskey(v))
			p[G,v]:=TV_Add(IsObject(k)?Chr(177) " " (&k):k,parent,"Sort"),p[G,p[G,v]]:=v
			,ObjTree_Add(v,p[G,v],p,G)
		else
			p[G,lastParent:=TV_Add(IsObject(k)?Chr(177) " " (&k):k,parent,"Sort")]:=IsObject(v)?v:obj
		If (IsObject(k) && !p[G].HasKey(v))
			p[G,k]:=TV_Add(Chr(177) " " (&k),IsObject(v)?p[G,v]:lastParent,"Sort"),p[G,p[G,k]]:=k
			,ObjTree_Add(k,p[G,k],p,G)
	}
}
ObjTree_Clone(obj,e=0){
	k:="",v:=""
	If !e
		e:={(obj):clone:=obj._Clone()}
	else If !e.HasKey(obj)
		e[obj]:=clone:=obj._Clone()
	for k,v in obj
	{
		If IsObject(v){
      If (IsObject(n:=k) && !e.HasKey(n))
         n:=ObjTree_Clone(k,e)
			else if e.HasKey(n)
				n:=e[n]
			If !e.HasKey(v){
				e[v]:=clone[n]:=ObjTree_Clone(v,e)
			} else clone[n]:=e[v]
		} else If IsObject(k) {
			If !e.HasKey(k){
				clone[n:=ObjTree_Clone(k,e)]:=e[k]:=clone[n],ObjRemove(clone,k)
			} else clone[e[k]]:=v,ObjRemove(clone,k)
		}
	}
	Return clone
}
ObjTree_TVReload(ByRef obj,TV_Item,Key,ByRef parents,G){ ; Version 1.0.1.0 http://www.autohotkey.com/forum/viewtopic.php?t=69756
	Gui,%G%:Default
	Gui,TreeView, ObjTreeTreeView%G%
	If !(TV_Child:=TV_GetParent(TV_Item))
		TV_Delete(),parents[G]:={}
	else {
		While % TV_GetChild(TV_Child)
			TV_Delete(TV_GetChild(TV_Child))
	}
	ObjTree_Add(obj,TV_Child,parents,G)
	ObjTree_LoadList(obj,Key,G)
	GuiControl, +Redraw, ObjTreeTreeView
	TV_Child:=TV_GetChild(TV_Child)
	While (TV_GetText(TV_Item,TV_Child) && TV_Item!=Key){
		TV_Child:=TV_GetNext(TV_Child)
	}
	TV_Modify(TV_Child,"Select") ;select item
	DllCall("InvalidateRect", "ptr", hwnd[G], "ptr", 0, "int", true)
}
ObjTree_LoadList(obj,text,G){
	LV_CurrRow:=""
	Gui,%G%:Default
	Gui,ListView, ObjTreeListView%G%
	select:=!TV_GetChild(TV_GetSelection())
	LV_Delete()
	GuiControl,,Edit1,
	GuiControl,Disable,Edit1
	for k,v in obj
	{
		LV_Add(((IsObject(v)||IsObject(k))?"Check":"") (select&&text=(IsObject(k)?(Chr(177) " " (&k)):k)?(" Select",LV_CurrRow:=A_Index):"")
					,IsObject(k)?(Chr(177) " " (&k)):k,IsObject(v)?(Chr(177) " " (&v)):v)
		If (LV_CurrRow=A_Index){
			LV_Modify(LV_CurrRow,"Vis Select") ;make sure selcted row it is visible
			GuiControl,Enable,Edit1
			GuiControl,,Edit1,%v%
		}
	}
	Loop 2
		LV_ModifyCol(A_Index,"AutoHdr") ;autofit contents
}

/*
	Function:		Attach
					Determines how a control is resized with its parent.

	hCtrl:			
					- hWnd of the control if aDef is not empty.					
					- hWnd of the parent to be reset if aDef is empty. If you omit this parameter function will use
					the first hWnd passed to it.
					With multiple parents you need to specify which one you want to reset.					
					- Handler name, if parameter is string and aDef is empty. Handler will be called after the function has finished 
					moving controls for the parent. Handler receives hWnd of the parent as its only argument.

	aDef:			
					Attach definition string. Space separated list of attach options. If omitted, function working depends on hCtrl parameter.
					You can use following elements in the definition string:
					
					- 	"x,y,w,h" letters along with coefficients, decimal numbers which can also be specified in m/n form (see example below).
					-   "r". Use "r1" (or "r") option to redraw control immediately after repositioning, set "r2" to delay redrawing 100ms for the control
						(prevents redrawing spam).
					-	"p" (for "proportional") is the special coefficient. It will make control's dimension always stay in the same proportion to its parent 
						(so, pin the control to the parent). Although you can mix pinned and non-pinned controls and dimensions that is rarely what you want. 
						You will generally want to pin every control in the parent.
					-	"+" or "-" enable or disable function for the control. If control is hidden, you may want to disable the function for 
						performance reasons, especially if control is container attaching its children. Its perfectly OK to leave invisible controls 
						attached, but if you have lots of them you can use this feature to get faster and more responsive updates. 
						When you want to show disabled hidden control, make sure you first attach it back so it can take its correct position
						and size while in hidden state, then show it. "+" must be used alone while "-" can be used either alone or in Attach definition string
						to set up control as initially disabled.

	Remarks:
					Function monitors WM_SIZE message to detect parent changes. That means that it can be used with other eventual container controls
					and not only top level windows.

					You should reset the function when you programmatically change the position of the controls in the parent control.
					Depending on how you created your GUI, you might need to put "autosize" when showing it, otherwise resetting the Gui before its 
					placement is changed will not work as intented. Autosize will make sure that WM_SIZE handler fires. Sometimes, however, WM_SIZE
					message isn't sent to the window. One example is for instance when some control requires Gui size to be set in advance in which case
					you would first have "Gui, Show, w100 h100 Hide" line prior to adding controls, and only Gui, Show after controls are added. This
					case will not trigger WM_SIZE message unless AutoSize is added.
				
				
	Examples:
	(start code)
					Attach(h, "w.5 h1/3 r2")	;Attach control's w, h and redraw it with delay.
					Attach(h, "-")				;Disable function for control h but keep its definition. To enable it latter use "+".
					Attach(h, "- w.5")			;Make attach definition for control but do not attach it until you call Attach(h, "+").
					Attach()					;Reset first parent. Use when you have only 1 parent.
					Attach(hGui2)				;Reset Gui2.
					Attach("Win_Redraw")		;Use Win_Redraw function as a Handler. Attach will call it with parent's handle as argument.
					Attach(h, "p r2")			;Pin control with delayed refreshing.

					
					; This is how to do delayed refresh of entire window.
					; To prevent redraw spam which can be annoying in some cases, 
					; you can choose to redraw entire window only when user has finished resizing it.
					; This is similar to r2 option for controls, except it works with entire parent.
					
					Attach("OnAttach")			;Set Handler to OnAttach function
					...
					
					OnAttach( Hwnd ) {
						global hGuiToRedraw := hwnd
						SetTimer, Redraw, -100
					}

					Redraw:
						Win_Redraw(hGuiToRedraw)
					return
	(end code)
	Working sample:
	(start code)
		#SingleInstance, force
			Gui, +Resize
			Gui, Add, Edit, HWNDhe1 w150 h100
			Gui, Add, Picture, HWNDhe2 w100 x+5 h100, pic.bmp 

			Gui, Add, Edit, HWNDhe3 w100 xm h100
			Gui, Add, Edit, HWNDhe4 w100 x+5 h100
			Gui, Add, Edit, HWNDhe5 w100 yp x+5 h100
			
			gosub SetAttach					;comment this line to disable Attach
			Gui, Show, autosize			
		return

		SetAttach:
			Attach(he1, "w.5 h")		
			Attach(he2, "x.5 w.5 h r")
			Attach(he3, "y w1/3")
			Attach(he4, "y x1/3 w1/3")
			Attach(he5, "y x2/3 w1/3")
		return
	(end code)

	About:
			o 1.1 by majkinetor
			o Licensed under BSD <http://creativecommons.org/licenses/BSD/> 
 */
Attach(hCtrl="", aDef="") {
	 Attach_(hCtrl, aDef, "", "")
}

Attach_(hCtrl, aDef, Msg, hParent){
	static
	local s1,s2, enable, reset, oldCritical

	if (aDef = "") {							;Reset if integer, Handler if string
		if IsFunc(hCtrl)
			return Handler := hCtrl
	
		ifEqual, adrWindowInfo,, return			;Resetting prior to adding any control just returns.
		hParent := hCtrl != "" ? hCtrl+0 : hGui
		loop, parse, %hParent%a, %A_Space%
		{
			hCtrl := A_LoopField, SubStr(%hCtrl%,1,1), aDef := SubStr(%hCtrl%,1,1)="-" ? SubStr(%hCtrl%,2) : %hCtrl%,  %hCtrl% := ""
			gosub Attach_GetPos
			loop, parse, aDef, %A_Space%
			{
				StringSplit, z, A_LoopField, :
				%hCtrl% .= A_LoopField="r" ? "r " : (z1 ":" z2 ":" c%z1% " ")
			}
			%hCtrl% := SubStr(%hCtrl%, 1, -1)				
		}
		reset := 1,  %hParent%_s := %hParent%_pw " " %hParent%_ph
	}

	if (hParent = "")  {						;Initialize controls 
		if !adrSetWindowPos
			adrSetWindowPos		:= DllCall("GetProcAddress", "uint", DllCall("GetModuleHandle", "str", "user32"), A_IsUnicode ? "astr" : "str", "SetWindowPos")
			,adrWindowInfo		:= DllCall("GetProcAddress", "uint", DllCall("GetModuleHandle", "str", "user32"), A_IsUnicode ? "astr" : "str", "GetWindowInfo")
			,OnMessage(5, A_ThisFunc),	VarSetCapacity(B, 60), NumPut(60, B), adrB := &B
			,hGui := DllCall("GetParent", "uint", hCtrl, "Uint") 

		hParent := DllCall("GetParent", "uint", hCtrl, "Uint") 
		
		if !%hParent%_s
			DllCall(adrWindowInfo, "uint", hParent, "uint", adrB), %hParent%_pw := NumGet(B, 28) - NumGet(B, 20), %hParent%_ph := NumGet(B, 32) - NumGet(B, 24), %hParent%_s := !%hParent%_pw || !%hParent%_ph ? "" : %hParent%_pw " " %hParent%_ph
		
		if InStr(" " aDef " ", "p")
			StringReplace, aDef, aDef, p, xp yp wp hp
		ifEqual, aDef, -, return SubStr(%hCtrl%,1,1) != "-" ? %hCtrl% := "-" %hCtrl% : 
		else if (aDef = "+")
			if SubStr(%hCtrl%,1,1) != "-" 
				 return
			else %hCtrl% := SubStr(%hCtrl%, 2), enable := 1 
		else {
			gosub Attach_GetPos
			%hCtrl% := ""
			loop, parse, aDef, %A_Space%
			{			
				if (l := A_LoopField) = "-"	{
					%hCtrl% := "-" %hCtrl%
					continue
				}
				f := SubStr(l,1,1), k := StrLen(l)=1 ? 1 : SubStr(l,2)
				if (j := InStr(l, "/"))
					k := SubStr(l, 2, j-2) / SubStr(l, j+1)
				%hCtrl% .= f ":" k ":" c%f% " "
			}
 			return %hCtrl% := SubStr(%hCtrl%, 1, -1), %hParent%a .= InStr(%hParent%, hCtrl) ? "" : (%hParent%a = "" ? "" : " ")  hCtrl 
		}
	}
	ifEqual, %hParent%a,, return				;return if nothing to anchor.

	if !reset && !enable {					
		%hParent%_pw := aDef & 0xFFFF, %hParent%_ph := aDef >> 16
		ifEqual, %hParent%_ph, 0, return		;when u create gui without any control, it will send message with height=0 and scramble the controls ....
	} 

	if !%hParent%_s
		%hParent%_s := %hParent%_pw " " %hParent%_ph

	oldCritical := A_IsCritical
	critical, 5000

	StringSplit, s, %hParent%_s, %A_Space%
	loop, parse, %hParent%a, %A_Space%
	{
		hCtrl := A_LoopField, aDef := %hCtrl%, 	uw := uh := ux := uy := r := 0, hCtrl1 := SubStr(%hCtrl%,1,1)
		if (hCtrl1 = "-")
			ifEqual, reset,, continue
			else aDef := SubStr(aDef, 2)	
		
		gosub Attach_GetPos
		loop, parse, aDef, %A_Space%
		{
			StringSplit, z, A_LoopField, :		; opt:coef:initial
			ifEqual, z1, r, SetEnv, r, %z2%
			if z2=p
				 c%z1% := z3 * (z1="x" || z1="w" ?  %hParent%_pw/s1 : %hParent%_ph/s2), u%z1% := true
			else c%z1% := z3 + z2*(z1="x" || z1="w" ?  %hParent%_pw-s1 : %hParent%_ph-s2), 	u%z1% := true
		}
		flag := 4 | (r=1 ? 0x100 : 0) | (uw OR uh ? 0 : 1) | (ux OR uy ? 0 : 2)			; nozorder=4 nocopybits=0x100 SWP_NOSIZE=1 SWP_NOMOVE=2
		;m(hParent, %hParent%a, hCtrl, %hCTRL%)
		DllCall(adrSetWindowPos, "uint", hCtrl, "uint", 0, "uint", cx, "uint", cy, "uint", cw, "uint", ch, "uint", flag)
		r+0=2 ? Attach_redrawDelayed(hCtrl) : 
	}
	critical %oldCritical%
	return Handler != "" ? %Handler%(hParent) : ""

 Attach_GetPos:									;hParent & hCtrl must be set up at this point
		DllCall(adrWindowInfo, "uint", hParent, "uint", adrB), 	lx := NumGet(B, 20), ly := NumGet(B, 24), DllCall(adrWindowInfo, "uint", hCtrl, "uint", adrB)
		,cx :=NumGet(B, 4),	cy := NumGet(B, 8), cw := NumGet(B, 12)-cx, ch := NumGet(B, 16)-cy, cx-=lx, cy-=ly
 return
}

Attach_redrawDelayed(hCtrl){
	static s
	s .= !InStr(s, hCtrl) ? hCtrl " " : ""
	SetTimer, %A_ThisFunc%, -100
	return
 Attach_redrawDelayed:
	loop, parse, s, %A_Space%
		WinSet, Redraw, , ahk_id %A_LoopField%
	s := ""
 return
}