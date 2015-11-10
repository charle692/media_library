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

  image_attachment.handle_uploaded_file(params['image-file'])
  video_attachment.handle_uploaded_file(params['video-file'])

  if video.save
    @message = 'Video was uploaded successfully'
  else
    @message = 'Video was not uploaded'
  end

  erb :create
end

get '/video/new' do
  @title = 'Upload Video'
  erb :new
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
end

configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end
