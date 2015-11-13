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

# Global variable
$config = YAML.load_file(File.join(Dir.pwd, 'config.yml'))
$tmdb_key = YAML.load_file(File.join(Dir.pwd, 'keys.yml'))['the_movie_db']
$img_poster_url = "http://image.tmdb.org/t/p/w500"
$img_backdrop_url = "http://image.tmdb.org/t/p/w780"
$image_path = "/media/image"

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

  # Move save file to a different method. Check if both files are valid mime_type before saving
  video_attachment.handle_uploaded_video(params['video-file'])

  if !video_attachment.path.nil?

    # Get video file metadata
    video_metadata = FFMPEG::Movie.new(video.attachments.first(mime_type: 'video/mp4').path)
    video.duration = (video_metadata.duration / 60).round
    video.size = video_metadata.size
    video.frame_rate = (video_metadata.frame_rate).round
    video.bitrate = video_metadata.bitrate

    # Get video details
    video.title = video.title.delete("'") # api doesn't like <'>
    video_details = Tmdb::Search.movie(video.title, page: 1)['results'][0]
    video.title = video.title.tr(" ", "_")
    video.release_date = video_details['release_date'][0..3]
    video.rating = video_details['vote_average'].round
    video.description = video_details['overview']

    poster = video.attachments.new
    backdrop = video.attachments.new

    # Get video poster
    File.open(File.join(Dir.pwd, $image_path, "#{video.title}.jpg"), "w") do |f|
  		f.write(open(File.join($img_poster_url, video_details['poster_path'])).read)
  	end

    # Get video background
    File.open(File.join(Dir.pwd, $image_path, "#{video.title}_backdrop.jpg"), "w") do |f|
  		f.write(open(File.join($img_backdrop_url, video_details['backdrop_path'])).read)
  	end

    # Poster
    poster.handle_uploaded_image
    poster.filename  = "#{video.title}.jpg"
    poster.path      = File.join(Dir.pwd, '/media/image', "#{video.title}.jpg")

    # Backdrop
    backdrop.handle_uploaded_image
    backdrop.filename  = "#{video.title}_backdrop.jpg"
    backdrop.path      = File.join(Dir.pwd, '/media/image', "#{video.title}_backdrop.jpg")

    # Create symlinks
    video_attachment.create_symlink("video")
    poster.create_symlink("image")
    backdrop.create_symlink("image")

    if video.save
      @message = 'Video was uploaded'
    else
      @message = 'Video was not uploaded'
    end
  else
    @message = 'Video was not uploaded'
  end

  # Renders the view
  erb :create
end

get '/video/new' do
  @title = 'Upload Video'
  erb :new
end

get '/video/show/:id' do
  @video = Video.first(id: params[:id])
  @title = @video.title

  if @video
    erb :show
  else
    redirect '/video/list'
  end
end

get '/video/watch/:id' do
  video = Video.first(id: params[:id])
  @title = "#{video.title}"
  @video = video.attachments.first(:extension.not => 'jpg') # needs to use =>

  if @video
    erb :watch
  else
    redirect "/video/show/#{video.id}"
  end
end

class Video
  include DataMapper::Resource # includes the database connection

  # creates a has many relationship with attachments
  has n, :attachments

  # defines video attributes
  property :id,           Serial
  property :description,  Text
  property :duration,     Integer
  property :size,         Integer
  property :frame_rate,   Integer
  property :bitrate,      Integer
  property :rating,       Integer
  property :genre,        String
  property :title,        String
  property :release_date, String
  property :updated_at,   DateTime
  property :created_at,   DateTime

  def get_video_show_path
    File.join("/video/show/#{self.id}")
  end

  def get_poster_path
    File.join('/media/image',
      self.attachments.first(filename: "#{self.title}.jpg").filename)
  end

  def get_backdrop_path
    File.join('/media/image',
      self.attachments.first(filename: "#{self.title}_backdrop.jpg").filename)
  end
end

class Attachment
  include DataMapper::Resource # includes the database connection

  belongs_to :video

  property :id,          Serial
  property :created_at,  DateTime
  property :extension,   String
  property :filename,    String
  property :mime_type,   String
  property :path,        Text
  property :updated_at,  DateTime

  def handle_uploaded_image
    self.extension = 'jpg'
    self.mime_type = 'image/jpeg'
  end

  def handle_uploaded_video(file)
    self.extension = File.extname(file[:filename]).sub(/^\./, '').downcase

    supported_mime_type = $config['file_properties']['supported_mime_types'].select do |type|
      type['extension'] == self.extension
    end.first

    return false unless supported_mime_type

    self.filename  = file[:filename].tr(" ", "_") # prevent errors caused by spaces in filename
    self.mime_type = file[:type]
    self.path      = File.join(Dir.pwd, $config['file_properties'][supported_mime_type['type']]['absolute_path'], self.filename)

    File.open(path, 'wb') do |f|
      f.write(file[:tempfile].read)
    end
  end

  def get_video_watch_path
    File.join("/media/video/#{self.filename}")
  end

  def create_symlink(media_type)
    FileUtils.symlink(self.path, File.join("public/media/#{media_type}", self.filename))
  end
end

# basically takes our classes and properties and creates database tables
configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end
