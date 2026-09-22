require "test_helper"

# The offline page is shown by the service worker when the server is unreachable, so
# every local asset it references must be precached at install time. A logo that was
# only cached lazily rendered as a broken image exactly when the page was needed.
class OfflinePageTest < ActiveSupport::TestCase
  test "every local asset used by offline.html is precached by the service worker" do
    html = Rails.root.join("public/offline.html").read
    worker = Rails.root.join("app/views/pwa/service-worker.js").read

    precached = worker[/OFFLINE_ASSETS\s*=\s*\[(.*?)\]/m, 1].to_s.scan(%r{'(/[^']+)'}).flatten
    used = html.scan(/(?:src|href)="(\/[^"#?]+)"/).flatten

    assert_includes precached, "/offline.html"
    used.each do |asset|
      assert_includes precached, asset, "#{asset} is used by offline.html but not precached by the service worker"
    end
  end

  test "offline page is in Spanish" do
    html = Rails.root.join("public/offline.html").read

    assert_includes html, 'lang="es"'
    assert_includes html, "Reintentar"
  end
end
