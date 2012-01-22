type regexp =
  { bool start_anchor,
    core_regexp core,
    bool end_anchor }

and core_regexp = list(simple)

and simple = list(basic)

and basic  =
   { elementary belt,
     postfix bpost }

and postfix =
  { noop } or
  { star } or
  { plus }

and elementary =
  { edot } or
  { string echar } or
  { core_regexp egroup } or
  { rset eset }

and rset =
  { bool neg, list(item) items }

and item =
  { string ichar } or
  { range irange }

and range =
  { string rstart, string rend }

module RegexpParser {

  function core_regexp coerce(core_regexp x) { x }

  regexp = parser
  | "^" x = {core_regexp} "$" -> { start_anchor: true, core: x, end_anchor: true }
  | "^" x = {core_regexp} -> { start_anchor: true, core: x, end_anchor: false }
  | x = {core_regexp} "$" -> { start_anchor: false, core: x, end_anchor: true }
  | x = { core_regexp } -> { start_anchor: false, core: x, end_anchor: false }

  core_regexp = parser
  | x = { simple } "|" ~core_regexp -> List.cons(x, core_regexp)
  | x = { simple } -> [x]

  simple = parser
  | ~basic ~simple -> List.cons(basic, simple)
  | ~basic -> [basic]

  basic = parser
  | ~elementary ~postfix -> { belt: elementary, bpost: postfix }
  | ~elementary -> { belt: elementary, bpost: { noop } }

  postfix = parser
  | "*" -> { star }
  | "+" -> { plus }

  elementary = parser
  | ~char -> { echar: char }
  | "." -> { edot }
  | "(" ~core_regexp ")" -> { egroup: coerce(core_regexp) }
  | "[^" ~items "]" -> { eset: { neg: true, ~items } }
  | "[" ~items "]" -> { eset: { neg:false, ~items } }

  char = parser
  | "\\" x = { Rule.alphanum_char } -> x
  | x = { Rule.alphanum_char } -> x
  | " " -> " "

  items = parser
  | ~item ~items -> List.cons(item, items)
  | ~item -> [item]

  item = parser
  | x = { Rule.alphanum_char } "-" y = { Rule.alphanum_char } ->
    { irange: { rstart: x, rend: y } }
  | x = { Rule.alphanum_char } -> { ichar: x }
  | " " -> { ichar: " " }

  function option(regexp) parse(string s) {
    Parser.try_parse(regexp, s)
  }

}

