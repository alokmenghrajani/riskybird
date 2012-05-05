/**
 * RiskyBird
 * Regular expression authors best friend
 *
 * Running: make run
 */

import stdlib.themes.bootstrap
import stdlib.web.client
import stdlib.database.db3

type regexp_result = {
  string regexp,
  string comment,
  intmap(string) true_positives,
  intmap(string) true_negatives
}

server exposed function my_log(obj) {
  Debug.warning(Debug.dump(obj))
}

function resource display() {
  Resource.styled_page(
    "RiskyBird | compose",
    ["/resources/riskybird.css"],
    <>
      <a href="https://github.com/alokmenghrajani/riskybird">
        <img style="position: absolute; top: 0; right: 0; border: 0;" src="https://a248.e.akamai.net/camo.github.com/e6bef7a091f5f3138b8cd40bc3e114258dd68ddf/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67" alt="Fork me on GitHub"/>
      </a>
      <div class="container">
        <div class="content">
          <section>
            <div class="page-header"><h1>Create a new Regular Expression</h1></div>
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
                      function(_){
                        check_regexp()
                        linter_run()
                      }
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

function void linter_run() {
  string regexp = Dom.get_value(#regexp)

  option(regexp) tree_opt = RegexpParser.parse(regexp)
  l =
    match(tree_opt) {
    case {none}: {none}
    case {some: tree}:
      lstatus status = RegexpLinter.regexp(tree)
      RegexpLinterRender.error(status)
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

function void append(list, item, expected) {
  *list =+ get_result_div(Dom.get_value(item), expected)
  Dom.set_value(item, "")
}

//client js_test = %%riskybird_binding.js_test%%

client function xhtml get_result_div(string str, bool expected) {
  string regexp = Dom.get_value(#regexp)
  result = test(regexp, str)
  id = Dom.fresh_id()
  str2 = if (str == "") { <i>empty string</i> } else { <>{str}</> }

  close = <a href="#" onclick={function(_){ Dom.remove(Dom.select_id(id)) }} class="close">×</a>

  if (expected && result) {
    <div id={id} str="{str}"><span class="label success">OK</span> {str2} {close}</div>
  } else if (expected==false && result==false) {
    <div id={id} str="{str}"><span class="label success">OK</span> {str2} {close}</div>
  } else {
    <div id={id} str="{str}"><span class="label warning">FAIL</span> <strong>{str2}</strong> {close}</div>
  }
}

client function void check_regexp() {
  // run regexp on true_positives and true_negatives and colorize the output
  x = Dom.fold_deep(
    function xhtml (dom el, xhtml r) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
        <>
          {r}
          {get_result_div(str, true)}
        </>
        case _ :
          r
      }
    },
    <></>,
    #true_positives
  )
  _ = Dom.put_inside(#true_positives, Dom.of_xhtml(x))

  x = Dom.fold_deep(
    function xhtml (dom el, xhtml r) {
      option(string) v = Dom.get_attribute(el, "str")
      match (v) {
        case {some:str}:
        <>
          {r}
          {get_result_div(str, false)}
        </>
        case _ :
          r
      }
    },
    <></>,
    #true_negatives
  )
  _ = Dom.put_inside(#true_negatives, Dom.of_xhtml(x))

  // Run the parser
  string regexp = Dom.get_value(#regexp)
  parsed_regexp = RegexpParser.parse(regexp)
  #parser_output = RegexpXhtmlPrinter.pretty_print(parsed_regexp)
  void
}

function resource start(Uri.relative uri) {
  match (uri) {
    case {path:{nil} ...}:
//      regexp_result data = {regexp:"", comment:"", true_positives:Map.empty, true_negatives:Map.empty}
//      regexp_id = Db3.fresh_key(@/regexps)
//      r = Resource.raw_status({address_redirected})
//      Resource.add_header(r, {location:"/{regexp_id}"})
//    case {path:{~hd, tl:[]} ...}:
//      int id = Int.of_string(hd)
//      regexp_result data = /regexps[id]
      display()
    case {~path ...}:
      my_log(path)
      Resource.styled_page("hmm", [], <>hi</>)
  }
}

Server.start(
  Server.http,
  [
    {resources: @static_include_directory("resources")},
    {dispatch: start}
  ]
)
