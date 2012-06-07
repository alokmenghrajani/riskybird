/**
 * Assigns an id to each basic and group elements.
 *
 * At some point in the future, we might want to add ids to everything.
 * It might make the linter simpler...
 */
type state = {
  int basic_id,
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
        st = {basic_id: 1, group_id: 1}
        t = regexp(st, some)
        {some: t.v}
      case {none}:
        {none}
    }
  }

  function wrap(regexp) regexp(state st, regexp r) {
    map(st, simple, r)
  }

  function wrap(simple) simple(state st, simple s) {
    map(st, basic, s)
  }

  function wrap(basic) basic(state st, basic b) {
    match (b) {
      case {id:_, ~belt, ~bpost, ~greedy}:
        st2 = {basic_id: st.basic_id + 1, group_id: st.group_id}
        t = elementary(st2, belt)
        b2 = {id: st.basic_id, belt: t.v, bpost: bpost, greedy: greedy}
        do_wrap(t.st, b2)
      case { anchor_start }:
        do_wrap(st, b)
      case { anchor_end }:
        do_wrap(st, b)
    }
  }

  function wrap(elementary) elementary(state st, elementary e) {
    match (e) {
      case {id:_, group_id:_, ~egroup}:
        st2 = {basic_id: st.basic_id+1, group_id: st.group_id+1}
        t = regexp(st2, egroup)
        do_wrap(t.st, {id: st.basic_id, group_id: st.group_id, egroup: t.v})
      case {id:_, ~eset}:
        e = {id: st.basic_id, ~eset}
        st = {basic_id: st.basic_id+1, group_id:st.group_id}
        do_wrap(st, e)
      case _:
        do_wrap(st, e)
   }
  }
}
