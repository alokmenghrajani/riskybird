##register js_test : string, string -> bool
##args(regexp, str)
{
  var r = new RegExp(regexp);
  return r.test(str);
}
