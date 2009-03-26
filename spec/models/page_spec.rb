require File.dirname(__FILE__) + '/../spec_helper'

describe Page do
  dataset :pages
  
  it "should be valid" do
    @page = Page.new(page_params)
    @page.should be_valid
  end
  
  it "should have one version when first created" do
    @page = Page.new(page_params)
    @page.save
    @page.should have(1).versions
  end
  
  it "should instantiate an instance including parts uniformly" do
    @page = pages(:first)
    @page.parts = [{"name"=>"body", "filter_id"=>"", "content"=>"I changed the body!"}]
    @page.save
    
    @page.current.should == @page.current
  end
  
  it "should save versions when updated" do
    @page = Page.create(page_params)
    @page.title = "Change the title"
    
    lambda { 
      @page.save.should == true
    }.should create_new_version
    
    @page.current.should == @page
    @page.current.should == @page
  end

  it "should save slug in the versions table" do
    @page = Page.create(page_params)
    @page.slug = "my-page"
    @page.save
    
    @page.versions.current.slug.should == @page.slug
  end
  
  it "should create a new draft in the main table" do
    @page = Page.create(page_params(:status_id => Status[:draft].id))
    @page.reload
    @page.status.should == Status[:draft]
  end
  
  describe "drafts" do
    before(:each) do
      @page = pages(:first)
      @page.status_id = Status[:draft].id
    end
    
    it "should not change the live version when Page is updated as a draft" do
      lambda { 
        @page.save.should == true
      }.should create_new_version
    
    
      @page.reload
      @page.status_id.should_not == Status[:draft].id
    end
  
    it "should properly save a version when Page is updated as a draft" do
      @page.title = "This is just a draft"
    
      lambda { 
        @page.save.should == true
      }.should create_new_version
    
      @page.reload
      @page.current.title.should == "This is just a draft"
      @page.current.status_id.should == Status[:draft].id
    end
  
    it "should not change the live version when PagePart is updated as a draft" do
      @page.parts = [{"name"=>"body", "filter_id"=>"", "content"=>"I changed the body!"}]
    
      lambda { 
        @page.save.should == true
      }.should create_new_version
    
      @page.reload
      @page.status_id.should_not == Status[:draft].id
      @page.parts.first.content.should_not == "I changed the body!"
    end
  
    it "should properly save a version when PagePart is updated as a draft" do
      @page.parts = [{"name"=>"body", "filter_id"=>"", "content"=>"I changed the body!"}]
    
      lambda { 
        @page.save.should == true
      }.should create_new_version
    
      @page.reload
      @page.current.parts.first.content.should == "I changed the body!"
      @page.current.status_id.should == Status[:draft].id
    end
    
    it "should have versioned draft child in #current_children" do
      @page.save
      
      pages(:home).current_children.should include(@page)
    end
  end

  describe "#find_by_url" do
    dataset :pages, :file_not_found
    
    before :each do
      @home = pages(:home)
      @page = pages(:another)
      @page.status = Status[:draft]
    end
    
    it "should find a first-version draft in dev mode" do
      draft_page = @home.find_by_url('/draft/', false)
      draft_page.should == pages(:draft)
      draft_page.should have(0).versions
    end
    
    it 'should not find a first-version draft in live mode' do
      @home.find_by_url('/draft/').should == pages(:file_not_found)
    end
    
    it "should find a second-version draft in dev mode" do
      @page.title = "Draft of Another"
      lambda { @page.save }.should create_new_version
      @draft = @page.current
      
      @home.find_by_url('/another/', false).should == @draft
    end
    
    it 'should not find a second-version draft in live mode' do
      @page.title = "Draft of Another"
      @page.save
      @draft = @page.current
      
      @home.find_by_url('/another/', false).should == pages(:another)
    end
    
    describe "when changed slug in draft" do
      before(:each) do
        parent = pages(:parent)
        parent.slug = "parent-draft"
        parent.status = Status[:draft]
        parent.save
      end
      
      it "should find the page at the new slug in dev mode" do
        @home.find_by_url('/parent-draft/', false).should == pages(:parent).current
      end

      it "should not find the page at the old slug in dev mode" do
        @home.find_by_url('/parent/', false).should == pages(:draft_file_not_found)
      end
      
      it "should find a published child at the new url in dev mode" do
        @home.find_by_url('/parent-draft/child/', false).should == pages(:child)
      end

      it "should not find a published child at the old url in dev mode" do
        @home.find_by_url('/parent/child/', false).should == pages(:draft_file_not_found)
      end
      
      it "should not find a published child at the new url in live mode" do
        @home.find_by_url('/parent-draft/child/').should == pages(:file_not_found)
      end
      
      it "should find a published child at the old url in live mode" do
        @home.find_by_url('/parent/child/').should == pages(:child)
      end
      
      it "should find the dev version of a FileNotFound page"
      
    end
    
  end
  
  def create_new_version
    change{ @page.versions.length }.by(1)
  end
end