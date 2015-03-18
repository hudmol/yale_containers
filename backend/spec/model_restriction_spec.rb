require 'spec_helper'
require_relative 'factories'
require_relative 'container_spec_helper'


def add_restriction_to_record(record,
                              begin_date = '2000-01-01',
                              end_date = '2020-01-01',
                              local_access_restriction_type = ["RestrictedSpecColl", "RestrictedCurApprSpecColl",
                                                               "RestrictedFragileSpecColl", "InProcessSpecColl",
                                                               "ColdStorageBrbl"])
  record['notes'] << build(:json_note_multipart,
                           :type => 'accessrestrict',
                           :rights_restriction => {
                             :begin => begin_date,
                             :end => end_date,
                             :local_access_restriction_type => local_access_restriction_type
                           }).to_hash

  clz = Kernel.const_get(record.class.record_type.to_s.camelize)

  clz[record.id].update_from_json(record)
end



describe 'Yale container restrictions' do

  let (:box_json) { create(:json_top_container, :indicator => "1", :barcode => "123") }
  let (:box_record) { TopContainer[box_json.id] }


  it "can find all restrictions on a record linked directly to a top container" do
    (resource, grandparent, parent, child) = create_tree(box_json)

    add_restriction_to_record(child)

    box_record.restrictions.count.should eq(1)
  end

  it "can find active restrictions on a record linked directly to a top container" do
    (resource, grandparent, parent, child) = create_tree(box_json)
    add_restriction_to_record(child, '1990-01-01', '1995-01-01')

    box_record.active_restrictions(stub(:today => Date.parse('1993-01-01'))).count.should eq(1)
    box_record.active_restrictions(stub(:today => Date.parse('2000-01-01'))).count.should eq(0)
  end


  it "applies restrictions from further up the record tree (from an archival object)" do
    (resource, grandparent, parent, child) = create_tree(box_json)
    add_restriction_to_record(grandparent)
    box_record.restrictions.count.should eq(1)
  end


  it "applies restrictions from further up the record tree (from a resource)" do
    (resource, grandparent, parent, child) = create_tree(box_json)

    add_restriction_to_record(Resource.to_jsonmodel(resource.id))
    box_record.restrictions.count.should eq(1)
  end


  it "doesn't duplicate restrictions when the same container is linked twice" do
    (resource, grandparent, parent, child) = create_tree(box_json)

    resource_json = Resource.to_jsonmodel(resource.id)
    resource_json["instances"] = [build_instance(box_json).to_hash]
    resource.update_from_json(resource_json)

    add_restriction_to_record(Resource.to_jsonmodel(resource.id))
    box_record.restrictions.count.should eq(1)
  end


  it "returns information about restrictions in the jsonmodel" do
    (resource, grandparent, parent, child) = create_tree(box_json)
    add_restriction_to_record(grandparent)

    json = TopContainer.to_jsonmodel(box_record.id)

    restriction = json['active_restrictions'].first

    restriction['begin'].should eq('2000-01-01')
    restriction['end'].should eq('2020-01-01')
    restriction['local_access_restriction_type'].should eq(["RestrictedSpecColl", "RestrictedCurApprSpecColl",
                                                            "RestrictedFragileSpecColl", "InProcessSpecColl",
                                                            "ColdStorageBrbl"])
    restriction['linked_records']['ref'].should eq(grandparent.uri)
  end

end