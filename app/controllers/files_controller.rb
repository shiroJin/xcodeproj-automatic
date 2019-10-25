class FilesController < ApplicationController
  def upload
    @upload_dir = Rails.root.join('public', 'upload')
    Dir.mkdir(@upload_dir) unless File.exist? @upload_dir

    @files, @result = params.values, Array.new
    @files.select do |file|
      file.instance_of? ActionDispatch::Http::UploadedFile
    end.each do |file|
      @filename = file.original_filename
      @path = @upload_dir.join(@filename)
      File.open(@path, 'wb') do |fp|
        fp.write(file.read)
      end
      @result << 'http://localhost:3000/files/' + @filename
    end
    
    render :json => @result
  end
  
  def fetch
    filename = request.fullpath.split('/').last
    src_path = Rails.root.join('public', 'upload', filename)
    data = File.new(src_path, 'rb').read
    send_data(data)
  end

  def fetch_local
    src = params['src']
    data = File.new(src, 'rb').read
    send_data(data)
  end
end
