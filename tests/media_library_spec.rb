ENV['RACK_ENV'] = 'test'

require './media_library'
require 'minitest/autorun'
require 'rack/test'

class MediaLibraryTest < Minitest::Test
  include Rack::Test::Methods

  def app
    MediaLibrary
  end

  def test_displays_index_page
    get '/'
    assert last_response.ok?
    assert last_response.body.include?('Personal Media Library')
  end

  def test_displayed_new_page
    get '/video/new'
    assert last_response.ok?
    assert last_response.body.include?('Title')
  end
end
