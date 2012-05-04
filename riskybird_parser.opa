type regexp = list(simple)

and simple = list(basic)

and basic  =
   { int id,
     elementary belt,
     postfix bpost } or
   { anchor_start } or
   { anchor_end }

and postfix =
  { noop } or
  { star } or
  { plus } or
  { qmark } or
  { int exact } or
  { int at_least } or
  { int min, int max }

and elementary =
  { edot } or
  { anchor_start } or
  { anchor_end } or
  { string echar } or
  { int group_ref } or
  { string escaped_char } or
  { int group_id, regexp egroup } or
  { rset eset }

and rset =
  { bool neg, list(item) items }

and item =
  { string iechar } or
  { string ichar } or
  { range irange }

and range =
  { string rstart, string rend }

module RegexpParser {

  function regexp coerce(regexp x) { x }

  regexp = parser
  l = {Rule.parse_list_sep(false, simple,
    (parser | "|" -> Rule.succeed))} -> l

  simple = parser
  l = {Rule.parse_list_sep(false, basic, Rule.succeed)} -> l

  basic = parser
  | "^" -> { anchor_start }
  | "$" -> { anchor_end }
  | ~elementary ~postfix -> { id: 0, belt: elementary, bpost: postfix }

  postfix = parser
  | "*" -> { star }
  | "+" -> { plus }
  | "?" -> { qmark }
  | "\{" ~repetition -> repetition
  | ""  -> { noop }

  repetition = parser
  | x = {Rule.integer} "\}" -> {exact: x}
  | x = {Rule.integer} ",\}"  -> {at_least: x}
  | x = {Rule.integer} "," y = {Rule.integer} "\}" -> {min:x, max:y}


  elementary = parser
  | "." -> { edot }
  | "(" ~regexp ")" -> { group_id: 0, egroup: coerce(regexp) }
  | "[^" ~items "]" -> { eset: { neg: true, ~items } }
  | "[" ~items "]" -> { eset: { neg:false, ~items } }
  | "\\" x = { Rule.integer } -> { group_ref: x }
  | "\\" x = { any_char } -> { escaped_char: x}
  | x = { char } -> { echar: x}

  any_char = parser
  | ~char -> char
  | x = "[" -> x
  | x = "]" -> x
  | x = "+" -> x
  | x = "*" -> x
  | x = "." -> x
  | x = "?" -> x
  | x = "|" -> x

  char = parser
  | x = { Rule.alphanum_char } -> x
  | x = " " -> x
  | x = "~" -> x
  | x = "!" -> x
  | x = "@" -> x
  | x = "#" -> x
  | x = "$" -> x
  | x = "%" -> x
  | x = "^" -> x
  | x = "&" -> x
  | x = "-" -> x
  | x = ":" -> x
  | x = "{" -> x
  | x = "}" -> x
//  | x = "(" -> x
//  | x = ")" -> x
  | x = "\\" -> x
  | x = "\"" -> x
  | x = "'" -> x
  | x = ";" -> x
  | x = "<" -> x
  | x = ">" -> x
  | x = "," -> x
  | x = "/" -> x
  | x = "`" -> x
  | x = "_" -> x
  | x = "=" -> x

  items = parser
  | ~item ~items -> List.cons(item, items)
  | ~item -> [item]

  item = parser
  | "-" -> { ichar: "-" }
  | "\\" x = { any_char } -> { iechar: x}
  | " " -> { ichar: " " }
  | x = { char } "-" y = { char } ->
    { irange: { rstart: x, rend: y } }
  | x = { char } -> { ichar: x }

  function option(regexp) parse(string s) {
    RegexpSolveId.solve_id(Parser.try_parse(regexp, s))
  }

}

/**
 * Finds the id of each basic and group elements
 */
type state = {
  int basic_id,
  int group_id,
}

type wrap('a) = {
  state st,
  'a v,
}

module RegexpSolveId {
  function wrap('a) do_wrap(state st, 'a v) {{~st, ~v}}

  function wrap(list('a)) map(state st, (state, 'a -> wrap('b)) f, list('a) l) {
    match (l) {
      case {nil}:
        do_wrap(st, {nil})
      case {~hd, ~tl}:
        {~st, v: hd} = f(st, hd)
        {~st, v: tl} = map(st, f, tl)
        do_wrap(st, List.cons(hd, tl))
    }
  }

  function option(regexp) solve_id(option(regexp) r) {
    match (r) {
      case {~some}:
        st = {basic_id: 1, group_id: 1}
        t = regexp(st, some)
        {some: t.v}
      case {none}:
        {none}
    }
  }

  function wrap(regexp) regexp(state st, regexp r) {
    map(st, simple, r)
  }

  function wrap(simple) simple(state st, simple s) {
    map(st, basic, s)
  }

  function wrap(basic) basic(state st, basic b) {
    match (b) {
      case {id:_, ~belt, ~bpost}:
        st2 = {basic_id: st.basic_id + 1, group_id: st.group_id}
        t = elementary(st2, belt)
        b2 = {id: st.basic_id, belt: t.v, bpost: bpost}
        do_wrap(t.st, b2)
      case { anchor_start }:
        do_wrap(st, b)
      case { anchor_end }:
        do_wrap(st, b)
    }
  }

  function wrap(elementary) elementary(state st, elementary e) {
    match (e) {
      case {group_id:_, ~egroup}:
        st2 = {basic_id: st.basic_id, group_id: st.group_id+1}
        t = regexp(st2, egroup)
        do_wrap(t.st, {group_id: st.group_id, egroup: t.v})
      case _:
        do_wrap(st, e)
   }
  }
}
