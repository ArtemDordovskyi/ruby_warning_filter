require "bundler/setup"
require_relative "../lib/ruby_warning_filter"
gem "minitest", "~> 5.0"
require "minitest/autorun"
require "stringio"
STDOUT.sync = true

class RubyWarningsFilterTest < Minitest::Test
  def setup
    @gems_dir = File.expand_path("../gems", __FILE__)
    @gems_link_dir = File.expand_path("../gems-link", __FILE__)
    @err = RubyWarningFilter.new(StringIO.new, ignore_path: ["/path/to/ruby/2.2.0/gems", @gems_link_dir])
  end

  def test_no_effect
    assert_equal 0, @err.ruby_warnings
    @err.puts "hello"
    assert_equal "hello\n", @err.string
    assert_equal 0, @err.ruby_warnings
  end

  def test_ruby_warning
    @err.write "/path/to/script/middleware_test.rb:58: warning: assigned but unused variable - status\n"
    assert_equal "/path/to/script/middleware_test.rb:58: warning: assigned but unused variable - status\n",
      @err.string
    assert_equal 1, @err.ruby_warnings

    @err.write "#{@gems_dir}/unicode_utils-1.4.0/lib/unicode_utils/sid.rb:11: warning: shadowing outer local variable - al\n"
    @err.write "/path/to/ruby/2.2.0/gems/unicode_utils-1.4.0/lib/unicode_utils/sid.rb:11: warning: shadowing outer local variable - al\n"

    # This warning actually writes newline separately.
    @err.write "/path/to/ruby/2.2.0/gems/dragonfly-1.0.6/lib/dragonfly/utils.rb:41:in `uri_unescape': warning: URI.unescape is obsolete"
    @err.write "\n"

    assert_equal "/path/to/script/middleware_test.rb:58: warning: assigned but unused variable - status\n",
      @err.string
    assert_equal 1, @err.ruby_warnings
  end

  def test_backtrace
    # in gem
    @err.write "/path/to/ruby/2.2.0/gems/sass-3.4.12/lib/sass/util/normalized_map.rb:2: warning: loading in progress...\n"
    @err.write "\tfrom /path/to/app/bin/rails:4:in  `<main>'\n"

    # in app
    @err.write "/path/to/app/script:1: warning: loading in progress...\n"
    @err.write "\tfrom /path/to/app/bin/rails:4:in  `<main>'\n"

    @err.write "something other\n"

    assert_equal \
      "/path/to/app/script:1: warning: loading in progress...\n"\
      "\tfrom /path/to/app/bin/rails:4:in  `<main>'\n"\
      "something other\n",
      @err.string

    assert_equal 1, @err.ruby_warnings
  end

  def test_method_redefined_eval
    # in gem
    @err.write "/path/to/ruby/2.2.0/gems/compass-core-1.0.3/lib/gradient_support.rb:319: warning: method redefined; discarding old to_moz\n"
    @err.write "(eval):2: warning: previous definition of to_moz was here\n"

    @err.write "/path/to/ruby/2.2.0/gems/sitemap_generator-6.3.0/lib/sitemap_generator/templates.rb:10: warning: method redefined; discarding old sitemap_sample\n"
    @err.write "(eval):1: warning: method redefined; discarding old sitemap_sample\n"

    # in app
    @err.write "/path/to/app.rb:123: warning: method redefined; discarding old foo\n"
    @err.write "(eval):2: warning: previous definition of foo was here\n"

    @err.write "(eval):1: warning: method redefined; discarding old sitemap_sample\n"

    @err.write "something other\n"

    assert_equal \
      "/path/to/app.rb:123: warning: method redefined; discarding old foo\n"\
      "(eval):2: warning: previous definition of foo was here\n"\
      "(eval):1: warning: method redefined; discarding old sitemap_sample\n"\
      "something other\n",
      @err.string

    assert_equal 3, @err.ruby_warnings
  end

  def test_template_warning
    @err.write "/path/to/app/template.html.slim:2: warning: possibly useless use of a variable in void context\n"
    assert_equal "", @err.string
    assert_equal 0, @err.ruby_warnings

    @err.write "/path/to/app/template.html.slim:2: warning: assigned but unused variable - foo\n"
    assert_equal "/path/to/app/template.html.slim:2: warning: assigned but unused variable - foo\n",
      @err.string
    assert_equal 1, @err.ruby_warnings
  end

  def test_internal_warning
    # in gem
    @err.write "<internal:/path/to/ruby/2.2.0/rubygems/core_ext/kernel_require.rb>:319: warning: loading in progress, circular require considered harmful - /path/to/ruby/2.2.0/gems/bugsnag-6.26.3/lib/bugsnag.rb\n"

    # in app
    @err.write "<internal:/path/to/ruby/2.2.0/rubygems/core_ext/kernel_require.rb>:319: warning: loading in progress, circular require considered harmful - /path/to/app.rb\n"

    @err.write "something other\n"

    assert_equal \
      "<internal:/path/to/ruby/2.2.0/rubygems/core_ext/kernel_require.rb>:319: warning: loading in progress, circular require considered harmful - /path/to/app.rb\n"\
        "something other\n",
      @err.string

    assert_equal 1, @err.ruby_warnings
  end
end
