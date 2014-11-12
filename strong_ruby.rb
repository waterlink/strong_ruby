STRONG_DEBUG = ENV['DEBUG']

StrongRuby = Class.new(BasicObject) do
  def initialize(&blk)
    @tokens = instance_eval(&blk)
  end

  def method_missing(*args)
    return StrongToken.new(args[0]) if args.count == 1
    StrongToken.new(args.map { |x| StrongToken.new(x) })
  end

  def compile
    StrongProgram.__dbg__ "compiling #{@tokens}"
    program = StrongCompiler.new(@tokens).compile
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
      return false unless v === args[i] || v == args[i]
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

  def self.__dbg__(message)
    Kernel.puts "DEBUG: #{message}" if STRONG_DEBUG
  end

  def __call__(name, *args)
    StrongProgram.__dbg__ "__call__ #{name}#{args}"
    self.__send__(name, *args)
      .tap { |result| StrongProgram.__dbg__ "__call__ [#{name}] Result: #{result}" }
  end

  def inspect
    "A Strong Ruby Program"
  end

  def self.__try_expand__(locals, body)
    return __try_lookup__(locals, body.value) if StrongToken === body
    return body unless Array === body
    return body if [] == body

    unless Array === body && StrongToken === body[0] && Symbol === body[0].value
      raise StrongCompilationError.new("#{body} does not look like an expandable call")
    end

    name = body[0].value

    args = body[1..-1].map do |tokens|
      __try_expand__(locals, tokens)
    end

    method = __methods__.find { |m| __legit__?(m, name, args) }

    unless method
      raise StrongCompilationError.new("#{StrongMethod.representation(name, args)} is not defined")
    end

    __result_of__(method)
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

  def self.__try_lookup__(locals, name)
    raise StrongCompilationError.new("#{name} is not found in local scope") unless locals.has_key?(name)
    locals[name]
  end

  def __lookup__(locals, name)
    locals[name]
  end

  def __expand__(locals, body)
    StrongProgram.__dbg__ "Expanding #{body}"
    return __lookup__(locals, body.value).tap { |value| StrongProgram.__dbg__ "#{body} => #{value} in locals" } if StrongToken === body
    return body unless Array === body
    return nil if [] == body
    name = body.shift.value
    args = body.map do |tokens|
      __expand__(locals, tokens)
    end
    __call__(name, *args)
  end

  def self.__methods__
    @___methods__ ||= [
      :println,
      StrongMethod.new(:format, nil, String),
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

    @program.new
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

    real_result = nil
    body.each do |tokens|
      real_result = @program.__try_expand__(compiled_locals, tokens)
    end
    result_type = Class === real_result ? real_result : real_result.class

    raise StrongCompilationError.new("#{signature} function should return #{result} but it returns #{result_type}") unless result_type == result || result_type < result

    @program.class_eval do
      __methods__ << StrongMethod.new(name.value, compiled_locals, result)

      define_method(name.value) do |*args|
        StrongProgram.__dbg__ "I have a body: #{body}; And I got #{args}"
        locals = compiled_locals.each_with_index.map { |(k, v), i| [k, args[i]] }.to_h

        result = nil
        body.each do |tokens|
          result = __expand__(locals, tokens)
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
