/**
 * RiskyBird
 * Regular expression authors best friend
 *
 * This parser is based on the EMCAScript-262 reference documentation.
 *
 * This works fine for parsing expressions when the target language is javascript.
 * We'll have to figure out a way to handle the differences between various programming
 * languages.
 */

type regexp = list(simple)

and simple = list(basic)

and basic  =
   { int id,
     elementary belt,
     postfix bpost,
     bool greedy } or
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
  { string echar } or
  { int group_ref } or
  { string escaped_char } or
  { int id, int group_id, regexp egroup } or
  { regexp ncgroup } or
  { int id, rset eset }

and rset =
  { bool neg, list(item) items }

and item =
  { string iechar } or
  { string ichar } or
  { range irange }

and range =
  { string rstart, string rend }

and all =
  { regexp r } or
  { simple s }

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
  | ~elementary ~postfix "?" -> { id: 0, belt: elementary, bpost: postfix, greedy: false }
  | ~elementary ~postfix -> { id: 0, belt: elementary, bpost: postfix, greedy: true }

  postfix = parser
  | "*" -> { star }
  | "+" -> { plus }
  | "?" -> { qmark }
  | "\{" ~repetition "\}" -> repetition
  | ""  -> { noop }

  repetition = parser
  | x = {Rule.digit} "," y = {Rule.digit} -> {min:x, max:y}
  | x = {Rule.digit} ","  -> {at_least: x}
  | x = {Rule.digit} -> {exact: x}

  elementary = parser
  | "." -> { edot }
  | "(?:" ~regexp ")" -> { ncgroup: coerce(regexp) }
  | "(" ~regexp ")" -> { id: 0, group_id: 0, egroup: coerce(regexp) }
  | "[^" ~items "]" -> { id: 0, eset: { neg: true, ~items } }
  | "[" ~items "]" -> { id: 0, eset: { neg:false, ~items } }
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
    RegexpAssignId.assign_id(Parser.try_parse(regexp, s))
  }

}
