require 'Liquid'

module HeadFile

  def HeadFile.load(file_path)
    return Hash.new unless File.readable?(file_path)

    hash = Hash.new
    dict = { "DEBUG" => Hash.new, "RELEASE" => Hash.new, "DISTRIBUTION" => Hash.new }
    dict.each do |method, configuration|
      start = false
      IO.foreach(file_path) do |line|
        if (/ifdef#{method}/.match(line.gsub(/\s/, '')))
          start = true
          next
        end
        if start && line.index('NSString')
          data = line.gsub(/\s/, '').gsub(/(staticNSString\*(const)?|@"|"|;|\n)/, '').split('=')
          key, value = data
          configuration[key] = value ? value : ""
        end
        if /endif/.match(line.gsub(/\s\t\n/, '')) and start
          break
        end
      end
    end
    return dict
  end

  def HeadFile.dump(dest, info)
    template_path = Rails.root.join('public', 'headfile_template')
    template_content = IO.read(template_path)
    template = Liquid::Template.parse(template_content)
    result = template.render('app' => info)
    IO.write(dest, result)
  end
end