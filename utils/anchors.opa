/**
 * Takes a regexp and finds all the first and last terms.
 *
 * This is useful to highlight start & end anchoring.
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

module RegexpAnchor {
  function intset findUnanchoredStarts(regexp) {
    function intset do_term(term term, intset set) {
      match (term) {
        case { assertion: {anchor_start} }: set
        case {~id, atom:_, quantifier:_, greedy:_}: IntSet.add(id, set)
        case _: set // unsure?
      }
    }
    function intset do_alternative(alternative alternative, intset set) {
      match (alternative) {
        case {~hd, tl:_}: do_term(hd, set)
        case []: set
      }
    }
    List.fold(do_alternative, regexp, IntSet.empty)
  }

  function intset findUnanchoredEnds(regexp) {
    function intset do_term(term term, intset set) {
      match (term) {
        case { assertion: {anchor_end} }: set
        case {~id, atom:_, quantifier:_, greedy:_}: IntSet.add(id, set)
        case _: set
      }
    }
    recursive function intset do_alternative(alternative s, intset set) {
      match (s) {
        case {~hd, tl:[]}: do_term(hd, set)
        case {hd:_, ~tl}: do_alternative(tl, set)
        case []: set
      }
    }
    List.fold(do_alternative, regexp, IntSet.empty)
  }


}
