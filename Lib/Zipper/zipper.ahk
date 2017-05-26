;Zipper by Paul Bichler. Inspired by shajul and Sean from this topic https://autohotkey.com/board/topic/60706-native-zip-and-unzip-xpvista7-ahk-l/


zipper_zip(FilesToZip, ZipPath)
{
	run compress-archive -path "%FilesToZip%" -DestinationPath "%ZipPath%"
	
	return
	
	
	If Not FileExist(ZipPath)
		CreateZipFile(ZipPath)
	;~ filecopy, %filestozip%,%zippath%
	com_shellapp :=  ComObjCreate( "Shell.Application" )
	com_zip_folder_obj := com_shellapp.Namespace( ZipPath )
	
	loop, %FilesToZip%, 1
	{
		com_zip_folder_obj.CopyHere( FilesToZip, 4|16 )
	}

}

CreateZipFile(sZip)
{
	Header1 := "PK" . Chr(5) . Chr(6)
	VarSetCapacity(Header2, 18, 0)
	file := FileOpen(sZip,"w")
	file.Write(Header1)
	file.RawWrite(Header2,18)
	file.close()
}
zipper_unzip(ZipPath, DestinationFolder)
{
	FileCreateDir, DestinationFolder
	if errorlevel
	{
		return "Folder cannnot be created"
	}
	
	com_shellapp :=  ComObjCreate( "Shell.Application" )
	com_zip_folder_obj := com_shellapp.Namespace( ZipPath )
	com_dest_folder_obj := com_shellapp.Namespace( DestinationFolder )
	
	zippedItems := com_zip_folder_obj.items().count
	com_dest_folder_obj.CopyHere( com_zip_folder_obj.items, 4|16 )
	
	Loop 
	{
        sleep 10
        unzippedItems := com_dest_folder_obj.items().count
        IfEqual,zippedItems,%unzippedItems%
            break
    }
}