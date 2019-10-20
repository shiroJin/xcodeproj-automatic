Rails.application.routes.draw do
  # files
  post 'files/upload', to: 'files#upload'
  get 'files/:filename', to: 'files#fetch'

  #project
  
end
