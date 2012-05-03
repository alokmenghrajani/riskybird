type regexp = list(simple)

and simple = list(basic)

and basic  =
   { elementary belt,
     postfix bpost }

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
  { string echar } or
  { string escaped_char } or
  { regexp egroup } or
  { rset eset } or
  { start_anchor } or
  { end_anchor }

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
  | ~elementary ~postfix -> { belt: elementary, bpost: postfix }

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
  | "(" ~regexp ")" -> { egroup: coerce(regexp) }
  | "[^" ~items "]" -> { eset: { neg: true, ~items } }
  | "[" ~items "]" -> { eset: { neg:false, ~items } }
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
    Parser.try_parse(regexp, s)
  }

}

