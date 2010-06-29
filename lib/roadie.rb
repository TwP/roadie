
require 'loquacious'

module Roadie

  # :stopdoc:
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  # :startdoc:

  # Returns the version string for the library.
  #
  def self.version
    @version ||= File.read(path('version.txt')).strip
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args, &block )
    rv =  args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
    if block
      begin
        $LOAD_PATH.unshift LIBPATH
        rv = block.call
      ensure
        $LOAD_PATH.shift
      end
    end
    return rv
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    args.empty? ? PATH : ::File.join(PATH, args.flatten)
  end

  # Called when this module is included into another module or class.
  #
  def self.included( other )
    other.extend ::Roadie::ClassMethods
    other.const_set('Initializer', ::Roadie::Initializer.clone)
    other.instance_variable_set(:@config_name, other.name)

    _setup_config_defaults other
  end

  # Private internal method that will setup some default configuration
  # settings for your application.
  #
  def self._setup_config_defaults( other )
    config = other.config {
      config_path %w[config], :desc => <<-__
        Array of paths to search for configuration and environment files.
      __

      initializers [], :desc => <<-__
        Array of initializers to invoke when setting up the system.
      __

      environment(
        (ENV['RACK_ENV'] || :development).to_sym,
        :desc => <<-__
          The current runtime environment. Can be one of
          |
          |  :production
          |  :development
          |  :test
          |
        __
      )

      database nil, :desc => <<-__
        The hash of database configuration settings for the various supported
        environments. These settings are loaded by default from the
        'database.yml' file in the configuration path.
      __
    }

    config.database = Proc.new {
      fn = other.config_path('database.yml')
      #raise "Database configuration file could not be found: #{fn.inspect}" unless test(?f, fn)
      YAML.load_file(fn) if test(?f, fn)
    }

    other
  end

  module ClassMethods
    # Returns your application's configuration object. If a block is given,
    # then it will be evaluated in the context of the configuration object.
    #
    def config( &block )
      Loquacious.configuration_for(@config_name, &block)
    end

    # Returns the configuration path for your application. This configuration
    # path is the location where database and environment specific settings are
    # located. Actually, it is an array of paths that will be searched in order
    # for the various configuration files.
    #
    # The configuration path is configured using the Roadie config block.
    #
    #   YourApp.config {
    #     config_path ['foo/bar/baz']
    #   }
    #
    # The default configuration path is the "config" directoy located alongside
    # your application's "lib" folder.
    #
    def config_path( *args )
      @__config = config unless defined? :@__config and @__config
      return @__config.config_path.first if args.empty?

      args.flatten!
      @__config.config_path.each do |path|
        p = ::File.join(path, args)
        return p if test ?e, p
      end
      return ::File.join(@__config.config_path.first, args)
    end

    # Run your application's initialization process. If a block is given to
    # this method, the configuration object will be yielded to the block after
    # the environment has been loaded. This allows the user to override
    # enironmental configuration settings at runtime.
    #
    def setup( &block )
      self.const_get(:Initializer).run(&block)
    end

    #
    #
    def help( name = nil, opts = {} )
      opts = {
        :io => $stdout,
        :colorize => true,
        :nesting_nodes => false,
        :descriptions => true,
        :values => true
      }.merge!(opts)

      help = Loquacious.help_for(@config_name, opts)
      help.show(name, opts)
    end
  end

  # The initializer configures the nevs framework according to the user
  # specified settings. The various initialization steps can be reorderd or
  # skipped altogether if that is the desire. Environment specific
  # configurations and heirerarchical configuration paths are supported.
  #
  class Initializer

    # Create a new Initializer instance and run the initialization process. If
    # a block is given to this method, the Nevs configuration object will be
    # yielded to the block after the environment has been loaded. This allows
    # the user to override enironmental configuration settings at runtime.
    #
    def self.run( *args, &block )
      new.process(*args, &block)
    end

    # Returns a reference to the parent namespace. The parent namespace is the
    # module / class that included Roadie. The Initializer is created
    # underneath this namespace, and it needs access to the "config_path"
    # method defined in the parent namespace context.
    #
    def self.context
      return @context if defined? :@context and @context

      ary = name.split '::'
      ary.slice!(-1)
      @context = ary.inject(Object) {|context, name| context.const_get name }
    end

    # Create a new Initializer instance.
    #
    def initialize
      @config = context.config
    end

    # Returns a reference to the parent namespace. The parent namespace is the
    # module / class that included Roadie. The Initializer is created
    # underneath this namespace, and it needs access to the "config_path"
    # method defined in the parent namespace context.
    #
    def context
      self.class.context
    end

    # Run the initialization process. If a block is given to this method,
    # the application's configuration object will be yielded to the block
    # after the environment has been loaded. This allows the user to override
    # enironmental configuration settings at runtime.
    #
    def process( *args, &block )
      load_environment
      block.call(@config) unless block.nil?
      @config.initializers.each {|init| self.send "initialize_#{init}"}
      self
    end

    # Load environment specific configuration settings if the environment file
    # exists.
    #
    def load_environment
      fn = context.config_path('environments', "#{@config.environment}.rb")
      return self unless test(?f, fn)

      config = @config
      eval(IO.read(fn), binding, fn)
      self
    end

  end  # Initializer
end  # module Roadie

module Kernel
  def Roadie( name )
    Module.new {
      eval <<-CODE
        def self.included( other )
          other.extend ::Roadie::ClassMethods
          other.const_set('Initializer', ::Roadie::Initializer.clone)
          other.instance_variable_set(:@config_name, "#{name}")

          ::Roadie._setup_config_defaults other
        end
      CODE
    }
  end
end

