require 'spec_helper'

describe "delegating attributes" do
  before :all do
    class PropertiesDatastream < ActiveFedora::OmDatastream
      set_terminology do |t|
        t.root(path: "fields")
        t.depositor index_as: [:symbol, :stored_searchable]
        t.wrangler index_as: [:facetable]
      end
    end
    class TitledObject < ActiveFedora::Base
      has_metadata 'foo', type: ActiveFedora::SimpleDatastream do |m|
        m.field "title", :string
      end
      has_attributes :title, datastream: 'foo', multiple: false
    end
    class RdfObject < ActiveFedora::Base
      contains 'foo', class_name: 'PropertiesDatastream'
      has_attributes :depositor, datastream: :foo, multiple: false
      has_attributes :wrangler, datastream: :foo, multiple: true
      property :resource_type, predicate: ::RDF::DC.type do |index|
        index.as :stored_searchable, :facetable
      end
    end
  end
  after :all do
    Object.send(:remove_const, :TitledObject)
    Object.send(:remove_const, :RdfObject)
    Object.send(:remove_const, :PropertiesDatastream)
  end

  context "with a simple datastream" do
    describe "save" do
      subject do
        obj = TitledObject.create
        obj.title = "Hydra for Dummies"
        obj.save
        obj
      end
      it "should keep a list of changes after a successful save" do
        expect(subject.previous_changes).to_not be_empty
        expect(subject.previous_changes.keys).to include("title")
      end
      it "should clean out changes" do
        expect(subject).to_not be_title_changed
        expect(subject.changes).to be_empty
      end
    end
  end

  context "with multiple datastreams" do

    subject { RdfObject.create }

    describe "getting attributes" do

      before do
        subject.depositor = "foo"
        subject.resource_type = "bar"
        subject.save
      end

      specify "using strings for keys" do
        expect(subject["depositor"]).to eql("foo")
        expect(subject["resource_type"]).to eql(["bar"])
      end
      specify "using symbols for keys" do
        expect(subject[:depositor]).to eql("foo")
        expect(subject[:resource_type]).to eql(["bar"])
      end

    end

    describe "setting attributes" do

      specify "using strings for keys" do
        subject["depositor"] = "foo"
        subject["resource_type"] = "bar"
        subject.save
        expect(subject.depositor).to eql("foo")
        expect(subject.resource_type).to eql(["bar"])
      end
      specify "using symbols for keys" do
        subject[:depositor] = "foo"
        subject[:resource_type] = "bar"
        subject.save
        expect(subject.depositor).to eql("foo")
        expect(subject.resource_type).to eql(["bar"])
      end

      # TODO: bug logged in issue #540
      describe "using shift", pending: "has_changed? not returning true" do
        specify "with rdf properties" do
          subject.resource_type << "bar"
          subject.save
          expect(subject.resource_type).to eql(["bar"])
        end
        specify "with om terms" do
          subject.wrangler << "bar"
          subject.save
          expect(subject.wrangler).to eql(["bar"])
        end
      end
          
    end

  end
end

