require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.default_cassette_options = {
    clean_outdated_http_interactions: true,
    re_record_interval: 7 * 24 * 3600,
    record: :once,
    preserve_exact_body_bytes: true,
    allow_playback_repeats: true,
  }
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<BEARER>') do
    'Bearer your_actual_token'
  end
end
