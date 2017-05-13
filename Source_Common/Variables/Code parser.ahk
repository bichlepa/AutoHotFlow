
;~ #Include %A_ScriptDir%\..\..
;~ #include lib\Object to file\String-object-file.ahk


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


class class_parser
{
	keywords:=" if else "
	
	parse(tokens, whatToParse ="code")
	{
		this.precedence:=Object()
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
		this.tokens:=tokens
		this.errors:=Object()
		this.Index:=0
		this.next()
		this.parsedTokens:=Object()
		
		if (whatToParse = "code")
		{
			return this.parseCode_toplevel()
		}
		else if (whatToParse = "expression")
		{
			return this.parse_expression_toplevel()
		}
		else
			MsgBox error don't know how to parse
			
	}
	
	next()
	{
		
		this.Index++
		if (this.tokens.haskey(this.Index))
		{
			this.nextToken:=this.tokens[this.Index+1]
			this.Token:=this.tokens[this.Index]
			this.prevToken:=this.tokens[this.Index-1]
		}
		else
			this.eof:=true
	}
	
	
	;Parse executable code inside {}
	parse_prog(insideBrackets=true)
	{
		prog:=Object()
		if (insideBrackets)
		{
			this.expect_punc("{")
				this.skip_whitespace()
		}
		while (not this.eof)
		{
			if (this.token.is_punc("}"))
				break
			
			prog.push(this.parse_code())
			
			this.skip_whitespace()
		}
		
		if (insideBrackets)
			this.expect_punc("}")
		
		
		retval:={type: "prog", prog: prog}
		return retval
	}
	
	
	;Entry point of the code parser
	parseCode_toplevel()
	{
		prog:=this.parse_prog(false)
		prog.errors:=this.errors
		return prog
	}
	
	;Entry point of the expression parser
	parse_expression_toplevel()
	{
		prog:=this.parse_expression(this.parse_expressionToken(),0)
		if (!isobject(prog))
			prog:=Object()
		prog.errors:=this.errors
		
		return prog
		
	}
	
	;parse some code
	parse_code()
	{
		this.skip_whitespace()
		expr:=this.parse_expression(this.parse_codeline(),0)
		
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(expr) "`n~`n" strobj(this)
		;~ if (this.token.is_punc("("))
			;~ return this.parse_call(expr)
		;~ else
			return expr
	}
	
	;parse a line of code
	parse_codeline()
	{
		if (this.is_punc("{")) ;inside {} there is always some executable code
		{
			expr:=this.parse_prog()
		}
		else if (this.is_whitespace(,true))
		{
			this.next()
			return this.parse_codeline()
		}
		else
		{
			;check whether a keyword
			if (this.is_kw("if"))
			{
				expr:=this.parse_if()
			}
			else if (this.is_kw("else"))
			{
				this.input.croak("Else with no matching if")
				this.next()
			}
			else if (this.token.type = "name")
			{
				expr:=this.parse_varname()
			}
			else
			{
				;If not, there is something what is not expected. Tell error
				expr:=""
				this.croak("Unexpected token in code" )
				
			}
		}
		;If after a token there are brackets, parse a function call
		if (this.is_punc("("))
			return this.parse_call(expr)
		else
			return expr
	}
	
	;Parse a if expression
	parse_if()
	{
		this.expect_kw("if")
		cond := this.parse_expression(this.parse_expressionToken(),0) 
			;~ MsgBox % strobj(cond)
		;~ if (!this.is_punc("{")) 
			;~ this.skip_punc("{")
		this.skip_whitespace()
		
		then:=this.parse_code()
		ret:= {type: "if", cond: cond, then: then}
		this.skip_whitespace()
		
		if (this.is_kw("else"))
		{
			this.next()
			ret.else:=this.parse_code()
		}
		return ret
	}
	
	
	;parse an expression. Parameters are the already parsed part of the expression and my current precendence
	parse_expression(left,my_prec, percentIsEnd = false)
	{
		if (this.token.line = 2)
			sleep 1
		this.skip_whitespace(false)
		
		;check whether the next token is a operation
		if not(this.is_op())
		{
			;Insert a concatenation token if missing
			if (this.token.type = "name" || this.token.type = "number" || this.token.value = """" )
			{
				;~ nexttok:=this.parse_expressionToken(percentIsEnd)
				if (this.is_kw("or"))
					tok := {type: "op", value: "||"}
				else if (this.is_kw("and"))
					tok := {type: "op", value: "&&"}
				else if (this.is_kw("not"))
					tok := {type: "op", value: "!"}
				else
				{
					tok := {type: "op", value: "."}
					DoNotSkipToken:=True
				}
			}
		}
		else
		{
			tok:=this.token
		}
		;~ MsgBox % strobj(tok)
		if (tok)
		{
			
			;if the token is a operation, check whether the new precedens is higher to my precendence
			his_prec := this.precedence[tok.value]
			
			if (his_prec > my_prec)
			{
				if not DoNotSkipToken
				{
					this.next()
					this.skip_whitespace(false)
				}
				;If the new precedence is higher to my precedese
				;check wheter the next token is the assign token
				if (tok.value = ":=" or tok.value = ".=" or tok.value = "+=" or tok.value = "-=" or tok.value = "*=" or tok.value = "/=")
					type := "assign"
				else
					type := "binary"
				
				;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(tok) "`n~`n" strobj(this)
				;parse the right part of the token
				right:= this.parse_expression(this.parse_expressionToken(percentIsEnd), his_prec, percentIsEnd)
				;continue parsing.
				newleft:={type: type, operator: tok.value, left: left, right: right}
				retval:=this.parse_expression(newleft, my_prec, percentIsEnd)			
				return retval
			}
			;else return the already parsed expression
			return left
			
		}
		
		
		; if the token is not an operation, return the already parsed expression
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(left) "`n~`n" strobj(this)
		return left
	}
	
	;parse a expression token
	parse_expressionToken(percentIsEnd=false)
	{
		;Skip whitespaces
		this.skip_whitespace(false)
		
		;Inside () is always an expression
		if (this.is_punc("("))
		{
			this.next()
			expr:=this.parse_expression(this.parse_expressionToken(),0)
			this.expect_punc(")")
		}
		else
		{
			;check whether next token is a variable name, a number or a string
			tok:=this.token
			if (this.is_punc(""""))
			{
				expr:=this.parse_String()
			}
			else if (this.token.type="number")
			{
				expr:=this.parse_Number()
			}
			else if (this.token.type="name")
			{
				expr:=this.parse_varname(percentIsEnd)
			}
			else
			{
				;If not, there is something what is not expected. Tell error
				expr:=""
				this.croak("Unexpected token in expression" )
				
			}
		}
		
		
		
		;If after a token there are brackets, parse a function call
		if (expr.type = "var" && this.is_punc("("))
			return this.parse_call(expr)
		
		return expr
	}
	
	;Parse a variable name
	parse_varname(percentIsEnd=false)
	{
		line:=this.token.line
		col:=this.token.col
		pos:=this.token.pos
		wholeline:=this.token.wholeline
		
		if (this.token.type!="name" and this.token.value != "%")
		{
			this.croak("expected variable name")
			return
		}
		
		;Create path, which length can be more than one if accessing a element of object (e.g. obj.value or obj[valuename][1]
		path:=object()
		Loop
		{
			if (a_index = 1)
			{
				;In the first part of the path, the variable name can be a deref (e.g. %varname% or value%index%)
				concat:=Object()
				Loop
				{
					
					if (this.token.type="name")
					{
						concat.push({type: "str", value: this.token.value})
						this.token.type:="var"
						this.next()
					}
					else if (!percentIsEnd and this.token.value="%")
					{
						this.next() ;Skipt first %
						expr:=this.parse_expression(this.parse_expressionToken(true),0, true)
						concat.push(expr)
						this.skip_punc("%") ;skip second %
					}
					else
					{
						break
					}
				}
				if (concat.maxindex()=1)
				{
					path.push(concat[1])
				}
				else
				{
					reverseOrderIndices:=Object()
					for oneindex, onepath in concat
					{
						reverseOrderIndices.push(oneindex)
					}
					obj:=object()
					for oneindex, oneReverseIndex in reverseOrderIndices
					{
						if (oneindex=1)
						{
							obj:=concat[oneReverseIndex]
						}
						else
						{
							obj:=({type: "binary", operator: ".", left: obj , right: concat[oneReverseIndex]})
						}
						
					}
					path.push(obj)
				}
			}
			else
			{
				;in other than first part of the path, the subelements can be specified after dots (e.g. obj.value) or in brackets as expressions (e.g. obj[valuename])
				if (this.is_op("."))
				{
					
					this.next() ;Skip "."
					if (this.token.type = "name" or this.token.type = "number")
					{
						this.token.type:="var"
						this.next()
						path.push({type: "str", value: this.token.value})
					}
					else if (!percentIsEnd and this.token.value="%")
					{
						this.croak("No derefs possible here" )
						this.next()
					}
					else
					{
						this.croak("Unexpected token in variable path" )
						this.next()
					}
					
				}
				else if (this.is_punc("["))
				{
					this.next()
					expr:=this.parse_expression(this.parse_expressionToken(),0)
					path.push(expr)
					this.skip_punc("]")
				}
				else if (!percentIsEnd and this.token.value="%")
				{
					this.input.croak("No derefs possible here: `n" )
				}
				else
				{
					break
				}
			}
			
		}
		
		expr:={type: "var", path: path, line: line, col: col, pos: pos, wholeline:wholeline}
		
		;~ ;Check whether it can be a keyword
		;~ if (expr.path.maxindex() = 1 and expr.path.1.type="str")
		;~ {
			;~ if instr(keywords," " expr.path.1.value " ")
			;~ {
				;~ expr.kw:=expr.path.1.value
			;~ }
		;~ }
		
		return expr
	}
	
	;Parse a function call
	parse_call(func)
	{
		pars:=object()
		this.expect_punc("(")
		this.skip_whitespace(false)
		
		while (not this.eof)
		{
			if (this.is_punc(")"))
				break
			
			pars.push(this.parse_expression(this.parse_expressionToken(),0))
			
			this.skip_whitespace(false)
			
			if (this.is_punc(")"))
				break
			
			if this.is_punc(",")
			{
				this.next()
			}
			else
			{
				this.croak("Unexpected token inside function parameters")
				break
			}
			
		}
		this.expect_punc(")")
		
		func.type:="func"
		call:={type: "call", path: func.path, args: pars, line: func.line, col: func.col, pos: func.pos, wholeline: func.wholeline}
		return call
		
		
		
	}
	
	;parse a number
	parse_Number()
	{
		num:=""
		if (this.token.type="number")
		{
			line:=this.token.line
			col:=this.token.col
			pos:=this.token.pos
			wholeline:=this.token.wholeline
			
			num:=this.token.value
			this.token.type:="num"
			this.next()
			if (this.token.value = ".")
			{
				num.="."
				this.token.type:="num"
				this.next()
				if (this.token.type = "number")
				{
					this.token.type:="num"
					num.=this.token.value
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
		
		line:=this.token.line
		col:=this.token.col
		pos:=this.token.pos
		wholeline:=this.token.wholeline
		
		this.expect_punc("""")
		string:=""
		Loop
		{
			if (this.token.type = "escape")
			{
				this.token.type:="str"
				this.next()
				if (this.token.type = name)
				{
					firstchar:=substr(this.token.value,1,1)
					if (firstchar = "n")
					{
						string.="`n" substr(this.token.value,2)
					}
					else if (firstchar = "r")
					{
						string.="`r" substr(this.token.value,2)
					}
					else if (firstchar = "b")
					{
						string.="`b" substr(this.token.value,2)
					}
					else if (firstchar = "t")
					{
						string.="`t" substr(this.token.value,2)
					}
					else if (firstchar = "v")
					{
						string.="`v" substr(this.token.value,2)
					}
					else if (firstchar = "a")
					{
						string.="`a" substr(this.token.value,2)
					}
					else if (firstchar = "f")
					{
						string.="`f" substr(this.token.value,2)
					}
					else
						string.=this.token.value
				}
				else if (this.is_punc(""""))
				{
					string.=""""
					this.token.type:="str"
					this.next()
				}
				else if (this.is_whitespace(,true))
				{
					this.croak("Linefeed inside a string")
					break
				}
				else
				{
					this.next()
					string.=this.token.value
				}
			}
			else if (this.is_punc(""""))
			{
				;end of string
				this.token.type:="str"
				this.next()
				break
				
			}
			else if (this.is_whitespace(,true))
			{
				this.croak("Linefeed inside a string") 
				break
			}
			else
			{
				string.= this.token.value
				this.token.type:="str"
				this.next()
			}
		}
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
	
	is_kw(kw)
	{
		if (this.token.type = "name")
		{
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
	
	is_punc(ch = "")
	{
		return this.token.is_punc(ch)
	}
	is_op(ch = "")
	{
		return this.token.is_op(ch)
	}
	is_whitespace(ch = "",  withLF=false)
	{
		return this.token.is_whitespace(ch, withLF)
	}
	
	
	
	croak(description)
	{
		wholelinehighlighted:=substr(this.token.wholeline,1,this.token.col-1) " -> " this.token.value " <- " substr(this.token.wholeline, this.token.col + strlen(this.token.value))
		error:={description: description, line: this.token.line, col: this.token.col, pos: this.token.pos, wholeline: this.token.wholeline, value: this.token.value, wholelinehighlighted: wholelinehighlighted}
		this.token.errors.push(error)
		this.errors.push(error)
		MsgBox % strobj(error)
	}
	
}


