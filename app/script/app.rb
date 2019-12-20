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

  def self.add_app(hash)
    path = Rails.root.join('public', 'app.json')
    app_list = JSON.load(path)
    id = -1
    app_list.each do |app|
      value = app["id"].to_i
      if value > id
        id = value
      end
    end
    hash["id"] = (id + 1).to_s
    app_list << hash
    IO.write(path, JSON.pretty_generate(app_list))
  end

end
