require 'json'

module App

  class MethodConfiguration
    attr_reader :target, :private_group, :image_assets, :headfile

    def initialize(hash)
      @private_group = hash["privateGroup"]
      @image_assets = hash["assets"]
      @headfile = hash["headfile"]
      @target = hash["targetName"]
    end
  end

  class AppItem
    attr_reader :display_name, :branch_name, :company_code, :enterprise_configuration, :store_configuration
    
    def initialize(hash)
      @display_name = hash["displayName"]
      @branch_name = hash["branchName"]
      @company_code = hash["code"]
      @enterprise_configuration = MethodConfiguration.new(hash['enterprise'])
      @store_configuration = MethodConfiguration.new(hash['store'])
    end
  end

  def self.find_app(company_code)
    app_list = JSON.load(Rails.root.join('public', 'app.json'))
    app_hash = app_list.find{ |hash| hash["code"] == company_code }
    unless app_hash
      return nil
    end
    return AppItem.new(app_hash)
  end

  def App.find_app_with_branch(branch)
    app_list = JSON.load(Rails.root.join('public', 'app.json'))
    app_hash = app_list.find { |hash| hash["branchName"] == branch }
    return nil unless app_hash
    return AppItem.new(app_hash)
  end

  def App.add_app(app_hash)
    path = Rails.root.join('public', 'app.json')
    app_list = JSON.load(path)
    app_list << app_hash
    IO.write(path, JSON.pretty_generate(app_list))
  end

end
