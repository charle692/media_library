require 'data_mapper'
require 'dm-sqlite-adapter'
require 'pry'
require 'pry-byebug'
require 'streamio-ffmpeg'
require 'themoviedb-api'
require 'open-uri'

require_relative 'models/video'
require_relative 'models/attachment'

class MediaLibrary < Sinatra::Base
  $tmdb_key = YAML.load_file(File.join(Dir.pwd, 'keys.yml'))['the_movie_db']
  $img_poster_url = "http://image.tmdb.org/t/p/w500"
  $img_backdrop_url = "http://image.tmdb.org/t/p/w780"
  $image_path = "/media/image"
  $valid_mime = YAML.load_file(File.join(Dir.pwd, 'config.yml'))['supported_mime_types']

  Tmdb::Api.key($tmdb_key)
  Tilt.register Tilt::ERBTemplate, 'html.erb'

  configure do
    DataMapper::setup(:default, File.join('sqlite://', Dir.pwd, 'development.db'))
  end

  get '/' do
    @title = 'Personal Media Library'
    @videos = Video.all(order: [:title.asc])

    erb :index
  end

  get '/video/new' do
    @title = 'Upload Video'
    erb :new
  end

  post '/video/create' do
    @video = Video.new(params[:video])
    video_attachment = @video.attachments.new

    if @video.valid? && video_attachment.handle_uploaded_video(params['video-file'])
      @video.get_metadata
      @video.title = @video.title.delete("'") # Tmdb doesn't like apostrophes
      video_details = Tmdb::Search.movie(@video.title, page: 1)['results'][0]

      if @video.get_video_details(video_details)
        poster = @video.attachments.new
        backdrop = @video.attachments.new

        poster.get_image($img_poster_url,
                         "#{@video.title}.jpg",
                         video_details['poster_path'])

        backdrop.get_image($img_backdrop_url,
                           "#{@video.title}_backdrop.jpg",
                           video_details['backdrop_path'])

        poster.handle_uploaded_image("#{@video.title}.jpg")
        backdrop.handle_uploaded_image("#{@video.title}_backdrop.jpg")

        video_attachment.create_symlink('video')
        poster.create_symlink('image')
        backdrop.create_symlink('image')
      end
    end

    if params[:filename] && @video.save
      redirect '/'
    else
      @message = 'The following prevented the video from being saved:'
      erb :new, locals: {video: @video, params: params}
    end
  end

  get '/video/show/:id' do
    @video = Video.first(id: params[:id])
    @title = @video.get_title if @video

    if @video
      erb :show
    else
      redirect '/'
    end
  end

  get '/video/watch/:id' do
    video = Video.first(id: params[:id])
    if video
      @title = video.get_title
      @video = video.attachments.first(type: 'video')
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
