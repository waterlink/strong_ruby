require_relative 'strong_ruby'

StrongRuby.new do
  [[fn, hello_world, [[name: String, greeting: String] => String], [
    [format, "%s, %s!", greeting, name]
  ]],

  [fn, user_name, [[] => String], [
    "Alex"
  ]],

  [fn, main, [[] => NilClass], [
    [println, [hello_world, [user_name], "Hi"]]
  ]]]
end.compile.main
