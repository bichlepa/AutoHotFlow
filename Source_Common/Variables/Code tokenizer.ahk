tokenizer(string)
{

	tokens:=Object()
	
	opchars:="+-*/%=&|<>!:."
	puncchars:=",(){}[]%`n"""
	whitespacechars:=" `t`r"
	whitespaceandLfchars:=" `t`r`n"
	
	mode:=1 ;variable name or keyword
	mode:=2 ;number
	mode:=3 ;whitespace
	mode:=4 ;escape char
	mode:=5 ;opchars
	mode:=6 ;puncchars
	mode:=10 ;unknown
	mode:=0 ;start new token
	
	wholeLines:=Object()
	preparedString:=""
	Loop,parse, string,`n
	{
		if ((pos:=instr(a_loopfield, "`n;")) or (pos:=instr(a_loopfield, "`r;")) or (pos:=instr(a_loopfield, " " ";")) or (pos:=instr(a_loopfield, "`t;")))
		{
			StringLeft,oneWholeLine,a_loopfield,% pos
			;~ MsgBox "%pos%" "%oneWholeLine%" "%a_loopfield%"
			wholeLines.push(oneWholeLine)
			preparedString.=oneWholeLine "`n"
		}
		else
		{
			wholeLines.push(A_LoopField)
			preparedString.=A_LoopField "`n"
		}
	}
	
	line:=1
	col:=1
	
	Loop, parse, preparedString
	{
		Char := A_LoopField
		CharNumber := Asc(Char) 
		;continue parsing a new token
		if (mode = 1) ;variable name or keyword
		{
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and  charNumber <=0x5A or charNumber >= 0x61 and  charNumber <=0x7A) or (charNumber>=0x30 and charNumber<=0x39) or (charNumber = 0x5F)) ;Unicode character or letter or number or _
			{
				currToken.value.=Char
			}
			else
			{
				tokens.push(currToken)
				mode:=0
			}
		}
		else if (mode = 2) ;number
		{
			if ( (charNumber>=0x30 and charNumber<=0x39)) ;number
			{
				currToken.value.=Char
			}
			else
			{
				tokens.push(currToken)
				mode:=0
			}
		}
		else if (mode = 3) ;whitespace
		{
			IfInString,whitespacechars,%Char%
			{
				currToken.value.=Char
			}
			else if (Char = "`n")
			{
				currToken.value.=Char
				currToken.withlf:=true
			}
			else
			{
				tokens.push(currToken)
				mode:=0
			}
		}
		;~ else if (mode = 4) ;can only be single letters
		else if (mode = 5) ;opchars
		{
			IfInString,opchars,%Char%
			{
				currToken.value.=Char
			}
			else
			{
				tokens.push(currToken)
				mode:=0
			}
		}
		else if (mode = 10) ;unknown chars
		{
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and  charNumber <=0x5A or charNumber >= 0x61 and  charNumber <=0x7A)) ;Unicode character or letter
			{
				tokens.push(currToken)
				mode:=0
			}
			else if (charNumber>=0x30 and charNumber<=0x39) ;number
			{
				tokens.push(currToken)
				mode:=0
			}
			else IfInString,whitespacechars,%Char%
			{
				tokens.push(currToken)
				mode:=0
			}
			else if (Char = "`n")
			{
				tokens.push(currToken)
				mode:=0
			}
			else IfInString,opchars,%Char%
			{
				tokens.push(currToken)
				mode:=0
			}
			else IfInString,puncchars,%Char%
			{
				tokens.push(currToken)
				mode:=0
			}
			else
			{
				currToken.value.=Char
			}
			
		}
		
		if (mode = 0) 
		{
			prevToken:=currToken
			currToken:=new class_token()
			
			;start parsing a new token
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and  charNumber <=0x5A or charNumber >= 0x61 and  charNumber <=0x7A)) ;Unicode character or letter
			{
				mode := 1 ;variable name or keyword
				currToken.value:=Char
				currToken.type:="name"
			}
			else if (charNumber>=0x30 and charNumber<=0x39) ;number
			{
				mode := 2 ;number
				currToken.value:=Char
				currToken.type:="number"
			}
			else IfInString,whitespacechars,%Char%
			{
				mode := 3 ;whitespace
				currToken.value:=Char
				currToken.type:="whitespace"
			}
			else if (Char = "`n")
			{
				mode := 3 ;whitespace
				currToken.value:=Char
				currToken.withlf:=true
				currToken.type:="whitespace"
			}
			else if (Char = "``")
			{
				mode := 0 ;a escape char is always alone
				currToken.value:=Char
				currToken.type:="escape"
			}
			else IfInString,opchars,%Char%
			{
				mode := 5 ;opchars
				currToken.value:=Char
				currToken.type:="op"
			}
			else IfInString,puncchars,%Char%
			{
				mode := 0 ; a puncchar is always alone
				currToken.value:=Char
				currToken.type:="punc"
				tokens.push(currToken)
			}
			else 
			{
				mode := 10 ;unknown
				currToken.value:=Char
				currToken.type:="unknown"
			}
			
			currToken.line:=line
			currToken.col:=col
			currToken.pos:=A_Index
			currToken.wholeline:=wholeLines[line]
		}
		
		
		if (char="`n")
		{
			line++
			col:=1
		}
		else
		{
			col++
		}
		;~ MsgBox, %Char% - %CharNumber%
	}
	if (currToken.type)
		tokens.push(currToken)
	
	
	return tokens
	
	
	
}

class class_token
{
	is_punc(ch = "")
	{
		if ((this.type = "punc" && !ch) || (this.value = ch))
		{
			return true
		}
		return false
	}
	is_op(ch = "")
	{
		if ((this.type = "op" && !ch) || (this.value = ch))
		{
			return true
		}
		return false
	}
	is_whitespace(ch = "", withLF=false)
	{
		if ((this.type = "whitespace" && !ch) || (this.value = ch))
		{
			if (withLF)
			{
				if (this.withlf)
					return true
				else
					return false
			}
			return true
		}
		return false
	}
}
	
