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
        <div class="pp">
          {print_simple_list(x, unanchored_starts, unanchored_ends)}
        </div>
     }
  }

  function xhtml join(list(xhtml) l, xhtml glue) {
    match (l) {
      case []: <></>
      case [x]: x
      case {~hd, ~tl}: <>{hd}{glue}{join(tl, glue)}</>
    }
  }

  function xhtml print_simple_list(regexp regexp, unanchored_starts, unanchored_ends) {
    t = List.map(
      function(e){print_basic_list(e, unanchored_starts, unanchored_ends)},
      regexp)
    r = join(t, <hr/>)

    <div class="print_simple_list">{r}</div>
  }

  function xhtml print_basic_list(simple simple, unanchored_starts, unanchored_ends) {
    t = List.fold(
      function (basic, r) {
        <>
          {r}
          {print_basic(basic, unanchored_starts, unanchored_ends)}
        </>
      },
      simple,
      <></>
    )
    <div class="noborder print_basic_list">{t}</div>
  }

  function xhtml print_basic(basic basic, unanchored_starts, unanchored_ends) {
    match (basic) {
      case {~id, ~belt, ~bpost, ~greedy}:
        anchor_start = if (Option.is_some(IntSet.get(id, unanchored_starts))) {
          <>&hellip;</> } else { <></> }
        anchor_end = if (Option.is_some(IntSet.get(id, unanchored_ends))) {
          <>&hellip;</> } else { <></> }
        <span class="print_basic">
          <span class="anchor">{anchor_start}</span>
          <span class="anchor">
            {print_postfix(bpost)}
            {print_elementary(belt, unanchored_starts, unanchored_ends)}
          </span>
          <span class="anchor">{anchor_end}</span>
        </span>
      case { anchor_start }:
        <span class="anchor">^</span>
      case { anchor_end }:
        <span class="anchor">$</span>
    }
  }

  function xhtml print_elementary(elementary elementary, unanchored_starts, unanchored_ends) {
    match (elementary) {
      case {edot}: <b>.</b>
      case {~echar}: <>{echar}</>
      case {group_ref:x}: <>{"\\{x}"}</>
      case {escaped_char:x}: <>{"\\{x}"}</>
      case {~ncgroup}:
        <span class="print_elementary">
          {print_simple_list(ncgroup, unanchored_starts, unanchored_ends)}
        </span>
      case {~group_id, ~egroup}:
        <span class="print_elementary">
          <span class="mylabel"><span>group {group_id}</span></span>
          {print_simple_list(egroup, unanchored_starts, unanchored_ends)}
        </span>
      case {~eset}: <>{print_set(eset)}</>
    }
  }

  function print_set(rset set) {
    t = List.fold(
      function(item, r) {
        i = match (item) {
          case {~iechar}: <>\\{iechar}</>
          case {~ichar}: <>{ichar}</>
          case {~irange}: <>{irange.rstart}-{irange.rend}</>
        }
        <>
          {r}
          {i}
        </>
      },
      set.items,
      <></>
    )
    if (set.neg) {
      <>[^{t}]</>
    } else {
      <>[{t}]</>
    }
  }

  function xhtml print_postfix(postfix) {
    match (postfix) {
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
 * Takes a regexp and finds all the first and last basics.
 *
 * This is useful to highlight start & end anchoring.
 */
module RegexpAnchor {
  function intset findUnanchoredStarts(regexp) {
    function intset do_basic(basic basic, intset set) {
      match (basic) {
        case { anchor_start }: set
        case {~id, belt:_, bpost:_, greedy:_}: IntSet.add(id, set)
      }
    }
    function intset do_simple(simple simple, intset set) {
      do_basic(List.head(simple), set)
    }
    List.fold(do_simple, regexp, IntSet.empty)
  }

  function intset findUnanchoredEnds(regexp) {
    function intset do_basic(basic basic, intset set) {
      match (basic) {
        case { anchor_end }: set
        case {~id, belt:_, bpost:_, greedy:_}: IntSet.add(id, set)
      }
    }
    recursive function intset do_simple(simple s, intset set) {
      match (s) {
        case {~hd, tl:[]}: do_basic(hd, set)
        case {~hd, ~tl}: do_simple(tl, set)
      }
    }
    List.fold(do_simple, regexp, IntSet.empty)
  }


}
