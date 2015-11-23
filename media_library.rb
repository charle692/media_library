require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'
require 'ostruct'
require 'pry'
require 'pry-byebug'
require 'streamio-ffmpeg'
require 'themoviedb-api'
require 'open-uri'
require 'sinatra/base'

require_relative 'models/video'
require_relative 'models/attachment'

class MediaLibrary < Sinatra::Base
  # Global variables
  $tmdb_key = YAML.load_file(File.join(Dir.pwd, 'keys.yml'))['the_movie_db']
  $img_poster_url = "http://image.tmdb.org/t/p/w500"
  $img_backdrop_url = "http://image.tmdb.org/t/p/w780"
  $image_path = "/media/image"
  $config = YAML.load_file(File.join(Dir.pwd, 'config.yml'))

  # TheMovideDB API Key - this key is not added to source control
  Tmdb::Api.key($tmdb_key)

  # Tells ruby that html.erb is an erb template
  Tilt.register Tilt::ERBTemplate, 'html.erb'

  # Connects to the database
  configure do
    DataMapper::setup(:default, File.join('sqlite://', Dir.pwd, 'development.db'))
  end

  # defining HTTP headers
  before do
    headers "Content-Type" => "text/html; charset=utf-8"
  end

  # RESTful routes
  get '/' do
    @title = 'Personal Media Library'
    @videos = Video.all(order: [:title.desc])

    erb :index
  end

  post '/video/create' do
    video = Video.new(params[:video])
    video_attachment = video.attachments.new

    # Check if file has a valid mime_type before saving
    video_attachment.handle_uploaded_video(params['video-file']) if !params['video-file'].blank?

    if !video_attachment.mime_type.nil?
      video.get_metadata
      video.title = video.title.delete("'") # api doesn't like apostrophes

      # API call
      video_details = Tmdb::Search.movie(video.title, page: 1)['results'][0]

      if video.get_video_details(video_details)
        poster = video.attachments.new
        backdrop = video.attachments.new

        poster.get_image($img_poster_url, "#{video.title}.jpg",
                                          video_details['poster_path'])

        backdrop.get_image($img_backdrop_url, "#{video.title}_backdrop.jpg",
                                              video_details['backdrop_path'])

        poster.handle_uploaded_image("#{video.title}.jpg")
        backdrop.handle_uploaded_image("#{video.title}_backdrop.jpg")
        video_attachment.create_symlink("video")
        poster.create_symlink("image")
        backdrop.create_symlink("image")

        if video.save
          @message = 'Video was uploaded'
        else
          @message = 'Video was not uploaded'
        end
      else
        @message = 'Not a valid video title'
      end
    else
      @message = 'Video was not uploaded'
    end

    erb :create
  end

  get '/video/new' do
    @title = 'Upload Video'
    erb :new
  end

  get '/video/show/:id' do
    @video = Video.first(id: params[:id])
    @title = @video.title if @video

    if @video
      erb :show
    else
      redirect '/'
    end
  end

  get '/video/watch/:id' do
    video = Video.first(id: params[:id])
    if video
      @title = video.title
      @video = video.attachments.first(:extension.not => 'jpg')
    end

    if @video
      erb :watch
    else
      redirect '/'
    end
  end

  # basically takes our classes and properties and creates database tables
  configure :development do
    DataMapper.finalize
    DataMapper.auto_upgrade!
  end
end
