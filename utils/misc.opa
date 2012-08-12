/**
 * Various helper functions
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

server function my_log(obj) {
  Debug.error(Debug.dump(obj))
}

/**
 * Given a list, check if all elements are the same.
 */
function bool list_check_all_same(list('a) l) {
  t = List.fold(
    function('a e, r) {
      if (r.result == false) {
        r;
      } else {
        match (r.elements) {
          case {none}: {elements: {some: e}, result: true}
          case {~some}: if (some == e) { r; } else { {elements: {some: e}, result: false} }
        }
      }
    },
    l,
    {elements: {none}, result: true}
  )
  t.result
}

/**
 * Returns true if haystack contains needle.
 */
function bool contains(string haystack, string needle) {
  Option.is_some(String.strpos(needle, haystack))
}

/**
 * Functional look&say. Takes a list and groups items
 * which match some criteria
 */
function list_group(list('a) l, ('a, 'a -> bool) comparison_f, ('a, 'a -> 'a) merge_f) {
  r = List.fold_right(
    function(acc, 'a e) {
      match (acc.prev) {
        case {none}:
          // we don't have any prev, so store e as prev
          {acc with prev:{some: e}, current:{some: e}}
        case {~some}:
          if (comparison_f(e, some)) {
            // we have a match, merge current with e
            current = {some: merge_f(e, Option.get(acc.current))}
            {acc with ~current}
          } else {
            // we have a mismatch, push current
            ll = List.cons(Option.get(acc.current), acc.ll)
            {prev:{some: e}, current:{some: e}, ~ll}
          }
      }
    },
    l,
    {prev: {none}, current: {none}, ll: []}
  )
  match (r.current) {
    case {~some}:
      List.cons(some, r.ll)
    case {none}:
      []
  }
}
