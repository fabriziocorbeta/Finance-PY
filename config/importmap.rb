# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Controllers are lazy-loaded on demand (see app/javascript/controllers/index.js), so most of
# them don't need a <link rel="modulepreload"> hint competing with CSS/fonts for first paint.
# Keep preload only for the controllers wired up on the root layout itself
# (app/views/layouts/shared/_htmldoc.html.erb), which are therefore present on every page.
pin_all_from "app/javascript/controllers", under: "controllers", preload: false
pin "controllers/theme_controller", preload: true
pin "controllers/viewport_controller", preload: true
pin "controllers/hotkey_controller", preload: true

pin_all_from "app/components", under: "controllers", to: ""
pin_all_from "app/javascript/services", under: "services", to: "services"
pin_all_from "app/javascript/utils", under: "utils", to: "utils"
pin "@github/hotkey", to: "@github--hotkey.js", preload: false # @3.1.1
pin "@simonwep/pickr", to: "@simonwep--pickr.js", preload: false # @1.9.1

# D3 packages — bundled into single chunks and lazy-loaded on demand by chart controllers
# (time_series_chart, sankey_chart, donut_chart). Not preloaded on first paint.
pin "d3", to: "d3.bundle.min.js", preload: false
pin "d3-sankey", to: "d3-sankey.bundle.min.js", preload: false
pin "@floating-ui/dom", to: "@floating-ui--dom.js", preload: false # @1.7.0
pin "@floating-ui/core", to: "@floating-ui--core.js", preload: false # @1.7.0
pin "@floating-ui/utils", to: "@floating-ui--utils.js", preload: false # @0.2.9
pin "@floating-ui/utils/dom", to: "@floating-ui--utils--dom.js", preload: false # @0.2.9
