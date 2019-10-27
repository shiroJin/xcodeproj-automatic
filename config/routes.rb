Rails.application.routes.draw do
  # files
  post 'files/upload', to: 'files#upload'
  get 'projectFile', to: 'files#fetch_local'
  get 'files/:filename', to: 'files#fetch'

  #project
  get 'project/list', to: 'project#fetch_project_list'
  get 'project/app-form', to: 'project#fetch_project_form'
  get 'project/projectInfo', to: 'project#fetch_project_info'
  post 'project/addProject', to: 'project#add_new_project'
  post 'project/editProject', to: 'project#edit_project'

  #workspace
  post 'workspace/pull', to: 'workspace#pull'
  get 'workspace/tags', to: 'workspace#tags'
  post 'workspace/clean', to: 'workspace#stash'
  post 'workspace/commit', to: 'workspace#commit'
  post 'workspace/merge', to: 'workspace#merge'

end
