module RegexpPrinter {
  function xhtml pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        <>
          <div class="alert-message error">
            <strong>oh snap!</strong> Parsing failed!
          </div>
        </>
      case {some: x}:
        start_anchor = if (x.start_anchor) { "^" } else { "…" }
        end_anchor = if (x.end_anchor) { "$" } else { "…" }
        <>
          <div class="pp">
            <span class="noborder">{start_anchor}</span>
            {print_simple_list(x.core)}
            <span class="noborder">{end_anchor}</span>
          </div>
          <br style="clear: both"/>
          <div>{Debug.dump(parsed_regexp)}</div>
        </>
     }
  }

  function xhtml print_simple_list(core_regexp regexp) {
    t = List.fold(
      function (simple, r) {
        <>
          {r}
          <span>{print_basic_list(simple)}</span><br/>
        </>
      },
      regexp,
      <></>
    )
    <span class="noborder">{t}</span>
  }

  function xhtml print_basic_list(simple simple) {
    t = List.fold(
      function (basic, r) {
        <>
          {r}
          {print_basic(basic)}
        </>
      },
      simple,
      <></>
    )
    <span class="noborder">{t}</span>
  }

  function xhtml print_basic(basic basic) {
    <span>
      {print_elementary(basic.belt)}
      {print_postfix(basic.bpost)}
    </span>
  }

  function xhtml print_elementary(elementary elementary) {
    match (elementary) {
      case {edot}: <b>.</b>
      case {~echar}: <>{echar}</>
      case {~egroup}: <>{print_simple_list(egroup)}</>
      case {~eset}: <>{print_set(eset)}</>
    }
  }

  function print_set(rset set) {
    t = List.fold(
      function(item, r) {
        i = match (item) {
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
      case {star}: <b>*</b>
      case {plus}: <b>+</b>
    }
  }
}
