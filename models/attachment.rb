class Attachment
  include DataMapper::Resource

  # creates association
  belongs_to :video

  # defines properties
  property :id,          Serial
  property :created_at,  DateTime
  property :extension,   String
  property :filename,    String
  property :mime_type,   String
  property :type,        String
  property :path,        Text
  property :updated_at,  DateTime

  validates_presence_of :extension, :filename, :mime_type, :path, :type

  def get_video_watch_path
    File.join("/media/video/#{self.filename}")
  end

  def create_symlink(media_type)
    FileUtils.symlink(self.path, File.join("public/media/#{media_type}", self.filename))
  end

  def get_image(base_url, filename, path)
    File.open(File.join(Dir.pwd, $image_path, filename), "w") do |f|
      f.write(open(File.join(base_url, path)).read)
    end
  end

  def handle_uploaded_image(filename)
    self.extension = 'jpg'
    self.mime_type = 'image/jpeg'
    self.type      = 'image'
    self.filename  = filename
    self.path      = File.join(Dir.pwd, '/media/image', filename)
  end

  def handle_uploaded_video(file)
    self.extension = File.extname(file[:filename]).sub(/^\./, '').downcase

    supported_mime_type = $config['file_properties']['supported_mime_types'].select do |type|
      type['extension'] == self.extension
    end.first

    return false unless supported_mime_type

    self.filename  = file[:filename].tr(" ", "_") # prevent errors caused by spaces in filename
    self.mime_type = file[:type]
    self.type      = 'video'
    self.path      = File.join(Dir.pwd, $config['file_properties'][supported_mime_type['type']]['absolute_path'], self.filename)

    File.open(path, 'wb') do |f|
      f.write(file[:tempfile].read)
    end
  end
end
