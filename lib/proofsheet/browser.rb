# frozen_string_literal: true

require "timeout"

module Proofsheet
  class Browser
    DRIVER = :proofsheet
    LOAD_TIMEOUT = 20
    SETTLE_TIME = 0.5

    LOADED = <<~JS
      document.readyState === "complete" &&
        (!document.fonts || document.fonts.status === "loaded") &&
        Array.from(document.querySelectorAll("iframe")).every(function (frame) {
          try {
            return !frame.contentDocument || frame.contentDocument.readyState === "complete";
          } catch (e) {
            return true;
          }
        })
    JS

    SCROLL_INTO_VIEW = <<~JS
      arguments[0].style.scrollMargin = arguments[1] + "px";
      arguments[0].scrollIntoView({block: "nearest"});
    JS

    def initialize(host:, viewport:)
      @host = host
      @width, @height = viewport
    end

    def start
      require "capybara"
      require "selenium-webdriver"

      Capybara.register_driver(DRIVER) { |app| chrome(app) }
      Capybara.run_server = false
      Capybara.app_host = @host
      Capybara.default_max_wait_time = 10

      @session = Capybara::Session.new(DRIVER)
      @session.visit("/")
      fit_viewport
      self
    end

    def quit
      @session&.quit
    end

    def current_path
      @session.current_path
    end

    def visit(path, wait_for: nil)
      @session.visit(path)
      @session.assert_selector(wait_for, visible: :all) if wait_for
      Timeout.timeout(LOAD_TIMEOUT) { sleep 0.1 until @session.evaluate_script(LOADED) }
      sleep SETTLE_TIME
    end

    def sign_in(login, username, password)
      @session.visit(login.path)
      @session.fill_in(login.username_field, with: username)
      @session.fill_in(login.password_field, with: password)
      @session.click_button(login.submit)
    end

    def shows?(selector, text)
      @session.has_css?(selector, text: text)
    end

    def click(selector)
      @session.find(selector).click
      sleep SETTLE_TIME
    end

    def evaluate(script)
      @session.evaluate_script(script)
    end

    def screenshot_png
      @session.driver.browser.screenshot_as(:png)
    end

    def rect_for(selector, margin: 0)
      node = @session.find(selector, match: :first)
      @session.execute_script(SCROLL_INTO_VIEW, node, margin)
      sleep SETTLE_TIME
      @session.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", node)
    end

    private

    def chrome(app)
      options = Selenium::WebDriver::Chrome::Options.new
      ["--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
       "--window-size=#{@width},#{@height}", "--disable-dev-shm-usage", "--no-sandbox",
       "--disable-gpu"].each { |argument| options.add_argument(argument) }
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end

    def fit_viewport
      inner = @session.evaluate_script("[window.innerWidth, window.innerHeight]")
      return if inner == [@width, @height]

      window = @session.driver.browser.manage.window
      size = window.size
      window.resize_to(size.width + (@width - inner[0]), size.height + (@height - inner[1]))
    end
  end
end
