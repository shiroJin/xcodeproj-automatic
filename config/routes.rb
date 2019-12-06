Rails.application.routes.draw do
  # files
  get 'projectFile', to: 'files#fetch_local'
  get 'files/:filename', to: 'files#fetch'

  post 'files/upload', to: 'files#upload'

  #project
  get 'project/list', to: 'project#fetch_project_list'
  get 'project/app-form', to: 'project#fetch_project_form'
  get 'project/projectInfo', to: 'project#fetch_project_info'
  get 'project/current', to: 'project#fetch_current_project'

  post 'project/addProject', to: 'project#add_new_project'
  post 'project/editProject', to: 'project#edit_project'

  #worktree
  get 'project/tags', to: 'project#fetch_avaiable_tags'
  get 'project/isDirty', to: 'project#is_dirty'

  post 'project/checkout', to: 'project#checkout_app'
  post 'project/pull', to: 'project#pull'
  post 'project/pullCurrent', to: 'project#pull_single_branch'
  post 'project/clean', to: 'project#stash'
  post 'project/commit', to: 'project#commit'
  post 'project/merge', to: 'project#merge'
  post 'project/trash', to: 'project#trash'

  #package
  post 'project/package', to: 'package#package'

  #workspace
  get 'workspace/repositories', to: 'workspace#list_repositories'
  
end
