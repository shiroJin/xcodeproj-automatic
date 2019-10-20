class ProjectController < ApplicationController
  def add_new_project
    XcodeProject.new_target(params)
    render()
  end

  def edit_project
    
  end
end
