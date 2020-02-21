require_relative '../script/app'
require_relative '../script/XcodeProject'
require_relative '../script/myUtils'
require 'git'
require 'open3'

class ProjectController < ApplicationController

  def git
    @git ||= Git.open(self.project_path)
  end

  def project_path
    @project_path ||= File.join(MyUtils.workspace_path, 'ButlerForFusion')
  end

  # 新增分支及target
  def add_new_project
    branch_name, tag_name = params[:branch], params[:tag]

    arr, cmd = [], "git --git-dir=#{self.project_path}/.git branch -a"
    IO.popen(cmd) { |stdout|
      stdout.each { |b|
        current = (b[0, 2] == '* ')
        arr << b.gsub('* ', '').strip
      }
    }
    exist = arr.find { |b| b.split('/').last == branch_name }
    
    if exist
      cmd = "git checkout #{branch_name}"
      Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
        puts o.read
      }
    else
      cmd = "git checkout -b #{branch_name} #{tag_name}"
      Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
        puts o.read
      }
    end

    # check branch
    if self.git.current_branch != branch_name
      raise "checkout new branch failed"
    end
    args = MyUtils.recover_file_path(params.as_json)
    begin
      XcodeProject.new_target(self.project_path, args["configuration"], args["form"])
    rescue => exception
      cmd = "git add . && git reset --hard HEAD"
      puts cmd
      Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
        o.each { |line| print line }
        e.each { |line| print line }
      }
      throw exception
    end
    # App.add_app({ "configuration" => args["configuration"], "branchName" => branch_name, "displayName" => args["form"]["plist"]["CFBundleDisplayName"] })
    render()
  end

  # 编辑项目
  def edit_project
    app = App.find_app(params["id"])
    update_form = params["form"]
    form = MyUtils.recover_file_path(update_form.as_json)
    XcodeProject.edit_project(self.project_path, app.configuration, form)
    render()
  end

  # 读取项目信息
  def read_project_info(project_path, target_configuration)
    data = XcodeProject.fetch_target_info(project_path, target_configuration)
    MyUtils.remote_file_path(data, request.protocol + request.host_with_port)
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
    render :json => { :id => app.id }
  end

  # 获取项目信息
  def fetch_project_info
    app = App.find_app(params[:id])
    result = read_project_info(self.project_path, app.configuration)
    render :json => result
  end

  # 获取所有tag
  def fetch_avaiable_tags
    self.git.tags.select do |tag|
      tag.name =~ /^Fusion_1.1\d+.[^0]$/
    end.map do |tag|
      tag.name
    end
  end

  #切换项目
  def checkout_app
    if worktree_is_dirty
      render :json => { :msg => "请先提交内容修改！"}
    else
      app = App.find_app(params[:id])
      cmd = "git checkout #{app.branch_name}"
      Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
        render :json => { :msg => o.read }
      }
    end
  end

  #下拉代码
  def pull
    cmd = "git pull 2>&1"
    Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
      render :json => { :msg => o.read }
    }
  end

  def worktree_is_dirty
    dirty = false
    message = self.repository_status
    if message.index('Untracked files') || message.index('Changes not staged')
      dirty = true
    end
    return dirty
  end

  def repository_status
    cmd = "git status"
    Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
      message = o.read
      return message
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

  def repository_pull
    cmd = "git pull"
    stdout, stderr = nil
    Open3.popen3(cmd, :chdir=>self.project_path) { |i, o, e, t|
      stdout = o.read
      stderr = e.read
    }
    render :json => { :stdout => stdout, :stderr => stderr }
  end

  def get_repository_info
    dirty = self.worktree_is_dirty
    status = self.repository_status
    tags = self.fetch_avaiable_tags
    project_list = self.fetch_project_list
    data = { :dirty => dirty, :tags => tags, :project_list => project_list, :status => status }
    render :json => data
  end

end
