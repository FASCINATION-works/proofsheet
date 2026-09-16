# frozen_string_literal: true

require "fileutils"
require "pathname"

module Proofsheet
  class Capturer
    def initialize(manifest:, host:, root: Dir.pwd, credentials: nil, browser_class: Browser, out: $stdout)
      @manifest = manifest
      @host = host
      @root = Pathname(root)
      @credentials = credentials
      @browser_class = browser_class
      @out = out
    end

    def capture(names = @manifest.names)
      shots = names.map { |name| @manifest.shot(name) }
      username, password = authentication

      @browser = @browser_class.new(host: @host, viewport: @manifest.viewport).start
      sign_in(username, password) if @manifest.login
      shots.each { |shot| capture_shot(shot) }
    ensure
      @browser&.quit
    end

    private

    def authentication
      return [nil, nil] unless @manifest.login

      username = @credentials.username
      expected = @manifest.expected_username
      if expected && username != expected
        raise Error, "credentials hold #{username.inspect} but the manifest expects #{expected.inspect}"
      end

      [username, @credentials.password]
    end

    def sign_in(username, password)
      login = @manifest.login
      @browser.sign_in(login, username, password)
      verify(login.expectation, "sign in") if login.expectation
    end

    def capture_shot(shot)
      @out.puts shot.name
      @browser.visit(@manifest.path_for(shot), wait_for: shot.wait_for)
      verify(shot.expectation, shot.name) if shot.expectation
      resolve_path(shot) if shot.path_script
      @browser.click(shot.click) if shot.click
      write(shot, image_for(shot))
    end

    def resolve_path(shot)
      path = @browser.evaluate(shot.path_script)
      raise Error, "#{shot.name}: path_script did not return a path" if path.nil? || path.empty?

      @browser.visit(path, wait_for: shot.resolved_wait_for)
    end

    def verify(expectation, context)
      return if @browser.shows?(expectation.selector, expectation.text)

      raise Error, "#{context}: #{@browser.current_path} does not show #{expectation.text.inspect}"
    end

    def image_for(shot)
      return @browser.screenshot_png unless shot.clip?

      rect = @browser.rect_for(shot.clip.selector, margin: shot.clip.padding)
      require "vips"
      image = Vips::Image.new_from_buffer(@browser.screenshot_png, "")
      verify_scale(image)
      crop(image, clip_for(shot, rect, image))
    end

    def crop(image, clip)
      @out.puts "  cropped to #{clip}"
      image.crop(clip.left, clip.top, clip.width, clip.height).write_to_buffer(".png")
    end

    def clip_for(shot, rect, image)
      if rect["height"] > image.height
        raise Error, "#{shot.name}: #{shot.clip.selector} is #{rect["height"].ceil}px tall, " \
                     "taller than the #{image.height}px viewport"
      end

      Clip.from_rect(rect, image_width: image.width, image_height: image.height,
                           full_width: shot.clip.full_width, padding: shot.clip.padding)
    end

    def verify_scale(image)
      width = @manifest.viewport.first
      return if image.width == width

      raise Error, "captured #{image.width}px wide but the viewport is #{width}px"
    end

    def write(shot, png)
      path = @root.join(@manifest.output_dir, shot.filename)
      FileUtils.mkdir_p(path.dirname)
      path.binwrite(png)
      @out.puts "  wrote #{path.relative_path_from(@root)}"
    end
  end
end
