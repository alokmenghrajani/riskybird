function start(_) {
//  p = RegexpParser.parse("^ab|c$")
  p = RegexpParser.parse("^a(b|cd|e)*f.gh$")

  Resource.styled_page("", [],
    <>
      {RegexpSvgPrinter.pretty_print(p)}
    </>
  )
}

Server.start(
  Server.http,
  [{dispatch: start}]
)
