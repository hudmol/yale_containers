Sequel.migration do

  up do

    create_table(:yale_container) do
      primary_key :id

      Integer :repo_id, :null => false

      Integer :lock_version, :default => 0, :null => false
      Integer :json_schema_version, :null => false

      Integer :parent_id, :null => true

      String :barcode
      String :voyager_id
      Integer :exported_to_voyager, :default => 0
      Integer :restricted, :default => 0

      DynamicEnum :type_id, :null => false
      String :indicator, :null => false

      apply_mtime_columns
    end

    alter_table(:yale_container) do
      add_foreign_key([:parent_id], :yale_container, :key => :id)
      add_unique_constraint([:repo_id, :barcode], :name => "yale_uniq_barcode")
    end


    create_table(:yale_container_instance_rlshp) do
      primary_key :id

      Integer :yale_container_id
      Integer :instance_id

      Integer :aspace_relationship_position

      apply_mtime_columns(false)
    end

    alter_table(:yale_container_instance_rlshp) do
      add_foreign_key([:yale_container_id], :yale_container, :key => :id)
      add_foreign_key([:instance_id], :instance, :key => :id)
    end


    create_table(:yale_container_housed_at_rlshp) do
      primary_key :id
      Integer :yale_container_id
      Integer :location_id
      Integer :aspace_relationship_position

      String :jsonmodel_type, :null => false, :default => 'container_location'

      String :status
      Date :start_date
      Date :end_date
      String :note

      apply_mtime_columns(false)
    end

    alter_table(:yale_container_housed_at_rlshp) do
      add_foreign_key([:yale_container_id], :yale_container, :key => :id)
      add_foreign_key([:location_id], :location, :key => :id)
    end

  end

  down do
  end

end
