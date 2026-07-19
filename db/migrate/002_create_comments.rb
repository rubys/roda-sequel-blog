Sequel.migration do
  change do
    create_table(:comments) do
      primary_key :id
      foreign_key :article_id, :articles, null: false, on_delete: :cascade
      String :commenter
      String :body, text: true
      DateTime :created_at
      DateTime :updated_at
      index :article_id
    end
  end
end
