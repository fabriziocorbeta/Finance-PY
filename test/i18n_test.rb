require "i18n/tasks"

# We're currently skipping some i18n tests to speed up development.  Eventually, we'll make a dedicated
# project for getting i18n working.  More details on that here:
# https://github.com/maybe-finance/maybe/issues/1225
class I18nTest < ActiveSupport::TestCase
  def setup
    @i18n = I18n::Tasks::BaseTask.new
  end

  def test_no_missing_keys
    skip "Skipping missing keys test"
    missing_keys = @i18n.missing_keys(locales: [ :en ])
    assert_empty missing_keys,
                 "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them"
  end

  def test_no_unused_keys
    skip "Skipping unused keys test"
    unused_keys = @i18n.unused_keys(locales: [ :en ])
    assert_empty unused_keys,
                 "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them"
  end

  def test_files_are_normalized
    skip "Skipping file normalization test"
    non_normalized = @i18n.non_normalized_paths(locales: [ :en ])
    error_message = "The following files need to be normalized:\n" \
                    "#{non_normalized.map { |path| "  #{path}" }.join("\n")}\n" \
                    "Please run `i18n-tasks normalize' to fix"
    assert_empty non_normalized, error_message
  end

  def test_no_inconsistent_interpolations
    skip "Skipping inconsistent interpolations test"
    inconsistent_interpolations = @i18n.inconsistent_interpolations(locales: [ :en ])
    error_message = "#{inconsistent_interpolations.leaves.count} i18n keys have inconsistent interpolations.\n" \
                    "Please run `i18n-tasks check-consistent-interpolations' to show them"
    assert_empty inconsistent_interpolations, error_message
  end
end

# Deliberately a separate class from I18nTest: that class's `setup` instantiates
# I18n::Tasks::BaseTask, which mutates I18n's global default_locale/available_locales
# for the rest of the process (i18n-tasks config uses base_locale: en) -- sharing
# `setup` here corrupted this test's I18n.available_locales silently.
#
# 2026-09-07: a real user hit a genuinely broken "New transaction" form because
# `t("helpers.select.search_placeholder")` was missing in Spanish (our default
# locale). When `t()` is interpolated directly into an HTML attribute value and
# the key is missing, Rails' translate helper returns an HTML-safe
# `<span class="translation_missing">...</span>` -- which, spliced raw into
# `placeholder="<%= t(...) %>"`, closes the attribute's quote early and dumps
# the rest of the tag's real attributes as visible page text. I18nTest's other
# tests stay skipped (870+ pre-existing missing keys, mostly rendered as element
# content where a missing key is merely ugly, not corrupting markup -- not
# something to mass-translate here without native review) -- this test targets
# only that specific, markup-breaking failure mode going forward.
class I18nAttributeInterpolationTest < ActiveSupport::TestCase
  APP_ROOT = File.expand_path("..", __dir__)

  # Mirrors config.i18n.available_locales / config.i18n.fallbacks in
  # config/application.rb: each locale falls back through its own chain to
  # :es (default_locale). Hardcoded, and this test reads translation YAML
  # directly from disk instead of going through the `I18n` module, because
  # I18n::Tasks::BaseTask (instantiated by I18nTest's `setup`, above) replaces
  # I18n's backend/load_path/default_locale/Rails-constant wiring for the rest
  # of this test process regardless of test order or class boundaries --
  # resetting each of those pieces individually was tried and still left
  # fallback resolution broken, so this test doesn't depend on global I18n
  # state at all.
  LOCALE_FALLBACK_CHAINS = {
    "es" => [ "es" ],
    "es-PY" => [ "es-PY", "es" ],
    "en" => [ "en", "es" ]
  }.freeze

  def test_no_missing_keys_interpolated_into_html_attributes
    translations = LOCALE_FALLBACK_CHAINS.keys.index_with { |locale| load_locale_tree(locale) }

    attribute_pattern = /(?:placeholder|aria-label|title|alt|value)="<%=\s*t\(([^)]*)\)\s*%>"/
    dangerous_calls = []

    Dir.glob(File.join(APP_ROOT, "app", "{views,components}", "**", "*.erb")).each do |path|
      File.readlines(path).each_with_index do |line, index|
        line.scan(attribute_pattern) do |(raw_args)|
          next if raw_args.include?("default:") # explicit fallback can't render a broken span
          next if raw_args.include?('#{') # dynamic key, can't statically resolve

          key_match = raw_args.match(/\A\s*["']([^"']+)["']/)
          next unless key_match

          dangerous_calls << { path: path, line: index + 1, raw_key: key_match[1] }
        end
      end
    end

    failures = dangerous_calls.filter_map do |call|
      resolved_key = resolve_view_relative_key(call[:raw_key], call[:path])
      key_parts = resolved_key.split(".")

      broken_locales = LOCALE_FALLBACK_CHAINS.reject do |_locale, chain|
        chain.any? { |fallback_locale| key_exists?(translations[fallback_locale], key_parts) }
      end.keys
      next if broken_locales.empty?

      relative_path = call[:path].delete_prefix("#{APP_ROOT}/")
      "#{relative_path}:#{call[:line]} (#{resolved_key}) missing for #{broken_locales.join(', ')}"
    end

    assert_empty failures,
      "The following i18n keys are interpolated directly into an HTML attribute and are missing " \
      "for at least one available locale. A missing key there renders as a raw HTML span inside " \
      "the attribute value and breaks the surrounding tag:\n\n#{failures.join("\n")}"
  end

  private

    def resolve_view_relative_key(raw_key, path)
      return raw_key unless raw_key.start_with?(".")

      base = path.delete_prefix("#{APP_ROOT}/app/views/").delete_prefix("#{APP_ROOT}/app/components/")
      base = base.sub(/\.[a-z]+\.erb\z/, "")
      segments = base.split("/")
      segments[-1] = segments[-1].sub(/\A_/, "")
      "#{segments.join('.')}#{raw_key}"
    end

    def load_locale_tree(locale)
      paths = Dir.glob(File.join(APP_ROOT, "config", "locales", "**", "*.yml"))
        .select { |path| File.basename(path, ".yml") == locale }

      paths.each_with_object({}) do |path, tree|
        data = YAML.load_file(path) || {}
        locale_data = data[locale] || {}
        deep_merge!(tree, locale_data)
      end
    end

    def deep_merge!(base, other)
      other.each do |key, value|
        if value.is_a?(Hash) && base[key].is_a?(Hash)
          deep_merge!(base[key], value)
        else
          base[key] = value
        end
      end
      base
    end

    def key_exists?(tree, key_parts)
      node = tree
      key_parts.each do |part|
        return false unless node.is_a?(Hash) && node.key?(part)
        node = node[part]
      end
      true
    end
end
