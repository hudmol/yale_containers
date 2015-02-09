class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/repositories/:repo_id/top_containers/search')
  .description("Search for yale containers")
  .params(["repo_id", :repo_id],
          *BASE_SEARCH_PARAMS)
  .permissions([:view_repository])
  .returns([200, "[(:top_container)]"]) \
  do

    [
      200,
      {'Content-Type' => 'application/json'},
      Enumerator.new do |y|
        TopContainer.search_stream(params.merge(:type => ['top_container']), params[:repo_id]) do |response|
          y << response.body
        end
      end
    ]

  end


  Endpoint.post('/repositories/:repo_id/top_containers/:id')
    .description("Update a yale container")
    .params(["id", :id],
            ["top_container", JSONModel(:top_container), "The updated record", :body => true],
            ["repo_id", :repo_id])
    .permissions([:manage_container])
    .returns([200, :updated]) \
  do
    handle_update(TopContainer, params[:id], params[:top_container])
  end


  Endpoint.post('/repositories/:repo_id/top_containers')
    .description("Create a yale container")
    .params(["top_container", JSONModel(:top_container), "The record to create", :body => true],
            ["repo_id", :repo_id])
    .permissions([:manage_container])
    .returns([200, :created]) \
  do
    handle_create(TopContainer, params[:top_container])
  end


  Endpoint.get('/repositories/:repo_id/top_containers')
    .description("Get a list of TopContainers for a Repository")
    .params(["repo_id", :repo_id])
    .paginated(true)
    .permissions([:view_repository])
    .returns([200, "[(:top_container)]"]) \
  do
    handle_listing(TopContainer, params)
  end


  Endpoint.get('/repositories/:repo_id/top_containers/:id')
    .description("Get a yale container by ID")
    .params(["id", :id],
            ["repo_id", :repo_id],
            ["resolve", :resolve])
    .permissions([:view_repository])
    .returns([200, "(:top_container)"]) \
  do
    json = TopContainer.to_jsonmodel(params[:id])

    json_response(resolve_references(json, params[:resolve]))
  end


  Endpoint.delete('/repositories/:repo_id/top_containers/:id')
    .description("Delete a yale container")
    .params(["id", :id],
            ["repo_id", :repo_id])
    .permissions([:manage_container])
    .returns([200, :deleted]) \
  do
    handle_delete(TopContainer, params[:id])
  end


  Endpoint.post('/repositories/:repo_id/top_containers/batch/ils_holding_id')
    .description("Update ild_holding_id for a batch of yale containers")
    .params(["ids", [Integer]],
            ["ils_holding_id", String, "Value to set for ils_holding_id"],
            ["repo_id", :repo_id])
    .permissions([:manage_container])
    .returns([200, :updated]) \
  do
    result = TopContainer.batch_update(params[:ids], :ils_holding_id => params[:ils_holding_id])
    json_response(result)
  end

end
