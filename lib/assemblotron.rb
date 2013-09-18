require "biopsy"
require "logger"
require "transrate"
require "assemblotron/version"

module Assemblotron

  include Transrate

  class Controller
  
    attr_accessor :global_opts
    attr_accessor :cmd_opts

    # Return a new Assemblotron
    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO
      self.load_config
      self.init_settings
      @assemblers = []
      self.load_assemblers
    end # initialize

    # Initialise the Biopsy settings
    def init_settings
      s = Biopsy::Settings.instance
      s.set_defaults
      libdir = File.dirname(__FILE__)
      s.target_dir = [File.join(libdir, 'assemblotron/assemblers/')]
      s.objectives_dir = [File.join(libdir, 'assemblotron/objectives/')]
      @log.debug "initialised Biopsy settings"
    end # init_settings

    # Load global configuration from the config file at
    # +~/.assemblotron+, if it exists.
    def load_config
      config_file = File.join(Dir.home, ".assemblotron")
      if File.exists? config_file
        @log.debug "config file found at #{config_file}"
        config = YAML::load_file(config_file)
        if config.nil?
          @log.warn "config file malformed or empty"
          return
        end
        @config = config.deep_symbolize
      end
    end # parse_config

    # Discover and load available assemblers.
    #
    # Loads all assemblers provided by the program, and
    # then searches any directories listed in the config
    # file (+~/.assemblotron+) setting +assembler_dirs+.
    #
    # Directories listed in +assembler_dirs+ must contain:
    #
    # +definitions+::  Directory with one +.yml+ definition per assembler.
    #                  See the documentation for Definition.
    # +constructors+:: Directory with one +.rb+ file per assembler.
    #                  See the documentation for Constructor. 
    def load_assemblers
      Biopsy::Settings.instance.target_dir.each do |dir|
        Dir.chdir dir do
          Dir['*.yml'].each do |file|
            name = File.basename(file, '.yml')
            target = Biopsy::Target.new
            target.load_by_name name
            @assemblers << target
          end
        end
      end
    end # load_assemblers

    # Return an array of the names of available assemblers
    def assemblers
      a = []
      @assemblers.each do |t|
        a << t.name
        a << t.shortname if t.shortname
      end
      a
    end # assemblers

    def list_assemblers
      puts "Available assemblers:\n\n"
      @assemblers.each do |a| 
        p = " - #{a.name}"
        p += " (#{a.shortname})" if a.respond_to? :shortname
        puts p
      end
    end # list_assemblers

    def run_options

    end # run_options

    def options_for_assembler assembler
      a = self.get_assembler assembler
      parser = Trollop::Parser.new do
          banner <<-EOS
Assemblotron: fast, automated, optimal transcriptome assembly

Options for assembler #{assembler}
EOS
        a.options.each_pair do |param, opts|
          opt param, 
              opts[:desc], 
              :type => Controller.class_from_type(opts[:type])
        end
      end
      Trollop::with_standard_exception_handling parser do
        parser.parse ARGV
        raise Trollop::HelpNeeded if ARGV.empty? # show help screen
      end
    end # options_for_assembler

    def get_assembler assembler
      ret = @assemblers.find do |a|
        a.name == assembler || 
        a.shortname == assembler
      end
      raise "couldn't find assembler #{assembler}" if ret.nil?
      ret
    end

    def self.class_from_type type
      case type
      when 'string'
        String
      when 'int'
        Integer
      when 'float'
        Float
      end
    end

    def run assembler
      a = self.get_assembler assembler
      e = Biopsy::Experiment.new a
      res = e.run
    end # run

  end # Controller

end # Assemblotron