require_relative 'strong_ruby'

Greeter = StrongRuby.build do
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
end

Greeter.new("Alex", "Hello").say

UltimateGreeter = StrongRuby.build do
  [[let, greeter: Greeter],

   [constructor, [name: String], [
     [:greeter=, [Greeter, new, name, "Ultimately Greetings"]],
  ]],

  [fn, say, [[] => NilClass], [
    [[greeter], say],
  ]]]
end

UltimateGreeter.new("Alexey").say

RecursionTest = StrongRuby.build do
  [[match, a, [
    [[count: 0] => Numeric], [
      0
    ],

    [[count: Numeric] => Numeric], [
      [println, count],
      [a, [:-, count, 1]],
    ]
  ]]]
end

RecursionTest.new.a(5)
