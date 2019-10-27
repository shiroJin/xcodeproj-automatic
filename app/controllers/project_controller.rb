require_relative '../script/app'
require_relative '../script/XcodeProject'
require 'git'
class ProjectController < ApplicationController
  @@project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
  def add_new_project
    company_code = params["kCompanyCode"]
    branch_name = "proj-#{company_code}-snapshot"
    project_path = @@project_path
    tag_name = params["tag"]

    git = Git.open(@@project_path)
    if branch = git.branches.find { |b| b.name == branch_name }
      raise "branch #{branch_name} alread existed"
    end
    
    if tag = git.tags.find { |t| t.name == tag_name }
      raise "tag #{tag_name} is not existed" unless tag
    end

    cmd = "git --git-dir=#{@@project_path}/.git -b #{branch_name} #{tag_name}"
    exec cmd
    raise "checkout new branch failed" if git.current_branch.name != branch_name

    XcodeProject.new_target(project_path, params.as_json)
    render()
  end

  def edit_project
    XcodeProject.edit_project(@@project_path, params['companyCode'], params['updateInfo'].as_json)
    render()
  end

  def fetch_project_info
    data = XcodeProject.fetch_target_info(@@project_path, params["companyCode"])
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
