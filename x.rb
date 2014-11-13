require_relative 'strong_ruby'

Greeter = StrongRuby.new do
  [[let, greeting: String],
   [let, name: String],

   [constructor, [name: String, greeting: String], [
     [:greeting=, greeting],
     [:name=, name],
   ]],

   [fn, hello_world, [[name: String, greeting: String] => String], [
     [format, "%s, %s!", greeting, name]
   ]],

   [fn, say, [[] => NilClass], [
     [println, [hello_world, [name], [greeting]]]
   ]]]
end.compile

Greeter.new("Alex", "Hello").say

UltimateGreeter = StrongRuby.new do
  [[let, greeter: Greeter],

   [constructor, [name: String], [
     [:greeter=, [Greeter, new, name, "Ultimately Greetings"]],
  ]],

  [fn, say, [[] => NilClass], [
    [[greeter], say],
  ]]]
end.compile

UltimateGreeter.new("Alexey").say
