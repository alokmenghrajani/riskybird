/* Module checking a regular expression for linting errors
*/

/* The status of the linter */
type lstatus =
  { ok } or
  { lerror error }

type lerror =
  { range range_not_used }

/* The ranges seen so far (when analysing ranges) */
type lranges = list(range)

/* The state when checking items */
type item_state = {
  lstatus status,
  lranges ranges,
}

module CheckerRender {

  function xhtml render(int rnbr, string msg) {
    <div id="lint_rule{rnbr}" class="alert-message block-message warning span8">
      <p>
        <span class="icon32 icon-alert"></span>
        <strong>LINT RULE {rnbr} </strong><br/>
        {msg}
     </p>
     <div class="alert-actions">
    </div>
    </div>
  }

  function xhtml xhtml_of_error(lerror err) {
    match(err) {
      case {range_not_used: {~rstart, ~rend}}:
        render(2, "the range [{rstart}-{rend}] is redondant")
      case _: <></>
    }
  }

  function option(xhtml) error(lstatus st) {
    match(st) {
      case {ok}: {none}
      case {~error}: {some: xhtml_of_error(error)}
    }
  }
}

module CheckerHelper {

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

module Checker {
  
  function lstatus lreturn(lstatus st, lstatus st2) {
    match(st) {
      case {error: _}: st
      case {ok}: st2
    }
  }

  function lstatus regexp(regexp re) {
    lstatus = {ok}
    core_regexp(lstatus, re.core)
  }

  function lstatus core_regexp(lstatus st, core_regexp re) {
    List.fold_left(simple, st, re)
  }

  function lstatus simple(lstatus st, list(basic) l) {
    List.fold_left(basic, st, l)
  }
  
  function lstatus basic(lstatus st, basic bc) {
    elementary(st, bc.belt)
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
        if(CheckerHelper.range_exists(r, state.ranges)) {
          status = {error: {range_not_used: r}}
          { ~status, ranges: state.ranges }
        }
        else {
          ranges = List.cons(r, state.ranges)
          { status: state.status, ~ranges }
        }
      case _: state
    }
  }
}
