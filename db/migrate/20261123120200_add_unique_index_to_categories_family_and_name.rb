# frozen_string_literal: true

class AddUniqueIndexToCategoriesFamilyAndName < ActiveRecord::Migration[7.2]
  def change
    add_index :categories, [ :family_id, :name ], unique: true, name: "index_categories_on_family_id_and_name", if_not_exists: true
  end
end
