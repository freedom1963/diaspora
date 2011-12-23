class AddSettingForNsfwTag < ActiveRecord::Migration
  def self.up
    add_column :users, :show_nsfw_posts_in_stream, :boolean, :default => false
  end

  def self.down
    remove_column :users, :show_nsfw_posts_in_stream
  end
end
