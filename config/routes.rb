Rails.application.routes.draw do
  # files
  post 'files/upload', to: 'files#upload'
  get 'files/:filename', to: 'files#fetch'

  #project
  get 'project/list', to: 'project#fetch_project_list'
  get 'project/projectInfo', to: 'project#fetch_project_info'
  post 'project/addProject', to: 'project#add_new_project'
  post 'project/editProject', to: 'project#edit_project'
end
