require_relative "../script/myUtils"

class WorkspaceController < ApplicationController

  def list_repositories
    list = JSON.load(Rails.root.join('public', 'repositories.json'))
    render :json => list
  end
  
  # create repository if not existed 
  def create_repository
    
    render()
  end

end
