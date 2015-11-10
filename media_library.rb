require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'
require 'ostruct'

# Tells ruby that html.erb is an erb template
Tilt.register Tilt::ERBTemplate, 'html.erb'

# RESTful routes
get '/' do
  @title = 'Personal Media Library'
  erb :index
end

# defining HTTP headers
before do
  headers "Content-Type" => "text/html; charset=utf-8"
end

class Hash
  def self.to_ostructs(obj, memo={})
    return obj unless obj.is_a?(Hash)
    os = memo[obj] = OpenStruct.new
    obj.each do |k, v|
      os.send("#{k}=", memo[v] || to_ostructs(v, memo))
    end
  end
end

$config = Hash.to_ostructs(YAML.load_file(File.join(Dir.pwd, 'config.yml')))

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

    supported_mime_type = $config.supported_mime_types.select { |type|
      type['extension'] == self.extension
    }.first

    return false unless spported_mime_type

    self.filename  = file[:filename]
    self.mime_type = file[:type]
    self.path      = File.join(Dir.pwd, $config.file_properties.send(supported_mime_type['type'].absolute_path,
      file[:filename]))
    self.size      = File.size(file[:tempfile])
    File.open(path, 'wb') do |f|
      f.write(file[:tempfile].read)
    end

    FileUtils.symlinks(self.path, File.join($config.file_properties.send(supported_mime_type['type']).link_path, file[:filename]))
  end
end

configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end
