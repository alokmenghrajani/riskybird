/**
 * Group terms in a regexp
 *
 * This piece of code is used by the SVG printer to renders things in a more compact way. The code is pulled into
 * the utils folder, because RegexpHighlightStringPrinter also needs it.
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

type mode =
  { svg_printer } or
  { highlight_string_printer }

module GroupRegexp {
  function regexp do_regexp(regexp r, mode m) {
  	List.map(function(a){do_alternative(a, m)}, r)
  }

  function term do_term(term t, mode m) {
    match (t) {
      case {~id, assertion: {match_ahead: regexp}}:
        {~id, assertion: {match_ahead: do_regexp(regexp, m)}}
      case {~id, assertion: {dont_match_ahead: regexp}}:
        {~id, assertion: {dont_match_ahead: do_regexp(regexp, m)}}
      case {~id, ~atom, ~quantifier, ~greedy}:
        {~id, atom: do_atom(atom, m), ~quantifier, ~greedy}
      case _:
        t
    }
  }

  function atom do_atom(atom atom, mode m) {
    match (atom) {
      case {~id, ~group_id, group: regexp}:
        {~id, ~group_id, group: do_regexp(regexp, m)}
      case {ncgroup: regexp}:
        {ncgroup: do_regexp(regexp, m)}
      case _:
        atom
    }
  }

  /**
   * Groups atoms which don't have any quantifiers
   * and which are simple characters for rendering purpose.
   */
  function list(term) do_alternative(list(term) terms, mode m) {
    /**
     * Returns true if a given term can be merged with the following term.
     */
    function bool can_merge(term x) {
      match (x) {
        case {atom:{char:_}, quantifier:{noop}, ...}: true
        case {atom:{escaped_char:{identity_escape:_}}, quantifier:{noop}, ...}: true
        case _: false
      }
    }
    /**
     * Returns true if two consecutive terms can be merged.
     */
    function bool comparison_f(term x, term y) {
      can_merge(x) && can_merge(y)
    }

    function string term_to_string(term x) {
      match (x) {
        case {atom:{escaped_char:{identity_escape:c}}, ...}:
          match (m) {
            case {highlight_string_printer}:
              "\\{c}"
            case {svg_printer}:
              "{c}"
          }
        case {atom:{char:c}, ...}:
          "{c}"
        case _:
          "TODO: FIXME"
      }
    }

    function term merge_f(term x, term y) {
      id = match (x) {
        case {~id, ...}: id
      }
      s1 = term_to_string(x)
      s2 = term_to_string(y)
      {~id, atom: {char:"{s1}{s2}"}, quantifier: {noop}, greedy: true}
    }

    terms = list_group(terms, comparison_f, merge_f)
    List.map(function(t){do_term(t, m)}, terms)
  }
}