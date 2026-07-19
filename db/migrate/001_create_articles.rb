Sequel.migration do
  change do
    create_table(:articles) do
      primary_key :id
      String :title
      String :body, text: true
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
