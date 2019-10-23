require 'json'
module App
  class AppItem
    attr_accessor :display_name, :target_name, :private_group, :assets, :headfile
    def initialize(hash)
      @display_name = hash["displayName"]
      @target_name = hash["targetName"]
      @private_group = hash["privateGroup"]
      @assets = hash["assets"]
      @headfile = hash["headfile"]
    end
  end

  def App.find_app(target_name)
    app_list = JSON.load(Rails.root.join('public', 'app.json'))
    app_hash = app_list.find{ |hash| hash["targetName"] == target_name }
    unless app_hash
      return nil
    end
    return AppItem.new(app_hash)
  end

  def App.add_app(app_hash)
    path = rails.root.join('public', 'app.json')
    app_list = JSON.load(path)
    app_list << app_hash
    IO.write(path, JSON.pretty_generate(app_list))
  end
end
