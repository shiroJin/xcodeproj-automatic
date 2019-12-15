module MyUtils

  # 将数据中的#{domain}替换成当前域名
  #
  # @return [data] 转化后的数据
  # @param [data] 数据
  # @params [String] remote
  #         remote address
  #
  def self.remote_file_path(data, remote)
    if data.instance_of? Hash
      data.transform_values {|item| remote_file_path(item, remote) }
    elsif data.instance_of? Array
      data.collect {|item| remote_file_path(item, remote) }
    elsif data.instance_of? String
      data.sub('#{domain}', remote)
    end
  end

  # recover from http path
  #
  # @param [Hash|Array|String] data
  #
  def self.recover_file_path(data)
    if data.instance_of? Hash
      data.transform_values { |item| recover_file_path(item) }
    elsif data.instance_of? Array
      data.collect { |item| recover_file_path(item) }
    elsif data.instance_of? String
      if data.include? ":3000/file"
        filename = data.split('/').last
        return Rails.root.join('public', 'upload', filename)
      else
        data
      end
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