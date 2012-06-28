/**
 * Main web app code.
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

import stdlib.themes.bootstrap
import stdlib.web.client

function resource display() {
  debug = <div class="row">
    <div class="span4">
      <h3>Debug output</h3>
      <p>
        For hackers
      </p>
    </div>
    <div class="span8">
      <h3>Serialized tree</h3>
      <div id=#parser_debug1/>
      <h3>Tree -&gt; string</h3>
      <div id=#parser_debug2/>
      <h3>SVG</h3>
      <div id=#parser_debug3 style="width: 1000px; height: 1000px"/>
    </div>
  </div>

  Resource.styled_page(
    "RiskyBird | compose",
    ["/resources/riskybird.css"],
    <>
      <a href="https://github.com/alokmenghrajani/riskybird">
        <img style="position: absolute; top: 0; right: 0; border: 0;" src="https://a248.e.akamai.net/camo.github.com/e6bef7a091f5f3138b8cd40bc3e114258dd68ddf/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67" alt="Fork me on GitHub"/>
      </a>
      <div class="container">
        <div class="content" onready={function(_){ready()}}>
          <section>
            <div class="page-header"><h1>Enter a regular expression</h1></div>
            <div class="row">
              <div class="span4">
                <h3>Regexp</h3>
              </div>
              <div class="span8">
                <div class="input">
                  <input
                    class="xxlarge"
                    type="text"
                    id=#regexp
                    placeholder="Enter a regular expression"
                    value=""
                    onkeyup={
                      function(_){ do_work(); }
                    }/>
                </div>
                <br/>
              </div>
            </div>
            <div class="row">
              <div class="span4">
                <h3>Pretty Printer</h3>
                <p>
                  This output helps you understand regular expressions.
                </p>
              </div>
              <div class="span8">
                <div id=#parser_output/>
              </div>
            </div>
            <div class="row"><div class="span12"><br/></div></div>
            {debug}
            <div class="row hide" id=#lint>
              <div class="span4">
                <h3>Lint errors & warnings</h3>
                <p>
                  The automated rules have detected one or more violations.
                </p>
              </div>
              <div class="span8" id=#lint_rules/>
            </div>
          </section>
        </div>
      </div>
    </>
  )
}

function bool contains(string haystack, string needle) {
  Option.is_some(String.strpos(needle, haystack))
}

function ready() {
  do_work()
  void
}

@async function do_work() {
  check_regexp()
}

/*
function void linter_run(option(regexp) tree_opt) {
  l =
    match(tree_opt) {
      case {none}: {none}
      case {some: tree}:
        lint_result status = RegexpLinter.regexp(tree)
        RegexpLinterRender.render(status)
     }
  if (Option.is_some(l)) {
    Dom.remove_class(#lint, "hide")
    _ = Dom.put_replace(#lint_rules, Dom.of_xhtml(Option.get(l)))
    void
  } else {
    Dom.add_class(#lint, "hide")
    Dom.remove_content(#lint_rules)
    void
  }
}
*/

client function void check_regexp() {
  // Run the parser
  string regexp = Dom.get_value(#regexp)
  parsed_regexp = RegexpParser.parse(regexp)
//  #parser_output = RegexpXhtmlPrinter.pretty_print(parsed_regexp)
  #parser_debug1 = Debug.dump(parsed_regexp)
  #parser_debug2 = RegexpStringPrinter.pretty_print(parsed_regexp)
  do_svg(parsed_regexp)
//  linter_run(parsed_regexp)

  void
}

server function do_svg(r) {
  #parser_debug3 = RegexpSvgPrinter.pretty_print(r)
  void;
}

function resource start(Uri.relative uri) {
  match (uri) {
    case {path:{nil} ...}:
      display()
    case {~path ...}:
      my_log(path)
      Resource.styled_page("Lost?", [], <>* &lt;------- you are here</>)
  }
}

Server.start(
  Server.http,
  [
    {resources: @static_include_directory("resources")},
    {dispatch: start}
  ]
)
