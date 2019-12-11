require_relative '../script/app'
require_relative '../script/XcodeProject'
require_relative '../script/TargetConfiguration'
require_relative '../script/myUtils'
require 'git'

class ProjectController < ApplicationController

  def git
    @git ||= Git.open(self.project_path)
  end

  def project_path
    @project_path ||= File.join(MyUtils.workspace_path, 'ButlerForFusion')
  end

  # 新增分支及target
  def add_new_project
    company_code = params["kCompanyCode"]
    branch_name = "proj-#{company_code}-snapshot"
    project_path = self.project_path
    tag_name = params["tag"]

    if branch = self.git.branches.find { |b| b.name == branch_name }
      raise "branch #{branch_name} alread existed"
    end
    
    if tag = self.git.tags.find { |t| t.name == tag_name }
      raise "tag #{tag_name} is not existed" unless tag
    end

    cmd = "git --git-dir=#{self.project_path}/.git checkout -b #{branch_name} #{tag_name}"
    exec cmd
    raise "checkout new branch failed" if self.git.current_branch.name != branch_name

    XcodeProject.new_target(project_path, params.as_json)
    
    render()
  end

  def add_new_target
    repository, branch = '', 'proj-xyjnh-snapshot'

    if current_branch = self.git.current_branch
      unless current_branch.name == branch
        Dir.chdir(project_path) do
          cmd = "git checkout #{branch}"
          IO.popen(cmd)
        end
      end
      raise "error branch" unless self.git.current_branch == branch
    end
    
    XcodeProject.new_target(repository, params.as_json)

    render()
  end

  # 编辑项目
  def edit_project
    XcodeProject.edit_project(self.project_path, params['companyCode'], params['updateInfo'].as_json)
    render()
  end

  # 获取项目信息
  def fetch_project_info(project_path, target_configuration)
    data = XcodeProject.fetch_target_info(project_path, target_configuration)
    MyUtils.map_remote(data, request.protocol + request.host_with_port)
  end

  # 获取目前所有APP
  def fetch_project_list
    JSON.load(Rails.root.join('public', 'app.json'))
  end

  # 新增项目所需要的表单
  def fetch_project_form
    form = JSON.load(Rails.root.join('public', 'butler_form.json'))
    render :json => form
  end

  # 获取当前项目
  def fetch_current_project
    app = App.find_app_with_branch(self.git.current_branch)
    data = self.fetch_project_info(self.project_path, app.store_configuration)
    render :json => data
  end

  # 获取所有tag
  def fetch_avaiable_tags
    data = self.git.tags.select do |tag|
      tag.name =~ /^Fusion_1.\d+.[^0]$/
    end.map do |tag|
      tag.name
    end
    return data
  end

  #切换项目
  def checkout_app
    if worktree_is_dirty
      response.status = 400
      render :text => 'worktree is dirty!'
      return
    end

    app = App.find_app(params["companyCode"])
    branch = self.git.branches.find{ |b| b.name == app.branch_name }
    branch.checkout
    render()
  end

  #下拉代码
  def pull
    cmd = "git --git-dir=#{self.project_path}/.git pull 2>&1"
    IO.popen(cmd) { |result|
      render :json => { :msg => result.read }
    }
  end

  def worktree_is_dirty
    cmd = "git --git-dir=#{self.project_path}/.git --work-tree=#{self.project_path} status"
    IO.popen(cmd) { |result|
      message = result.read
      dirty = false
      if message.index('Untracked files') || message.index('Changes not staged')
        dirty = true
      end
      return dirty
    }
  end

  def trash
    self.git.add
    self.git.reset_hard('HEAD')
    render()
  end

  def commit
    if message = params['msg']
      self.git.add
      self.git.commit(message)
      self.git.push('origin', self.git.current_branch)
    else
      reponse.status = 502
    end
    render()
  end

  def pull_single_branch
    self.git.pull('origin', self.git.current_branch)
    render()
  end

  def get_repository_info
    dirty = self.worktree_is_dirty
    tags = self.fetch_avaiable_tags
    project_list = self.fetch_project_list
    data = { :dirty => dirty, :tags => tags, :project_list => project_list }
    render :json => data
  end

end
