class Video
  include DataMapper::Resource # includes the database connection

  # creates association
  has n, :attachments

  # defines video attributes
  property :id,           Serial
  property :description,  Text
  property :duration,     Integer
  property :size,         Integer
  property :frame_rate,   Integer
  property :bitrate,      Integer
  property :rating,       Integer
  property :genre,        String, length: 1..50, :format => /\A[\w\s,]+\z/
  property :title,        String, length: 1..50, :format => /\A[\s\w'.,]+\z/
  property :release_date, String
  property :updated_at,   DateTime
  property :created_at,   DateTime

  validates_presence_of :genre, :title

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

  def get_title
    self.title.tr('_', ' ')
  end

  def get_metadata
    video_metadata = FFMPEG::Movie.new(self.attachments.first(type: 'video').path)
    self.duration = (video_metadata.duration / 60).round
    self.size = video_metadata.size
    self.frame_rate = (video_metadata.frame_rate).round
    self.bitrate = video_metadata.bitrate
  end

  def get_video_details(video_details)
    return false if video_details.blank?

    self.title = self.title.tr(" ", "_")
    self.release_date = video_details['release_date'][0..3]
    self.rating = video_details['vote_average'].round
    self.description = video_details['overview']
    true
  end
end
