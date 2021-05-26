
;~ #Include %A_ScriptDir%\..\..


;~ string=
;~ (
;~ aasdf:=round(2)
;~ bage:="hello" 4
;~ if (bage = "hel" "o" . round(10/2-1))
	
	;~ cee:=1

;~ else if bage = "hell" "o" . round(10/2-1)
	
;~ {
	
	;~ cee:="richtig"
	
	;~ d:=2
	
;~ }
;~ else
	;~ cee:=3


;~ )

;Thanks to Mihai Bazon for the tutorial: http://lisperator.net/pltut/parser/

;~ tokens:=tokenizer(string)
;~ MsgBox % strobj(tokens)
;~ parsedCode:=parser.parse(tokens)
;~ MsgBox % strobj(parsedCode)
;~ FileDelete, result.txt
;~ FileAppend,% strobj(parsedCode), result.txt

; code parser. Needs a tokenized code.
class class_parser
{
	; define available keywords
	keywords:=" if else "
	
	; parse a code
	parse(tokens, whatToParse ="code")
	{
		; define the precedence of all available operators
		this.precedence := Object()
		this.precedence[":="] :=  1
		this.precedence["+="] :=  1
		this.precedence["-="] :=  1
		this.precedence[".="] :=  1
		this.precedence["/="] :=  1
		this.precedence["*="] :=  1
		this.precedence["||"] :=  2
		this.precedence["&&"] :=  3
		this.precedence["!"] :=  4
		this.precedence["<"] :=  7
		this.precedence[">"] :=  7
		this.precedence["<="] :=  7
		this.precedence[">="] :=  7
		this.precedence["="] :=  7
		this.precedence["=="] :=  7
		this.precedence["!="] :=  7
		this.precedence["."] :=  9
		this.precedence["+"] :=  10
		this.precedence["-"] :=  10
		this.precedence["*"] :=  20
		this.precedence["/"] :=  20
		this.precedence["//"] :=  20
		this.precedence["%"] :=  20

		; save tokens
		this.tokens:=tokens

		; prepare variable which will contain the errors
		this.errors := Object()
		
		; prepare variable which will contain the parsed tokens
		this.parsedTokens := Object()

		; Initialize token index
		this.Index := 0

		; will be set to true, if we reach end of code
		this.eof := false

		; set the first token as current token and skip first whitespaces
		this.next()
		this.skip_whitespace()

		; check whether expression or code is empty
		if (this.eof)
		{
			; there is nothing here, return nothing
			return
		}
		
		if (whatToParse = "code")
		{
			return this.parseCode_toplevel()
		}
		else if (whatToParse = "expression")
		{
			return this.parse_expression_toplevel()
		}
		else
			throw exception("cannot parse code of type " whatToParse)
	}
	
	; set the next token as the current one
	next()
	{
		; increase the token index
		this.Index++

		; find the next token
		if (this.tokens.haskey(this.Index))
		{
			; set the next token as the current one. Also save next token and previous token
			this.nextToken := this.tokens[this.Index+1]
			this.Token := this.tokens[this.Index]
			this.prevToken := this.tokens[this.Index-1]
		}
		else
		{
			; we reached the end of the code
			this.nextToken := ""
			this.Token := ""
			this.prevToken := ""
			this.eof := true
		}
	}
	
	
	;Entry point of the code parser
	parseCode_toplevel()
	{
		; start parsing the code (do not expect brackets at the beginning)
		prog := this.parse_prog(false)
		; return the parsed code
		prog.errors := this.errors

		return prog
	}
	
	; Parse executable code
	; if insideBrackets, we will only execute the code inside the brackets
	; todo: implementation in progress
	parse_prog(insideBrackets = true)
	{
		; initialize variable where we will save the parsed code
		prog := Object()

		if (insideBrackets)
		{
			; skip the opening bracket
			this.expect_punc("{")

			; skip whitespace characters
			this.skip_whitespace()
		}

		; parse until we finish the code
		while (not this.eof)
		{
			; break if we reach the closing bracket
			if (this.token.is_punc("}"))
				break
			
			; parse the code
			prog.push(this.parse_code())
			
			this.skip_whitespace()
		}
		
		if (insideBrackets)
		{
			; skip the closing bracket
			this.expect_punc("}")
		}
		
		; return the parsing result
		retval := {type: "prog", prog: prog}
		return retval
	}

	;parse some code
	; todo: implementation in progress
	parse_code()
	{
		; skip whitespaces (if any)
		this.skip_whitespace()

		; parse an expression in current code line
		expr := this.parse_expression(this.parse_codeline(), 0)
		
		; todo: parse a call
		;~ if (this.token.is_punc("("))
			;~ return this.parse_call(expr)
		;~ else
			return expr
	}
	
	;parse a line of code
	; todo: implementation in progress
	parse_codeline()
	{
		; check the current token
		if (this.token.is("{"))
		{
			 ;inside brackets {} there is always some executable code. Parse the code
			expr := this.parse_prog()
		}
		else if (this.is_whitespace(true))
		{
			; we have a linefeed, we can parse the next code line
			this.next()
			return this.parse_codeline()
		}
		else if (this.token.is("if"))
		{
			; we have an if condition. Parse it
			expr:= this.parse_if()
		}
		else if (this.is_kw("else"))
		{
			; we have an else keyword without an if condition. Generate error
			this.input.croak("Else with no matching if")
			this.next()
		}
		else if (this.token.type = "name")
		{
			; we have a name. Parse the variable name
			expr := this.parse_varname()
		}
		else
		{
			; The token contains something that is not expected. Generate error
			expr := ""
			this.croak("Unexpected token in code")
			
		}
		;If after a token there are brackets, parse a function call
		if (this.token.is("("))
			return this.parse_call(expr)
		else
			return expr
	}
	
	;Parse an if expression
	; todo: implementation in progress
	parse_if()
	{
		; skip the if keyword
		this.expect_kw("if")

		; parse the expression after the if keyword
		cond := this.parse_expression(this.parse_expressionToken(), 0) 
		
		; todo: remove?
		;~ if (!this.token.is("{")) 
			;~ this.skip_punc("{")

		; skip whitespace
		this.skip_whitespace()
		
		; parse the code after the if expression
		then := this.parse_code()

		; prepare return value of parsed if condition
		ret := {type: "if", cond: cond, then: then}

		; skip whitespace
		this.skip_whitespace()
		
		; check whether we have now an else keyword
		if (this.is_kw("else"))
		{
			; parse the code after the else keyword
			this.next()

			; add the parsed code after else to the return value
			ret.else := this.parse_code()
		}

		return ret
	}
	
	;Entry point of the expression parser
	parse_expression_toplevel()
	{
		; Start parsing the expression
		prog := this.parse_expression(this.parse_expressionToken(), 0)

		; if the returned value is not set, create a new object
		if (!isobject(prog))
			prog := Object()

		; write errors in return value, if any
		prog.errors := this.errors
		
		return prog
	}

	; parse an expression. Parameters are the already parsed part of the expression and my current precendence
	; left: already parsed part of expression which is on the left side
	; my_prec: precedence of the last parsed token
	; percentIsEnd: used if there is an expression or variable name enclosed inside percent signs and we need to stop when we find a percent sign (todo: do some tests)
	parse_expression(left, my_prec, percentIsEnd = false)
	{
		;Skip whitespaces
		this.skip_whitespace(false)
		
		;check whether the next token is an operation
		if not(this.token.is_op())
		{
			; we have no operator. Try to find out, whether there is an operator keyword or if there is a missing concatenation token.
			if (this.token.type = "name" || this.token.type = "number" || this.token.value = """" )
			{
				if (this.is_kw("or"))
				{
					; we have a keyword. Convert it to operator.
					tok := {type: "op", value: "||"}
				}
				else if (this.is_kw("and"))
				{
					; we have a keyword. Convert it to operator.
					tok := {type: "op", value: "&&"}
				}
				else if (this.is_kw("not"))
				{
					; we have a keyword. Convert it to operator.
					tok := {type: "op", value: "!"}
				}
				else
				{
					; we have a name, number or string which can be concatenated. Insert the missing concatenation token.
					tok := {type: "op", value: "."}

					; since we do neither use an existing token nor dit convert a token, we must not skip the current token
					DoNotSkipToken := True
				}
			}
		}
		else
		{
			; we have an oprator token. Use it
			tok := this.token
		}

		; did we find an operator token?
		if (tok)
		{
			; we have an operator token. We can parse it.

			; get the precedence of the current token
			his_prec := this.precedence[tok.value]
			
			if (his_prec > my_prec)
			{
				; The precedence of the current token is higher than the precedence of the last parsed token. Parse the token
				if not DoNotSkipToken
				{
					; skip current token, (if we do not parse a missing token)
					this.next()
					this.skip_whitespace(false)
				}
				
				;check wheter the next token is the assign token
				if (tok.value = ":=" or tok.value = ".=" or tok.value = "+=" or tok.value = "-=" or tok.value = "*=" or tok.value = "/=")
					type := "assign"
				else
					type := "binary"
				
				;parse the right part of the token
				right := this.parse_expression(this.parse_expressionToken(percentIsEnd), his_prec, percentIsEnd)

				; defind a new left token, which is a combination of the left part of expression, the operator and the right part of expression
				newleft := {type: type, operator: tok.value, left: left, right: right}

				;continue parsingthe next token
				retval := this.parse_expression(newleft, my_prec, percentIsEnd)			
				return retval
			}
			else
			{
				; The precedence of the current token is lower than the precedence of the last parsed token. Return the already expressed token.
				return left
			}
		}
		
		; We have no operator token, return the already parsed expression
		return left
	}
	
	; parse a token in an expression.
	parse_expressionToken(percentIsEnd = false)
	{
		;Skip whitespaces
		this.skip_whitespace(false)
		
		;Do we have an openig bracket?
		if (this.token.is("("))
		{
			; we have an opening bracket. Parse the expression inside the brackets
			this.next()
			expr := this.parse_expression(this.parse_expressionToken(), 0)
			this.expect_punc(")")
		}
		else
		{
			;check whether next token is a variable name, a number or a string
			tok := this.token
			if (this.token.is(""""))
			{
				; we have a string. start parsing the string
				expr := this.parse_String()
			}
			else if (this.token.type = "number")
			{
				; we have a number. start parsing the number
				expr := this.parse_Number()
			}
			else if (this.token.type = "name")
			{
				; we have a variable name. start parsing the variable name.
				expr := this.parse_varname(percentIsEnd)
			}
			else
			{
				;If not, there is something what is not expected. Tell error
				expr := ""
				this.croak("Unexpected token in expression" " - '" value "'")
			}
		}
		
		;If after a variable name token there are brackets
		if (expr.type = "var" && this.token.is("("))
		{
			; we have a function call instead of a variable name. convert it and parse function parameters.
			return this.parse_call(expr)
		}
		
		return expr
	}
	
	; Parse a variable name
	; percentIsEnd: stops on percent sign. Used if we have an epxression inside percent signs 
	parse_varname(percentIsEnd = false)
	{
		line := this.token.line
		col := this.token.col
		pos := this.token.pos
		wholeline := this.token.wholeline
		
		; catch error
		if (this.token.type != "name" and this.token.value != "%")
		{
			this.croak("expected variable name")
			return
		}
		
		;Create path, which length can be more than one if accessing a element of object (e.g. obj.value or obj[valuename][1]
		path := object()
		Loop
		{
			if (a_index = 1)
			{
				;In the first part of the path, the variable name can be a deref (e.g. %varname% or value%index%)
				concat := Object()
				Loop
				{
					if (this.token.type = "name")
					{
						; we have a variable name (or at least a part of it)
						; add this part of name to the concat object
						concat.push({type: "str", value: this.token.value})

						; change the type of current token
						this.token.type := "var"

						; skip the current token
						this.next()
					}
					else if (!percentIsEnd and this.token.value = "%")
					{
						; we have a percent sign (and we don't need to stop on percent sign)
						; Skipt first %
						this.next()

						; parse the expression inside the percent signs
						expr := this.parse_expression(this.parse_expressionToken(true), 0, true)

						; add this part of name to the concat object
						concat.push(expr)

						;skip second %
						this.skip_punc("%")
					}
					else
					{
						; we do not have a name and not a percent sign. The first part of the path has finished
						break
					}
				}
				; we parsed the first part of the path

				if (concat.maxindex() = 1)
				{
					; we have only one part of the first path part. We can just use it as the first path part
					path.push(concat[1])
				}
				else
				{
					; we have multiple parts of the first path part

					; todo: how does it work???
					reverseOrderIndices := Object()
					for oneindex, onepath in concat
					{
						reverseOrderIndices.push(oneindex)
					}

					; 
					obj := object()
					for oneindex, oneReverseIndex in reverseOrderIndices
					{
						if (oneindex=1)
						{
							obj := concat[oneReverseIndex]
						}
						else
						{
							obj := ({type: "binary", operator: ".", left: obj, right: concat[oneReverseIndex]})
						}
						
					}
					path.push(obj)
				}
			}
			else
			{
				;in other than first part of the path, the subelements can be specified after dots (e.g. obj.value) or in brackets as expressions (e.g. obj[valuename])
				if (this.token.is("."))
				{
					this.next() ;Skip "."

					if (this.token.type = "name" or this.token.type = "number")
					{
						; the token type is name or number. We can add it as a path part
						this.token.type := "var"
						this.next()
						path.push({type: "str", value: this.token.value})
					}
					else if (!percentIsEnd and this.token.value="%")
					{
						; we have a percent sign. We do not support derefs here
						this.croak("No derefs possible here" )
						this.next()
					}
					else
					{
						; unexpected token
						this.croak("Unexpected token in variable path" )
						this.next()
					}
				}
				else if (this.token.is("["))
				{
					; we have an array bracket
					; skip the opening bracket
					this.next()

					; parse tht expression inside the brackets
					expr := this.parse_expression(this.parse_expressionToken(), 0)
					path.push(expr)

					; skip the closing bracket
					this.skip_punc("]")
				}
				else if (!percentIsEnd and this.token.value="%")
				{
					; we have a percent sign. We do not support derefs here
					this.input.croak("No derefs possible here: `n" )
				}
				else
				{
					break
				}
			}
		}
		
		; create return value
		expr := {type: "var", path: path, line: line, col: col, pos: pos, wholeline: wholeline}
		
		return expr
	}
	
	;Parse a function call
	parse_call(func)
	{
		; prepare return value with the function parameters
		pars := object()

		; skip the opening brackets and whitespaces
		this.expect_punc("(")
		this.skip_whitespace(false)
		
		if (this.token.is(")"))
		{
			while (not this.eof)
			{
				; parse the function parameter
				pars.push(this.parse_expression(this.parse_expressionToken(),0))
				
				; skip whitespaces (if any)
				this.skip_whitespace(false)
				
				; break on closing bracket (do not skip it yet)
				if (this.token.is(")"))
					break
				
				if this.token.is(",")
				{
					; we have a comma. Skip it and stay inside the loop to parse the next function parameter
					this.next()
				}
				else
				{
					this.croak("Unexpected token inside function parameters")
					break
				}
			}
		}
		; else we have no function parameter since we have a closing bracket right after the opening bracket
		; there must be a closing bracket, if we finished the last loop
		this.expect_punc(")")
		
		; change the type of the last token
		func.type := "func"

		; create a new parsed token
		call := {type: "call", path: func.path, args: pars, line: func.line, col: func.col, pos: func.pos, wholeline: func.wholeline}
		return call
	}
	
	;parse a number
	parse_Number()
	{
		; prepare return value
		num := ""
		if (this.token.type = "number")
		{
			line := this.token.line
			col := this.token.col
			pos := this.token.pos
			wholeline := this.token.wholeline
			
			; write the value of current numerical token and skip the token
			num := this.token.value
			this.token.type := "num"
			this.next()

			; check whether we have a decimal number
			if (this.token.value = ".")
			{
				; we have a decimal number
				; skip the dot
				num .= "."
				this.token.type := "num"
				this.next()

				; if the next token is a number
				if (this.token.type = "number")
				{
					; add the number after the dot
					this.token.type := "num"
					num .= this.token.value

					; check whether we have an other decimal number
					if (this.token.value = ".")
					{
						this.croak("Two dots in a number")
					}
				}
			}
			return {type: "num", value: num, line: line, col: col, pos: pos, wholeline: wholeline}
		}
		else
		{
			this.croak("Number expected")
			return
		}
	}
	
	;parse a string
	parse_string()
	{
		
		line := this.token.line
		col := this.token.col
		pos := this.token.pos
		wholeline := this.token.wholeline
		
		; skip the quotation marks
		this.expect_punc("""")

		; prepare the return value
		string := ""

		Loop
		{
			; check the next token type
			if (this.token.type = "escape")
			{
				; we have an escape token
				this.token.type := "str"

				; skip the escape token
				this.next()

				; do we have an other name token?
				if (this.token.type = name)
				{
					; check the first character. Add it and all remaining characters in the token.
					firstchar := substr(this.token.value, 1, 1)
					if (firstchar = "n")
					{
						; we have a linefeed. Add it and all remaining characters in the token.
						string.="`n" substr(this.token.value,2)
					}
					else if (firstchar = "r")
					{
						; we have a carriage return. Add it and all remaining characters in the token.
						string.="`r" substr(this.token.value,2)
					}
					else if (firstchar = "b")
					{
						; we have a backspace. Add it and all remaining characters in the token.
						string.="`b" substr(this.token.value,2)
					}
					else if (firstchar = "t")
					{
						; we have a tabulator. Add it and all remaining characters in the token.
						string.="`t" substr(this.token.value,2)
					}
					else if (firstchar = "v")
					{
						; we have a vertical tab. Add it and all remaining characters in the token.
						string.="`v" substr(this.token.value,2)
					}
					else if (firstchar = "a")
					{
						; we have an alert. Add it and all remaining characters in the token.
						string.="`a" substr(this.token.value,2)
					}
					else if (firstchar = "f")
					{
						; we have a formfeed. Add it and all remaining characters in the token.
						string.="`f" substr(this.token.value,2)
					}
					else
					{
						; we don't have a supported escape character. Just add the current token value string
						string .= this.token.value
					}

					; skip the current token
					this.next()
				}
				else if (this.token.is(""""))
				{
					; we have an escaped quotation mark
					; add it to the string
					string .= """"
					this.token.type := "str"
					this.next()
				}
				else if (this.token.is_whitespace(true))
				{
					; we do not support linfeeds inside strings
					this.croak("Linefeed inside a string")
					break
				}
				else
				{
					; we have any other token type. Add it to string
					this.next()
					string .= this.token.value
				}
			}
			else if (this.token.is(""""))
			{
				; we have reached the closing quotatin mark
				this.token.type := "str"
				this.next()
				break
				
			}
			else if (this.token.is_whitespace(true))
			{
				; we do not support linfeeds inside strings
				this.croak("Linefeed inside a string") 
				break
			}
			else
			{
				; we have any other token type. Add it to string
				string .= this.token.value
				this.token.type := "str"
				this.next()
			}
		}

		; return the parsed string
		return {type: "str", value: string, line: line, col: col, pos: pos, wholeline: wholeline}
	}
	
	;Skips the next punctuation. The parameter is the expected punctuation. If the punctuation is not found, it will report error.
	expect_punc(ch)
	{
		if (this.token.value = ch)
			this.next()
		else
			this.croak("Expecting punctuation: """  ch  """")
	}

	;Skips the next keyword. The parameter is the expected punctuation. If the keyword is not found, it will report error.
	expect_kw(ch)
	{
		if (this.token.value = ch)
			this.next()
		else
			this.croak("Expecting keyword: """  ch  """")
	}
	
	;Skips whitespaces
	skip_whitespace(AllowLF=true)
	{
		if (this.token.type = "whitespace")
		{
			if (AllowLF or !(this.token.withlf))
				this.next()
		}
	}
	
	; checks whether the current token is a keyword
	is_kw(kw)
	{
		; a keyword must be a name token
		if (this.token.type = "name")
		{
			; after the name token there must be a whitespace or an opening bracket
			if (this.nexttoken.is_whitespace() or this.nexttoken.is_punc("("))
			{
				if (this.token.value = kw)
				{
					return true
				}
			}
		}
		return false
	}
	
	; creates an error message on parsing error
	croak(description)
	{
		wholelinehighlighted := substr(this.token.wholeline,1,this.token.col-1) " -> " this.token.value " <- " substr(this.token.wholeline, this.token.col + strlen(this.token.value))
		error := {description: description, line: this.token.line, col: this.token.col, pos: this.token.pos, wholeline: this.token.wholeline, value: this.token.value, wholelinehighlighted: wholelinehighlighted}
		this.token.errors.push(error)
		this.errors.push(error)
	}
	
}


