class ProjectController < ApplicationController
  def add_new_project
    @company_code = params["kCompanyCode"]
    @branch_name = "proj-#{@company_code}-snapshot"
    
    XcodeProject.new_target(params)
    render()
  end

  def edit_project
    XcodeProject.edit_project(params)
    render()
  end

  def fetch_project_info
    XcodeProject.fetch_target_info()
    render()
  end

  def fetch_project_list
    @project_list = JSON.load(Rails.root.join('public', 'app.json'))
    render :json => @project_list
  end
end
