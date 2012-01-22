
type regexp = list(simple)
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
  { edollar } or
  { ecaret } or
  { string echar } or
  { regexp egroup } or
  { rset eset }

and rset =
  { bool neg, list(item) items }

and item =
  { string ichar } or
  { range irange }

and range =
  { string rstart, string rend }

module RegexpParser {

  function regexp coerce(regexp x) { x }

  regexp = parser
  | x = { simple } "|" ~regexp -> List.cons(x, regexp)
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
  | "$" -> { edollar }
  | "^" -> { ecaret }
  | "(" ~regexp ")" -> { egroup: coerce(regexp) }
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

  function regexp parse(string s) {
    match (Parser.try_parse(regexp, s)) {
     case {some: result}: result;
     case {none}: [];
    }
  }

}

