; tokenizer of code
; it will parse the code and split it into tokens
tokenizer(string)
{
	; initialize empty return value
	tokens := Object()
	
	; define operator characters
	opchars := "+-*/%=&|<>!:."
	; define punctuation characters
	puncchars := ",(){}[]%`n"""
	; define whitespace characters
	whitespacechars := " `t`r"
	; define whitespace characters with linefeed
	whitespaceandLfchars := " `t`r`n"
	
	
	; first split the code into lines and remove comments
	wholeLines := Object()
	preparedString := ""
	Loop, parse, string, `n
	{
		; check whether the line has a comment
		if ((pos := instr(a_loopfield, "`n;")) or (pos := instr(a_loopfield, "`r;")) or (pos := instr(a_loopfield, " " ";")) or (pos := instr(a_loopfield, "`t;")))
		{
			; comment found. remove it
			StringLeft, oneWholeLine, a_loopfield, % pos
		}
		Else
		{
			; not comment found. take whole line
			oneWholeLine := A_LoopField
		}
		wholeLines.push(oneWholeLine)
		preparedString .= oneWholeLine "`n"
	}
	
	; We will use a state machine. those are possible states
	mode := 1 ;variable name or keyword
	mode := 2 ;number
	mode := 3 ;whitespace
	mode := 4 ;escape char
	mode := 5 ;opchars
	mode := 6 ;puncchars
	mode := 10 ;unknown
	mode := 0 ;start new token. We start from this state

	; init line and column (character in line) counters
	line := 1
	col := 1
	
	; start tokenizing with the state machine
	Loop, parse, preparedString
	{
		Char := A_LoopField
		CharNumber := Asc(Char)

		;continue parsing a new token
		if (mode = 1) ;variable name or keyword
		{
			; check character
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and  charNumber <=0x5A or charNumber >= 0x61 and  charNumber <=0x7A) or (charNumber>=0x30 and charNumber<=0x39) or (charNumber = 0x5F))
			{
				; we have an Unicode character or letter or number or _
				; add it to the current token
				currToken.value .= Char
			}
			else
			{
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
		}
		else if (mode = 2) ;number
		{
			; check character
			if ((charNumber>=0x30 and charNumber<=0x39)) ;number
			{
				; we have a number
				; add it to the current token
				currToken.value .= Char
			}
			else
			{
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
		}
		else if (mode = 3) ;whitespace
		{
			; check character
			IfInString, whitespacechars, %Char%
			{
				; we have a whitespace character (not a linefeed)
				; add it to the current token
				currToken.value .= Char
			}
			else if (Char = "`n")
			{
				; we have a linefeed
				; add it to the current token. Remember that this token has a linefeed
				currToken.value .= Char
				currToken.withlf := true
			}
			else
			{
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
		}
		;~ else if (mode = 4) ;escape char can only be a single letter, so the state machine cannot be in that mode
		else if (mode = 5) ;opchars
		{
			; check character
			IfInString, opchars, %Char%
			{
				; we have an operator character
				; add it to the current token
				currToken.value .= Char
			}
			else
			{
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
		}
		else if (mode = 10) ;unknown chars
		{
			; check character
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and charNumber <= 0x5A or charNumber >= 0x61 and  charNumber <= 0x7A)) ;Unicode character or letter
			{
				; we have an unicode character or a letter (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else if (charNumber >= 0x30 and charNumber <= 0x39) ;number
			{
				; we have a number (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else IfInString, whitespacechars, %Char%
			{
				; we have a whitespace (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else if (Char = "`n")
			{
				; we have a linefeed (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else IfInString, opchars,%Char%
			{
				; we have an operator (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else IfInString,puncchars,%Char%
			{
				; we have an punctuation (not an unknown character anymore)
				; the current token has finished. Add it to the token list and search for a new token in next step
				tokens.push(currToken)
				mode := 0
			}
			else
			{
				; we still have an unknown character
				; add it to the current token
				currToken.value .= Char
			}
		}
		
		; we just entered the state machine or have now finished a token. Find the next token
		if (mode = 0)
		{
			; create a new token
			currToken := new class_token()
			
			;start parsing a new token
			if ((CharNumber > 0x7f) or (charNumber >= 0x41 and  charNumber <= 0x5A or charNumber >= 0x61 and  charNumber <= 0x7A)) ;Unicode character or letter
			{
				; we have an unicode character or a letter
				; this token will be a name (of a variable or keyword)
				mode := 1 ;variable name or keyword
				currToken.value := Char
				currToken.type := "name"
			}
			else if (charNumber >= 0x30 and charNumber <= 0x39) ;number
			{
				; we have a number
				; this token will be a number
				mode := 2 ;number
				currToken.value := Char
				currToken.type := "number"
			}
			else IfInString,whitespacechars,%Char%
			{
				; we have a whitespace
				; this token will be a whitespace
				mode := 3 ;whitespace
				currToken.value := Char
				currToken.type := "whitespace"
			}
			else if (Char = "`n")
			{
				; we have a linefeed
				; this token will be a whitespace with a linefeed
				mode := 3 ;whitespace
				currToken.value := Char
				currToken.withlf := true
				currToken.type := "whitespace"
			}
			else if (Char = "``")
			{
				; we have an escape character
				; this token will be an escape character
				mode := 0 ;a escape char is always alone
				currToken.value := Char
				currToken.type := "escape"
			}
			else IfInString, opchars ,%Char%
			{
				; we have an operator character
				; this token will be an operator
				mode := 5 ;opchars
				currToken.value := Char
				currToken.type := "op"
			}
			else IfInString, puncchars, %Char%
			{
				; we have a punctuation character
				; this token will be a punctuation
				mode := 0 ; a puncchar is always alone
				currToken.value := Char
				currToken.type := "punc"
				tokens.push(currToken)
			}
			else 
			{
				; we have an uknown character
				; this token will be unknown
				mode := 10 ;unknown
				currToken.value := Char
				currToken.type := "unknown"
			}
			
			; save the position of the current token
			currToken.line := line
			currToken.col := col
			currToken.pos := A_Index

			; save the whole line where the current token is, so we use it for warning messages
			currToken.wholeline := wholeLines[line]
		}
		
		; check whether the current character is a linefeed
		if (char = "`n")
		{
			; we have a linefeed. increase line counter and reset column counter
			line++
			col := 1
		}
		else
		{
			; we have not a linefeed. increase column counter
			col++
		}
	}

	; we finished parsing the code. We may have to save the last token
	if (currToken.type)
		tokens.push(currToken)
	
	return tokens
}

; token class which provide some functions
class class_token
{
	; returns whether the token is a punktuation
	is_punc()
	{
		if (this.type = "punc")
		{
			return true
		}
		return false
	}
	; returns whether the token is an operator
	is_op()
	{
		if (this.type = "op")
		{
			return true
		}
		return false
	}
	; returns whether the token is a whitespace
	; withLF: if true, it will only return true if the token has a linefeed
	is_whitespace(withLF = false)
	{
		if (this.type = "whitespace")
		{
			if (withLF and this.withlf or not withLF)
			{
				return true
			}
		}
		return false
	}

	; returns true if the token is equal to p_token_str
	is(p_token_str)
	{
		if (this.value = p_token_str)
			return true
		Else
			return false
	}
}
	
