require 'blockenspiel'

# A basic command line option parser with group support.
class OptionGrouper
  include Blockenspiel::DSL

  # A Group contains some parameters
  class Group
    include Blockenspiel::DSL

    # Initialize a new group
    # @param name [Symbol] name of the group
    def initialize name
      @name = name
      @long = name.to_s.gsub(/_/, '-')
      @opts = {}
    end

    # Invoke Group in a block to configure
    def invoke &blk
      Blockenspiel.invoke blk, self
    end

    # Define a new option
    # @param name [Symbol] name of the parameter. Underscores will be converted
    #  to hypens in long argument, and a short one will be generated unless you
    #  define one or you declare not to generate one.
    # @param desc [#to_s] description of the argument.
    # @param opts [Hash] additional options.
    # @option opts [String] :long use this as a long option.
    # @option opts [String] :short use this as a short option (must be 1
    #  character long to work)
    # @option opts [Boolean] :no_short do not automatically generate a short
    #  option if set to true
    # @option opts [Proc] :on invoke block after parsing argument
    # @option opts [Symbol, Array<Symbol>, Array<Array<Symbol, String>>]
    #  :value describe additional values to the argument. Symbols declare the
    #  type of the value, and also the string displayed on help page using
    #  `[[Symbol, String], ...]` syntax.
    # @option opts :default (nil) default value of the option if not specified
    #  on command line.
    # @option opts :set (true) set valueless commands to this if specified.
    # @return [void]
    def opt name, desc, opts = {}
      opts[:desc] = desc
      opts[:long] ||= name.to_s.gsub(/_/, '-')
      opts[:set] ||= true
      @opts[name] = opts
    end

    # Defines the name used in command line. By default it's the normal name
    # with underscores replaced with hyphens. It's not advised to change it.
    # @overload long()
    #  Gets current command line name.
    #  @return [String] current name
    # @overload long str
    #  Sets current command line name.
    #  @return [String] the newly set name
    def long *args
      if args.size == 0
        @long
      else
        @long = args[0]
      end
    end

    # @overload header
    #  Gets current header message.
    #  @return [String] header message
    # @overload header str
    #  Sets a new header message
    #  @param str [String] new header message
    #  @return [String] header message
    def header *args
      if args.size == 0
        if @header
          "#{@header} (#{@long}):"
        else
          "#{@long}:"
        end
      else
        @header = args[0]
      end
    end

    # @private
    attr_reader :opts
  end

  # Initialize an OptionGrouper. You can configure it using the yielded block.
  def initialize &blk
    @groups = {}
    @on_version = :exit
    @on_help = :exit
    @on_invalid_parameter = :exit
    @on_ambigous_parameter = :exit
    @on_not_argument = :exit

    run = Proc.new { show_help }
    group do
      header 'General options'
      opt :help, 'Show this message', :short => 'h', :on => run
    end

    invoke &blk if blk
  end

  # Yield the configurator block again.
  def invoke &blk
    Blockenspiel.invoke blk, self
  end

  # What to do after printing version.
  # * `:exit`: call exit to quit the program.
  # * `:continue`: continue processing
  # * `:stop`: stop processing
  # * a Proc: call it
  # @param res [Symbol, Proc] do this.
  # @return [void]
  def on_version res
    @on_version = res
  end

  # What to do after printing help. Takes same options as \{#on_version}.
  def on_help res
    @on_help = res
  end

  # What to do after an invalid parameter. Takes the same options as
  # \{#on_version}, except you can also use `:raise` to raise an exception.
  def on_invalid_parameter to
    @on_invalid_parameter = to
  end

  # What to do after an ambigous parameter. Takes same options as
  # \{#on_invalid_parameter}.
  def on_ambigous_parameter to
    @on_ambigous_parameter = to
  end

  # What to do with a non-option string. Takes same options as
  # \{#on_invalid_parameter}.
  def on_not_argument to
    @on_not_argument = to
  end

  # Sets the version of the program
  # @param version [#to_s] program name and version.
  # @return [void]
  def version version
    @version = version
    run = Proc.new { show_version }
    group :default do
      opt :version, 'Show version', :on => run
    end
  end

  # Sets header printed when help is requested.
  # @param str [#to_s] header message
  # @return [void]
  def header str
    @header = str
  end

  # Define a new group, if needed, then invoke it.
  # @param name [Symbol] name of the group
  # @yield a configuration block
  # @return [Group] the defined group
  def group name = :default, &blk
    @groups[name] ||= Group.new(name)
    @groups[name].invoke &blk
    @groups[name]
  end

  # Parse command line arguments
  # @param args [Array<String>] list of command line arguments.
  # @return [Hash] \{#result}
  def parse args = ARGV
    init_parse

    catch(:stop) do
      while a = args.shift
        if a == '--'
          break
        elsif a =~ /^--[^-]/
          handle_long args, a
        elsif a =~ /^-[^-]/
          handle_short args, a
        else
          @ignored << a
          on_error @on_not_argument, "`#{a}' is not an argument."
        end
      end
    end
    @result
  ensure
    args.unshift *@ignored
  end

  # Hash of parsed results.
  # Hash keys are the group names, values are another hashes, where key is the
  # option name and value is the parsed value.
  # @return [Hash{Symbol => Hash{Symbol => Object}}]
  attr_reader :result

  # Stop argument processing (call it in callbacks)
  def stop
    throw :stop
  end

  private
  # @private
  # Marker for ambigous arguments without group
  AMBIGOUS = -1

  # Initialize parsing structures
  def init_parse
    # list of long arguments without group
    @long_nogrp = {}
    # long arguments in group:name format
    @long_grp = {}
    # short arguments
    @shorts = {}
    @result = {}
    @group_names = {}
    # list of ignored parameters
    @ignored = []

    @groups.each do |gname, grp|
      @group_names[grp.long] = gname

      @result[gname] = {}
      grp.opts.each do |oname, opt|
        long = opt[:long].to_s
        if @long_nogrp[long] # if this group is already defined
          unless @long_nogrp[long][0] == :default
            # only mark as ambigous if the other item is not in the default group
            ot = @long_nogrp[long][@long_nogrp[0] == AMBIGOUS ? 1..-1 : 0]
            @long_nogrp[long] = [AMBIGOUS, ot, gname].flatten
          end
        else
          @long_nogrp[long] = [gname, oname]
        end
        @long_grp["#{grp.long}:#{long}"] = [gname, oname]
        short_coll gname, oname if @shorts[opt[:short]]
        @shorts[opt[:short]] = [gname, oname] if opt[:short]

        @result[gname][oname] = opt[:default]
      end
    end
    # after gone through the list once, fill in unset short parameters
    # automatically
    @groups.each do |gname, grp|
      grp.opts.each do |oname, opt|
        next if opt[:short] || opt[:no_short]
        opt[:long].each_char do |c|
          next if c == "-"
          if !@shorts[c]
            @shorts[c] = [gname, oname]
            break
          elsif !@shorts[c.capitalize]
            @shorts[c.capitalize] = [gname, oname]
            break
          end
        end
      end
    end
  end

  # Called when two options try to set the same short argument.
  def short_coll g, o
    s = @groups[g].opts[o][:short]
    a = @shorts[s]
    raise RuntimeError, "`--#{a.join ':'}` and `--#{g}:#{o}' both tried to set short option `-#{s}'."
  end

  # Handle long parameters (`--xx`)
  def handle_long args, a
    arg = a[2..-1].split '=', 2

    # Check first if we have group defined
    grparg = arg[0].split ':', 2
    if grparg.size == 2
      unless @group_names[grparg[0]]
        c = @group_names.select {|k,v| k.start_with? grparg[0] }
        return invalid_parameter a if c.size == 0
        return ambigous_parameter a, c.map {|k,v| "#{k}:..." } if c.size > 1
        grparg[0] = c.keys.first
      end
      find = "#{grparg[0]}:#{grparg[1]}"
      long = @long_grp
    else
      find = arg[0]
      long = @long_nogrp
    end

    x = long[find]
    unless x # handle abbreviated options
      c = long.select {|k,v| k.start_with? find }
      return invalid_parameter a if c.size == 0
      return ambigous_parameter a, c.keys if c.size > 1
      x = c.values.first
    end
    return ambigous_parameter a, x[1..-1].map {|m| "#{m}:#{arg[0]}"} if x[0] == AMBIGOUS
    opt = @groups[x[0]].opts[x[1]]

    handle_general args, x, opt, arg[1]
  end

  # Handle short options
  def handle_short args, arg, a = arg[1..-1]
    x = @shorts[a[0]]
    return invalid_parameter "-#{a}" unless x
    opt = @groups[x[0]].opts[x[1]]

    # If it has a value, we take anything left in the argument as value
    if opt[:value] && a.size > 1
      handle_general args, x, opt, a[1..-1]
    else
      handle_general args, x, opt
      handle_short args, arg, a[1..-1] if a.size > 1
    end
  end

  def handle_general args, x, opt, value = nil
    if opt[:value]
      if opt[:value].is_a? Array
        @result[x[0]][x[1]] = opt[:value].map do |v|
          z = parse_param(value || args.shift, v)
          value = nil
          z
        end
      else
        @result[x[0]][x[1]] = parse_param(value || args.shift, opt[:value])
      end
    else
      @result[x[0]][x[1]] = opt[:set]
    end
    opt[:on].call @result[x[0]][x[1]] if opt[:on]
  end

  def invalid_parameter par
    @ignored << par
    on_error @on_invalid_parameter, "Unknown argument `#{par}'."
  end

  def ambigous_parameter par, cand
    @ignored << par
    msg = "Ambigous parameter `#{par}'.\nCandidates:\n"
    msg << cand.map {|m| "  --#{m}" }.join("\n")
    on_error @on_ambigous_parameter, msg
  end

  def show_version
    puts @version
    on_general @on_version
  end

  def show_help
    puts @version if @version
    puts @header if @header

    prompts = {}
    max = 1
    @groups.each do |gname, grp|
      prompts[gname] = {}
      grp.opts.each do |oname, opt|
        short = @shorts.key [gname, oname]
        msg = short ? " -#{short}, " : "     "
        if @long_nogrp[opt[:long]][0] != gname
          msg << "--#{grp.long}:#{opt[:long]}"
        else
          msg << "--#{opt[:long]}"
        end
        if opt[:value].is_a? Array
          opt[:value].each {|v| msg << param_display(v) }
        elsif opt[:value]
          msg << param_display(opt[:value])
        end
        prompts[gname][oname] = msg
        max = msg.size if msg.size > max
      end
    end

    @groups.each do |gname, grp|
      puts grp.header
      grp.opts.each do |oname, opt|
        printf "%#{max}s: %s\n", prompts[gname][oname], opt[:desc]
      end
      puts
    end

    on_general @on_help
  end

  def on_general on
    case on
    when :exit
      exit
    when :continue
      # nop
    when :stop
      stop
    else
      on.call
    end
  end

  def on_error on, msg
    case on
    when :exit
      $stderr.puts msg
      $stderr.puts "\nRun with `--help' to get help."
      exit
    when :raise
      raise RuntimeError, msg
    when :continue
      # nop
    when :stop
      stop
    else
      on.call msg
    end
  end

  def parse_param param, type
    type = type[0] if type.is_a? Array
    if type.is_a? Proc
      type.call param
    elsif Kernel.respond_to? type.to_s.capitalize
      Kernel.send type.to_s.capitalize, param
    else
      raise RuntimeError, "Unknown type #{type.inspect} specified"
    end
  end

  def param_display type
    str = if type.is_a? Array
            type[1]
          elsif type.is_a? Proc
            "PARAM"
          else
            type.to_s.upcase
          end
    " <#{str}>"
  end
end
