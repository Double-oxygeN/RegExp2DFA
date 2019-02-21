let examples = {
  "epsilon": "",
  "singleton": "a",
  "sample": "(a|b)*abb",
  "question": "a?b?c?d?e?f?g",
  "google": "go+gle"
}

for name, exp in examples.items:
  exec "./regexp '" & exp & "' > examples/" & name & ".dot"

exec "dot -Tpng -O examples/*.dot"
