![](http://imgs.xkcd.com/comics/regular_expressions.png "")

RiskyBird
---------
**Regular expression authors best friend**


Overview
--------
Regular Expressions are notoriously hard to get right. When you are writing a new expression, it
is hard for reviewers to read & assert with confidence that the expression is correct. Tweaking
existing expressions can often lead to unintended consequences.

RiskyBird tries to mitigate this by offering a set of tools for software engineers:

1.  A parser: guarantees the expression is well formed.
2.  A pretty printer: helps interpret the regular expression.
3.  A lint engine: catches common mistakes.
4.  A unittest engine: prevents future mishapes.
5.  A collaboration platform: reviewers can add tests and provide feedback.


This project also provides a reusable regular expression parser.


Why RiskyBird
-------------
We love AngryBirds and we wanted a name that starts with R.


See it in action
----------------
https://www.quaxio.com/regexp_lint/


Some notes
----------
I haven't found a nice place to put these, so leaving these notes here.

Here are some tips to help you write better regular expressions:

1.  Is the language regular(*)? We have often tried to write regular expressions for languages which are not regular! This
    always leads to issues down the road. If the language is not regular, you will need to use a Lexer/Grammar.

    (*) regular expression engines actually implement some features which cannot be described by regular languages (in the
    formal sense), but you get my point.

2.  Can I use a less powerful but faster library (i.e. pattern matching instead of regular expressions)?

3.  Am I trying to match a URI (or part of one)? It is **extreemly hard** to get URI parsing right, and different
    browsers interpret URIs differently. The only way to get this right is to split the URI into parts (protocol,
    user, password, domain, port, path, etc.), run the desired checks on the parts and then rebuilt a new URI with
    the proper escaping applied to each part. Again, we have libraries to do this!

    If you aren't convinced this is required, go read the browser security handbook or the Tangled Web.

4.  Don't be lazy. If you know your expression should match the beginning of a string put the ^ anchor. If you
    are expecting a ".", use \. instead of the dot metacharacter. Use non capturing groups when you don't need
    to capture a group. Etc.

5.  Different engines / different programming languages behave in slightly different ways (what were you expecting?).
    Don't just copy paste regular expressions from one language in to another!

    Proof:
    - in JavaScript: new RegExp(/^[\\\\abc]+$/).test('abc\\\\'); → true
    - in PHP: preg_match("/^[\\\\abc]+$/", "abc\\\\"); → false


Code Layout
-----------
* riskybird.opa: web code
* riskybird_parser.opa: regular expression parser
* riskybird_string_printer.opa: pretty printer
* riskybird_xhtml_printer.opa: pretty printer
* riskybird_lint.opa: lint engine
* riskybird_eval.opa: evaluation engine
* riskybird_unittest.opa: unittests

License
-------
RiskyBird is distribtued under the AGPL license.
