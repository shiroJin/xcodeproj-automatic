module MyUtils

  def MyUtils.map_remote(data, remote)
    if data.instance_of? Hash
      data.transform_values {|item| map_remote(item, remote) }
    elsif data.instance_of? Array
      data.collect {|item| map_remote(item, remote) }
    elsif data.instance_of? String
      data.sub('#{domain}', remote)
    end
  end

  def MyUtils.workspace_path
    path = Rails.root.join("..", "workspace")
    unless Dir.exist? path
      Dir.mkdir(path)
    end
    return dir_path
  end

end