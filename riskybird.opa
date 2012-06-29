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
  Resource.styled_page(
    "RegexpLint",
    ["/resources/riskybird.css"],
    <>
      <div class="navbar navbar-fixed-top">
        <div class="navbar-inner">
          <div class="container">
            <a href="/" class="brand">RegexpLint</a>
          </div>
        </div>
      </div>

      <div class="container" style="margin-top: 80px;" onready={function(_){ready()}}>
        <section id="info">
          <p class="lead">
            RegexpLint helps you understand and analyze regular expressions.<br/>
            We graphically render regular expressions and point out common pitfalls.
          </p>
        </section>

        <section id="go">
            <div class="row">
              <div class="span12">
                <div class="input">
                  <input
                    class="xxlarge"
                    type="text"
                    id=#regexp
                    placeholder="Enter a regular expression"
                    style="width: 80%"
                    value=""
                    onkeyup={
                      function(_){ do_work(); }
                    }/>
                </div>
                <br/>
              </div>
            </div>
            <div class="row">
              <div class="span12">
                <div id=#parser_output/>
              </div>
            </div>
            <div class="row"><div class="span12"><br/></div></div>
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

        <footer class="footer">
          <p>
          <a href="#">About us</a> ·
          <a href="http://www.opalang.org/">Written in Opa</a> ·
          <a href="http://github.com/alokmenghrajani/riskybird/">Fork on github.com</a>
          </p>
          <div class="social-buttons">
          </div>
        </footer>

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

function do_work() {
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
  string regexp = Dom.get_value(#regexp)
  parsed_regexp = RegexpParser.parse(regexp)
  do_svg(parsed_regexp)
//  linter_run(parsed_regexp)
  void
}

server function do_svg(r) {
  #parser_output = RegexpSvgPrinter.pretty_print(r)
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
