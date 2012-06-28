/**
 * Converts a parsed regexp into xhtml.
 *
 * This is the code used for pretty printing the regexp.
 */
module RegexpXhtmlPrinter {
  function xhtml pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        <>
          <div class="alert-message error">
            <strong>oh snap!</strong> Parsing failed!
          </div>
        </>
      case {some: x}:
        unanchored_starts = RegexpAnchor.findUnanchoredStarts(x)
        unanchored_ends = RegexpAnchor.findUnanchoredEnds(x)
        <>
          <div class="pp">
            {print_alternative_list(x, unanchored_starts, unanchored_ends)}
          </div>
        </>
     }
  }

  function xhtml join(list(xhtml) l, xhtml glue) {
    match (l) {
      case []: <></>
      case [x]: x
      case {~hd, ~tl}: <>{hd}{glue}{join(tl, glue)}</>
    }
  }

  function xhtml print_alternative_list(regexp regexp, unanchored_starts, unanchored_ends) {
    t = List.map(
      function(e){print_term_list(e, unanchored_starts, unanchored_ends)},
      regexp)
    r = join(t, <hr/>)

    <div class="print_alternative_list">{r}</div>
  }

  function xhtml print_term_list(alternative alternative, unanchored_starts, unanchored_ends) {
    t = List.fold(
      function (term, r) {
        <>
          {r}
          {print_term(term, unanchored_starts, unanchored_ends)}
        </>
      },
      alternative,
      <></>
    )
    <div class="print_term_list">{t}</div>
  }

  function xhtml print_term(term term, unanchored_starts, unanchored_ends) {
    match (term) {
      case {~id, ~belt, ~bpost, ~greedy}:
        anchor_start = if (Option.is_some(IntSet.get(id, unanchored_starts))) {
          <>&hellip;</> } else { <></> }
        anchor_end = if (Option.is_some(IntSet.get(id, unanchored_ends))) {
          <>&hellip;</> } else { <></> }
        <span class="print_term">
          <span class="anchor">{anchor_start}</span>
          <span class="anchor">
            {print_quantifier(bpost)}
            {print_atom(belt, unanchored_starts, unanchored_ends)}
          </span>
          <span class="anchor">{anchor_end}</span>
        </span>
      case { anchor_start }:
        <span class="anchor">^</span>
      case { anchor_end }:
        <span class="anchor">$</span>
    }
  }

  function xhtml print_atom(atom atom, unanchored_starts, unanchored_ends) {
    match (atom) {
      case {edot}: <b>.</b>
      case {~echar}: <>{echar}</>
      case {group_ref:x}: <>{"\\{x}"}</>
      case {escaped_char:x}: <>{"\\{x}"}</>
      case {~ncgroup}:
        <span class="print_atom">
          {print_alternative_list(ncgroup, unanchored_starts, unanchored_ends)}
        </span>
      case {id:_, ~group_id, ~egroup}:
        <span class="print_atom">
          <span class="mylabel"><span>group {group_id}</span></span>
          {print_alternative_list(egroup, unanchored_starts, unanchored_ends)}
        </span>
      case {id:_, ~eset}: <>{print_set(eset)}</>
    }
  }

  function print_set(character_class set) {
    t1 = List.map(
      function(item) {
        match (item) {
          case {~iechar}: <>\\{iechar}</>
          case {~ichar}: <>{ichar}</>
          case {~irange}: <>{irange.rstart}-{irange.rend}</>
        }
      },
      set.items)
    t2 = join(t1, <>,</>)

    if (set.neg) {
      <>[^{t2}]</>
    } else {
      <>[{t2}]</>
    }
  }

  function xhtml print_quantifier(quantifier) {
    match (quantifier) {
      case {noop}: <></>
      case {star}: <span class="mylabel"><span>&infin;</span></span>
      case {plus}: <span class="mylabel"><span>1-&infin;</span></span>
      case {qmark}: <span class="mylabel"><span>0-1</span></span>
      case {exact: x}: <span class="mylabel"><span>{x}</span></span>
      case {at_least: x}: <span class="mylabel"><span>{x}-&infin;</span></span>
      case {~min, ~max}: <span class="mylabel"><span>{min}-{max}</span></span>
    }
  }
}

/**
 * Takes a regexp and finds all the first and last terms.
 *
 * This is useful to highlight start & end anchoring.
 */
module RegexpAnchor {
  function intset findUnanchoredStarts(regexp) {
    function intset do_term(term term, intset set) {
      match (term) {
        case { anchor_start }: set
        case {~id, belt:_, bpost:_, greedy:_}: IntSet.add(id, set)
      }
    }
    function intset do_alternative(alternative alternative, intset set) {
      match (alternative) {
        case {~hd, ~tl}: do_term(hd, set)
        case []: set
      }
    }
    List.fold(do_alternative, regexp, IntSet.empty)
  }

  function intset findUnanchoredEnds(regexp) {
    function intset do_term(term term, intset set) {
      match (term) {
        case { anchor_end }: set
        case {~id, belt:_, bpost:_, greedy:_}: IntSet.add(id, set)
      }
    }
    recursive function intset do_alternative(alternative s, intset set) {
      match (s) {
        case {~hd, tl:[]}: do_term(hd, set)
        case {~hd, ~tl}: do_alternative(tl, set)
        case []: set
      }
    }
    List.fold(do_alternative, regexp, IntSet.empty)
  }


}
