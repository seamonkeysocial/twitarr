# == Schema Information
#
# Table name: forums
#
#  id             :bigint           not null, primary key
#  last_post_time :datetime         not null
#  locked         :boolean          default(FALSE), not null
#  sticky         :boolean          default(FALSE), not null
#  subject        :string           not null
#
# Indexes
#
#  index_forums_on_sticky_and_last_post_time  (sticky,last_post_time)
#  index_forums_subject                       (to_tsvector('english'::regconfig, (subject)::text)) USING gin
#

class Forum < ApplicationRecord
  include Searchable

  PAGE_SIZE = 20
  FORUM_CACHE_TIME = 30.minutes

  has_many :posts, -> { order(:created_at) }, class_name: 'ForumPost', dependent: :destroy, inverse_of: :forum
  has_many :forum_view_timestamps, dependent: :destroy

  validates :subject, presence: true, length: { maximum: 200 }
  validate :validate_posts

  def self.base_query(current_user)
    if current_user
      Forum.includes(:forum_view_timestamps).where('forum_view_timestamps.user_id is null or forum_view_timestamps.user_id = ?', current_user.id).references(:forum_view_timestamps)
    else
      Forum.all
    end
  end

  def validate_posts
    errors[:base] << 'Must have a post' if posts.empty?
    posts.each do |post|
      post.errors.full_messages.each { |x| errors[:base] << x } unless post.valid?
    end
  end

  def subject=(subject)
    super subject&.strip
  end

  def last_post
    posts.includes(:user).order(:created_at).last
  end

  def update_cache
    Rails.cache.fetch("forum:last_post_author:#{id}", force: true, expires_in: Forum::FORUM_CACHE_TIME) do
      {
          username: last_post.user.username,
          display_name: last_post.user.display_name,
          last_photo_updated: last_post.user.last_photo_updated.to_ms
      }
    end
    Rails.cache.fetch("forum:post_count:#{id}", force: true, expires_in: Forum::FORUM_CACHE_TIME) do
      posts.count
    end

    self.last_post_time = last_post.created_at
    save
  end

  def last_post_author
    Rails.cache.fetch("forum:last_post_author:#{id}", expires_in: FORUM_CACHE_TIME) do
      {
          username: last_post.user.username,
          display_name: last_post.user.display_name,
          last_photo_updated: last_post.user.last_photo_updated.to_ms
      }
    end
  end

  def post_count
    Rails.cache.fetch("forum:post_count:#{id}", expires_in: FORUM_CACHE_TIME) do
      posts.count
    end
  end

  def post_count_since(timestamp)
    if timestamp
      posts.where('created_at > ?', timestamp).count
    else
      post_count
    end
  end

  def self.create_new_forum(author, subject, first_post_text, _photos, original_author)
    forum = Forum.new(subject: subject)
    forum.posts << ForumPost.new(author: author, text: first_post_text, original_author: original_author)
    forum.save if forum.valid?
    forum
  end

  def add_post(author, text, _photos, original_author)
    posts.create(author: author, text: text, original_author: original_author)
  end

  def self.view_mentions(params = {})
    query_string = params[:query]
    start_loc = params[:page] || 0
    limit = params[:limit] || 20
    queryParams = Hash.new
    queryParams[:mn] = query_string
    if params[:after]
      val = Time.from_param(params[:after])
      queryParams[:ts] = { '$gt' => val } if val
    end
    query = where(posts: { '$elemMatch' => queryParams }).order_by(id: :desc).skip(start_loc * limit).limit(limit)
  end

  def self.search(params = {})
    search_text = params[:query].strip.downcase.gsub(/[^\w&\s@-]/, '')
    criteria = Forum.or({ 'fp.au': /^#{search_text}.*/i }, '$text' => { '$search' => "\"#{search_text}\"" })
    limit_criteria(criteria, params)
  end
end
