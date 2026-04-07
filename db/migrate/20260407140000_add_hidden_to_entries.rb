class AddHiddenToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :hidden, :boolean, default: false, null: false
  end
end
