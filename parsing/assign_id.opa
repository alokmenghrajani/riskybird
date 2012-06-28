/**
 * Assigns an id to each term and group elements.
 *
 * At some point in the future, we might want to add ids to everything.
 * It might make the linter simpler...
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
      case { assertion:_ }:
        do_wrap(st, b)
    }
  }

  function wrap(atom) do_atom(state st, atom a) {
    match (a) {
      case {id:_, group_id:_, ~group}:
        st2 = {term_id: st.term_id+1, group_id: st.group_id+1}
        t = regexp(st2, group)
        do_wrap(t.st, {id: st.term_id, group_id: st.group_id, group: t.v})
      case {id:_, ~char_class}:
        a = {id: st.term_id, ~char_class}
        st = {term_id: st.term_id+1, group_id:st.group_id}
        do_wrap(st, a)
      case _:
        do_wrap(st, a)
    }
  }
}
