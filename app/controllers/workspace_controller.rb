require_relative "../script/myUtils"
require_relative "../models/repository"

class WorkspaceController < ApplicationController
  REPOSITORY_PATH = Rails.root.join('public', 'repositories.json')

  # list all repositories
  def list_repositories
    list = JSON.load(REPOSITORY_PATH)
    render :json => list
  end
  
  # create repository if not existed  
  def create_repository
    name, remote_url = params["name"], params["remoteUrl"]
    repository = Repository::Base.new(name, remote_url)
    puts repository.name
    render()
  end

end
