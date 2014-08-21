require 'spec_helper'
@@last_pid = 0

describe ActiveFedora::Base do
  it_behaves_like "An ActiveModel"

  describe 'rdf' do
    it "should have a graph" do
      puts subject.resource.dump(:ttl)
      puts subject.datastream_assertions
    end
  end
  describe 'descendants' do
    it "should record the decendants" do
      expect(ActiveFedora::Base.descendants).to include(ModsArticle, SpecialThing)
    end
  end

  describe "reindex_everything" do
    it "should call update_index on every object represented in the sitemap" do
      allow(ActiveFedora::Base).to receive(:urls_from_sitemap_index) { ['http://localhost/test/XXX', 'http://localhost/test/YYY', 'http://localhost/test/ZZZ'] }
      mock_update = double(:mock_obj)
      expect(mock_update).to receive(:update_index).exactly(3).times
      expect(ActiveFedora::Base).to receive(:find).with(instance_of Ldp::Resource::RdfSource ).and_return(mock_update).exactly(3).times
      ActiveFedora::Base.reindex_everything
    end
  end

  describe "urls_from_sitemap_index" do
    before { @obj = ActiveFedora::Base.create }
    after { @obj.destroy }
    it "should return a list of all the ids in all the sitemaps in the sitemap index" do
      expect(ActiveFedora::Base.urls_from_sitemap_index).to include(@obj.uri)
    end
  end

  describe "With a test class" do
    before :each do
      class FooHistory < ActiveFedora::Base
        has_metadata 'someData', type: ActiveFedora::SimpleDatastream, autocreate: true do |m|
          m.field "fubar", :string
          m.field "swank", :text
        end
        has_metadata "withText", type: ActiveFedora::SimpleDatastream, autocreate: true do |m|
          m.field "fubar", :text
        end
        has_metadata "withText2", type: ActiveFedora::SimpleDatastream, autocreate: true do |m|
          m.field "fubar", :text
        end
        has_attributes :fubar, datastream: 'withText', multiple: true
        has_attributes :swank, datastream: 'someData', multiple: true
      end

      class FooAdaptation < ActiveFedora::Base
        has_metadata 'someData', type: ActiveFedora::OmDatastream
      end

      class FooInherited < FooHistory

      end
    end

    after :each do
      Object.send(:remove_const, :FooHistory)
      Object.send(:remove_const, :FooAdaptation)
      Object.send(:remove_const, :FooInherited)
    end

    def increment_pid
      @@last_pid += 1
    end

    before do
      @this_pid = increment_pid.to_s
      @test_object = ActiveFedora::Base.new
      allow(@test_object).to receive(:assign_pid).and_return(@this_pid)
    end


    describe '#new' do
      before do
        allow_any_instance_of(FooHistory).to receive(:assign_pid).and_return(@this_pid)
      end
      context "with no arguments" do
        it "should not get a pid on init" do
          expect(FooHistory.new.pid).to be_nil
        end
      end

      context "with a pid argument" do
        it "should be able to create with a custom pid" do
          expect(FooHistory).to receive(:id_to_uri).and_call_original
          f = FooHistory.new('baz_1')
          expect(f.id).to eq 'baz_1'
          expect(f.pid).to eq 'baz_1'
        end
      end

      context "with a hash argument" do
        context "that has a pid" do
          it "should be able to create with a custom pid" do
            expect(FooHistory).to receive(:id_to_uri).and_call_original
            f = FooHistory.new(pid: 'baz_1')
            expect(f.id).to eq 'baz_1'
            expect(f.pid).to eq 'baz_1'
          end
        end

        context "that doesn't have a pid" do
          it "should be able to create with a custom pid" do
            f = FooHistory.new(fubar: ['baz_1'])
            expect(f.id).to be_nil
          end
        end
      end
    end

    describe ".datastream_class_for_name" do
      it "should return the specifed class" do
        expect(FooAdaptation.datastream_class_for_name('someData')).to eq ActiveFedora::OmDatastream
      end
      it "should return the specifed class" do
        expect(FooAdaptation.datastream_class_for_name('content')).to eq ActiveFedora::Datastream
      end
    end

    ### Methods for ActiveModel::Conversions
    context "before saving" do
      context "#to_param" do
        subject { @test_object.to_param }
        it { should be_nil }
      end
      context "#to_key" do
        subject { @test_object.to_key }
        it { should be_nil }
      end
    end

    context "when its saved" do
      before do
        allow(@test_object).to receive(:new_record?).and_return(false)
        allow(@test_object).to receive(:uri).and_return('http://localhost:8983/fedora/rest/test/one/two/three')
      end

      context "#to_param" do
        subject { @test_object.to_param }
        it { should eq 'one/two/three' }
      end

      context "#to_key" do
        subject { @test_object.to_key }
        it { should eq ['one/two/three'] }
      end
    end
    ### end ActiveModel::Conversions

    ### Methods for ActiveModel::Naming
    it "Should know the model_name" do
      expect(FooHistory.model_name).to eq 'FooHistory'
      expect(FooHistory.model_name.human).to eq 'Foo history'
    end
    ### End ActiveModel::Naming


    describe ".datastreams" do
      let(:test_history) { FooHistory.new }
      it "should create accessors for datastreams declared with has_metadata" do
        expect(test_history.withText).to eq test_history.datastreams['withText']
      end
      describe "dynamic accessors" do
        before do
          test_history.add_datastream(ds)
          test_history.class.build_datastream_accessor(ds.dsid)
        end
        describe "when the datastream is named with dash" do
          let(:ds) {double('datastream', :dsid=>'eac-cpf')}
          it "should convert dashes to underscores" do
            expect(test_history.eac_cpf).to eq ds
          end
        end
        describe "when the datastream is named with underscore" do
          let (:ds) { double('datastream', :dsid=>'foo_bar') }
          it "should preserve the underscore" do
            expect(test_history.foo_bar).to eq ds
          end
        end
      end
    end

    it 'should provide #find' do
      expect(ActiveFedora::Base).to respond_to(:find)
    end

    it "should provide .create_date" do
      expect(@test_object).to respond_to(:create_date)
    end

    it "should provide .modified_date" do
      expect(@test_object).to respond_to(:modified_date)
    end

    describe '.save' do
      it "should create a new record" do
        allow(@test_object).to receive(:new_record?).and_return(true)
        expect(@test_object).to receive(:serialize_datastreams)
        expect(@test_object).to receive(:assign_rdf_subject)
        expect(@test_object.orm).to receive(:create)
        expect(@test_object).to receive(:update_index)
        @test_object.save
      end

      context "on an existing record" do
        let(:stub_source) { double('RdfSource') }

        it "should update" do
          allow(@test_object).to receive(:new_record?).and_return(false)
          expect(@test_object).to receive(:serialize_datastreams)
          expect(Ldp::Resource::RdfSource).to receive(:new).and_return(stub_source)
          expect(stub_source).to receive(:update)
          expect(@test_object).to receive(:update_modified_date)
          expect(@test_object).to receive(:update_index)
          @test_object.save
        end
      end

      context "when assign pid returns a value" do
        context "an no pid has been set" do

          it "should set the pid" do
            @test_object.save
            expect(@test_object.pid).to eq @this_pid
          end

          context "and the object has properties" do
            let(:test_object) { WithProperty.new(title: 'foo') }
            before do
              class WithProperty < ActiveFedora::Base
                property :title, predicate: RDF::DC.title
              end
              allow(test_object).to receive(:assign_pid).and_return(@this_pid)
              test_object.save
            end
            after do
              Object.send(:remove_const, :WithProperty)
            end

            it "should update the resource" do
              expect(test_object.resource.rdf_subject).to eq RDF::URI.new("#{ActiveFedora.fedora.host}#{ActiveFedora.fedora.base_path}/#{@this_pid}")
              expect(test_object.title).to eq ['foo']
            end
          end
        end

        context "when a pid is set" do
          before do
            @test_object = ActiveFedora::Base.new(pid: '999')
            allow(@test_object).to receive(:assign_pid).and_return(@this_pid)
          end
          it "should not set the pid" do
            @test_object.save
            expect(@test_object.pid).to eq '999'
          end
        end
      end
    end

    describe "#create" do
      it "should build a new record and save it" do
        obj = double()
        expect(obj).to receive(:save)
        expect(FooHistory).to receive(:new).and_return(obj)
        @hist = FooHistory.create(fubar: 'ta', swank: 'da')
      end
    end

    describe ".to_solr" do
      it "should provide .to_solr" do
        expect(@test_object).to respond_to(:to_solr)
      end

      it "should add pid, system_create_date, system_modified_date from object attributes" do
        expect(@test_object).to receive(:create_date).and_return(["2012-03-04T03:12:02Z"]).twice
        expect(@test_object).to receive(:modified_date).and_return(["2012-03-07T03:12:02Z"]).twice
        allow(@test_object).to receive(:pid).and_return('changeme:123')
        solr_doc = @test_object.to_solr
        expect(solr_doc[ActiveFedora::SolrService.solr_name("system_create", :stored_sortable, type: :date)]).to eql("2012-03-04T03:12:02Z")
        expect(solr_doc[ActiveFedora::SolrService.solr_name("system_modified", :stored_sortable, type: :date)]).to eql("2012-03-07T03:12:02Z")
        expect(solr_doc[:id]).to eql("changeme:123")
      end

      it "should add self.class as the :active_fedora_model" do
        @test_history = FooHistory.new()
        solr_doc = @test_history.to_solr
        expect(solr_doc[ActiveFedora::SolrService.solr_name("active_fedora_model", :stored_sortable)]).to eql("FooHistory")
      end

      it "should call .to_solr on all datastreams, passing the resulting document to solr" do
        mock1 = double("ds1")
        expect(mock1).to receive(:to_solr).and_return({})
        mock2 = double("ds2")
        expect(mock2).to receive(:to_solr).and_return({})

        allow(@test_object).to receive(:datastreams).and_return(ds1: mock1, ds2: mock2)
        expect(@test_object).to receive(:solrize_relationships)
        @test_object.to_solr
      end
    end

    describe "update_attributes" do
      it "should set the attributes and save" do
        m = FooHistory.new
        att= {"fubar"=> '1234', "baz" =>'stuff'}

        expect(m).to receive(:fubar=).with('1234')
        expect(m).to receive(:baz=).with('stuff')
        expect(m).to receive(:save)
        m.update_attributes(att)
      end
    end

    describe "update" do
      it "should set the attributes and save" do
        m = FooHistory.new
        att= {"fubar"=> '1234', "baz" =>'stuff'}

        expect(m).to receive(:fubar=).with('1234')
        expect(m).to receive(:baz=).with('stuff')
        expect(m).to receive(:save)
        m.update(att)
      end
    end

    describe ".solrize_relationships" do
      let(:person_reflection) { double('person', foreign_key: 'person_id', options: {property: :is_member_of}, kind_of?: true) }
      let(:location_reflection) { double('location', foreign_key: 'location_id', options: {property: :is_part_of}, kind_of?: true) }
      let(:reflections) { { 'person' => person_reflection, 'location' => location_reflection } }

      it "should serialize the relationships into a Hash" do

        expect(@test_object).to receive(:[]).with('person_id').and_return('info:fedora/demo:10')
        expect(@test_object).to receive(:[]).with('location_id').and_return('info:fedora/demo:11')
        expect(@test_object.class).to receive(:reflections).and_return(reflections)
        solr_doc = @test_object.solrize_relationships
        expect(solr_doc[ActiveFedora::SolrService.solr_name("is_member_of", :symbol)]).to eq "info:fedora/demo:10"
        expect(solr_doc[ActiveFedora::SolrService.solr_name("is_part_of", :symbol)]).to eq "info:fedora/demo:11"
      end
    end
  end
end
