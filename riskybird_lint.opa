/**
 * Lint engine for regular expressions.
 *
 * The purpose of the lint engine is to detect common mistakes people make when
 * composing regular expressions.
 *
 * At some point, we might even suggest auto-fixes.
 *
 * Note: for now, we will only return one lint error at a time.
 *       it might be a little hard to generate all lint errors all
 *       at once. We might also want to allow lint errors to point
 *       to specific parts of the regexp (using some kind of dynamic
 *       highlighting).
 *
 * Lint rules:
 * - detect www., .com or .net and
 *    suggest replacing "." with "\.".
 *
 * - detect \/\/ and suggest using % % as the regexp seperator
 *
 * - detect error prone priority rules (e.g. ^ab|c$)
 *
 * - incorrect group reference
 *    "(a)\2" or "(a)\2(b)"
 *
 * - unused groups => non capturing groups?
 */

/* The status of the linter */
type lstatus =
  { ok } or
  { lerror error }

type lerror =
  { range range_not_used } or
  { int lint_rule, string title, string body }

/* The ranges seen so far (when analysing ranges) */
type lranges = list(range)

/* The state when checking items */
type item_state = {
  lstatus status,
  lranges ranges,
}

/* used in regexp2 and related functions */
type error_state = {
  option(lerror) r,
  intset groups_seen,
  intset groups_used,
}

module RegexpLinterRender {

  function xhtml render(string title, string body) {
    <div id="lint_rule" class="alert-message block-message warning span8">
      <p>
        <span class="icon32 icon-alert"></span>
        <strong>{title}</strong><br/>
        {body}
      </p>
      <div class="alert-actions"/>
    </div>
  }

  function xhtml xhtml_of_error(lerror err) {
    match(err) {
      case {range_not_used: {~rstart, ~rend}}:
        render("Useless range", "the range [{rstart}-{rend}] is redundant and can be removed.")
      case {lint_rule:_, ~title, ~body}:
        render(title, body)
    }
  }

  function option(xhtml) error(lstatus st) {
    match(st) {
      case {ok}: {none}
      case {~error}: {some: xhtml_of_error(error)}
    }
  }
}

module RegexpLinterHelper {

  function bool range_is_included(range r1, range r2) {
    r1.rstart >= r2.rstart && r1.rend <= r2.rend
  }

  /* Checks whether the range r is already covered by the list of
   * ranges l. So r = [a-b], lr = [[a-d]] ==> true
   * using fold is an overkill since we need to handle the case
   * where the list is empty anyway
   */
  function bool range_exists(range r, lranges lr) {
    match(lr) {
      case {nil}: false
      case {~hd, ~tl}:
        range_is_included(r, hd) || range_exists(r, tl)
    }
  }
}

module RegexpLinter {

  function lstatus lreturn(lstatus st, lstatus st2) {
    match(st) {
      case {error: _}: st
      case {ok}: st2
    }
  }

  function lstatus regexp(regexp re) {
    s = List.fold(simple, re, {ok})
    if (s == {ok}) {
      t = regexp2(re)
      match (t) {
        case {~some}: {error:some}
        case {none}: {ok}
      }
    } else s
  }

  function option(lerror) regexp2(regexp re) {
    // go through regexp and keep track of state:
    // - which groups have been seen
    // - which groups have been references
    // - result
    error_state s = {r: {none}, groups_seen: IntSet.empty, groups_used: IntSet.empty}
    error_state t = do_regexp2(re, s)
    t.r
  }

  function error_state do_regexp2(regexp re, error_state s) {
    List.fold(do_simple2, re, s)
  }

  function lstatus simple(list(basic) l, lstatus st) {
    List.fold(basic, l, st)
  }

  function error_state do_simple2(simple l, error_state s) {
    List.fold(do_basic2, l, s)
  }

  function lstatus basic(basic bc, lstatus st) {
    match (st) {
      case {ok}:
        match (bc) {
          case {~id, ~belt, ~bpost, ~greedy}:
            t = postfix(st, bpost, greedy)
            if (t == {ok}) {
              elementary({ok}, belt)
            } else t
          case _:
            {ok}
        }
      case _:
        st
    }
  }

  function error_state do_basic2(basic b, error_state s) {
    match (b) {
      case {id:_, ~belt, bpost:_, greedy:_}:
        do_elementary2(belt, s)
      case _:
        s
    }
  }

  function bool intset_contains(int elem, intset s) {
    t = IntSet.get(elem, s)
    Option.is_some(t)
  }

  function error_state do_elementary2(elementary e, error_state s) {
    match (e) {
      case {~group_id, ~egroup}:
        s2 = {r: s.r, groups_seen: IntSet.add(group_id, s.groups_seen),
              groups_used: s.groups_used}
        do_regexp2(egroup, s2)
      case {~group_ref}:
        t = if (intset_contains(group_ref, s.groups_seen)) s.r else
        {some: {lint_rule: 7, title: "incorrect reference", body:"group_ref too high"}}

        {r: t, groups_seen: s.groups_seen, groups_used: IntSet.add(group_ref, s.groups_used)}
      case _:
        s
    }
  }

  function lstatus postfix(lstatus st, postfix bpost, bool greedy) {
    match (bpost) {
      case {~min, ~max}:
        if (min < max) {
          {ok}
        } else if (min == max) {
          { error: {lint_rule: 2, title: "Improve the quantifier",
             body: "\{{min},{max}\} can be written as \{{min}\}"}}
        } else {
          { error: {lint_rule: 1, title: "Incorrect quantifier",
            body: "max > min."}}
        }
      case {exact:_}:
        if (greedy == false) {
          { error: {lint_rule: 3, title: "Useless non greedy",
            body: "When matching an exact amount, using non greedy makes no sense" }}
        } else {
          {ok}
        }
      case _:
        {ok}
    }
  }

  function lstatus elementary(lstatus st, elementary elt) {
    match(elt) {
      case {eset:{items:l, ...}}:
        lranges ranges = []
        state = { status: st, ~ranges }
        range_status = List.fold_left(item, state, l)
        lreturn(st, range_status.status)
      case _: st
     }
   }

  function item_state item(item_state state, item it) {
    match(it) {
      case {irange: r}:
        if (r.rstart > r.rend) {
          e = {error: {lint_rule: 4, title: "Invalid range in character class",
          body: "The character class contains an invalid range."}}
          {status: e, ranges: state.ranges}
        } else if (r.rstart == r.rend) {
          e = {error: {lint_rule: 5, title: "Useless range in character class",
          body: "The character class contains a useless range."}}
          {status: e, ranges: state.ranges}
        } else if (RegexpLinterHelper.range_exists(r, state.ranges)) {
          status = {error: {range_not_used: r}}
          { ~status, ranges: state.ranges }
        } else if (r.rstart == "A" && r.rend == "z") {
          e = {error: {lint_rule: 6, title: "Progammer laziness",
          body: "When you write A-z instead of A-Za-z, you are including 6 extra characters!"}}
          {status: e, ranges: state.ranges}
        } else {
          ranges = List.cons(r, state.ranges)
          { status: state.status, ~ranges }
        }
      case _: state
    }
  }
}
