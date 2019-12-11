module MyUtils

  # 将数据中的#{domain}替换成当前域名
  #
  # @return [data] 转化后的数据
  # @param [data] 数据
  # @params [String] remote
  #         remote address
  #
  def self.map_remote(data, remote)
    if data.instance_of? Hash
      data.transform_values {|item| map_remote(item, remote) }
    elsif data.instance_of? Array
      data.collect {|item| map_remote(item, remote) }
    elsif data.instance_of? String
      data.sub('#{domain}', remote)
    end
  end

  # @return workspace path
  #
  def self.workspace_path
    path = Rails.root.join("..", "workspace")
    unless Dir.exist? path
      Dir.mkdir(path)
    end
    return path
  end

end