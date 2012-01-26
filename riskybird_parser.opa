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
  { plus } or
  { int exact } or
  { int at_least } or
  { int min, int max } 

and elementary =
  { qmark } or
  { edot } or
  { string echar } or
  { string escaped_char } or
  { core_regexp egroup } or
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

  function core_regexp coerce(core_regexp x) { x }

  regexp = parser
  | "^" x = {core_regexp} "$" -> { start_anchor: true, core: x, end_anchor: true }
  | "^" x = {core_regexp} -> { start_anchor: true, core: x, end_anchor: false }
  | x = {core_regexp} "$" -> { start_anchor: false, core: x, end_anchor: true }
  | x = { core_regexp } -> { start_anchor: false, core: x, end_anchor: false }

/* Ok this is ugly as hell!!!
 * I am forced into this nightmare because of erling, first thing he tried was
 * "((((((((((((((", except that with the original parser (the one with nice code),
 * it stalls (too much CPU is burnt). I suspect it's the backtracking mechanism of
 * of the parser costing too much ... eventhough, I didn't look, so don't really know.
 * However, I can avoid backtracking with this ugly piece of code ... and solve the
 * problem. Damn you erling!
*/
  core_regexp = parser
  | ")" -> [[]]
  | Rule.eos -> [[]]
  | "|" ~core_regexp -> List.cons([], core_regexp)
  | ~basic ~core_regexp ->
    match(core_regexp) {
      case {nil}: nil /* never triggered */
      case { ~hd, ~tl }: 
         { hd: List.cons(basic, hd), tl: tl }
    }

  basic = parser
  | ~elementary ~postfix -> { belt: elementary, bpost: postfix }

  postfix = parser
  | "*" -> { star }
  | "+" -> { plus }
  | "\{" ~repetition -> repetition
  | ""  -> { noop }

  repetition = parser
  | x = {Rule.integer} "\}" -> {exact: x}
  | x = {Rule.integer} ",\}"  -> {at_least: x}
  | x = {Rule.integer} "," y = {Rule.integer} "\}" -> {min:x, max:y}


  elementary = parser
  | "?" -> { qmark }
  | "." -> { edot }
  | "(" ~core_regexp -> { egroup: coerce(core_regexp) }
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
  | x = "(" -> x
  | x = ")" -> x
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

