///|
fn main {
  let args = @env.args()
  let user_args : Array[String] = []
  let start = if args.length() > 0 &&
    (
      args[0] == "node" ||
      args[0].contains(".wasm") ||
      args[0].contains("/") ||
      args[0].contains("\\") ||
      args[0].has_suffix(".exe") ||
      args[0].has_suffix(".js")
    ) {
    1
  } else {
    0
  }
  if args.length() > start {
    for index in start..<args.length() {
      user_args.push(args[index])
    }
  }
  match @cli.execute_cli(user_args) {
    Ok(output) => println(output)
    Err(message) => eprintln(message)
  }
}
