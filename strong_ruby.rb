STRONG_DEBUG = ENV['DEBUG']

Boolean = Struct.new(:value)
boolean_true = Boolean.new(true)
boolean_false = Boolean.new(false)

Tuple = Struct.new(:value)
CallTuple = Struct.new(:value, :locals) do
  def initialize(program, locals, value)
    super(value, locals)
  end
end

ArgsTuple = Struct.new(:value)

Auto = Class.new

Return = Struct.new(:value)

StrongRuby = Class.new(BasicObject) do
  def initialize(&blk)
    @tokens = instance_eval(&blk)
  end

  def self.build(&blk)
    new(&blk).__compile__
  end

  def method_missing(*args)
    return StrongToken.new(args[0]) if args.count == 1
    StrongToken.new(args.map { |x| StrongToken.new(x) })
  end

  def __compile__
    StrongProgram.__dbg__ "compiling #{@tokens}"
    program = StrongCompiler.new(@tokens).compile
  end

  def __tokens__
    @tokens
  end
end

StrongMethod = Struct.new(:name, :compiled_locals, :result) do
  def initialize(*args)
    super
    StrongProgram.__dbg__("Just created method with args #{args}")
  end

  def self.representation(name, args)
    typed_args = args.map { |x| Class === x ? x : x.class }
    "#{name}#{typed_args}"
  end

  def legit?(other_name, args)
    return false unless name == other_name
    return true unless compiled_locals

    compiled_locals.each_with_index do |(k, v), i|
      return false unless v === args[i] || v == args[i] || (Class === v && (args[i] < v || args[i].class < v)) || v == Auto
    end

    true
  end
end

StrongProgram = Class.new(BasicObject) do
  def println(*args)
    Kernel.puts *args
  end

  def format(pattern, *args)
    pattern % args
  end

  def -(a, b)
    a - b
  end

  def __if__(condition, locals, block)
    if condition
      Return[__expand__(locals, block.value)]
    end
  end

  def self.__dbg__(message)
    Kernel.puts "DEBUG: #{message}" if STRONG_DEBUG
  end

  def __call__(name, *args)
    StrongProgram.__dbg__ "__call__ #{name}#{args}"
    self.__send__(name, *args)
  end

  def self.__call__(name, *args)
    StrongProgram.__dbg__ "self.__call__ #{name}#{args}"
    self.__send__(name, *args)
  end

  def inspect
    "A Strong Ruby Program"
  end
  alias :to_s :inspect

  def self.inspect
    "A Strong Ruby Program Class"
  end

  def self.to_s
    inspect
  end

  def self.__try_expand__(locals, body)
    __dbg__("Trying to expand #{body} with #{locals}")

    return __try_lookup__(locals, body.value) if StrongToken === body
    return body unless Array === body
    return body if [] == body

    return __try_expand__(locals, [__try_expand__(locals, body[0])] + body[1..-1]) if Array === body[0]

    return __foreign_try_expand__(body[0], locals, body[1..-1]) if StrongProgram === body[0] || (Class === body[0] && body[0] < StrongProgram)


    return __try_expand__(locals, [body[0]] + __try_expand__(locals, body[1].value)) if ArgsTuple === body[1]

    unless Array === body && ((StrongToken === body[0] && Symbol === body[0].value) || Symbol === body[0])
      raise StrongCompilationError.new("#{body} does not look like an expandable call")
    end

    name = Symbol === body[0] ? body[0] : body[0].value

    args = body[1..-1].map do |tokens|
      __try_expand__(locals, tokens)
    end

    method = __methods__.find { |m| __legit__?(m, name, args) }

    unless method
      __dbg__("Defined methods are: #{__methods__}")
      raise StrongCompilationError.new("#{StrongMethod.representation(name, args)} is not defined")
    end

    __result_of__(method)
  end

  def __expand__(locals, body)
    StrongProgram.__dbg__ "Expanding #{body}"

    return __lookup__(locals, body.value)
      .tap { |value| StrongProgram.__dbg__ "#{body} => #{value} in locals" } if StrongToken === body

    return body unless Array === body
    return nil if [] == body

    return __expand__(locals, [__expand__(locals, body[0])] + body[1..-1]) if Array === body[0]

    return __foreign_expand__(body[0], locals, body[1..-1]) if StrongProgram === body[0] || (Class === body[0] && body[0] < StrongProgram)

    return __expand__(locals, [body[0]] + __expand__(locals, body[1].value)) if ArgsTuple === body[1]

    name = body[0]
    name = Symbol === name ? name : name.value
    args = body[1..-1].map do |tokens|
      __expand__(locals, tokens)
    end
    __call__(name, *args)
  end

  def self.__expand__(locals, body)
    StrongProgram.__dbg__ "Expanding #{body}"

    return __lookup__(locals, body.value)
      .tap { |value| StrongProgram.__dbg__ "#{body} => #{value} in locals" } if StrongToken === body
    return body unless Array === body
    return nil if [] == body

    return __expand__(locals, body[0]) if Array === body[0]

    return __foreign_expand__(body.shift, locals, body) if StrongProgram === body[0] || (Class === body[0] && body[0] < StrongProgram)

    name = body.shift
    name = Symbol === name ? name : name.value
    args = body.map do |tokens|
      __expand__(locals, tokens)
    end
    __call__(name, *args)
  end

  def self.__foreign_try_expand__(foreigner, locals, body)
    foreigner.__try_expand__(locals, body)
  end

  def __foreign_expand__(foreigner, locals, body)
    foreigner.__expand__(locals, body)
  end

  def self.__result_of__(method)
    return NilClass if Symbol === method
    __dbg__("Got suitable method: #{method}")
    method.result
  end

  def self.__legit__?(method, name, args)
    return name == method if Symbol === method
    __dbg__("Checking if it is legit: #{method}, #{name}, #{args}")
    method.legit?(name, args)
  end

  def __legit__?(program, name, args)
    program.__methods__.each do |method|
      return true if program.__legit__?(method, name, args)
    end
    false
  end

  def self.__try_lookup__(locals, name)
    raise StrongCompilationError.new("#{name} is not found in local scope") unless locals.has_key?(name)
    locals[name]
  end

  def __lookup__(locals, name)
    locals[name]
  end

  def self.__lookup__(locals, name)
    locals[name]
  end

  def self.__methods__
    @___methods__ ||= [
      :println,
      StrongMethod.new(:format, nil, String),
      StrongMethod.new(:-, { a: Numeric, b: Numeric }, Numeric),
      StrongMethod.new(:__legit__?, { program: StrongProgram, name: Symbol, args: Array }, Boolean),
      StrongMethod.new(:__if__, { condition: Boolean, locals: Hash, block: CallTuple }, Auto),
    ]
  end
end

StrongCompilationError = Class.new(StandardError)
StrongCompiler = Class.new do

  def initialize(tokens)
    @tokens = tokens
    @program = Class.new(StrongProgram)
  end

  def compile
    @tokens.each do |token|
      # some definition
      if Array === token
        raise StrongCompilationError unless StrongToken === token[0]
        statement = token.shift.value
        send(statement, *token)
      end
    end

    @program
  end

  def let(lets)
    StrongProgram.__dbg__ "Defining let #{lets}"

    raise StrongCompilationError.new("#{lets} should be a hash containing lets signature: { var1: type1, var2: type2, ... }") unless Hash === lets

    @program.class_eval do
      lets.each do |name, type|
        __methods__ << StrongMethod.new(name, {}, type)
        __methods__ << StrongMethod.new(:"#{name}=", { value: type }, type)
        attr_accessor name
      end
    end
  end

  def constructor(signature, body)
    fn(:initialize, [signature => NilClass], body + [nil])
    me = @program

    @program.class_eval do
      __methods__ << StrongMethod.new(:new, (signature[0] || {}), me)
    end
  end

  # last signature should be the most generic one - it is used as a signature for method
  def match(name, body)
    raise StrongCompilationError.new("#{body} should contain even elements (signature, body pair), i.e.: [params => type], [body], ...") unless body.count.even?

    patterns = body.each_slice(2).map { |x| x }
    me = @program

    fn(name, patterns.last[0], patterns.first[1])

    patterns.each_with_index do |(signature, body), index|
      fn(:"__match__#{name}_#{index}", signature, body)
    end

    fn(name, patterns.last[0], StrongRuby.new {
      patterns.each_with_index.map { |(signature, body), index|
        lname = :"__match__#{name}_#{index}"
        [:__if__, [__legit__?, me, lname, __args__], __locals__, CallTuple[me, __locals__, [lname, ArgsTuple[__args__]]]]
      }
    }.__tokens__)
  end

  def fn(name, signature, body)
    StrongProgram.__dbg__ "Defining fn #{name}#{signature} with #{body}"

    raise StrongCompilationError.new("#{body} does not look like function body") unless Array === body

    raise StrongCompilationError.new("#{signature} should be a signature hash: [[a: Type1, b: Type2, ...] => ResultType], but it was not an Array") unless Array === signature

    raise StrongCompilationError.new("#{signature} should be a signature hash: [[a: Type1, b: Type2, ...] => ResultType], but its first element was not a Hash") unless Hash === signature[0]

    raise StrongCompilationError.new("#{signature} should be a signature hash: [[a: Type1, b: Type2, ...] => ResultType], but its first params => result have not exactly one pair") unless signature[0].count == 1

    raise StrongCompilationError.new("#{signature} should be a signature hash: [[a: Type1, b: Type2, ...] => ResultType], but its params part was not Array") unless Array === signature[0].first[0]

    raise StrongCompilationError.new("#{signature} should be a signature hash: [[a: Type1, b: Type2, ...] => ResultType], but its params inner part was nor Hash, nor empty") unless (signature[0].first[0].count == 0 || Hash === signature[0].first[0][0])

    params = signature[0].first[0]
    result = signature[0].first[1]
    compiled_locals = params[0] || {}
    args = compiled_locals.map { |_, v| v }

    real_result = nil
    body.each do |tokens|
      real_result = @program.__try_expand__(compiled_locals.merge(__args__: args, __locals__: compiled_locals), tokens)
    end
    result_type = Class === real_result ? real_result : real_result.class

    raise StrongCompilationError.new("#{name.value}#{signature} function should return #{result} but it returns #{result_type}") unless result_type == result || result_type < result || Auto == result_type

    name = Symbol === name ? name : name.value

    @program.class_eval do
      __methods__ << StrongMethod.new(name, compiled_locals, result)

      define_method(name) do |*args|
        StrongProgram.__dbg__ "I have a body: #{body}; And I got #{args}"
        locals = compiled_locals.each_with_index.map { |(k, v), i| [k, args[i]] }.to_h
        locals[:__args__] = args
        locals[:__locals__] = locals

        result = nil
        body.each do |tokens|
          result = __expand__(locals, tokens)
          if Return === result
            result = result.value
            break
          end
        end
        result
      end
    end
  end
end

StrongToken = Class.new(StrongRuby) do
  def initialize(value)
    value = value.value while StrongToken === value
    @value = value
  end

  def self.[](value)
    new(value)
  end

  def value
    @value
  end

  def to_s
    "T(#{value})"
  end
  alias :inspect :to_s
  alias :to_str :to_s

  def to_ary
    [value]
  end
end

CT = StrongToken
