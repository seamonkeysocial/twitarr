class ForumDecorator < BaseDecorator
  delegate_all
  include ActionView::Helpers::TextHelper

  def to_meta_hash(current_user = nil, page_size = Forum::PAGE_SIZE)
    ret = {
        id: id.to_s,
        subject: subject,
        sticky: sticky,
        locked: locked,
        last_post_author: last_post_author,
        posts: post_count,
        timestamp: last_post_time.to_ms,
        last_post_page: 0
    }
    unless current_user.nil?
      count = post_count_since(forum_view_timestamps.first&.view_time)
      ret[:new_posts] = count if count > 0
      ret[:last_post_page] = (post_count - count) / page_size
    end
    ret
  end

  def to_hash(current_user = nil, options = {})
    last_view = forum_view_timestamps.first&.view_time

    ret = {
      id: id.to_s,
      subject: subject,
      sticky: sticky,
      locked: locked,
      post_count: post_count,
      posts: posts.map { |x| x.decorate.to_hash(locked, current_user, last_view, options) }
    }
    ret[:latest_read] = last_view&.to_ms unless current_user.nil?
    ret
  end

  def to_paginated_hash(page, page_size = Forum::PAGE_SIZE, current_user = nil, options = {})
    offset = page * page_size
    next_page = nil
    prev_page = nil

    next_page = page + 1 if posts.offset((page + 1) * page_size).limit(page_size).to_a.count != 0
    prev_page = page - 1 unless (offset - 1) < 0
    page_count = (posts.count.to_f / page_size).ceil

    last_view = forum_view_timestamps.first&.view_time

    ret = {
      id: id.to_s,
      subject: subject,
      sticky: sticky,
      locked: locked,
      next_page: next_page,
      prev_page: prev_page,
      page: page,
      page_count: page_count,
      post_count: post_count,
      posts: posts.limit(page_size).offset(offset).map { |x| x.decorate.to_hash(locked, current_user, last_view, options) }
    }
    ret[:latest_read] = last_view&.to_ms unless current_user.nil?
    ret
  end

end
