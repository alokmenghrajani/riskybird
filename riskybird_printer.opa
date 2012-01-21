module RegexpPrinter {
  function xhtml pretty_print(regexp parsed_regexp) {
    <>
      {print_simple_list(parsed_regexp)}
      <div>{Debug.dump(parsed_regexp)}</div>
    </>
  }

  function xhtml print_simple_list(regexp parsed_regexp) {
    List.fold(
      function (simple, r) {
        <>
          {r}
          {print_basic_list(simple)}
        </>
      },
      parsed_regexp,
      <></>
    )
  }

  function xhtml print_basic_list(simple simple) {
    List.fold(
      function (basic, r) {
        <>
          {r}
          {print_basic(basic)}
        </>
      },
      simple,
      <></>
    )
  }

  function xhtml print_basic(basic basic) {
    <span style="border: 1px solid black; margin:1px">
      {print_elementary(basic.belt)}
      {print_postfix(basic.bpost)}
    </span>
  }

  function xhtml print_elementary(elementary elementary) {
    match (elementary) {
      case {edot}: <b>.</b>
      case {edollar}: <b>$</b>
      case {~echar}: <>{echar}</>
      case {~egroup}: <>{print_simple_list(egroup)}</>
      case _: <>{Debug.dump(elementary)}</>
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
