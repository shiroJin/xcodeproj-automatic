require 'json'

module App

  class AppItem
    attr_accessor :display_name, :branch_name, :id, :configuration
    def initialize(hash)
      @display_name = hash["displayName"]
      @branch_name = hash["branchName"]
      @id = hash["id"]
      @configuration = hash['configuration']
    end
  end

  def self.find_app(id)
    app_list = JSON.load(Rails.root.join('public', 'app.json'))
    app_hash = app_list.find{ |hash| hash["id"] == id }
    unless app_hash
      return nil
    end
    return AppItem.new(app_hash)
  end

  def self.find_app_with_branch(branch)
    app_list = JSON.load(Rails.root.join('public', 'app.json'))
    app_hash = app_list.find { |hash| hash["branchName"] == branch }
    return nil unless app_hash
    return AppItem.new(app_hash)
  end

  def self.add_app(app_hash)
    path = Rails.root.join('public', 'app.json')
    app_list = JSON.load(path)
    app_list << app_hash
    IO.write(path, JSON.pretty_generate(app_list))
  end

end
