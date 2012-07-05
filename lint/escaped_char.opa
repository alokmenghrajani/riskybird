/**
 * Lint rules for escaped characters.
 *
 * These rules can detect things like:
 *  \i => equivalent to i
 *  \u0020 => equivalent to \x20
 *  \cj => \x10
 *  \x61 => a
 *  etc.
 *
 * The lint rules work by first converting the escaped character into an int,
 * and then converting the int back into an atom.
 *
 * The resulting atom is then compared with the input.
 *
 *
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

module LintEscapedChar {
  function lint_result escaped_char(escaped_char e, lint_result res) {
    function atom int_to_atom(int i) {
      ll = ["^", "$", "\\", "/", ".", "*", "+", "?", "(", ")", "[", "]", "\{", "\}", "|"]
      c = textToString(Text.from_character(i))
      if (i == 10) {
        {escaped_char: {control_escape: "n"}}
      } else if (i < 33) {
        {escaped_char: {hex_escape_sequence: RegexpLinterHelper.int_to_hex(i)}}
      } else if (List.contains(c, ll)) {
        {escaped_char: {control_escape: c}}
      } else if (i < 127) {
        {char: c}
      } else if (i < 256) {
        {escaped_char: {hex_escape_sequence: RegexpLinterHelper.int_to_hex(i)}}
      } else {
        {escaped_char: {unicode_escape_sequence: RegexpLinterHelper.int_to_unicode_hex(i)}}
      }
    }

    i = RegexpLinterHelper.escaped_char_to_int(e)
    atom = int_to_atom(i)
    o = RegexpStringPrinter.print_escaped_char(e)
    s = RegexpStringPrinter.print_atom(atom)

    match (atom) {
      case {char:_}:
        err = {
          lint_rule: {improve_escaped_char},
            title: "improve escaped character",
            body: "{o} can simply be written as {s}.",
            class: "",
            patch: {none}
          }
        RegexpLinter.add(res, err)
      case {escaped_char:_}:
        if (s != o) {
          err = {
            lint_rule: {improve_escaped_char},
              title: "improve escaped character",
              body: "{o} can simply be written as {s}.",
              class: "",
              patch: {none}
            }
            RegexpLinter.add(res, err)
        } else {
          res;
        }
      case _:
        // fatal!
        res;
    }
  }
}

