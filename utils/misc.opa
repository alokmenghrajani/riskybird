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
  Debug.warning(Debug.dump(obj))
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

