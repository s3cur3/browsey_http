export_locals_without_parens = [
  assert_any_call: 1,
  assert_any_call: 2,
  assert_called: 1,
  attr: 3,
  delete: 2,
  delete: 3,
  embed_templates: 2,
  field: 2,
  forward: 2,
  forward: 3,
  forward: 4,
  get: 2,
  get: 3,
  head: 2,
  head: 3,
  plug: 1,
  plug: 2,
  match: 2,
  match: 3,
  options: 2,
  options: 3,
  patch: 2,
  patch: 3,
  post: 2,
  post: 3,
  put: 2,
  put: 3,
  refute_any_call: 1,
  refute_any_call: 2,
  slot: 2,
  slot: 3
]

[
  line_length: 98,
  heex_line_length: 120,
  import_deps: [],
  plugins: [
    Styler
  ],
  locals_without_parens: export_locals_without_parens,
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs,heex}"],
  subdirectories: ["priv/*/migrations", "priv/repo/data_migrations"]
]
