require "test_helper"
require "socket"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DEFAULT_VIEWPORT_WIDTH = 1400
  DEFAULT_VIEWPORT_HEIGHT = 1400

  setup do
    # CI runs on a shared, resource-constrained ubuntu-latest runner (2 vCPU)
    # alongside Postgres, Redis, and headless Chrome all competing for the
    # same CPU -- local dev has none of that contention. Several different,
    # unrelated system tests have flaked there (ChatsTest, PropertiesEditTest,
    # SettingsTest) with no common code-level cause, which points at
    # environment jitter rather than a shared bug. This is a wider safety
    # margin for that, not a fix for any specific test -- see #209 and #210
    # for the two flakes that DID have real, non-timing root causes.
    Capybara.default_max_wait_time = ENV["CI"].present? ? 10 : 5

    if ENV["SELENIUM_REMOTE_URL"].present?
      server_port = ENV.fetch("CAPYBARA_SERVER_PORT", 30_000 + (Process.pid % 1000)).to_i
      app_host = ENV["CAPYBARA_APP_HOST"].presence || IPSocket.getaddress(Socket.gethostname)

      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = server_port
      Capybara.always_include_port = true
      Capybara.app_host = "http://#{app_host}:#{server_port}"
    end

    reset_viewport
  end

  if ENV["SELENIUM_REMOTE_URL"].present?
    Capybara.register_driver :selenium_remote_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--window-size=1400,1400")

      Capybara::Selenium::Driver.new(
        app,
        browser: :remote,
        url: ENV["SELENIUM_REMOTE_URL"],
        capabilities: options
      )
    end

    driven_by :selenium_remote_chrome, screen_size: [ 1400, 1400 ]
  else
    driven_by :selenium, using: ENV["CI"].present? ? :headless_chrome : ENV.fetch("E2E_BROWSER", :chrome).to_sym, screen_size: [ 1400, 1400 ] do |driver_option|
      # Chrome's default /dev/shm is small on many CI containers; without
      # this flag Chrome falls back to writing shared memory to disk under
      # pressure instead of just refusing, which shows up as intermittent
      # slowness/crashes rather than a clean error -- exactly the kind of
      # cause that's invisible from a test failure alone. Guarded to CI only
      # (a no-op locally) and a no-op on any CI runner that already has
      # enough /dev/shm.
      driver_option.add_argument("--disable-dev-shm-usage") if ENV["CI"].present?
    end
  end

  def teardown
    reset_viewport
    super
  end

  private

    def reset_viewport
      page.current_window.resize_to(DEFAULT_VIEWPORT_WIDTH, DEFAULT_VIEWPORT_HEIGHT) if page&.current_window
    end

    def sign_in(user)
      visit new_session_path
      within %(form[action='#{sessions_path}']) do
        fill_in "Email", with: user.email
        fill_in "Password", with: user_password_test
        click_on "Log in"
      end

      # Trigger Capybara's wait mechanism to avoid timing issues with logins
      find("h1", text: "Welcome back, #{user.first_name}")
    end

    def login_as(user)
      sign_in(user)
    end

    def sign_out
      find("#user-menu").click
      click_button "Logout"

      # Trigger Capybara's wait mechanism to avoid timing issues with logout
      find("a", text: "Sign in")
    end

    def within_testid(testid)
      within "[data-testid='#{testid}']" do
        yield
      end
    end

    # Diagnostic instrumentation for the recurring, environment-sensitive
    # system-test flakes (turbo frame / Stimulus controller connect races --
    # see PRs #209, #210, #211). Capybara's finders retry silently for up to
    # default_max_wait_time before raising, so a bare ElementNotFound gives
    # no signal on whether something was merely slow (found just under the
    # wire) or never happening at all (pegged at the full wait every time).
    # Wrapping the wait in this logs the real elapsed time to CI's stdout on
    # every run, pass or fail, so the next flake comes with an actual number
    # instead of another guess. Not meant to stay forever -- remove once
    # enough data narrows down (or rules out) CI resource contention as the
    # cause.
    def with_timing(label)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        yield
      ensure
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        puts "[TIMING] #{label}: #{elapsed_ms}ms"
      end
    end

    # Interact with DS::Select custom dropdown components.
    # DS::Select renders as a button + listbox — not a native <select> — so
    # Capybara's built-in `select(value, from:)` does not work with it.
    def select_ds(label_text, record)
      field_label = find("label", exact_text: label_text)
      container = field_label.ancestor("div.relative")
      container.find("button").click
      if container.has_selector?("input[type='search']", visible: true)
        container.find("input[type='search']", visible: true).set(record.name)
      end
      listbox = with_timing("select_ds(#{label_text.inspect}) listbox visible") do
        container.find("[role='listbox']", visible: true)
      end
      listbox.find("[role='option'][data-value='#{record.id}']", visible: true).click
    end
end
