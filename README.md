OptionGrouper
=========

Command line option parsing, inspired by trollop, in an unusual way.

## Quick intro

Options are grouped into groups, you can define the same option in more than one
group. In this case, you can use a `--group:option` syntax on the command line.

The default group (`:default`, also used when you do not specify a name) is a
bit special, as you do not need to prefix commands in this group.

    require 'optiongrouper'

    opts = OptionGrouper.new do
      version "My Program 1.0"
      header "\nUsage:\n  my_program [options]\n\n"

      group do
        opt :debug, "Enable debugging"
      end

      group :debug do
        header "Debugging options"
        opt :level, "Set debug level", :value => :integer, :default => 0
        opt :kill, "Kill the process <PID> with signal <SIGNAL>", :value =>
          [[:integer, "PID"], [:integer, "SIGNAL"]]
      end
    end.parse

    # opts[:default][:debug] is true if --debug was passed on command line
    # opts[:debug][:kill] contains an array with [PID, SIGNAL]
    # etc

Hope you get the idea now.

## Contributing to optiongrouper

* Check out the latest master to make sure the feature hasn't been implemented
  or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it
  and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to
  have your own version, or is otherwise necessary, that is fine, but please
  isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright © 2010 Kővágó, Zoltán. See [LICENSE.txt](LICENSE.txt) for further
details.

