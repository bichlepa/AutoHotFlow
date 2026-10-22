"""WI-0119: end-to-end tests of the text elements of the package Default: Search in a string, Substring, Substring2,
Get string length, Replace in a string, Trim a string, Split a string, Change character case, Encode string and the
condition String contains text. Every test builds small flows with the flow builder, adds them to the data folder of
one session and runs them one after the other (`support/coreflows.py`). The result is read with a probe of the variable
`x` after the element; an error is the exception of the run. The expected values are those of v1 unless MIGRATION
M-0108 or M-0111 says otherwise (the new regular expression mode, the edge cases).
"""

import pytest

from support.coreflows import answer, condition_flow, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


def text_flow(name, cls, strict=True, **pars):
    """trigger -> the element (its result in `x`) -> probe of `x`."""
    fb = FlowBuilder(name, strict_types=strict)
    el = fb.action(cls, **pars)
    fb.chain(fb.trigger(), el, fb.probe("x"))
    return fb


def value(run, name="x"):
    """The probe of the variable as (text, type), or None when the flow ended before the probe (an exception)."""
    probe = run.seen.get(name) if run.seen else None
    return None if probe is None else (probe.text, probe.type)


def text_of(run):
    """The text of `x`; the test fails if the flow did not reach the probe."""
    got = value(run)
    assert got is not None, run.exceptions
    return got[0]


# --- Action_Search_in_a_string ----------------------------------------------------------------------------------------
def search(name, text, needle, occurrence=1, offset=1, direction="GoRight", case="CaseInsensitive"):
    return text_flow(name, "Action_Search_in_a_string", Varname="x", VarValue=text, SearchText=needle,
                     OccurenceNumber=occurrence, Offset=offset, LeftOrRight=direction, CaseSensitive=case)


def test_search_gives_the_position_from_the_left_and_the_right(flows):
    runs = run_all(flows, [
        search("srch_first", "Hello World", "World"),
        search("srch_second_o", "Hello World", "o", occurrence=2),
        search("srch_last_o", "Hello World", "o", direction="GoLeft"),
        search("srch_from_right_2", "Hello World", "o", occurrence=2, direction="GoLeft"),
        search("srch_offset", "Hello World", "o", offset=6),
    ])
    assert value(runs[0]) == ("7", "Integer")
    assert value(runs[1]) == ("8", "Integer")
    assert value(runs[2]) == ("8", "Integer")
    assert value(runs[3]) == ("5", "Integer")
    assert value(runs[4]) == ("8", "Integer")


def test_search_case_and_not_found_are_an_exception(flows):
    runs = run_all(flows, [
        search("srch_case_no", "Hello World", "world", case="CaseSensitive"),
        search("srch_case_yes", "Hello World", "world"),
        search("srch_missing", "Hello World", "xyz"),
        search("srch_empty", "Hello World", ""),
    ])
    assert runs[0].exceptions and value(runs[0]) is None
    assert value(runs[1]) == ("7", "Integer")
    assert runs[2].exceptions and "not found" in runs[2].exceptions[0].lower()
    assert runs[3].exceptions                       # an empty text is never found


# --- Action_Substring -------------------------------------------------------------------------------------------------
def substring(name, text, **pars):
    return text_flow(name, "Action_Substring", Varname="x", VarValue=text, **pars)


def test_substring_from_the_left_and_the_right(flows):
    runs = run_all(flows, [
        substring("sub_left", "Hello world!", WhereToBegin="FromLeft", Length=5),
        substring("sub_right", "Hello world!", WhereToBegin="FromRight", Length=6),
        substring("sub_right_long", "abc", WhereToBegin="FromRight", Length=50),
        substring("sub_zero", "Hello", WhereToBegin="FromLeft", Length=0),
    ])
    assert text_of(runs[0]) == "Hello"
    assert text_of(runs[1]) == "world!"
    assert text_of(runs[2]) == "abc"
    assert text_of(runs[3]) == ""


def test_substring_from_a_position_to_the_right_and_to_the_left(flows):
    runs = run_all(flows, [
        substring("sub_pos", "Hello Paul", WhereToBegin="Position", StartPos=7, Length=4, LeftOrRight="GoRight"),
        substring("sub_pos_end", "Hello Paul", WhereToBegin="Position", StartPos=7, UntilTheEnd=1,
                  LeftOrRight="GoRight"),
        substring("sub_pos_left", "The Red Fox", WhereToBegin="Position", StartPos=7, Length=3, LeftOrRight="GoLeft"),
        substring("sub_pos_left_end", "The Red Fox", WhereToBegin="Position", StartPos=3, UntilTheEnd=1,
                  LeftOrRight="GoLeft"),
        substring("sub_pos_beyond", "The Red Fox", WhereToBegin="Position", StartPos=40, Length=3,
                  LeftOrRight="GoRight"),
    ])
    assert text_of(runs[0]) == "Paul"
    assert text_of(runs[1]) == "Paul"
    assert text_of(runs[2]) == "Red"                 # v1 example: the three characters that end at position 7
    assert text_of(runs[3]) == "The"
    assert text_of(runs[4]) == ""


def test_substring_umlauts_are_characters(flows):
    run = run_all(flows, [substring("sub_umlaut", "Grüße Äpfel", WhereToBegin="Position", StartPos=1, Length=5,
                                    LeftOrRight="GoRight")])[0]
    assert text_of(run) == "Grüße"


# --- Action_Substring2 ------------------------------------------------------------------------------------------------
def substring2(name, text, **pars):
    return text_flow(name, "Action_Substring2", Varname="x", VarValue=text, **pars)


def test_substring2_from_the_left_with_a_count_and_a_position(flows):
    runs = run_all(flows, [
        substring2("sub2_count", "Hello world!", WhereToBegin="FromLeft", WhereToEnd="CountOfChars", Length=5),
        substring2("sub2_pos", "Hello Paul", WhereToBegin="Position", StartPos=7, WhereToEnd="AtTheEnd"),
        substring2("sub2_end_pos", "Hello Paul", WhereToBegin="FromLeft", WhereToEnd="Position", EndPos=5),
        substring2("sub2_end_before", "Hello Paul", WhereToBegin="Position", StartPos=7, WhereToEnd="Position",
                   EndPos=2),
    ])
    assert text_of(runs[0]) == "Hello"
    assert text_of(runs[1]) == "Paul"
    assert text_of(runs[2]) == "Hello"
    assert runs[3].exceptions and "higher" in runs[3].exceptions[0], runs[3].exceptions


def test_substring2_between_two_texts(flows):
    html = "<html><h1>Title</h1></html>"
    run = run_all(flows, [substring2(
        "sub2_html", html, WhereToBegin="String", StartTextExcluding="<h1>", StartTextIncluding="",
        WhereToEnd="String", EndTextIncluding="", EndTextExcluding="</h1>")])[0]
    assert text_of(run) == "Title"


def test_substring2_text_that_is_not_found_gives_the_empty_text(flows):
    run = run_all(flows, [substring2(
        "sub2_nf", "Hello", WhereToBegin="String", StartTextExcluding="", StartTextIncluding="zzz",
        WhereToEnd="AtTheEnd")])[0]
    assert text_of(run) == "" and not run.exceptions


def test_substring2_without_a_start_text_is_an_exception(flows):
    run = run_all(flows, [substring2(
        "sub2_no_text", "Hello", WhereToBegin="String", StartTextExcluding="", StartTextIncluding="",
        WhereToEnd="AtTheEnd")])[0]
    assert run.exceptions and "Start text not specified" in run.exceptions[0]


# --- Action_Get_String_Length -----------------------------------------------------------------------------------------
def test_get_string_length_counts_characters(flows):
    runs = run_all(flows, [
        text_flow("len_hello", "Action_Get_String_Length", Varname="x", VarValue="Hello World"),
        text_flow("len_umlaut", "Action_Get_String_Length", Varname="x", VarValue="Grüße"),
        text_flow("len_empty", "Action_Get_String_Length", Varname="x", VarValue=""),
    ])
    assert value(runs[0]) == ("11", "Integer")
    assert value(runs[1]) == ("5", "Integer")
    assert runs[2].exceptions                # an empty input is refused by the parameter check (WarnIfEmpty)


# --- Action_replace_in_a_string ---------------------------------------------------------------------------------------
def replace(name, text, search_text, replacement, all_=False, case="CaseInsensitive", mode="Plain"):
    return text_flow(name, "Action_replace_in_a_string", Varname="x", VarValue=text, SearchText=search_text,
                     ReplaceText=replacement, ReplaceAll="all" if all_ else "first", CaseSensitive=case,
                     TextMode=mode)


def test_replace_plain_first_all_case_and_delete(flows):
    runs = run_all(flows, [
        replace("rep_first", "a-a-a", "a", "b"),
        replace("rep_all", "a-a-a", "a", "b", all_=True),
        replace("rep_case", "Hello World", "world", "Paul", all_=True),
        replace("rep_case_sensitive", "Hello World", "world", "Paul", all_=True, case="CaseSensitive"),
        replace("rep_delete", "Hello", "l", "", all_=True),
    ])
    assert text_of(runs[0]) == "b-a-a"
    assert text_of(runs[1]) == "b-b-b"
    assert text_of(runs[2]) == "Hello Paul"
    assert text_of(runs[3]) == "Hello World"
    assert text_of(runs[4]) == "Heo"


def test_replace_regular_expression_and_its_groups(flows):
    runs = run_all(flows, [
        replace("rep_re_digits", "a1 b22", r"\d+", "#", all_=True, mode="RegEx"),
        replace("rep_re_groups", "John Smith", r"(\w+) (\w+)", "$2, $1", mode="RegEx"),
        replace("rep_re_bad", "abc", "(", "x", mode="RegEx"),
        replace("rep_plain_brackets", "a(b)", "(b)", "[b]", mode="Plain"),
    ])
    assert text_of(runs[0]) == "a# b#"
    assert text_of(runs[1]) == "Smith, John"
    assert runs[2].exceptions and "not valid" in runs[2].exceptions[0]
    assert text_of(runs[3]) == "a[b]"                 # plain mode: the brackets are text


# --- Action_Trim_a_string ---------------------------------------------------------------------------------------------
def trim(name, text, **pars):
    return text_flow(name, "Action_Trim_a_string", Varname="x", VarValue=text, **pars)


def test_trim_a_number_of_characters_from_each_side(flows):
    runs = run_all(flows, [
        trim("trim_left", "Hello world!", TrimWhat="Number", LeftSide=1, RightSide=0, Length=6),
        trim("trim_right", "Hello world!", TrimWhat="Number", LeftSide=0, RightSide=1, Length=6),
        trim("trim_both", "[Hello]", TrimWhat="Number", LeftSide=1, RightSide=1, Length=1),
        trim("trim_zero", "Hello", TrimWhat="Number", LeftSide=1, RightSide=1, Length=0),
        trim("trim_no_side", "Hello", TrimWhat="Number", LeftSide=0, RightSide=0, Length=2),
    ])
    assert text_of(runs[0]) == "world!"
    assert text_of(runs[1]) == "Hello "
    assert text_of(runs[2]) == "Hello"
    assert text_of(runs[3]) == "Hello"
    assert text_of(runs[4]) == "Hello"


def test_trim_specified_characters_from_each_side(flows):
    runs = run_all(flows, [
        trim("trim_spaces", "  Hello  ", TrimWhat="Specified", LeftSide=1, RightSide=1, OmitChars=" "),
        trim("trim_left_x", "xxhixx", TrimWhat="Specified", LeftSide=1, RightSide=0, OmitChars="x"),
        trim("trim_right_x", "xxhixx", TrimWhat="Specified", LeftSide=0, RightSide=1, OmitChars="x"),
    ])
    assert text_of(runs[0]) == "Hello"
    assert text_of(runs[1]) == "hixx"
    assert text_of(runs[2]) == "xxhi"


# --- Action_Split_a_string (checked by converting the list back to a text) --------------------------------------------
def split_and_convert(name, text, compact=1, **pars):
    fb = FlowBuilder(name)
    split = fb.action("Action_Split_a_string", Varname="myList", VarValue=text, **pars)
    convert = fb.action("Action_Convert_list_to_string", Varname="x", ListName="myList",
                        listToStringOutputFormat="JSON", compactMode=compact)
    fb.chain(fb.trigger(), split, convert, fb.probe("x"))
    return fb


def test_split_gives_one_value_per_field(flows):
    runs = run_all(flows, [
        split_and_convert("split_comma", "a,b,,c", Delimiters=",", OmitChars=""),
        split_and_convert("split_omit", "a , b", Delimiters=",", OmitChars=" "),
        split_and_convert("split_chars", "abc", Delimiters="", OmitChars=""),
        split_and_convert("split_empty", "", Delimiters=",", OmitChars=""),
    ])
    assert text_of(runs[0]) == '["a","b","","c"]'
    assert text_of(runs[1]) == '["a","b"]'
    assert text_of(runs[2]) == '["a","b","c"]'
    assert runs[3].exceptions                # an empty input is refused by the parameter check (WarnIfEmpty)


# --- Action_Change_character_case -------------------------------------------------------------------------------------
@pytest.mark.parametrize("kind, text, expected", [
    ("upper", "hello WORLD", "HELLO WORLD"),
    ("lower", "hello WORLD", "hello world"),
    ("firstUp", "hello WORLD", "Hello World"),
    ("upper", "ärger", "ÄRGER"),
], ids=["upper", "lower", "title", "umlaut-upper"])
def test_change_character_case(flows, kind, text, expected):
    run = run_all(flows, [text_flow("case_" + kind + str(len(text)), "Action_Change_character_case",
                                    Varname="x", VarValue=text, CharCase=kind)])[0]
    assert text_of(run) == expected


# --- Action_Encode_string -----------------------------------------------------------------------------------------------
def test_encode_string_as_url(flows):
    runs = run_all(flows, [
        text_flow("enc_space", "Action_Encode_string", Varname="x", VarValue="Hello World!",
                  outputEncodingFormat="URL"),
        text_flow("enc_umlaut", "Action_Encode_string", Varname="x", VarValue="ä", outputEncodingFormat="URL"),
        text_flow("enc_unreserved", "Action_Encode_string", Varname="x", VarValue="a-b_c.d~E9",
                  outputEncodingFormat="URL"),
    ])
    assert text_of(runs[0]) == "Hello%20World%21"
    assert text_of(runs[1]) == "%C3%A4"
    assert text_of(runs[2]) == "a-b_c.d~E9"


# --- Condition_String_Contains_Text -----------------------------------------------------------------------------------
def contains(name, text, needle, where, case="CaseInsensitive"):
    return condition_flow(name, "Condition_String_Contains_Text", VarValue=text, SearchText=needle,
                          WhereToBegin=where, CaseSensitive=case)


def test_contains_text_at_start_end_and_anywhere(flows):
    runs = run_all(flows, [
        contains("cont_start_yes", "Hello World", "hello", "Start"),
        contains("cont_start_no", "Hello World", "World", "Start"),
        contains("cont_end_yes", "Hello World", "WORLD", "End"),
        contains("cont_end_no", "Hello World", "Hello", "End"),
        contains("cont_any", "Hello World", "lo Wo", "Anywhere"),
        contains("cont_case", "Hello World", "hello", "Anywhere", case="CaseSensitive"),
        contains("cont_longer", "ab", "abc", "End"),
        contains("cont_empty", "Hello", "", "Start"),   # refused by the parameter check (WarnIfEmpty)
    ])
    assert [answer(run) for run in runs] == ["YES", "NO", "YES", "NO", "YES", "NO", "NO", "EXCEPTION"]


def test_contains_text_default_and_stored_numbers_are_read(flows):
    stored = contains("cont_stored", "Hello World", "World", 3)       # v1 stored the position of the enum (3)
    run = run_all(flows, [stored])[0]
    assert answer(run) == "YES"

