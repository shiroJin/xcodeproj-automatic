require 'Liquid'

module HeadFile
  def HeadFile.project_fields
    return [
      'CFBundleDisplayName',
      'CFBundleShortVersionString',
      'CFBundleVersion',
      'PRODUCT_BUNDLE_IDENTIFIER',
      'images',
      'files',
      'projectPath',
      'tag'
    ]
  end

  def HeadFile.load(file_path)
    return Hash.new unless File.readable?(file_path)

    hash = Hash.new
    dict = Hash["DEBUG" => Hash.new, "RELEASE" => Hash.new, "DISTRIBUTION" => Hash.new]
    dict.each do |key, value|
      start = false
      IO.foreach(file_path) do |line|
        if (/ifdef#{key}/.match(line.gsub(/\s/, '')))
          start = true
          next
        end
        if start
          data = line.gsub(/\s/, '').gsub(/(staticNSString\*(const)?|@"|"|;|\n)/, '').split('=')
          value[data[0]] = data[1] if data.length == 2
        end
        if /endif/.match(line.gsub(/\s\t\n/, '')) and start
          break
        end
      end
    end
    return dict
  end

  def HeadFile.dump(dest, info)
    template_path = File.join(File.expand_path('..', __FILE__), 'Sources/template')
    template_content = IO.read(template_path)
    template = Liquid::Template.parse(template_content)
    result = template.render('app' => info)
    IO.write(dest, result)
  end
end