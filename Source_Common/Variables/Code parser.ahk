
global vars:={a: 2, b: 5}
getvar(varname)
{
	return vars[varname]
}

;~ a:=1
;~ if (a =1) 
	 ;~ {c:=3}
;~ else {c:=4}
;~ a:=2
;~ if (a ==1) 
	 ;~ {d:=3}
;~ else {d:=4}

;~ MsgBox %a% %c% %d%

;~ testExpr =
;~ (
;~ aasdf:=round(2)
;~ bage:="hello" 4

;~ if (bage = "hel" "o"  round(10/2-1))
	
	;~ cee:=1

;~ else if bage = "hell" "o"  round(10/2-1) 
;~ {
	
	;~ cee:="richtig" 
	
	;~ d:=2
	
;~ }
;~ else cee:=3

;~ str:="sd"
;~ asdf:=object()
;~ a`%str`%f.baba:=2
;~ asdf.baba:=2
;~ asdf["cab" "a"]:=asdf.baba + 3
;~ )


;~ testExpr := "(5<7)*5"


Var_EvaluateExpression(environment,ExpressionString,  func_GetVariable)
{
	;~ MsgBox %testExpr%
	myinputstream := new inputstream(ExpressionString)
	;~ MsgBox % A_LineNumber "`n" strobj(myinputstream) "`n~`n" myinputstream.peek()

	myTokenstream:=new tokenstream(myinputstream)
	;~ MsgBox % A_LineNumber "`n" strobj(myTokenstream) "`n~`n" myTokenstream.peek()
	;~ MsgBox % A_LineNumber "`n" strobj(myinputstream) "`n~`n" myinputstream.peek()
	;~ MsgBox % A_LineNumber "`n" strobj(myTokenstream) "`n~`n" myTokenstream.next()
	;~ MsgBox % A_LineNumber "`n" strobj(myinputstream) "`n~`n" myinputstream.peek()
	parsedCode:=new parse(myTokenstream, "expression")
	
	
	FileDelete,result.txt
	FileAppend,% ExpressionString "`n`n" ,result.txt,utf-8
	FileAppend,% strobj(parsedCode) "`n`n",result.txt,utf-8
	;~ MsgBox % strobj(parsedCode)
	
	if (parsedCode.errors.MaxIndex())
	{
		MsgBox % "Do not execute because there are errors:`n" strobj(parsedCode.errors)
	}
	else
	{
		env:=new environment()
		result:=evaluate(parsedCode, env, func_GetVariable)
		FileAppend,% strobj(env) "`n`n",result.txt,utf-8
		;~ MsgBox % "result = " result "`n`n" strobj(env)
	}
	
	return result
}




;Thanks to Mihai Bazon for the tutorial: http://lisperator.net/pltut/parser/

;Abstraction layer which allows some operations on a string
class inputStream
{
	;New input stream
	__new(input)
	{
		this.input:=input
		this.pos := 1
		this.line:=1
		this.linestart:=1
		this.col:=1
		this.errors:=Object()
	}
	
	;Get the next character and move on
	next()
	{
		ch := substr(this.input,this.pos++,1)
		if (ch == "`n")
		{
			this.linestart:=this.pos
			this.line++
			this.col := 1
		}
		else
		{
			this.col++
		}
		return ch
	}
	;Get the next character without moving on
	peek()
	{
		return substr(this.input,this.pos,1)
	}
	;Checks whether the end of the string was reached
	eof()
	{
		peekresult:=this.peek()
		return (peekresult =="")
	}
	;Reports an error
	croak(msg,len=1)
	{
		static
		lfpos:=InStr(this.input,"`n",,this.linestart)
		if (lfpos)
			linestring:=substr(this.input,this.linestart,lfpos-this.linestart) 
		else
			linestring:=substr(this.input,this.linestart) 
		;~ posstring:=format("{1:" this.col -2 "s}"," ")
		;~ MsgBox % this.col
		posstring:=""
		if (this.col >len+1)
			posstring:=format("{1:" this.col -len-1 "s}"," ")
		while(len>=a_index)
			posstring.="^"
		this.errors.push({description: msg, linenr: this.line, colnr: this.col, line: linestring, linepos: posstring})
		gui,font,,consolas
		gui,add,edit,readonly,% msg "`n`nline: " this.line "`ncol: " this.col "`n`n" linestring "`n" posstring
		gui,add,button,gok vok w100 default,OK
		guicontrol,focus,ok
		gui,show
		okpressed:=false
		while(okpressed=false)
			sleep 10
		;~ MsgBox ,0, error while parsing, % msg "`n`nline: " this.line "`ncol: " this.col "`n`n" linestring "`n" posstring
		ok:
		gui,destroy
		okpressed:=true
		return
	}
	getErrors()
	{
		return this.Errors
	}
}

;abstraction layer which makes an array of chars to an array of tokens
class TokenStream
{
	;define which operation chars, punctuation chars and whitespace chars are available
	opchars:="+-*/%=&|<>!:"
	puncchars:=".,(){}[]%`n"
	whitespacechars:=" `t`r"
	
	;create a new tokenstream. Needs a inputstream as parameter
	__new(input)
	{
		this.input:=input
	}
	
	;Checks whether a character is a digit
	is_digit(ch)
	{
		If ch is number
			return true
		return false
	}
	;Checks whether a character can be the beginning of a variable name or a keyword
	is_id_start(ch)
	{
		if (ch != "")
			If ch is alpha
				return true
		if (ch = "_")
			return true
		return false
		
	}
	;Checks wheter a character can be a letter of a variable name or keyword
	is_id(ch)
	{
		if (ch != "")
			If ch is alnum
				return true
		if (ch = "_")
			return true
		return false
		
	}
	;Checks wheter a character is a operation char
	is_op_char(ch)
	{
		If (InStr(this.opchars,ch))
			return true
		return false
		
	}
	;Checks wheter a character is a punctuation char
	is_punc(ch)
	{
		If (InStr(this.puncchars,ch))
			return true
		return false
		
	}
	;checks whether a character is a whitespace
	is_whitespace(ch)
	{
		If (InStr(this.whitespacechars,ch))
			return true
		return false
		
	}
	;checks whether a character is a whitespace or linefeeds
	is_whitespace_or_lf(ch)
	{
		If (InStr(this.whitespacechars,ch) or ch="`n")
			return true
		return false
		
	}
	;Read all characters until they are whitespaces
	read_while_is_whitespace()
	{
		str:=""
		while (not this.input.eof() and this.is_whitespace(this.input.peek()))
			str.=this.input.next()
		return str
	}
	;Read all characters until they are whitespaces or linefeeds
	read_while_is_whitespace_or_lf()
	{
		str:=""
		while (not this.input.eof() and this.is_whitespace_or_lf(this.input.peek()))
			str.=this.input.next()
		return str
	}
	;Read all characters until they are a number
	read_while_is_number()
	{
		num:=""
		hasdot:=false
		while (not this.input.eof())
		{
			ch:=this.input.peek()
			if (ch = ".")
			{
				if (hasdot)
					break
				else
				{
					hasdot:=true
				}
			}
			else if not (this.is_digit(ch))
			{
				break
			}
			num.=this.input.next()
		}
		return {type: "num", value: num}
	}
	;Read all characters until they are a variable name or keyword
	read_while_is_id()
	{
		str:=""
		while (not this.input.eof() )
		{
			ch:=this.input.peek()
			if not (this.is_id(ch))
			{
				break
			}
			str.=this.input.next()
		}
		
		return str
	}
	;read all characters until they are a operation char
	read_while_is_op_char()
	{
		str:=""
		while (not this.input.eof() and this.is_op_char(this.input.peek()))
			str.=this.input.next()
		return str
	}
	;Read a string until the "end" charater appears. escape escaped characters
	read_escaped(end)
	{
		escaped:=false
		str:=""
		this.input.next()
		while (!this.input.eof())
		{
			ch := this.input.next()
			if (escaped)
			{
				str.= ch
				escaped:=false
			}
			else if (ch = "\")
			{
				escaped := true
			}
			else if (ch =end)
			{
				break
			}
			else 
			{
				str.=ch
			}
		}
		return str
	}
	;read a string
	read_string()
	{
		str:= this.read_escaped("""")
			return {type: "str", value: str}
	}
	;Skipt a comment
	skip_comment()
	{
		str:=""
		loop 
		{
			;~ temp:=this.input.eof()
			if (this.input.eof())
				break
			if (this.input.peek() = "`n")
				break
			next:=this.input.next()
		}
		this.input.next()
	}
	;read next token.
	read_next()
	{
		;Skip all whitespaces
		this.read_while_is_whitespace()
		if (this.input.eof()) 
			return
		
		;Get first character
		ch := this.input.peek()
		;If a comment starts, skip it and get next token
		if (ch = ";")
		{
			this.skip_comment()
			return this.read_next()
		}
		;if a string starts, read and return the string
		if (ch = """") 
			return this.read_string()
		;if a number starts, read and return the number
		if this.is_digit(ch)
			return this.read_while_is_number()
		;if a variable name or keyword starts, read and return it
		if (this.is_id_start(ch))
		{
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" ch "`n~`n" strobj(this)
			varname:=this.read_while_is_id()
			return {type: "var", value: varname}
		}
		;if a punctuation starts, read and return the whole punctuation
		if (this.is_punc(ch))
			return {type: "punc", value: this.input.next()}
		;if a operation char starts, read and return the whole operation
		if (this.is_op_char(ch))
			return {type: "op", value: this.read_while_is_op_char()}
		;This should not be reached
		this.input.croak("Can't handle character: " ch)
	}
	;Return the next token without moving on
	peek()
	{
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" ch "`n~`n" strobj(this)
		if not (this.current)
			this.current := this.read_next()
		
		return this.current 
	}
	;return the next token and move on
	next()
	{
		if (this.current)
		{
			tok :=this.current
			
			this.current := ""
		}
		else
		{
			tok:=this.read_next()
		}
		return tok 
	}
	;Check whether the string has ended
	eof()
	{
		if (this.peek() = "")
			return true
		else
			return false
	}
	;Report error
	croak(msg,len = 1)
	{
		this.input.croak(msg,len)
	}
	;return errors
	getErrors()
	{
		return this.input.getErrors()
	}
}

;Code parser
class parse
{
	keywords:=" if then else "
	;Create a new parser. Parameter is a TokenStream
	__new(input, whatParse="code")
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
		this.input:=input
		if (whatParse="code")
			return this.parse_code_toplevel()
		else if (whatParse="expression")
			return this.parse_expression_toplevel()
		else
			MsgBox I dont't know what to parse!
			
	}
	
	;check whether a character is a punctuation. If parameter is empty, it returns the token if the type is "punc". If parameter is not empty, it returns the token if the parameter and the value are identical
	is_punc(ch = "")
	{
		tok:=this.input.peek()
		if ((tok.type = "punc" && !ch) || (tok.value = ch))
		{
			return tok
		}
		return
	}
	;check whether a token is a operation. If parameter is empty, it returns the token if the type is "op". If parameter is not empty, it returns the token if the parameter and the value are identical
	is_op(op = "")
	{
		tok:=this.input.peek()
		if ((tok.type = "op" && !op) || (tok.value = op))
		{
			return tok
		}
		return
	}
	;check whether a token is a operation. If parameter is empty, it returns the token if the type is "op". If parameter is not empty, it returns the token if the parameter and the value are identical
	is_kw(kw = "")
	{
		tok:=this.input.peek()
		if ((tok.type = "var" && !kw) || (tok.value = kw))
		{
			if (this.input.is_whitespace_or_lf() or this.input.is_punc("("))
				return tok
		}
		return
	}
	;Skips the next punctuation. The parameter is the expected punctuation. If the punctuation is not found, it will report error.
	skip_punc(ch)
	{
		if (this.is_punc(ch))
			this.input.next()
		else
			this.input.croak("Expecting punctuation: """  ch  """")
	}
	;Skips the next keyword. The parameter is the expected keyword. If the keyword is not found, it will report error.
	skip_kw(ch)
	{
		if (this.is_kw(ch))
			this.input.next()
		else
			this.input.croak("Expecting keyword: """  ch  """")
	}
	;Skips the next operation. The parameter is the expected operation. If the operation is not found, it will report error.
	skip_op(op)
	{
		if (this.is_op(ch))
			this.input.next()
		else
			this.input.croak("Expecting operator: """  ch  """")
	}
	;Skips emptylines.
	skip_empty_lines()
	{
		this.input.read_while_is_whitespace()
		while(this.is_punc("`n"))
		{
			this.input.next()
			this.input.read_while_is_whitespace()
		}
	}
	;Get the values enclosed by start and stop, separated by the separator and use a specific parser to parse the values
	delimited(start, stop, separator, parser)
	{
		a:=object()
		first:=true
		this.skip_punc(start)
			this.skip_empty_lines()
		while (not this.input.eof())
		{
			temp:=this.input.peek()
			if (this.is_punc(stop))
				break
			if (first)
				first:=false
			else
				this.skip_punc(separator)
			if (this.is_punc(stop))
				break
			if (parser = "parse_code")
				a.push(this.parse_code())
			else if (parser = "parse_expression")
				a.push(this.parse_expression(this.parse_expressionToken(),0))
			else
				MsgBox unexpected error. unknown parser
			
			this.skip_empty_lines()
		}
		this.skip_punc(stop)
		return a
	}
	;Parse a function call
	parse_call(func)
	{
		call:={type: "call", func: {type: "func", path:func.path}, args: this.delimited("(", ")", ",", "parse_expression")}
		return call
	}
	;Parse a variable name
	parse_varname(percentIsEnd=false)
	{
		tok:=this.input.peek()
		if (tok.type!="var" and tok.value != "%")
		{
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
					
					tok:=this.input.peek()
					if (tok.type="var")
					{
						concat.push({type: "str", value: tok.value})
						this.input.next()
					}
					else if (!percentIsEnd and tok.value="%")
					{
						this.input.next() ;Skipt first %
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
				tok:=this.input.peek()
				if (this.is_punc("."))
				{
					
					this.input.next() ;Skip "."
					tok:=this.input.next() ;Get next token (should be variable)
					if (tok.type = "var")
					{
						path.push({type: "str", value: tok.value})
					}
					else if (!percentIsEnd and tok.value="%")
					{
						this.input.croak("No derefs possible here: `n"  strobj(tok) , strlen(tok.value) )
						this.input.next()
					}
					else
					{
						this.input.croak("Unexpected token in variable path: `n"  strobj(tok) , strlen(tok.value) )
						this.input.next()
					}
					
				}
				else if (this.is_punc("["))
				{
					this.input.next()
					expr:=this.parse_expression(this.parse_expressionToken(),0)
					path.push(expr)
					this.skip_punc("]")
				}
				else if (!percentIsEnd and tok.value="%")
				{
					this.input.croak("No derefs possible here: `n"  strobj(tok) , strlen(tok.value) )
				}
				else
				{
					break
				}
			}
			
			
			;~ path:=object()
			;~ path.push(tok.value) ;save the first path part
			;~ this.input.next() ;Skip first path part
			
			;~ nextTok:=this.input.peek()
			;~ if (this.is_punc("."))
			;~ {
				
				;~ this.input.next() ;Skip "."
				;~ tok:=this.input.next() ;Get next token (should be variable)
				;~ if (tok.type = "var")
				;~ {
					;~ path.push(tok.value)
				;~ }
				;~ else
				;~ {
					;~ this.input.croak("Unexected token in variable path: `n"  strobj(tok) , strlen(tok.value) )
				;~ }
				
			;~ }
			;~ else if (!percentIsEnd and this.is_punc("%"))
			;~ {
				;~ if (this.is_punc("%"))
				;~ {
					;~ this.input.next()
					;~ expr:=this.parse_expression(this.parse_expressionToken(true),0, true)
					;~ this.skip_punc("%")
				;~ }
			;~ }
			;~ else
			;~ {
				;~ break
			;~ }
		}
		
		expr:={type: "var", path: path}
		
		;Check whether it can be a keyword
		if (expr.path.maxindex() = 1 and expr.path.1.type="str")
		{
			if instr(keywords," " expr.path.1.value " ")
			{
				expr.kw:=expr.path.1.value
			}
		}
		
		return expr
	}
	;Parse a if expression
	parse_if()
	{
		this.skip_kw("if")
		cond := this.parse_expression(this.parse_expressionToken(),0) 
			;~ MsgBox % strobj(cond)
		;~ if (!this.is_punc("{")) 
			;~ this.skip_punc("{")
		this.skip_empty_lines()
		
		then:=this.parse_code()
		ret:= {type: "if", cond: cond, then: then}
		this.skip_empty_lines()
		
		if (this.is_kw("else"))
		{
			this.input.next()
			ret.else:=this.parse_code()
		}
		return ret
	}
	
	;parse an expression. Parameters are the already parsed part of the expression and my current precendence
	parse_expression(left,my_prec, percentIsEnd = false)
	{
		;check whether the next token is a operation
		tok := this.is_op()
		
		if not (tok)
		{
			;Insert a concatenation token if missing
			nexttok:=this.input.peek()
			if (nexttok.type = "var" || nexttok.type = "num" || nexttok.type = "str" )
			{
				tok := {type: "op", value: "."}
				DoNotSkipToken:=True
			}
		}
		;~ MsgBox % strobj(tok)
		if (tok)
		{
			
			;if the token is a operation, check whether the new precedens is higher to my precendence
			his_prec := this.precedence[tok.value]
			
			if (his_prec > my_prec)
			{
				if not DoNotSkipToken
					this.input.next()
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
				retval:=this.parse_expression({type: type, operator: tok.value, left: left, right: right}, my_prec, percentIsEnd)			
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
		;Inside () is always an expression
		if (this.is_punc("("))
		{
			this.input.next()
			expr:=this.parse_expression(this.parse_expressionToken(),0)
			this.skip_punc(")")
		}
		else
		{
			;check wheter next token is a variable name, a number or a string
			tok:=this.input.peek()
			if (tok.type = "num" || tok.type = "str")
			{
				expr:=tok
				this.input.next() ;skip current token
		;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(expr) "`n~`n" strobj(this)
			}
			else
			{
				;Try to get a variable
				expr:=this.parse_varname(percentIsEnd)
				
			
				if not (expr)
				{
					;If not, there is something what is not expected. Tell error
					expr:=""
					;~ MsgBox % strobj(tok)
					this.input.croak("Unexected token in expression: `n"  strobj(tok) , strlen(tok.value) )
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(expr) "`n~`n" strobj(this)
				}
			}
		}
		
		
		
		;If after a token there are brackets, parse a function call
		if (tok.type = "var" && this.is_punc("("))
			return this.parse_call(expr)
		
		return expr
	}
	;parse a line of code
	parse_codeline()
	{
		;inside {} there is always some executable code
		
		if (this.is_punc("{"))
		{
			expr:=this.parse_prog()
		}
		else if (this.is_punc("`n"))
		{
			this.input.next()
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
				this.input.next()
			}
			else
			{
				
				;Try to get a variable
				tok:=this.input.peek()
				expr:=this.parse_varname()
				
				if (expr)
				{
				}
				else
				{
					;If not, there is something what is not expected. Tell error
					expr:=""
					this.input.croak("Unexected token in code: `n"  strobj(tok) , strlen(tok.value) )
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(expr) "`n~`n" strobj(this)
				}
			}
		}
		;If after a token there are brackets, parse a function call
		if (this.is_punc("("))
			return this.parse_call(expr)
		else
			return expr
	}
	;parse some code
	parse_code()
	{
		expr:=this.parse_expression(this.parse_codeline(),0)
		
			;~ MsgBox % A_ThisFunc " @ " A_LineNumber "`n" strobj(expr) "`n~`n" strobj(this)
		if (this.is_punc("("))
			return this.parse_call(expr)
		else
			return expr
	}
	
	;Parse executable code inside {}
	parse_prog(insideBrackets=true)
	{
		if (insideBrackets)
		this.skip_punc("{")
			this.skip_empty_lines()
		prog:=Object()
		while (not this.input.eof())
		{
			temp:=this.input.peek()
			if (this.is_punc("}"))
				break
			
			prog.push(this.parse_code())
			
			this.skip_empty_lines()
		}
		
		if (insideBrackets)
			this.skip_punc("}")
		
		
		retval:={type: "prog", prog: prog}
		return retval
	}
	;Entry point of the code parser
	parse_code_toplevel()
	{
		prog:=this.parse_prog(false)
		prog.errors:=this.getErrors()
		return prog
		
	}
	;Entry point of the expression parser
	parse_expression_toplevel()
	{
		prog:=this.parse_expression(this.parse_expressionToken(),0)
		prog.errors:=this.getErrors()
		return prog
		
	}
	
	getErrors()
	{
		return this.input.getErrors()
	}
}


class Environment
{
	__new()
	{
		this.vars:=Object()
	}
	
	
	lookup(name)
	{
		
	}
	get(name,warn:=true)
	{
		if (isobject(name))
		{
			result:=this.vars[name[1]]
			if (this.vars.haskey(name[1]))
				loop % name.maxindex() -1
				{
					result:=result[name[a_index+1]]
				}
			return result
		}
		else
		{
			if (this.vars.haskey(name))
				return this.vars[name]
			else
			{
				if (warn)
					MsgBox Error. undefined variable %name%
				return
			}
		}
	}
	set(name,value)
	{
		if (isobject(name))
		{
			result:=this.vars
			pathstring:=""
			lastindex:=0
			loop % name.maxindex() -1
			{
				pathstring.=name[a_index]
				if (result.haskey(name[a_index]))
				{
					result:=result[name[a_index]]
				}
				else
				{
					MsgBox Error. variable %pathstring% is not object 
				}
				lastindex:=A_Index
				pathstring.="."
			}
			result[name[lastindex+1]]:=value
			return result
		}
		else
		{
			this.vars[name] := value
			return value
		}
	}
	def(name, value)
	{
		this.vars[name] := value
		return value
	}
}


callfunc(path, args*)
{
	if (path.maxindex() >1)
	{
		MsgBox cannot call functions inside an object
	}
	funcname:=path[1]
	if (funcname = "print")
	{
		MsgBox % args[1]
		return
	}
	if (funcname = "round")
	{
		return round(args[1], args[2])
	}
	if (funcname = "object")
	{
		return object()
	}
	MsgBox % "unknown function " funcname " called with pars: `n" strobj(args)
	
}

evaluate(exp,env, func_GetVariable)
{
	if (exp.type = "num" or exp.type = "str")
	{
		return exp.value
	}
	if (exp.type = "var")
	{
		path:=object()
		for oneindex, onepath in exp.path
		{
			;~ MsgBox % strobj(onepath)
			path.push(evaluate(onepath,env, func_GetVariable))
		}
		varValue:=%func_GetVariable%(env,path)
		;~ d(path, func_GetVariable)
		return varValue
	}
	if (exp.type = "func")
	{
		path:=object()
		for oneindex, onepath in exp.path
		{
			path.push(evaluate(onepath,env, func_GetVariable))
		}
		return path
	}
	if (exp.type = "assign")
	{
		if (exp.left.type != "var")
		{
			MsgBox % "Cannot assign to " + strobj(exp.left)
			return
		}
		else
		{
			path:=object()
			for oneindex, onepath in exp.left.path
			{
				path.push(evaluate(onepath,env, func_GetVariable))
			}
			value:=%func_GetVariable%(env,path)
			value:=apply_op.assign(exp.operator, value, evaluate(exp.right, env, func_GetVariable))
			return %func_setVariable%(env,path) ;TODO
			
		}
	}
	if (exp.type = "binary")
	{
		return apply_op.apply(exp.operator, evaluate(exp.left, env, func_GetVariable), evaluate(exp.right, env, func_GetVariable))
	}
	if (exp.type = "if")
	{
		cond:=evaluate(exp.cond, env, func_GetVariable)
		if (cond != false)
			return evaluate(exp.then,env, func_GetVariable)
		else if (exp.else)
			return evaluate(exp.else,env, func_GetVariable)
		else 
			return false
	}
	if (exp.type = "prog")
	{
		val := false
		for oneIndex, oneProgExp in exp.prog
		{
			val:=evaluate(oneProgExp, env, func_GetVariable)
		}
		return val
	}
	if (exp.type = "call")
	{
		args:=Object()
		func := evaluate(exp.func,env, func_GetVariable)
		for oneIndex, oneArgsExp in exp.args
		{
			args.push(evaluate(oneArgsExp, env, func_GetVariable))
		}
		return callfunc(func,args*)
	}
	
	MsgBox % "Error: I don't know how to evaluate `n" strobj(exp)
}

class apply_op
{
	num(x)
	{
		if x is not number
			MsgBox % "Error: Expected number but got " x
		return x
	}
	div(x)
	{
		if (this.num(x) = 0)
			MsgBox % "Error: Divide by zero"
		return x
	}
	
	apply(op,a,b)
	{
		if (op = "+")
			return this.num(a) + this.num(b)
		if (op = "-")
			return this.num(a) - this.num(b)
		if (op = "*")
			return this.num(a) * this.num(b)
		if (op = "/")
			return this.num(a) / this.div(b)
		if (op = "//")
			return this.num(a) // this.div(b)
		if (op = "&&")
			return a && b
		if (op = "||")
			return a || b
		if (op = "<")
			return this.num(a) < this.num(b)
		if (op = ">")
			return this.num(a) > this.num(b)
		if (op = "<=")
			return this.num(a) <= this.num(b)
		if (op = ">=")
			return this.num(a) >= this.num(b)
		if (op = "==")
			return a == b
		if (op = "=")
			return a = b
		if (op = "!=")
			return a != b
		if (op = ".")
			return a . b
		MsgBox % "Error: Can't apply operator "  op
	}
	
	assign(op,a,b)
	{
		;~ MsgBox % op " - " a " - " b
		if (op = ":=")
			return b
		if (op = ".=")
			return a b
		if (op = "+=")
			return this.num(a) + this.num(b)
		if (op = "-=")
			return this.num(a) - this.num(b)
		if (op = "*=")
			return this.num(a) * this.num(b)
		if (op = "/=")
			return this.num(a) / this.num(b)
		MsgBox % "Error: Can't apply assign "  op
	}
}
