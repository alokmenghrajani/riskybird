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

  regexp = parser {
    case l = {Rule.parse_list_sep(false, simple, (parser { case "|": Rule.succeed}))}: l
  }

  simple = parser {
    case l = {Rule.parse_list_sep(false, basic, Rule.succeed)}: l
  }

  basic = parser {
    case "^": { anchor_start }
    case "$": { anchor_end }
    case ~elementary ~postfix "?": { id: 0, belt: elementary, bpost: postfix, greedy: false }
    case ~elementary ~postfix: { id: 0, belt: elementary, bpost: postfix, greedy: true }
  }

  postfix = parser {
    case "*": { star }
    case "+": { plus }
    case "?": { qmark }
    case "\{" ~repetition "\}": repetition
    case "":  { noop }
  }

  repetition = parser {
    case x = {Rule.digit} "," y = {Rule.digit}: {min:x, max:y}
    case x = {Rule.digit} "," : {at_least: x}
    case x = {Rule.digit}: {exact: x}
  }

  elementary = parser {
    case ".": { edot }
    case "(?:" ~regexp ")": { ncgroup: coerce(regexp) }
    case "(" ~regexp ")": { id: 0, group_id: 0, egroup: coerce(regexp) }
    case "[^" ~items "]": { id: 0, eset: { neg: true, ~items } }
    case "[" ~items "]": { id: 0, eset: { neg:false, ~items } }
    case "\\" x = { Rule.integer }: { group_ref: x }
    case "\\" x = { any_char }: { escaped_char: x}
    case x = { char }: { echar: x}
  }

  any_char = parser {
    case ~char: char
    case x = "[": x
    case x = "]": x
    case x = "+": x
    case x = "*": x
    case x = ".": x
    case x = "?": x
    case x = "case": x
  }

  char = parser {
    case x = { Rule.alphanum_char }: x
    case x = " ": x
    case x = "~": x
    case x = "!": x
    case x = "@": x
    case x = "#": x
    case x = "$": x
    case x = "%": x
    case x = "^": x
    case x = "&": x
    case x = "-": x
    case x = ":": x
    case x = "{": x
    case x = "}": x
//    case x = "(": x
//    case x = ")": x
    case x = "\\": x
    case x = "\"": x
    case x = "'": x
    case x = ";": x
    case x = "<": x
    case x = ">": x
    case x = ",": x
    case x = "/": x
    case x = "`": x
    case x = "_": x
    case x = "=": x
  }

  items = parser {
    case ~item ~items: List.cons(item, items)
    case ~item: [item]
  }

  item = parser {
    case "-": { ichar: "-" }
    case "\\" x = { any_char }: { iechar: x}
    case " ": { ichar: " " }
    case x = { char } "-" y = { char }: { irange: { rstart: x, rend: y } }
    case x = { char }: { ichar: x }
  }

  function option(regexp) parse(string s) {
    RegexpAssignId.assign_id(Parser.try_parse(regexp, s))
  }

}
