# wtp nushell integration: dynamic completion + cd/add navigation
# Source it once from your env.nu or config.nu:
#   wtp shell-init nushell | save -f ~/.cache/wtp-init.nu
#   source ~/.cache/wtp-init.nu

def "nu-complete wtp" [context: string] {
  let spans = ($context | split row ' ' | skip 1)
  let args = if ("--generate-shell-completion" in $spans) {
    $spans
  } else {
    ($spans | append "--generate-shell-completion")
  }
  let raw: list<string> = try {
    with-env {WTP_SHELL_COMPLETION: 1, SHELL: "fish"} {
      ^wtp ...$args | lines
    }
  } catch {
    []
  }
  $raw | where { ($in | str trim) != "" } | each { |line|
    let parts = ($line | split row ":")
    if (($parts | length) > 1) {
      let value = ($parts | first)
      let desc = ($parts | skip 1 | str join ":")
      if (($value | str trim) == "") or (($desc | str trim) == "") {
        $line
      } else {
        {value: $value, description: $desc}
      }
    } else {
      $line
    }
  }
}

# Every branch ends in the external call (never return after one): in
# nushell an external's stdout only flows to the caller's pipeline when it is
# the branch value, so calling wtp and then returning would leak its output
# to the terminal instead of the pipeline.
def --env --wrapped wtp [...args: string@"nu-complete wtp"] {
  if ($args | is-empty) or ("--generate-shell-completion" in $args) or ("--help" in $args) or ("-h" in $args) {
    ^wtp ...$args
  } else if ($args.0 == "cd") {
    let rest = ($args | skip 1)
    let res = (^wtp cd ...$rest | complete)
    if $res.exit_code == 0 and (($res.stdout | str trim) != "") {
      cd ($res.stdout | str trim)
    } else {
      # Re-run uncaptured so the error surfaces and the failure status
      # propagates, like the bash/fish hooks.
      ^wtp cd ...$rest
    }
  } else if ($args.0 == "add") and (is-terminal) {
    let quiet_args = if ("--quiet" in $args) { $args } else { ($args | append "--quiet") }
    let res = (^wtp ...$quiet_args | complete)
    if $res.exit_code == 0 {
      if (($res.stderr | str trim) != "") {
        print -e ($res.stderr | str trim)
      }
      if (($res.stdout | str trim) != "") {
        cd ($res.stdout | str trim)
      }
    } else {
      # Re-run uncaptured so the error surfaces and the failure status
      # propagates, like the bash/fish hooks.
      ^wtp ...$quiet_args
    }
  } else {
    ^wtp ...$args
  }
}
