require 'uri'
require 'net/http'

class TopContainer < Sequel::Model(:top_container)
  include ASModel

  include Relationships

  corresponds_to JSONModel(:top_container)

  set_model_scope :repository


  def validate
    validates_unique([:repo_id, :barcode],
                     :message => "A barcode must be unique within a repository")
    map_validation_to_json_property([:repo_id, :barcode], :barcode)

    check = BarcodeCheck.new(Repository[self.class.active_repository].repo_code)

    if !check.valid?(self[:barcode])
      errors.add(:barcode, "Length must be within the range set in configuration")
    end

    super
  end


  def delete
    DB.attempt {
      super
    }.and_if_constraint_fails {
      raise ConflictException.new("Top container in use")
    }

  end


  def format_barcode
    if self.barcode
      "[#{self.barcode}]"
    end
  end


  # For Archival Objects, the series is the topmost record in the tree.
  def tree_top(obj)
    if obj.respond_to?(:series)
      obj.series
    else
      nil
    end
  end


  # return all archival records linked to this top container
  def linked_archival_records
    related_records(:top_container_link).map {|subcontainer|
      linked_archival_record_for(subcontainer)
    }.compact.uniq {|obj| obj.uri}
  end


  def linked_archival_record_for(subcontainer)
    # Find its linked instance
    instance = Instance[subcontainer.instance_id]

    return nil unless instance

    # Find the record that links to that instance
    ASModel.all_models.each do |model|
      next unless model.associations.include?(:instance)

      association = model.association_reflection(:instance)

      key = association[:key]

      if instance[key]
        return model[instance[key]]
      end
    end
  end


  def collections
    linked_archival_records.map {|obj|
      if obj.respond_to?(:series)
        obj.class.root_model[obj.root_record_id]
      else
        obj
      end
    }.uniq {|obj| obj.uri}
  end


  def series
    linked_archival_records.map {|record| tree_top(record)}.compact.uniq {|obj| obj.uri}
  end


  def self.find_title_for(series)
    series.respond_to?(:display_string) ? series.display_string : series.title
  end


  def level_display_string(series)
    series.other_level || I18n.t("enumerations.archival_record_level.#{series.level}", series.level)
  end

  def series_label
    attached_series = self.series
    if attached_series.empty?
      nil
    else
      attached_series.map {|s| "#{level_display_string(s)} #{s.component_id}" }.join("; ")
    end
  end


  def display_string
    ["Container", "#{indicator}:", series_label, format_barcode].compact.join(" ")
  end


  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    jsons.zip(objs).each do |json, obj|
      json['display_string'] = obj.display_string

      obj.series.each do |series|
        json['series'] ||= []
        json['series'] << {
          'ref' => series.uri,
          'identifier' => series.component_id,
          'display_string' => find_title_for(series),
          'level_display_string' => obj.level_display_string(series)
        }
      end

      obj.collections.each do |collection|
        json['collection'] ||= []
        json['collection'] << {
          'ref' => collection.uri,
          'identifier' => Identifiers.format(Identifiers.parse(collection.identifier)),
          'display_string' => find_title_for(collection)
        }
      end

      if json['exported_to_ils']
        json['exported_to_ils'] = json['exported_to_ils'].getlocal.iso8601
      end

    end

    jsons
  end


  define_relationship(:name => :top_container_housed_at,
                      :json_property => 'container_locations',
                      :contains_references_to_types => proc {[Location]},
                      :class_callback => proc { |clz|
                        clz.instance_eval do
                          plugin :validation_helpers

                          define_method(:validate) do
                            if self[:status] === "previous" && !Location[self[:location_id]].temporary
                              errors.add("container_locations/#{self[:aspace_relationship_position]}/status",
                                         "cannot be previous if Location is not temporary")
                            end

                            super
                          end

                        end
                      })

  define_relationship(:name => :top_container_profile,
                      :json_property => 'container_profile',
                      :contains_references_to_types => proc {[ContainerProfile]},
                      :is_array => false)

  define_relationship(:name => :top_container_link,
                      :contains_references_to_types => proc {[SubContainer]},
                      :is_array => true)


  # Only allow delete if the top containers aren't linked to subcontainers.
  def self.handle_delete(ids)
    linked_subcontainers = find_relationship(:top_container_link).find_by_participant_ids(TopContainer, ids)

    if !linked_subcontainers.empty?
      raise ConflictException.new("Can't remove a Top Container that is still in use")
    end

    super
  end


  def self.search_stream(params, repo_id, &block)
    query = if params[:q]
              Solr::Query.create_keyword_search(params[:q])
            else
              Solr::Query.create_match_all_query
            end


    max_results = AppConfig.has_key?(:max_top_container_results) ? AppConfig[:max_top_container_results] : 10000

    query.pagination(1, max_results).
      set_repo_id(repo_id).
      set_record_types(params[:type]).
      set_filter_terms(params[:filter_term]).
      set_facets(params[:facet])


    query.add_solr_param(:qf, "series_identifier_u_stext collection_identifier_u_stext")

    url = query.to_solr_url
    req = Net::HTTP::Get.new(url.request_uri)

    Net::HTTP.start(url.host, url.port) do |http|
      http.request(req, nil) do |response|
        if response.code =~ /^4/
          raise response.body
        end

        block.call(response)
      end
    end
  end


  def self.batch_update(ids, fields)
    out = {}
    begin
      n = self.filter(:id => ids).update(fields.merge({:system_mtime => Time.now, :user_mtime => Time.now}))
      out[:records_updated] = n
    rescue
      out[:error] = $!
    end
    out
  end

end
