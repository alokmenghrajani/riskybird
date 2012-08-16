/**
 * Assigns an id to each term and group elements.
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

type state = {
  int term_id,
  int group_id,
}

type wrap('a) = {
  state st,
  'a v,
}

module RegexpAssignId {
  function wrap('a) do_wrap(state st, 'a v) {{~st, ~v}}

  function wrap(list('a)) map(state st, (state, 'a -> wrap('b)) f, list('a) l) {
    match (l) {
      case {nil}:
        do_wrap(st, {nil})
      case {~hd, ~tl}:
        {~st, v: hd} = f(st, hd)
        {~st, v: tl} = map(st, f, tl)
        do_wrap(st, List.cons(hd, tl))
    }
  }

  function option(regexp) assign_id(option(regexp) r) {
    match (r) {
      case {~some}:
        st = {term_id: 1, group_id: 1}
        t = regexp(st, some)
        {some: t.v}
      case {none}:
        {none}
    }
  }

  function wrap(regexp) regexp(state st, regexp r) {
    map(st, alternative, r)
  }

  function wrap(alternative) alternative(state st, alternative s) {
    map(st, term, s)
  }

  function wrap(term) term(state st, term b) {
    match (b) {
      case {id:_, ~atom, ~quantifier, ~greedy}:
        st2 = {st with term_id: st.term_id + 1}
        t = do_atom(st2, atom)
        b2 = {id: st.term_id, atom: t.v, ~quantifier, ~greedy}
        do_wrap(t.st, b2)
      case {id:_, ~assertion}:
        t = {id: st.term_id, ~assertion}
        do_wrap({st with term_id: st.term_id + 1}, t)
    }
  }

  function wrap(atom) do_atom(state st, atom a) {
    match (a) {
      case {id:_, group_id:_, ~group}:
        st2 = {term_id: st.term_id+1, group_id: st.group_id+1}
        t = regexp(st2, group)
        do_wrap(t.st, {id: st.term_id, group_id: st.group_id, group: t.v})
      case {~ncgroup}:
        st2 = {term_id: st.term_id+1, group_id: st.group_id}
        t = regexp(st2, ncgroup)
        do_wrap(t.st, {ncgroup: t.v})
      case {id:_, ~char_class}:
        a = {id: st.term_id, ~char_class}
        st = {term_id: st.term_id+1, group_id:st.group_id}
        do_wrap(st, a)
      case _:
        do_wrap(st, a)
    }
  }
}
