# You can get the spec for these errors to ignore by running:
#     $ mix dialyzer --format short
# ...and then taking that "short" output and either reproducing it whole here or by
# pulling out the file and error atom.
#
# More info in the Dialyxir README:
# https://github.com/jeremyjh/dialyxir#elixir-term-format
[
  # :dockerexec.run/3 *can* return other success results, but based on the arguments
  # we've hard-coded, we know the result will always be this structure.
  {"lib/browsey_http/util/exec.ex", :missing_range},
  # Dialyzer thinks dockerexec will always be there
  {"lib/browsey_http/util/exec.ex", :pattern_match}
]
