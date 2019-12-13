require 'xcodeproj'
require 'json'
require 'plist'
require 'fileutils'
require_relative './HeadFile'
require_relative './ImageAsset'

module XcodeProject

  class ProjectForm
    attr_accessor :pbxproj, :plist, :headfile, :image_assets, :files

    def initialize(hash)
      @pbxproj = hash["pbxproj"]
      @plist = hash["plist"]
      @headfile = hash["headfile"]
      @image_assets = hash["imageAssets"]
      @files = hash["files"]
    end

  end

  class TargetConfiguration
    attr_accessor :target, :private_group, :image_assets, :headfile, :store, :identify

    def initialize(hash)
      @private_group = hash["privateGroup"]
      @image_assets = hash["imageAssets"]
      @headfile = hash["headfile"]
      @target = hash["targetName"]
      @store = hash["store"]
      @identify = hash["identify"]
    end
  end

  IMAGE_ASSETS_EXT = ['imageset', 'appiconset', 'launchimage']

  # find xcodeproj file
  #
  # @return xcodeproj file name in directory
  # @param [PathString] dir
  #
  def XcodeProject.xcodeproj_file(dir)
    file_name = Dir.entries(dir).find { |entry| entry.index('xcodeproj') }
    return File.join(dir, file_name)
  end

  # insert "target xxx do\n end" into podfile
  #
  # @param [String] project_path
  # @param [String] target 
  #
  def XcodeProject.podfile_add_target(project_path, target)
    podfile_path = File.join(project_path, 'Podfile')
    content = ""
    IO.foreach(podfile_path) do |line|
      content += line
      if line.index("abstract_target")
        content += "target '#{target}' do\nend\n"
      end
    end
    IO.write(podfile_path, content)
  end

  # import header file in config file
  #
  def XcodeProject.config_add_headfile(config_file_path, pre_process_macro, headfile_name)
    index, content = 0, ""
    IO.foreach(config_file_path) do |line|
      content += line
      if index == 1
        content += %Q{\n#ifdef #{pre_process_macro}\n#import "#{headfile_name}"\n#endif\n}
      end
      index += 1   
    end
    IO.write(config_file_path, content)
  end

  # add file into target, if file is existed, replace it. if file is not existed, new file_ref and build_file
  #
  # @param [PBXTarget] pbxtarget
  # @param [String] filename
  # @param [PathString] filepath
  # @param [PBXGroup] pbxgroup
  #
  def self.target_add_resouce(project_path, pbxtarget, filename, filepath, pbxgroup)
    files = pbxtarget.resources_build_phase.files
    file = files.find { |f| f.display_name == filename }

    if filepath.empty? && file
      target.resources_build_phase.remove_build_file(file)
    end

    if filepath && file
      dest = File.join(project_path, file.file_ref.full_path)
      FileUtils.cp(filepath, dest)
    end

    if filepath && !file
      dest_path = File.join(project_path, pbxgroup.full_path, filename)
      FileUtils.cp(filepath, dest)
      file_ref = pbxgroup.new_reference(filename)
      pbxtarget.add_resources([file_ref])
    end
  end

  # put images into image assets
  #
  # @param [PathString] assets_dir
  # @param [String] name
  # @param [Array] paths
  #
  def self.target_add_image(assets_dir, name, paths)
    if name == "AppIcon"
      ImageAsset.new_icon(paths, assets_dir)
    elsif name == "LaunchImage"
      ImageAsset.new_launch(paths, assets_dir)
    else
      ImageAsset.add_imageset(name, paths, assets_dir)
    end
  end

  # 根据路径返回文件组
  #
  # @param [PBXProject] project
  # @param [PathString] group_path
  #
  def self.pbxgroup(project, group_path, create=false)
    subPaths = group_path.split('/')
    group = project.main_group

    while subPaths.length > 0
      name = subPaths.shift
      child = group.groups.find { |g| g.display_name == name }
      if !child && create
        group = group.new_group(nil, name)
        Dir.mkdir(group.real_path) unless File.exist? group.real_path
      else
        group = child
      end
    end

    return group
  end

  # create target
  #
  # @param [String] project_path
  # @param [TargetConfiguration] configuration
  # @param [String] template_name
  #
  def self.create_target(project_path, configuration, template_name="ButlerForRemain")
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))

    if project.targets.find { |t| t.display_name == configuration.target }
      raise "❗target already existed" if target
    end

    src_target = project.targets.find { |item| item.name == template_name }
    unless src_target
      raise "❗src target is not existed"
    end

    target = project.new_target(src_target.symbol_type, configuration.target, src_target.platform_name, src_target.deployment_target)
    target.product_name = configuration.target
    puts "Step 1: new target #{target}"

    src_target.build_phases.each do |src|
      klass = src.class
      dest = target.build_phases.find { |phase| phase.instance_of? klass }
      unless dest
        dest ||= project.new(klass)
        target.build_phases << dest
      end
      dest.files.map { |item| item.remove_from_project }
      
      src.files.each do |file|
        if file.file_ref.hierarchy_path.index("/Butler/ButlerForRemain")
          puts '-------- ignore ' + file.display_name
          next
        end
        if dest.instance_of? Xcodeproj::Project::Object::PBXFrameworksBuildPhase
          if file.display_name.include? "libPods-CommonPods"
            puts '-------- ignore ' + file.display_name
            next
          end
        end
        dest.add_file_reference(file.file_ref, true)
      end
    end
    puts "Step 2: copy build phase"

    src_target.build_configurations.each do |config|
      dest_config = target.build_configurations.find { |dest| dest.name == config.name }
      dest_config.build_settings.update(config.build_settings)
    end
    puts "Step 3: copy build setting"

    private_group = pbxgroup(project, configuration.private_group, create=true)
    puts "Step 4: created private group: #{configuration.private_group}"

    imageset_group_path = File.join(project.main_group.real_path, configuration.image_assets)
    ImageAsset.new_assets_group(imageset_group_path)
    imageset = private_group.new_reference(imageset_group_path.split('/').last)
    target.add_resources([imageset])
    puts "Step 5: created imagesets: #{configuration.image_assets}"
  
    plist_name = "#{configuration.target}-Info.plist"
    src_build_settings = src_target.build_settings("Distribution")
    src_plist_path = src_build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', project_path)
    plist_hash = Plist.parse_xml(src_plist_path)
    IO.write(File.join(private_group.real_path, plist_name), plist_hash.to_plist)
    private_group.new_reference(plist_name)
    puts "Step 6: create plist file: #{plist_name}"
    
    headfile_path = File.join(project.main_group.real_path, configuration.headfile)
    unless File.exist? headfile_path
      IO.write(headfile_path, '')
      private_group.new_reference(configuration.headfile)
    end
    puts "Step 7: created private headfile: #{configuration.headfile}"
    
    target.build_configurations.each do |config|
      build_settings = config.build_settings
      build_settings["INFOPLIST_FILE"] = File.join('$(SRCROOT)', configuration.private_group, plist_name)
      preprocess_defs = ["$(inherited)"]
      if config.name == 'Release'
        preprocess_defs << "RELEASE=1"
      elsif config.name == 'Distribution'
        preprocess_defs << "DISTRIBUTION=1"
      end
      preprocess_defs << "#{configuration.identify.upcase}=1"
      if configuration.store
        preprocess_defs << "STORE=1"
      end
      build_settings["GCC_PREPROCESSOR_DEFINITIONS"] = preprocess_defs
    end
    
    podfile_add_target(project_path, configuration.identify)
    config_path = File.join(project_path, 'Butler', 'SCCommonConfig.h')
    config_add_headfile(config_path, configuration.identify.upcase, configuration.headfile)
    
    project.save
    puts "🍺🍺🍺 project saved, target create succeed"
  end

  # edit target
  #
  # @param [String] project_path
  # @param [TargetConfiguration] target_configuration
  # @param [ProjectForm] form
  #
  def XcodeProject.edit_target(project_path, target_configuration, form)
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))
    target = project.targets.find { |item| item.name == target_configuration.target }
    private_group = pbxgroup(project, target_configuration.private_group)
    raise "❗target #{target_name} not exist" unless target

    # handle image resource
    assets_path = File.join(project_path, target_configuration.image_assets)
    if images = form.image_assets
      images.map do |name, paths|
        target_add_image(assets_path, name, paths)
      end
    end

    # handle file resource
    if files = form.files
      files.map do |name, path|
        target_add_resouce(project_path, target, name, path, private_group)
      end
    end

    # info.plist
    if plist = form.plist
      build_settings = target.build_settings("Distribution")
      plist_path = build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', project_path)
      info_plist = Plist.parse_xml(plist_path)

      if display_name = form.plist["CFBundleDisplayName"]
        info_plist["CFBundleDisplayName"] = form["CFBundleDisplayName"] 
      end
      if short_version = form.plist["CFBundleShortVersionString"]
        info_plist["CFBundleShortVersionString"] = short_version
      end
      if build_version = form.plist["CFBundleVersion"]
        info_plist["CFBundleVersion"] = build_version
      end
      
      url_types = info_plist["CFBundleURLTypes"]
      unless url_types
        url_types = Array.new
        info_plist["CFBundleURLTypes"] = url_types
      end
      types = { 'kWechatAppId' => 'wx', 
                'kTencentQQAppId' => 'tencent', 
                'PRODUCT_BUNDLE_IDENTIFIER' => 'product' }
      types.map { |key, identify|
        if scheme = target_configuration.headfile[key]
          url_type = url_types.find { |item| item['CFBundleURLName'] == identify }
          unless url_type
            url_type = { 'CFBundleTypeRole' => 'Editor', 
                        'CFBundleURLName' => identify, 
                        'CFBundleURLSchemes' => Array.new }
            url_types << url_type
          end
          if identify == 'tencent'
            scheme = 'tencent' + scheme
          end
          url_type['CFBundleURLSchemes'] = Array[scheme]
        end
      }
      IO.write(plist_path, info_plist.to_plist)
    end

    # handle headfile
    if headfile_form = form.headfile
      headfile = HeadFile.load(File.join(project_path, target_configuration.headfile))
      distribution_hash = headfile["DISTRIBUTION"]
      unless distribution_hash
        headfile["DISTRIBUTION"] = hash.new
        distribution_hash = headfile["DISTRIBUTION"]
      end
      headfile_form.each do |key, value|
        distribution_hash[key] = value
      end
      HeadFile.dump(File.join(project_path, target_configuration.headfile), headfile)
    end

    # handle xcode params
    if pbxproj_info = form.pbxproj
      pbxproj_info.each do |key, value|
        target.build_configurations.each do |config|
          config.build_settings[key] = value
        end
      end
    end

    project.save

  end

  # create_target method do follow things for you
  # 1. create target from template, copy build phase and build settings, 
  # 2. make private directory, plist file, headerfile and imagset.
  # 3. edit Podfile file, common config file
  #
  # @param [String] project_path
  # @param [Hash] configuration
  # @param [Hash] form
  #
  def XcodeProject.new_target(project_path, configuration, form)
    configuration = TargetConfiguration.new(configuration)
    form = ProjectForm.new(form)
    create_target(project_path, configuration)
    edit_target(project_path, configuration, form)
  end

  # edit project's config, such as http address, project version, build version, etc.
  #
  # @param [String] project_path
  # @param [String] company_code
  # @param [Hash] form
  #
  def XcodeProject.edit_project(project_path, company_code, form)
    app = App.find_app(company_code)
    form = ProjectForm.new(form)
    configuration = TargetConfiguration.new(app.enterprise_configuration)
    edit_target(project_path, configuration, form)
  end

  # fetch target info from project
  #
  # @param [String] project_path
  # @param [Hash] configuration
  #
  def self.fetch_target_info(project_path, configuration)
    target_configuration = TargetConfiguration.new(configuration)
    standard_form = JSON.load(Rails.root.join('public', 'butler_form.json'))

    proj = Xcodeproj::Project.open(xcodeproj_file(project_path))
    target = proj.targets.find { |target| target.display_name == target_configuration.target }
    build_settings = target.build_settings('Distribution')
    
    # pbxproj information
    pbxproj_info = Hash.new
    pbxproj_info["PRODUCT_BUNDLE_IDENTIFIER"] = build_settings["PRODUCT_BUNDLE_IDENTIFIER"]
    pbxproj_info["CODE_SIGN_IDENTITY"] = build_settings['CODE_SIGN_IDENTITY']
    pbxproj_info['PROVISIONING_PROFILE_SPECIFIER'] = build_settings['PROVISIONING_PROFILE_SPECIFIER']
    standard_form["pbxproj"].merge!(pbxproj_info)

    # plist information
    plist_info = Hash.new
    plist_path = build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', project_path)
    info_plist = Plist.parse_xml(plist_path)
    fields =['CFBundleDisplayName', 'CFBundleShortVersionString', 'CFBundleVersion']
    fields.each do |field|
      plist_info[field] = info_plist[field]
    end
    # in xcode 11, CFBundleShortVersionString may get $(MARKETING_VERSION), CFBundleVersion get
    # $(CURRENT_PROJECT_VERSION)
    if plist_info['CFBundleShortVersionString'] == '$(MARKETING_VERSION)'
      plist_info['CFBundleShortVersionString'] = build_settings['MARKETING_VERSION']
    end
    if plist_info['CFBundleVersion'] == '$(CURRENT_PROJECT_VERSION)'
      plist_info['CFBundleVersion'] = build_settings['CURRENT_PROJECT_VERSION']
    end
    standard_form["plist"].merge!(plist_info)

    # headfile information
    headfile_path = File.join(project_path, target_configuration.headfile)
    headfile = HeadFile.load(headfile_path)
    headfile_info = headfile["DISTRIBUTION"]
    standard_form["headfile"].merge!(headfile_info)

    # image asset information
    assets_info = Hash.new
    image_assets_path = File.join(project_path, target_configuration.image_assets)
    Dir.entries(image_assets_path).each do |entry|
      filename, extname = entry.split('.')
      absolute_path = File.join(image_assets_path, entry)
      if IMAGE_ASSETS_EXT.include? extname
        content_path = File.join(absolute_path, 'Contents.json')
        if File.exist? content_path
          content_json = JSON.load(File.open(content_path))
          assets = Array.new
          content_json["images"].each do |item|
            value = '#{domain}/projectFile?src=' + File.join(absolute_path, item['filename'])
            assets << value
          end
          assets_info[filename] = assets
        end
      end
    end
    standard_form['imageAssets'].merge!(assets_info)

    # file information
    files_info = standard_form["files"]
    files_info.keys.each do |filename|
      file = target.resources_build_phase.files.find { |f| f.display_name == filename }
      if file
        file_path = File.join(project_path, file.file_ref.full_path)
        files_info[filename] = remoteUrl(file_path)
      end
    end
    standard_form['files'].merge!(files_info)

    return standard_form
  end

  def self.remoteUrl(file_path)
    return '#{domain}/projectFile?src=' + file_path
  end

  def XcodeProject.build_configuration(project_path, target_name, name="Distribution")
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))
    target = project.targets.find { |t| t.display_name == target_name }
    raise "❗target #{target_name} not exist" unless target
    build_configuration = target.build_configurations.find { |b| b.name == name }
    raise "❗build_configuration #{name} not exist" unless build_configuration
    return build_configuration.build_settings
  end

end