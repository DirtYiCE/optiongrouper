require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe OptionGrouper do
  before(:each) { $stdout = StringIO.new; $stderr = StringIO.new }
  after(:each) { $stdout = STDOUT; $stderr = STDERR }
  let(:out) { $stdout.string }
  let(:err) { $stderr.string }

  describe 'built-in commands' do
    it 'should print a version number' do
      OptionGrouper.new do
        on_version :continue
        version '0.0.0'
      end.parse ['--version']
      out.should == "0.0.0\n"
    end

    it 'should print a version number and exit' do
      o = OptionGrouper.new do
        version 'x.x.x'
      end
      o.parse []
      lambda { o.parse ['--version'] }.should raise_error SystemExit
      out.should == "x.x.x\n"

      o.on_version :exit
      lambda { o.parse ['--version'] }.should raise_error SystemExit
    end

    it 'should stop processing if told so' do
      o = OptionGrouper.new do
        on_version :stop
        version '0.0.0'
        group do
          opt :foo, "Foo bar"
        end
      end
      o.parse([])[:default][:foo].should be_nil
      o.parse(['--foo'])[:default][:foo].should be_true
      out.should be_empty
      o.parse(%w(--version --foo))[:default][:foo].should be_nil
      out.should == "0.0.0\n"
    end

    it 'should print a help message' do
      o = OptionGrouper.new do
        header "FooBar\n\n"
        group do
          opt :foo, "Do foo foo"
        end
        group :bar do
          header "Bing"
          opt :foo, "Foo collission"
          opt :asd, "Asd asd", :value => :integer
          opt :zee, "Zee", :value => [:string, :integer]
          opt :fee, "Fee", :value => [[:integer, 'INT'], [:string, 'STR']]
        end
        group :asd do
          long :foobar
          opt :foo, "Foo n+1", :no_short => true
        end
      end
      lambda { o.parse ['--help'] }.should raise_error SystemExit
      out.should == <<EOS
FooBar

General options (default):
                   -h, --help: Show this message
                    -f, --foo: Do foo foo

Bing (bar):
                -F, --bar:foo: Foo collission
          -a, --asd <INTEGER>: Asd asd
 -z, --zee <STRING> <INTEGER>: Zee
        -e, --fee <INT> <STR>: Fee

foobar:
                 --foobar:foo: Foo n+1

EOS
    end
  end

  describe 'single-group long parameters' do
    it 'should parse more valueless parameters' do
      res = OptionGrouper.new do
        group do
          opt :foo, "Foo"
          opt :bar, "Bar", :default => 3, :set => 5
          opt :asd, "Asd"
          opt :def, "Def", :set => :def
        end
      end.parse(%w(--asd --def))[:default]
      res[:foo].should be_nil
      res[:bar].should == 3
      res[:asd].should be_true
      res[:def].should == :def
    end

    it 'should parse string arguments' do
      res = OptionGrouper.new do
        group do
          opt :foo, "Foo", :value => :string
          opt :bar, "Bar", :value => :string, :default => "bar"
          opt :asd, "Asd", :value => :string, :default => "asd"
        end
      end.parse(%w(--foo foo --asd gher))[:default]
      res[:foo].should == "foo"
      res[:bar].should == "bar"
      res[:asd].should == "gher"
    end

    it 'should parse string arguments using =' do
      res = OptionGrouper.new do
        group do
          opt :foo, "Foo", :value => :string
          opt :bar, "Bar", :value => :string, :default => "bar"
          opt :asd, "Asd", :value => :string, :default => "asd"
        end
      end.parse(%w(--foo=foo --asd=gher))[:default]
      res[:foo].should == "foo"
      res[:bar].should == "bar"
      res[:asd].should == "gher"
    end

    it 'should parse integer, float arguments' do
      res = OptionGrouper.new do
        group do
          opt :int1, "int", :value => :integer
          opt :int2, "int", :value => :integer, :default => 3
          opt :flt1, "float", :value => :float, :default => 4.3
          opt :flt2, "float", :value => :float, :default => 2.2
        end
      end.parse(%w(--int2=99 --flt1 9.8))[:default]
      res[:int1].should be_nil
      res[:int2].should == 99
      res[:flt1].should be_within(0.0001).of(9.8)
      res[:flt2].should be_within(0.0001).of(2.2)
    end

    it 'should parse using lambdas' do
      res = OptionGrouper.new do
        group do
          opt :a, "a", :value => lambda {|s| Integer(s) + 5 }
          opt :b, "b", :value => lambda {|s| Float(s) / 2 }
        end
      end.parse(%w(--a 1 --b=5))[:default]
      res[:a].should == 6
      res[:b].should be_within(0.0001).of(2.5)
    end

    it 'should parse multi value arguments' do
      res = OptionGrouper.new do
        group do
          opt :a, "a", :value => [:string, :integer], :default => ["a", 3]
          opt :b, "b", :value => [[:integer, "INT"], :string], :default => [7, "b"]
          opt :c, "c", :value => [:integer, :integer, :string]
        end
      end.parse(%w(--b=2 foo --c 2 5 foo))[:default]
      res[:a].should == ["a", 3]
      res[:b].should == [2, "foo"]
      res[:c].should == [2, 5, 'foo']
    end
  end

  describe 'single-group short options' do
    it 'should use supplied single arguments' do
      res = OptionGrouper.new do
        group do
          opt :foo, "foo", :short => 'f'
          opt :bar, "bar", :short => 'b'
          opt :asd, "asd", :short => 'a'
        end
      end.parse(%w(-f -ba))[:default]
      res[:foo].should be_true
      res[:bar].should be_true
      res[:asd].should be_true
    end

    it 'should automatically generate single arguments' do
      res = OptionGrouper.new do
        group do
          opt :foo, "foo"
          opt :bar, "bar"
        end
      end.parse(%w(-b))[:default]
      res[:foo].should be_nil
      res[:bar].should be_true
    end

    it 'should work with multiple options starting the same' do
      res = OptionGrouper.new do
        group do
          opt :foo1, "foo1"
          opt :foo2, "foo2"
          opt :foo3, "foo3"
          opt :foo4, "foo4"
          opt :foo5, "foo5"
        end
      end.parse(['-Fo5'])[:default]
      res[:foo1].should be_nil
      res[:foo2].should be_true
      res[:foo3].should be_true
      res[:foo4].should be_nil
      res[:foo5].should be_true
    end

    it 'should parse values' do
      res = OptionGrouper.new do
        group do
          opt :foo, "foo", :value => :integer
          opt :bar, "bar", :value => :string
          opt :multi, "multi", :value => [:integer, :string]
        end
      end.parse(%w(-f 6 -bzizi -m3 bar))[:default]
      res[:foo].should == 6
      res[:bar].should == "zizi"
      res[:multi].should == [3, "bar"]
    end
  end

  describe 'single-group error handling' do
    it 'should handle invalid commands' do
      lambda { OptionGrouper.new.parse(['--foo']) }.should raise_error SystemExit
      err.should == "Unknown argument `--foo'.\n\nRun with `--help' to get help.\n"
    end

    it 'should handle invalid short commands' do
      lambda { OptionGrouper.new.parse(['-f']) }.should raise_error SystemExit
      err.should == "Unknown argument `-f'.\n\nRun with `--help' to get help.\n"
    end

    it 'should ignore invalid commands' do
      args = %w(--xd -x -f7 --bar)
      res = OptionGrouper.new do
        on_invalid_parameter :continue
        group do
          opt :foo, "foo", :value => :integer
        end
      end.parse(args)[:default]
      res[:foo].should == 7
      args.should == %w(--xd -x --bar)
    end

    it 'should stop processing at an invalid command' do
      args = %w(--foo --xd --bar)
      res = OptionGrouper.new do
        on_invalid_parameter :stop
        group do
          opt :foo, "foo"
          opt :bar, "bar"
        end
      end.parse(args)[:default]
      res[:foo].should be_true
      res[:bar].should be_nil
      args.should == %w(--xd --bar)
    end

    it 'should raise an error on invalid commands' do
      o = OptionGrouper.new { on_invalid_parameter :raise }
      lambda { o.parse(['--foo']) }.should raise_error RuntimeError, "Unknown argument `--foo'."
    end

    it 'should call lambda on invalid command' do
      check = 0
      OptionGrouper.new do
        on_invalid_parameter lambda {|msg| check += 1 }
      end.parse ['--foo']
      check.should == 1
    end
  end

  describe 'single-group abbreviation' do
    it 'should acceppt non-ambigous abbrevations' do
      res = OptionGrouper.new do
        group do
          opt :foo_bar, "FooBar"
          opt :asd, "Asd"
        end
      end.parse(['--foo'])[:default]
      res[:foo_bar].should be_true
      res[:asd].should be_nil
    end

    it 'should bail out on ambigous parameters' do
      o = OptionGrouper.new do
        group do
          opt :foo_bar, "FooBar"
          opt :foo_baz, "FooBaz"
        end
      end
      l = lambda { o.parse ['--foo'] }
      l.should raise_error SystemExit
      msg = <<EOS
Ambigous parameter `--foo'.
Candidates:
  --foo-bar
  --foo-baz
EOS
      err.should == msg + "\nRun with `--help' to get help.\n"

      o.on_ambigous_parameter :raise
      l.should raise_error RuntimeError, msg.strip
    end

    it 'should ignore ambigous parameters (why?)' do
      res = OptionGrouper.new do
        on_ambigous_parameter :continue
        group do
          opt :foo_bar, "FooBar"
          opt :foo_baz, "FooBaz"
          opt :bar, "bar"
        end
      end.parse(%w(--foo --bar))[:default]
      res[:foo_bar].should be_nil
      res[:foo_baz].should be_nil
      res[:bar].should be_true
    end

    it 'should stop on ambigous parameters' do
      res = OptionGrouper.new do
        on_ambigous_parameter :stop
        group do
          opt :foo_bar, "FooBar"
          opt :foo_baz, "FooBaz"
          opt :bar, "bar"
        end
      end.parse(%w(--foo --bar))[:default]
      res[:foo_bar].should be_nil
      res[:foo_baz].should be_nil
      res[:bar].should be_nil
    end
  end

  describe 'multi group' do
    it 'should work with no collisions' do
      res = OptionGrouper.new do
        group :a do
          opt :a, "a"
          opt :a_b, "a b"
        end
        group :b do
          opt :x, "x"
          opt :yize, "y"
        end
      end.parse %w(--a-b -x --yize)
      res[:a][:a].should be_nil
      res[:a][:a_b].should be_true
      res[:b][:x].should be_true
      res[:b][:yize].should be_true
    end

    it 'should work with no collision full name qualifying' do
      res = OptionGrouper.new do
        group :aaa do
          opt :a, "a"
          opt :a_b, "a b"
        end
        group :bbb do
          long "ccc"
          opt :x, "x"
          opt :yize, "y"
        end
      end.parse %w(--aaa:a-b --ccc:yize)
      res[:aaa][:a].should be_nil
      res[:aaa][:a_b].should be_true
      res[:bbb][:x].should be_nil
      res[:bbb][:yize].should be_true
    end

    it 'should work with collissions also' do
      res = OptionGrouper.new do
        group :abc do
          opt :foo, "foo"
          opt :bar, "bar"
        end
        group :def do
          opt :foo, "foo"
          opt :baz, "baz"
        end
      end.parse %w(--abc:foo --bar --baz)
      res[:abc][:foo].should be_true
      res[:abc][:bar].should be_true
      res[:def][:foo].should be_nil
      res[:def][:baz].should be_true
    end

    it 'should handle ambigous parameters' do
      o = OptionGrouper.new do
        group :abc do
          opt :foo, "foo"
          opt :bar, "bar"
        end
        group :def do
          opt :foo, "foo"
          opt :baz, "baz"
        end
      end
      lambda { o.parse ['--foo'] }.should raise_error SystemExit
      msg = <<EOS
Ambigous parameter `--foo'.
Candidates:
  --abc:foo
  --def:foo
EOS
      err.should == msg + "\nRun with `--help' to get help.\n"

      o.on_ambigous_parameter :raise
      lambda { o.parse ['--foo']}.should raise_error RuntimeError, msg.strip

      o.on_ambigous_parameter :continue
      res = o.parse %w(--foo --bar)
      res[:abc][:foo].should be_nil
      res[:abc][:bar].should be_true
      res[:def][:foo].should be_nil
      res[:def][:baz].should be_nil

      o.on_ambigous_parameter :stop
      res = o.parse %w(--foo --bar)
      res[:abc][:foo].should be_nil
      res[:abc][:bar].should be_nil
      res[:def][:foo].should be_nil
      res[:def][:baz].should be_nil
    end

    it 'should allow abbreviated groups' do
      o = OptionGrouper.new do
        group :abcd do
          long "abgh"
          opt :opt1, "opt1"
        end
        group :abef do
          opt :opt2, "opt2"
        end
      end
      res = o.parse %w(--abg:opt1)
      res[:abcd][:opt1].should be_true
      res[:abef][:opt2].should be_nil

      lambda { o.parse %w(--ab:opt1) }.should raise_error SystemExit
      err.should == <<EOS
Ambigous parameter `--ab:opt1'.
Candidates:
  --abgh:...
  --abef:...

Run with `--help' to get help.
EOS
    end
  end

  describe 'not an option' do
    it 'should bail out on not an option' do
      lambda { OptionGrouper.new.parse %w(foo --bar) }.should raise_error SystemExit
      err.should == "`foo' is not an argument.\n\nRun with `--help' to get help.\n"
    end

    it 'should throw an exception and stop' do
      o = OptionGrouper.new do
        on_not_argument :raise
        group do
          opt :foo, "foo"
          opt :bar, "bar"
        end
      end
      args = %w(--foo foo --bar)

      lambda { o.parse args }.should raise_error RuntimeError, "`foo' is not an argument."
      res = o.result[:default]
      res[:foo].should be_true
      res[:bar].should be_nil
      args.should == %w(foo --bar)
    end

    it 'should ignore or stop' do
      o = OptionGrouper.new do
        on_not_argument :continue
        group do
          opt :foo, "foo"
          opt :bar, "bar"
        end
      end
      args = %w(--bar foo --foo)
      res = o.parse(args)[:default]
      res[:foo].should be_true
      res[:bar].should be_true
      args.should == ['foo']

      o.on_not_argument :stop
      args = %w(--bar foo --foo)
      res = o.parse(args)[:default]
      res[:foo].should be_nil
      res[:bar].should be_true
      args.should == %w(foo --foo)
    end
  end
end
