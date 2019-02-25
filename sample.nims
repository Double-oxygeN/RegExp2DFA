let examples = {
  "epsilon": "",
  "singleton": "a",
  "sample": "(a|b)*abb",
  "question": "colou?r( [ABC]|s)?",
  "charset1": "[\\+-]?([0123456789]|[123456789][0123456789]+)",
  "google": "go+gle",
  "anychar": "a...e",
  "js-identifier": "[A-Za-z_$][A-Za-z0-9_$]*"
}

for name, exp in examples.items:
  exec "./regexp '" & exp & "' > examples/" & name & ".dot"

exec "dot -Tpng -O examples/*.dot"
