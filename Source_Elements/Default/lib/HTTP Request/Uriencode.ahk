/*
license info:
{
	"name": "uriencode",
	"author": "VxE",
	"source": "https://autohotkey.com/board/topic/69205-lib-oauth-10a-ahk-basic-ahk-l-unicode-v103/page-2",
	"license": "BSD",
	"licenselink": "https://opensource.org/licenses/BSD-3-Clause"
}
*/

uriencode( str ) { ; -------------------------------------------------------------------------------
; Characters in str are converted to their %## encoding except unreserved ones ( a-z A-Z 0-9 _.~- ).
; If the string contains a character with an ascii code higher than 126, this function uses UTF-8
; encoding for those characters. E.g: '¢' will appear as %C2%A2 instead of %A2.
; ! IMPORTANT ! For ANSI versions of AHK, this function assumes that the input string is ALREADY IN
; UTF-8 FORMAT. 
   If !RegexMatch( str, "[^\x01-\x7e]" ) ; This regex shouldn't be too slow in unicode AHK.
   {
      ; Use the simple character conversion method. For each ascii code that is not reserved,
      StringReplace, str, str, `%, `%25, A
      Loop 125
         If ( A_Index < 45 && A_Index != 37 ) || A_Index = 47 || A_Index = 96 || 122 < A_Index
         || ( 57 < A_Index && A_Index < 65 ) || ( 90 < A_Index && A_Index < 95)
            StringReplace, str, str, % Chr( A_Index ), % "%" Chr( 48 + ( A_Index >> 4 )
            + 7 * ( 159 < A_Index )) Chr( 48 + ( A_Index & 15 ) + 7 * ( 9 < A_Index & 15 )), A
      Return str
   }
   ; Use the strict (and slow) method. This takes a UTF-8 string and parses it by bytes to rebuild
   ; the string with the right chars encoded.
   If ( A_IsUnicode )
   {
      c := str
      s := -1 + DllCall( "WideCharToMultiByte", "UInt", 65001, "UInt", 0
      , "UInt", &c, "Int", -1, "UInt", 0, "Int", 0, "UInt", 0, "UInt", 0 )
      VarSetCapacity( str, s + 1 )
      DllCall( "WideCharToMultiByte", "UInt", 65001, "UInt", 0
      , "UInt", &c, "Int", -1, "UInt", &str, "Int", s + 1, "UInt", 0, "UInt", 0 )
   }
   Else StringLen, s, str
   VarSetCapacity( c, s + 1, 0 )
   Loop % s
   {
      i := *(&str - 1 + A_Index)
      If ( 96 < i && i < 123 ) || ( 47 < i && i < 58 ) || ( 64 < i && i < 91 )
      || i = 45 || i = 46 || i = 96 || i = 126
         c .= Chr( i )
      Else c .= "%" Chr( 48 + ( i >> 4 ) + 7 * ( 159 < i ) ) Chr( 48 + ( i & 15 ) + 7 * ( 9 < i & 15 ) )
   }
   Return c
} ; uriencode( str ) -------------------------------------------------------------------------------