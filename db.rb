# Database connection + schema.
#
# Sequel connects before any model class is defined (models subclass
# Sequel::Model, which needs a DB handle at class-definition time), and the
# migrations in db/migrate are run on boot so the app is runnable with no
# separate setup step.
require "sequel"

DB = Sequel.sqlite(ENV.fetch("DATABASE", File.expand_path("db/blog.db", __dir__)))

Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path("db/migrate", __dir__))

# Plugins applied to every model.
Sequel::Model.plugin :validation_helpers          # ActiveRecord-style validations
Sequel::Model.plugin :timestamps, update_on_create: true
