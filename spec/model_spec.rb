require File.dirname(__FILE__) + '/spec_helper'

describe 'ActiveRecord mixin' do
  integrate_sunspot
  
  describe 'index()' do
    before :each do
      @post = Post.create!
      @post.index
    end

    it 'should not commit the model' do
      Post.search.results.should be_empty
    end

    it 'should index the model' do
      Sunspot.commit
      Post.search.results.should == [@post]
    end
  end

  describe 'index!()' do
    before :each do
      @post = Post.create!
      @post.index!
    end

    it 'should immediately index and commit' do
      Post.search.results.should == [@post]
    end
  end

  describe 'remove_from_index()' do
    before :each do
      @post = Post.create!
      @post.index!
      @post.remove_from_index
    end

    it 'should not commit immediately' do
      Post.search.results.should == [@post]
    end

    it 'should remove the model from the index' do
      Sunspot.commit
      Post.search.results.should be_empty
    end
  end

  describe 'remove_from_index!()' do
    before :each do
      @post = Post.create!
      @post.index!
      @post.remove_from_index!
    end

    it 'should immediately remove the model and commit' do
      Post.search.results.should be_empty
    end
  end

  describe 'remove_all_from_index' do
    before :each do
      @posts = Array.new(10) { Post.create! }.each { |post| Sunspot.index(post) }
      Sunspot.commit
      Post.remove_all_from_index
    end

    it 'should not commit immediately' do
      Post.search.results.to_set.should == @posts.to_set
    end

    it 'should remove all instances from the index' do
      Sunspot.commit
      Post.search.results.should be_empty
    end
  end

  describe 'remove_all_from_index!' do
    before :each do
      Array.new(10) { Post.create! }.each { |post| Sunspot.index(post) }
      Sunspot.commit
      Post.remove_all_from_index!
    end

    it 'should remove all instances from the index and commit immediately' do
      Post.search.results.should be_empty
    end
  end

  describe 'search()' do
    before :each do
      @post = Post.create!(:title => 'Test Post')
      @post.index!
    end

    it 'should return results specified by search' do
      Post.search do
        with :title, 'Test Post'
      end.results.should == [@post]
    end

    it 'should not return results excluded by search' do
      Post.search do
        with :title, 'Bogus Post'
      end.results.should be_empty
    end
    
    it 'should find ActiveRecord objects with an integer, not a string' do
      Post.should_receive(:find).with([@post.id.to_i]).and_return([@post])
      Post.search do
        with :title, 'Test Post'
      end.results.should == [@post]
    end
  end

  describe 'search_ids()' do
    before :each do
      @posts = Array.new(2) { Post.create! }.each { |post| post.index }
      Sunspot.commit
    end

    it 'should return IDs' do
      Post.search_ids.to_set.should == @posts.map { |post| post.id }.to_set
    end
  end
  
  describe 'searchable?()' do
    it 'should not be true for models that have not been configured for search' do
      Blog.should_not be_searchable
    end

    it 'should be true for models that have been configured for search' do
      Post.should be_searchable
    end
  end

  describe 'index_orphans()' do
    before :each do
      @posts = Array.new(2) { Post.create }.each { |post| post.index }
      Sunspot.commit
      @posts.first.destroy
    end

    it 'should return IDs of objects that are in the index but not the database' do
      Post.index_orphans.should == [@posts.first.id]
    end
  end

  describe 'clean_index_orphans()' do
    before :each do
      @posts = Array.new(2) { Post.create }.each { |post| post.index }
      Sunspot.commit
      @posts.first.destroy
    end

    it 'should remove orphans from the index' do
      Post.clean_index_orphans
      Sunspot.commit
      Post.search.results.should == [@posts.last]
    end
  end

  describe 'reindex()' do
    before :each do
      @posts = Array.new(2) { Post.create }
    end

    it 'should index all instances' do
      Post.reindex(:batch_size => nil)
      Sunspot.commit
      Post.search.results.to_set.should == @posts.to_set
    end

    it 'should remove all currently indexed instances' do
      old_post = Post.create!
      old_post.index!
      old_post.destroy
      Post.reindex
      Sunspot.commit
      Post.search.results.to_set.should == @posts.to_set
    end
    
  end

  describe 'reindex() with real data' do
    before :each do
      @posts = Array.new(2) { Post.create }
    end

    it 'should index all instances' do
      Post.reindex(:batch_size => nil)
      Sunspot.commit
      Post.search.results.to_set.should == @posts.to_set
    end

    it 'should remove all currently indexed instances' do
      old_post = Post.create!
      old_post.index!
      old_post.destroy
      Post.reindex
      Sunspot.commit
      Post.search.results.to_set.should == @posts.to_set
    end
    
    describe "using batch sizes" do
      it 'should index with a specified batch size' do
        Post.reindex(:batch_size => 1)
        Sunspot.commit
        Post.search.results.to_set.should == @posts.to_set
      end
    end
    
  end
  
  describe "reindex()" do
  
    before(:each) do
      @posts = Array.new(10) { Post.create }
    end

    describe "when not using batches" do
      
      it "should select all if the batch_size is nil" do
        Post.should_receive(:all).with(:include => []).and_return([])
        Post.reindex(:batch_size => nil)
      end

      it "should search for models with includes" do
        Post.should_receive(:all).with(:include => :author).and_return([])
        Post.reindex(:batch_size => nil, :include => :author)
      end
    
    end

    describe "when using batches" do
      
      it "should use the default options" do
        Post.should_receive(:all).with do |params|
          params[:limit].should == 500
          params[:include].should == []
          params[:conditions].should == ['posts.id > ?', 0]
          params[:order].should == 'id'
        end.and_return(@posts)
        Post.reindex
      end

      it "should set the conditions using the overridden table attributes" do
        @posts = Array.new(10) { Author.create }
        Author.should_receive(:all).with do |params|
          params[:conditions].should == ['writers.writer_id > ?', 0]
          params[:order].should == 'writer_id'
        end.and_return(@posts)
        Author.reindex
      end

      it "should count the number of records to index" do
        Post.should_receive(:count).and_return(10)
        Post.reindex
      end

      it "should override the batch_size" do
        Post.should_receive(:all).with do |params|
          params[:limit].should == 20
          @posts
        end.and_return(@posts)
        Post.reindex(:batch_size => 20)
      end

      it "should set the include option" do
        Post.should_receive(:all).with do |params|
          params[:include].should == [{:author => :address}]
          @posts
        end.and_return(@posts)
        Post.reindex(:include => [{:author => :address}])
      end

      it "should commit after indexing each batch" do
        Sunspot.should_receive(:commit).twice
        Post.reindex(:batch_size => 5)
      end

      it "should commit after indexing everything" do
        Sunspot.should_receive(:commit).once
        Post.reindex(:batch_commit => false)
      end
      
    end
  end
  
end
