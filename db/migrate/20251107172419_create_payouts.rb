class CreatePayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :payouts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false

      t.timestamps
    end
    
    add_index :payouts, [:user_id, :period_start, :period_end]
  end
end
