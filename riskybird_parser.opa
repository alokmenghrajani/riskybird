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
  | ""  -> { noop }

  elementary = parser
  | "." -> { edot }
  | "(" ~core_regexp -> { egroup: coerce(core_regexp) }
  | "[^" ~items "]" -> { eset: { neg: true, ~items } }
  | "[" ~items "]" -> { eset: { neg:false, ~items } }
  | "\\" x = { Rule.alphanum_char } -> { echar: x}
  | " " -> {echar: " "}
  | x = { Rule.alphanum_char } -> { echar: x}

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

