class FilesController < ApplicationController
  def upload
    @file = params['file']
    @filename = @file.original_filename

    @upload_dir = Rails.root.join('public', 'upload')
    Dir.mkdir('@upload_dir') unless File.exist? @upload_dir

    @path = @upload_dir.join(@filename)
    File.open(@path, 'wb') do |file|
      file.write(@file.read)
    end

    render()
  end
  
  def fetch
    @filename = request.fullpath.split('/').last
    @src_path = Rails.root.join('public', 'upload', @filename)
    @data = File.new(@src_path, 'rb').read
    send_data(@data)
  end
end
