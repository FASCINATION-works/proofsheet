# frozen_string_literal: true

require "optparse"

module Proofsheet
  class CLI
    USAGE = "Usage: proofsheet <capture [SHOT ...] | compose [COMPOSITION ...] | list> " \
            "[--config PATH] [--host HOST]"

    def initialize(argv, out: $stdout, err: $stderr, root: Dir.pwd, manifest_loader: Manifest.method(:load), **classes)
      @argv = argv.dup
      @out = out
      @err = err
      @root = root
      @manifest_loader = manifest_loader
      @capturer_class = classes.fetch(:capturer_class, Capturer)
      @composer_class = classes.fetch(:composer_class, Composer)
    end

    def run
      command = @argv.shift
      return help(0) if %w[help --help -h].include?(command)
      return version if %w[--version -v].include?(command)
      return help(1) unless %w[capture compose list].include?(command)

      options = { config: Manifest::DEFAULT_PATH }
      parser(options).parse!(@argv)
      manifest = @manifest_loader.call(options[:config])

      dispatch(command, manifest, options)
      0
    rescue OptionParser::ParseError, Error, KeyError => e
      @err.puts "proofsheet: #{e.message}"
      1
    end

    private

    def dispatch(command, manifest, options)
      return list(manifest) if command == "list"
      return compose(manifest) if command == "compose"

      capture(manifest, options)
    end

    def parser(options)
      OptionParser.new do |opts|
        opts.on("-c", "--config PATH") { |path| options[:config] = path }
        opts.on("--host HOST") { |host| options[:host] = host }
      end
    end

    def list(manifest)
      raise Error, "list does not accept shot names" unless @argv.empty?

      manifest.shots.each { |shot| @out.puts "#{shot.name.ljust(20)} #{shot.path_template}" }
    end

    def capture(manifest, options)
      host = options[:host] || manifest.host
      raise Error, "host is missing from #{manifest.path}; pass --host HOST" if host.nil? || host.empty?

      credentials = Credentials.new(manifest.credentials) if manifest.login
      capturer = @capturer_class.new(manifest: manifest, host: host, root: @root,
                                     credentials: credentials, out: @out)
      names = @argv.empty? ? manifest.names : @argv
      @out.puts "Capturing #{names.size} #{names.size == 1 ? "shot" : "shots"} from #{host}"
      capturer.capture(names)
      @out.puts "Done."
    end

    def compose(manifest)
      names = @argv.empty? ? manifest.composition_names : @argv
      @out.puts "Composing #{names.size} #{names.size == 1 ? "image" : "images"}"
      @composer_class.new(manifest: manifest, root: @root, out: @out).compose(names)
      @out.puts "Done."
    end

    def help(status)
      (status.zero? ? @out : @err).puts USAGE
      status
    end

    def version
      @out.puts Proofsheet::VERSION
      0
    end
  end
end
