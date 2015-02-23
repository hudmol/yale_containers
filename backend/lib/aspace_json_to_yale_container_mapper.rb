class AspaceJsonToYaleContainerMapper

  def initialize(json)
    @json = json
  end


  def call
    @json['instances'].each do |instance|

      if instance['sub_container']
        # Just need to make sure there are no conflicting ArchivesSpace containers
        instance.delete('container')
        next
      end

      top_container = get_or_create_top_container(instance)

      instance['sub_container'] = {
        'top_container' => {'ref' => top_container.uri}
      }
    end
  end


  private

  def get_or_create_top_container(instance)
    container = instance['container']

    result = (try_matching_barcode(container) ||
              try_matching_indicator_within_series(container))

    if result
      result
    else
      p "UNHANDLED MAPPING - generating new container"
      p ({:instance => instance, :record => @json})
      TopContainer.create_from_json(JSONModel(:top_container).from_hash('barcode' => SecureRandom.hex, 'indicator' => (rand() * 10000).to_i.to_s))
    end

  end


  def get_default_indicator
    if AppConfig.has_key?(:yale_containers_default_indicator)
      AppConfig[:yale_containers_default_indicator]
    else
      '1'
    end
  end


  def try_matching_barcode(container)
    # If we have a barcode, attempt to locate an existing top container
    barcode = container['barcode_1']

    if barcode
      if (top_container = TopContainer[:barcode => barcode])
        top_container
      else
        indicator = container['indicator_1'] || get_default_indicator
        TopContainer.create_from_json(JSONModel(:top_container).from_hash('barcode' => barcode, 'indicator' => indicator))
      end
    else
      nil
    end
  end


  def try_matching_indicator_within_series(container)
    indicator = container['indicator_1']

    if indicator && @json['parent'] && @json.is_a?(JSONModel(:archival_object))

      parent_ao = ArchivalObject[JSONModel(:archival_object).id_for(@json['parent']['ref'])]
      series = parent_ao.series

      series_object_graph = series.object_graph

      top_container_link_rlshp = SubContainer.find_relationship(:top_container_link)
      relationship_ids = series_object_graph.ids_for(top_container_link_rlshp)

      DB.open do |db|
        top_container_ids = db[:top_container_link_rlshp].filter(:id => relationship_ids).select(:top_container_id)
        TopContainer[:indicator => indicator, :id => top_container_ids]
      end

    else
      nil
    end
  end

end