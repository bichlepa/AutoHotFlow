;http://ahkscript.org/boards/viewtopic.php?f=6&t=3892
#Include ZipFile.ahk
 
;// Instantiates the class, creates 'MyZip.zip' if it doesn't exist
zip := new ZipFile("MyZip.zip")
;// Add all text documents in the current directory to the archive and delete them
zip.pack("*.txt", true)
;// Enumerate the items in the archive
for item in zip
	MsgBox % "Name: "            . item.name
	       . "`nSize: "          . item.size
	       . "`nType: "          . item.type
	       . "`nDate modified: " . item.date
	       . "`nRelative Path: " . item.path
;// Delete 'test.txt' from the archive
zip.delete("test.txt")
;// Extract the contents of the archive to folder 'Extracted'
zip.unpack(, "Extracted")
return