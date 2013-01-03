/**
 * Regular Expression Parser
 *
 * This code takes a regular expression as a string and returns a tree
 * representation. The tree representation makes it easier to inspect and
 * manipulate the regular expression, since things are structured.
 *
 * After you are done parsing the regexp, you probably want to run the tree
 * through the assign_id function. This will fill the tree with ids that can
 * then be used modify or highlight elements on the tree.
 *
 * The tree can be converted to xhtml, svg or back to a string using one of
 * the various pretty printers.
 *
 * This parser is based on the EMCAScript-262 reference documentation:
 * http://www.ecma-international.org/publications/files/ECMA-ST/Ecma-262.pdf
 *
 * This parser is designed to parse javascript regular expressions surounded by
 * '/' characters, e.g. /a.*b/
 *
 * Note:
 * We are currently not dealing with regular expressions which are being stored
 * as String objects (and used with String.match). We are also not handling the
 * differences between various programming languages, something we will have
 * to deal with at some point.
 *
 *   This file is part of RiskyBird
 *
 *   RiskyBird is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   RiskyBird is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with RiskyBird.  If not, see <http://www.gnu.org/licenses/>.
 *
 * @author Julien Verlaguet
 * @author Alok Menghrajani
 */

type regexp = list(alternative)         // foo|bar

and alternative = list(term)            // foo

and term  =
   { int id,
     assertion assertion } or           // ^foo
   { int id,
     atom atom,                         // f*?
     quantifier quantifier,
     bool greedy }

and assertion =
  { anchor_start } or                   // ^foo
  { anchor_end } or                     // bar$
  { match_word_boundary } or            // \bfoo bar\b
  { dont_match_word_boundary } or       // foo\Bbar
  { regexp match_ahead } or             // (?=...)
  { regexp dont_match_ahead }           // (?!...)

and quantifier =
  { noop } or
  { star } or                           // f*
  { plus } or                           // f+
  { qmark } or                          // f?
  { int exactly } or                    // f{5}
  { int at_least } or                   // f{5,}
  { int min, int max }                  // f{5,10}

and atom =
  { string char } or
  { dot } or
  { string character_class_escape } or
  { escaped_char escaped_char } or
  { int group_ref} or
  { int id, character_class char_class } or
  { int id, int group_id, regexp group } or
  { regexp ncgroup }

and character_class =
  { bool neg, list(class_range) class_ranges }

and escaped_char =
  { string control_escape } or
  { string control_letter } or
  { string hex_escape_sequence } or
  { string unicode_escape_sequence } or
  { string identity_escape } or
  { string character_class_escape }

and class_range =
  { class_atom class_atom } or
  { class_atom start_char, class_atom end_char }

and class_atom =
  { string char } or
  { escaped_char escaped_char }

module RegexpParser {

  function regexp coerce(regexp x) { x }

  regexp = parser {
    case l = {Rule.parse_list_sep(false, alternative, (parser { case "|": Rule.succeed}))}: l
  }

  alternative = parser {
    case l = {Rule.parse_list_sep(false, term, Rule.succeed)}: l
  }

  term = parser {
    case x = { assertion }: { id: 0, assertion: x }
    case ~atom ~quantifier "?": { id: 0, ~atom, ~quantifier, greedy: false }
    case ~atom ~quantifier: { id: 0, ~atom, ~quantifier, greedy: true }
  }

  assertion = parser {
    case "^": { anchor_start }
    case "$": { anchor_end }
    case "\\b": { match_word_boundary }
    case "\\B": { dont_match_word_boundary }
    case "(?=" ~regexp ")": { match_ahead: regexp }
    case "(?!" ~regexp ")": { dont_match_ahead: regexp }
  }

  quantifier = parser {
    case "*": { star }
    case "+": { plus }
    case "?": { qmark }
    case "\{" ~repetition "\}": repetition
    case "":  { noop }
  }

  repetition = parser {
    case x = {Rule.natural} "," y = {Rule.natural}: {min:x, max:y}
    case x = {Rule.natural} "," : {at_least: x}
    case x = {Rule.natural}: {exactly: x}
  }

  atom = parser {
    case ".": { dot }
    case "(?:" ~regexp ")": { ncgroup: coerce(regexp) }
    case "(" ~regexp ")": { id: 0, group_id: 0, group: coerce(regexp) }
    case "[^" class_ranges=class_range* "]": { id: 0, char_class: {neg: true, ~class_ranges} }
    case "[" class_ranges=class_range* "]": { id: 0, char_class: {neg:false, ~class_ranges} }
    case "\\" x = { Rule.integer }: { group_ref: x }
    case "\\" x = { character_class_escape }: { character_class_escape:x }
    case x = { character_escape }: { escaped_char: x}
    case x = { pattern_char }: { char: x}
  }

  pattern_char = parser {
    case x = (!pattern_char_no .): "{x}"
  }

  pattern_char_no = parser {
    case x = "^": x
    case x = "$": x
    case x = "\\": x
    case x = "/": x
    case x = ".": x
    case x = "*": x
    case x = "+": x
    case x = "?": x
    case x = "(": x
    case x = ")": x
    case x = "[": x
    case x = "]": x
    case x = "\{": x
    case x = "\}": x
    case x = "|": x
  }

  character_class_escape = parser {
    case x = "d": x
    case x = "D": x
    case x = "s": x
    case x = "S": x
    case x = "w": x
    case x = "W": x
  }

  hex = parser {
    case x = [0-9a-fA-F]: x
  }

  character_escape = parser {
    case "\\" x = { control_escape }: { control_escape: x }
    case "\\c" x = ([a-zA-Z]): { control_letter: "{x}" }
    case "\\x" x = (hex hex): { hex_escape_sequence: "{x}" }
    case "\\u" x = (hex hex hex hex): { unicode_escape_sequence: "{x}" }
    case "\\" x = (.): { identity_escape: "{x}" }
  }

  control_escape = parser {
    case x = "f": x
    case x = "n": x
    case x = "r": x
    case x = "t": x
    case x = "v": x
  }

  class_atom_char = parser {
    case x = (!class_atom_char_no .): "{x}"
  }

  class_atom_char_no = parser {
    case x = "\\": x
    case x = "]": x
  }

  class_escape = parser {
    case "\\" x = { character_class_escape }: { character_class_escape: x }
    case x = { character_escape }: x
  }

  class_atom = parser {
    case x = { class_escape }: {escaped_char: x}
    case x = { class_atom_char }: {char: x}
  }

  class_range = parser {
    case x = { class_atom } "-" y = { class_atom }: {start_char: x, end_char: y}
    case x = { class_atom}: {class_atom: x}
  }

  function option(regexp) parse(string s) {
    RegexpAssignId.assign_id(Parser.try_parse(regexp, s))
  }
}
