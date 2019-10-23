require_relative '../../script/app'
require_relative '../../script/XcodeProject'
class ProjectController < ApplicationController
  def add_new_project
    @company_code = params["kCompanyCode"]
    @branch_name = "proj-#{@company_code}-snapshot"
    @project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'

    XcodeProject.new_target(@project_path, params)
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

  def fetch_project_form
    @form = JSON.load(Rails.root.join('public', 'butler_form.json'))
    render :json => @form
  end
end
