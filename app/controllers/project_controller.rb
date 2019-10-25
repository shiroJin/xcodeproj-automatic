require_relative '../script/app'
require_relative '../script/XcodeProject'
require 'git'
class ProjectController < ApplicationController
  def add_new_project
    company_code = params["kCompanyCode"]
    branch_name = "proj-#{company_code}-snapshot"
    project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
    tag_name = params["tag"]

    git = Git.open(project_path)
    git.branches.each do |branch|
      raise "branch #{branch_name} alread existed"
    end
    
    git.tags.each do |t|
      tag = t if t.name == tag_name
    end
    raise "tag #{tag_name} is not existed" unless tag

    XcodeProject.

    XcodeProject.new_target(project_path, params.as_json)
    render()
  end

  def edit_project
    project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
    XcodeProject.edit_project(project_path, params['companyCode'], params['updateInfo'].as_json)
    render()
  end

  def fetch_project_info
    project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
    data = XcodeProject.fetch_target_info(project_path, params["companyCode"])
    render :json => data
  end

  def fetch_project_list
    project_list = JSON.load(Rails.root.join('public', 'app.json'))
    render :json => project_list
  end

  def fetch_project_form
    form = JSON.load(Rails.root.join('public', 'butler_form.json'))
    render :json => form
  end
end
