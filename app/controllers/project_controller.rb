require_relative '../script/app'
require_relative '../script/XcodeProject'
require 'git'
class ProjectController < ApplicationController
  @@project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
  
  def git
    @git ||= Git.open(@@project_path)
  end

  # 新增分支及target
  def add_new_project
    company_code = params["kCompanyCode"]
    branch_name = "proj-#{company_code}-snapshot"
    project_path = @@project_path
    tag_name = params["tag"]

    if branch = self.git.branches.find { |b| b.name == branch_name }
      raise "branch #{branch_name} alread existed"
    end
    
    if tag = self.git.tags.find { |t| t.name == tag_name }
      raise "tag #{tag_name} is not existed" unless tag
    end

    cmd = "git --git-dir=#{@@project_path}/.git -b #{branch_name} #{tag_name}"
    exec cmd
    raise "checkout new branch failed" if self.git.current_branch.name != branch_name

    XcodeProject.new_target(project_path, params.as_json)
    render()
  end

  # 编辑项目
  def edit_project
    XcodeProject.edit_project(@@project_path, params['companyCode'], params['updateInfo'].as_json)
    render()
  end

  # 获取项目信息
  def fetch_project_info
    data = XcodeProject.fetch_target_info(@@project_path, params["companyCode"])
    render :json => data
  end

  # 获取目前所有APP
  def fetch_project_list
    project_list = JSON.load(Rails.root.join('public', 'app.json'))
    render :json => project_list
  end

  # 新增项目所需要的表单
  def fetch_project_form
    form = JSON.load(Rails.root.join('public', 'butler_form.json'))
    render :json => form
  end

  # 获取当前项目
  def fetch_current_project
    app = App.find_app_with_branch(self.git.current_branch)
    data = XcodeProject.fetch_target_info(@@project_path, app.company_code)
    render :json => data
  end

  # 获取所有tag
  def fetch_avaiable_tags
    data = self.git.tags.select do |tag|
      tag.name =~ /^Fusion_1.\d+.[^0]$/
    end.map do |tag|
      tag.name
    end
    render :json => data
  end

  #切换项目
  def checkout_app
    if worktree_is_dirty
      response.status = 400
      render :json => 'worktree is dirty!'
      return
    end

    app = App.find_app(params["companyCode"])
    branch = self.git.branches.find{ |b| b.name == app.branch_name }
    branch.checkout
    render()
  end

  #下拉代码
  def pull
    cmd = "git --git-dir=#{@@project_path}/.git pull 2>&1"
    IO.popen(cmd) { |result|
      render :json => { 'msg' => result.read }
    }
  end

  def worktree_is_dirty
    cmd = "git --git-dir=#{@@project_path}/.git --work-tree=#{@@project_path} status"
    IO.popen(cmd) { |result|
      message = result.read
      dirty = false
      if message.index('Untracked files') || message.index('Changes not staged')
        dirty = true
      end
      return dirty
    }
  end

  def is_dirty
    cmd = "git --git-dir=#{@@project_path}/.git --work-tree=#{@@project_path} status"
    IO.popen(cmd) { |result|
      message = result.read
      dirty = false
      if message.index('Untracked files') || message.index('Changes not staged')
        dirty = true
      end
      render :json => { 'dirty' => dirty, 'msg' => message }
    }
  end

  def trash
    self.git.add
    self.git.reset_hard('HEAD')
    render()
  end

  def commit
    message = params['message']
    self.git.add
    self.git.push('origin', self.git.current_branch)
    self.git.commit(message)
  end

end
