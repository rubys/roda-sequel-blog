class Article < Sequel::Model
  one_to_many :comments, key: :article_id, order: Sequel.desc(:created_at)

  def validate
    super
    validates_presence [:title, :body]
    validates_min_length 10, :body, message: "must be at least 10 characters"
  end
end
