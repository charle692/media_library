require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'
require 'ostruct'
require 'pry'
require 'ruby-filemagic'
require 'pry-byebug'

# Global variable
$config = YAML.load_file(File.join(Dir.pwd, 'config.yml'))

# Tells ruby that html.erb is an erb template
Tilt.register Tilt::ERBTemplate, 'html.erb'

# RESTful routes
get '/' do
  @title = 'Personal Media Library'
  erb :index
end

post '/video/create' do
  video = Video.new(params[:video])
  image_attachment = video.attachments.new
  video_attachment = video.attachments.new

  # Move save file to a different method. Check if both files are valid mime_type before saving
  image_attachment.handle_uploaded_file(params['image-file'])
  video_attachment.handle_uploaded_file(params['video-file'])

  if !image_attachment.path.nil? && !video_attachment.path.nil?
    if video.save
      @message = 'Video was uploaded'
    else
      @message = 'Video was uploaded'
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

get '/video/list' do
  @title = 'Available Videos'
  @videos = Video.all(order: [:title.desc])

  erb :videos
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
  @video = video.attachments.last

  if @video
    erb :watch
  else
    redirect "/video/show/#{video.id}"
  end
end

# defining HTTP headers
before do
  headers "Content-Type" => "text/html; charset=utf-8"
end

# Connects to the database
configure do
  DataMapper::setup(:default, File.join('sqlite://', Dir.pwd, 'development.db'))
end

class Video
  include DataMapper::Resource # includes the database connection

  # creates a has many relationship with attachments
  has n, :attachments

  # defines video attributes
  property :id,   Serial
  property :created_at,   DateTime
  property :description,  Text
  property :genre,        String
  property :length,       Integer
  property :title,        String
  property :updated_at,   DateTime

  def get_video_show_path
    File.join("/video/show/#{self.id}")
  end

  def get_poster_path
    File.join("/media/image/#{self.attachments.first(mime_type: 'image/jpeg').filename}")
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
  property :size,        Integer
  property :updated_at,  DateTime

  def handle_uploaded_file(file)
    self.extension = File.extname(file[:filename]).sub(/^\./, '').downcase

    supported_mime_type = $config['file_properties']['supported_mime_types'].select do |type|
      type['extension'] == self.extension
    end.first

    return false unless supported_mime_type

    self.filename  = file[:filename]
    self.mime_type = file[:type]
    self.path      = File.join(Dir.pwd, $config['file_properties'][supported_mime_type['type']]['absolute_path'], file[:filename])
    self.size      = File.size(file[:tempfile])

    File.open(path, 'wb') do |f|
      f.write(file[:tempfile].read)
    end

    FileUtils.symlink(self.path, File.join($config['file_properties'][supported_mime_type['type']]['link_path'], file[:filename]))
  end

  def get_video_watch_path
    File.join("/media/video/#{self.filename}")
  end
end

# basically takes our classes and properties and creates database tables
configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end
