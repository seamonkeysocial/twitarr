module Postable
  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
  end

  module InstanceMethods
    include Twitter::TwitterText::Extractor

    def location=(loc)
      location_id = loc
    end

    # noinspection RubyResolve
    def parse_hash_tags
      entities = extract_entities_with_indices text
      # self.hash_tags = []
      self.mentions = []
      entities.each do |entity|
        entity = entity.inject({}) { |x, (k, v)| x[k.to_sym] = v; x }
        if entity.key? :hashtag
          hash_tags << entity[:hashtag].downcase
        elsif entity.key? :screen_name
          mentions << entity[:screen_name].downcase
        end
      end
    end

    def post_create_operations
      # record_hashtags
    end

    def record_hashtags
      hash_tags.each do |ht|
        Hashtag.add_tag ht
      end
    end

    def validate_location
      post_location = self[:location]
      result = Location.valid_location? post_location
      errors[:base] << "Invalid location: #{post_location}" unless result
      result
    end

    def add_reaction(user_id, reaction_id)
      doc = post_reactions.find_or_create_by(user_id: user_id, reaction_id: reaction_id)
    end

    def remove_reaction(user_id, reaction_id)
      doc = post_reactions.find_by(user_id: user_id, reaction_id: reaction_id)
      doc.destroy && return if doc

      logger.info "Could not find reaction to remove. UserID: #{user_id}, ReactionID: #{reaction_id}"
    end
  end

  module ClassMethods
    def view_mentions(params = {})
      query_string = params[:query]
      start_loc = params[:page] || 0
      limit = params[:limit] || 20
      query = if params[:mentions_only]
                where('mentions @> ?', "{#{query_string}}")
              else
                where('mentions @> ?', "{#{query_string}}").or(where(author: query_string))
              end
      if params[:after]
        val = Time.from_param(params[:after])
        query = query.where(:timestamp.gt => val) if val
      end
      query.order(id: :desc).offset(start_loc * limit).limit(limit)
    end

    def view_hashtags(params = {})
      query_string = params[:query]
      start_loc = params[:page] || 0
      limit = params[:limit] || 20
      query = where(hash_tags: query_string)
      if params[:after]
        val = Time.from_param(params[:after])
        query = query.where(:timestamp.gt => params[:after]) if val
      end
      query.order_by(id: :desc).skip(start_loc * limit).limit(limit)
    end
  end
end
