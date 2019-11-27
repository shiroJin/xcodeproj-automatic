require 'json'

module App

  class AppItem
    attr_accessor :display_name, :target_name, :private_group, :assets, :headfile, :branch_name, :company_code
    def initialize(hash)
      @display_name = hash["displayName"]
      @target_name = hash["targetName"]
      @private_group = hash["privateGroup"]
      @assets = hash["assets"]
      @headfile = hash["headfile"]
      @branch_name = hash["branchName"]
      @company_code = hash["code"]
    end
  end

  def App.find_app(company_code)
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
