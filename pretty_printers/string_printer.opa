/**
 * RiskyBird String Printer
 *
 * The string printer is used in various parts of the code:
 * - in the Lint engine, to convert a transformed regexp back into a string
 * - in the unittest framework to ensure strings parse correctly
 * - for debugging
 * - etc.
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

module RegexpStringPrinter {
  function string pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        ""
      case {some: x}: print_regexp(x)
     }
  }

  function string print_regexp(regexp regexp) {
    String.concat("|", List.map(print_term_list, regexp))
  }

  function string print_term_list(alternative alternative) {
    List.fold(
      function (term, r) {
        "{r}{print_term(term)}"
      },
      alternative,
      ""
    )
  }

  function string print_term(term term) {
    match (term) {
      case {~assertion}: print_assertion(assertion)
      case {id:_, ~atom, ~quantifier, ~greedy}:
        g = if(greedy) {""} else {"?"}
        "{print_atom(atom)}{print_quantifier(quantifier)}{g}"
    }
  }

  function string print_assertion(assertion assertion) {
    match (assertion) {
      case { anchor_start }:
        "^"
      case { anchor_end }:
        "$"
      case { match_word_boundary }:
        "\\b"
      case { dont_match_word_boundary }:
        "\\B"
      case { ~match_ahead }:
        "(?={print_regexp(match_ahead)})"
      case { ~dont_match_ahead }:
        "(?!{print_regexp(dont_match_ahead)})"
    }
  }

  function string print_atom(atom atom) {
    match (atom) {
      case {dot}: "."
      case {~char}: "{char}"
      case {group_ref:x}: "\\{x}"
      case {~escaped_char}: print_escaped_char(escaped_char)
      case {~ncgroup}: "(?:{print_regexp(ncgroup)})"
      case {id:_, group_id:_, ~group}: "({print_regexp(group)})"
      case {id:_, ~char_class}: print_character_class(char_class)
      case {~character_class_escape}: "\\{character_class_escape}"
    }
  }

  function string print_escaped_char(escaped_char escaped_char) {
    match (escaped_char) {
      case {~control_escape}: "\\{control_escape}"
      case {~control_letter}: "\\c{control_letter}"
      case {~hex_escape_sequence}: "\\x{hex_escape_sequence}"
      case {~unicode_escape_sequence}: "\\u{unicode_escape_sequence}"
      case {~identity_escape}: "\\{identity_escape}"
      case {~character_class_escape}: "\\{character_class_escape}"
    }
  }

  function string print_character_class(character_class char_class) {
    t = List.fold(
      function(class_range, r) {
        i = match (class_range) {
          case {~char}: char
          case {~escaped_char}: print_escaped_char(escaped_char)
          case {~start_char, ~end_char}: "{start_char}-{end_char}"
        }
        "{r}{i}"
      },
      char_class.class_ranges,
      ""
    )
    if (char_class.neg) {
      "[^{t}]"
    } else {
      "[{t}]"
    }
  }

  function string print_quantifier(quantifier) {
    match (quantifier) {
      case {noop}: ""
      case {star}: "*"
      case {plus}: "+"
      case {qmark}: "?"
      case {exactly: x}: "\{{x}\}"
      case {at_least: x}: "\{{x},\}"
      case {~min, ~max}: "\{{min},{max}\}"
    }
  }
}
