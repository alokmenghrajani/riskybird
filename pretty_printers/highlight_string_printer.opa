/**
 * RiskyBird Highlight String Printer
 *
 * The highlight string printer is used with the svg printer and mouseover/mouseout interactions.
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

module RegexpHighlightStringPrinter {
  function xhtml pretty_print(regexp parsed_regexp) {
    <>{print_regexp(parsed_regexp)}</>
  }

  function xhtml print_regexp(regexp regexp) {
    r = List.map(print_term_list, regexp)
    xhtml_join(r, <>|</>)
  }

  function xhtml print_term_list(alternative alternative) {
    List.fold(
      function (term, r) {
        <>{r}{print_term(term)}</>
      },
      alternative,
      <></>
    )
  }

  function xhtml print_term(term term) {
    match (term) {
      case {~id, ~assertion}:
        r = print_assertion(assertion)
        <span id={id}>{r}</span>
      case {~id, ~atom, ~quantifier, ~greedy}:
        g = if(greedy) {""} else {"?"}
        <span id={id}>{print_atom(atom)}{print_quantifier(quantifier)}{g}</span>
    }
  }

  function xhtml print_assertion(assertion assertion) {
    match (assertion) {
      case { anchor_start }:
        <>^</>
      case { anchor_end }:
        <>$</>
      case { match_word_boundary }:
        <>\\b</>
      case { dont_match_word_boundary }:
        <>\\B</>
      case { ~match_ahead }:
        <>(?={print_regexp(match_ahead)})</>
      case { ~dont_match_ahead }:
        <>(?!{print_regexp(dont_match_ahead)})</>
    }
  }

  function xhtml print_atom(atom atom) {
    match (atom) {
      case {dot}: <>.</>
      case {~char}: <>{char}</>
      case {group_ref:x}: <>\\{x}</>
      case {~escaped_char}: print_escaped_char(escaped_char)
      case {~ncgroup}: <>(?:{print_regexp(ncgroup)})</>
      case {~id, group_id:_, ~group}: <span id={id}>({print_regexp(group)})</span>
      case {~id, ~char_class}: <span id={id}>{print_character_class(char_class)}</span>
      case {~character_class_escape}: <>\\{character_class_escape}</>
    }
  }

  function xhtml print_escaped_char(escaped_char escaped_char) {
    match (escaped_char) {
      case {~control_escape}: <>\\{control_escape}</>
      case {~control_letter}: <>\\c{control_letter}</>
      case {~hex_escape_sequence}: <>\\x{hex_escape_sequence}</>
      case {~unicode_escape_sequence}: <>\\u{unicode_escape_sequence}</>
      case {~identity_escape}: <>\\{identity_escape}</>
      case {~character_class_escape}: <>\\{character_class_escape}</>
    }
  }

  function xhtml print_character_class(character_class char_class) {
    t = List.fold(
      function(class_range, r) {
        i = match (class_range) {
          case {~class_atom}: print_class_atom(class_atom)
          case {~start_char, ~end_char}:
            s1 = print_class_atom(start_char)
            s2 = print_class_atom(end_char)
            <>{s1}-{s2}</>
        }
        <>{r}{i}</>
      },
      char_class.class_ranges,
      <></>
    )
    if (char_class.neg) {
      <>[^{t}]</>
    } else {
      <>[{t}]</>
    }
  }

  function xhtml print_class_atom(class_atom class_atom) {
    match (class_atom) {
      case {~char}: <>{char}</>
      case {~escaped_char}: print_escaped_char(escaped_char)
    }
  }

  function xhtml print_quantifier(quantifier) {
    match (quantifier) {
      case {noop}: <></>
      case {star}: <>*</>
      case {plus}: <>+</>
      case {qmark}: <>?</>
      case {exactly: x}: <>\{{x}\}</>
      case {at_least: x}: <>\{{x},\}</>
      case {~min, ~max}: <>\{{min},{max}\}</>
    }
  }
}
