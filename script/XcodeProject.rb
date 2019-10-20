require 'xcodeproj'
require 'json'
require 'plist'
require 'fileutils'
require_relative './HeadFile'
require_relative './ImageAsset'

module XcodeProject
  # return xcodeproj file name in directory
  def XcodeProject.xcodeproj_file(dir)
    file_name = Dir.entries(dir).find { |entry| entry.index('xcodeproj') }
    return File.join(dir, file_name)
  end

  # insert "target xxx do\n end" into podfile
  def XcodeProject.podfile_add_target(project_path, target_name)
    podfile_path = File.join(project_path, 'Podfile')
    content = ""
    IO.foreach(podfile_path) do |line|
      content += line
      if line.index("abstract_target")
        content += "target '#{target_name}' do\nend\n"
      end
    end
    IO.write(podfile_path, content)
  end

  # import header file in config file
  def XcodeProject.config_add_headfile(config_file_path, pre_process_macro, headfile_name)
    index, content = 0, ""
    IO.foreach(config_file_path) do |line|
      content += line
      if index == 1
        content += %Q{\n#ifdef #{pre_process_macro}\n#import "#{headfile_name}.h"\n#endif\n}
      end
      index += 1   
    end
    IO.write(config_file_path, content)
  end

  # create template target and private files
  def XcodeProject.create_target_template(project, target_name, company_code, src_name='ButlerForRemain')
    target = project.targets.find { |item| item.name == target_name }
    raise "❗target already existed" if target

    src_target = project.targets.find { |item| item.name == src_name }
    raise "❗src target is not existed" unless src_target

    target = project.new_target(src_target.symbol_type, target_name, src_target.platform_name, src_target.deployment_target)
    target.product_name = target_name

    src_target.build_phases.each do |src|
      klass = src.class
      dest = target.build_phases.find { |phase| phase.instance_of? klass }
      unless dest
        dest ||= project.new(klass)
        target.build_phases << dest
      end
      dest.files.map { |item| item.remove_from_project }
      
      src.files.each do |file|
        # ignore private files
        if file.file_ref.hierarchy_path.index("/Butler/ButlerForRemain")
          puts '-------- ignore ' + file.display_name
          next
        end
        if dest.instance_of? Xcodeproj::Project::Object::PBXFrameworksBuildPhase
          if file.display_name.index('libPods-CommonPods')
            puts '-------- ignore ' + file.display_name
            next
          end
        end
        dest.add_file_reference(file.file_ref, true)
      end
    end
    puts "🍺 copy build phase finished"

    src_target.build_configurations.each do |config|
      dest_config = target.build_configurations.find { |dest| dest.name == config.name }
      dest_config.build_settings.update(config.build_settings)
    end
    puts "🍺 copy build setting finished"

    private_group_name = "ButlerFor#{company_code.capitalize}"
    target_group_path = File.join(project_path, 'Butler', private_group_name)
    Dir.mkdir(target_group_path) unless File.exist? target_group_path
    private_group = project.main_group.find_subpath("Butler").new_group(nil, private_group_name)
    puts "created private group: ButlerFor#{company_code.capitalize}"

    pending_files = Array.new

    top_asset = "ImagesFor#{code.capitalize}.xcassets"
    top_assets_path = File.join(target_group_path, top_asset)
    ImageAsset.new_assets_group(top_assets_path)
    puts "created image assets: #{top_asset}"
    pending_files << top_asset
  
    plist_name = "#{company_code.capitalize}-info.plist"
    dest_plist_path = File.join(target_group_path, plist_name)
    src_build_settings = src_target.build_settings("Distribution")
    src_plist_path = src_build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', project_path)
    plist_hash = Plist.parse_xml(src_plist_path)
    IO.write(dest_plist_path, plist_hash.to_plist)
    puts "create plist file: #{plist_name}"
    pending_files << plist_name
    
    headfile_name = "SCAppConfigFor#{code.capitalize}Butler.h"
    headfile_path = File.join(target_group_path, headfile_name)
    IO.write(headfile_path, '')
    puts "created private headfile: #{headfile_name}"
    pending_files << headfile_name
    
    pending_resource_refs = Array.new
    pending_files.map { |file|
      ref = private_group.new_reference(file)
      pending_resource_refs << ref unless file.index('.h')
    }
    target.add_resources(pending_resource_refs)
    puts "create file indexes finished"
    puts "🍺 private files created finished"
    
    target.build_configurations.each do |config|
      build_settings = config.build_settings
      build_settings["INFOPLIST_FILE"] = dest_plist_path.gsub(project_path, '$(SRCROOT)')
      preprocess_defs = ["$(inherited)", "#{code.upcase}=1"]
      if config.name == 'Release'
        preprocess_defs.push("RELEASE=1")
      elsif config.name == 'Distribution'
        preprocess_defs.push("DISTRIBUTION=1")
      end
      build_settings["GCC_PREPROCESSOR_DEFINITIONS"] = preprocess_defs
    end
    
    podfile_add_target(project_path, target_name)
    puts "podfile added target"

    config_path = File.join(project_path, 'Butler', 'SCCommonConfig.h')
    config_add_headfile(config_path, company_code.upcase, "SCAppConfigFor#{code.capitalize}Butler")
    puts "common config file added private headfile: #{headfile_name}"
    
    project.save
    puts "🍺 project saved"

    return target
  end

  def XcodeProject.edit_target(target, update_info)
  end

  # create_target method do follow things for you
  # 1. create target from template
  # 2. copy build phase and build setttins from template, igonre template's private build files, 
  #    in addition, method will add a target's pre-preocess macro 
  # 3. make directory for new target, create plist file and headerfile which contains project's 
  #    configs, such as http address, jpush key, umeng key and etc. In addition, create imagset.
  # 4. edit Podfile file
  def XcodeProject.new_target(project_path, target_name, configuration, template_name="ButlerForRemain")
    code = configuration['kCompanyCode']
    xcodeproj_path = xcodeproj_file(project_path)
    project = Xcodeproj::Project.open(xcodeproj_path)
    target = project.targets.find { |item| item.name == target_name }
    raise '[Script] target already exist' if target

    # make native target
    puts '[Scirpt] create native target'
    src_target = project.targets.find { |item| item.name == template_name }
    target = project.new_target(src_target.symbol_type, target_name, src_target.platform_name, src_target.deployment_target)
    target.product_name = target_name

    # copy build source from template
    puts '[Scirpt] copy build phase'
    src_target.build_phases.each do |src|
      klass = src.class
      dest = target.build_phases.find { |phase| phase.instance_of? klass }
      unless dest
        dest ||= project.new(klass)
        target.build_phases << dest
      end
      dest.files.map { |item| item.remove_from_project }
      
      src.files.each do |file|
        # 过滤私有文件
        if file.file_ref.hierarchy_path.index("/Butler/ButlerForRemain")
          puts '-------- ignore ' + file.display_name
          next
        end
        if dest.instance_of? Xcodeproj::Project::Object::PBXFrameworksBuildPhase
          if file.display_name.index('libPods-CommonPods')
            puts '-------- ignore ' + file.display_name
            next
          end
        end
        dest.add_file_reference(file.file_ref, true)
      end
    end

    # copy build settings from source target
    puts '[Scirpt] copy build setting'
    src_target.build_configurations.each do |config|
      dest_config = target.build_configurations.find { |dest| dest.name == config.name }
      dest_config.build_settings.update(config.build_settings)
    end

    # group
    puts '[Scirpt] create private files'
    target_group_path = "#{project_path}/Butler/ButlerFor#{code.capitalize}"
    Dir.mkdir(target_group_path) unless File.exist? target_group_path
    group = project.main_group.find_subpath("Butler").new_group(nil, "ButlerFor#{code.capitalize}")

    pending_files = Array.new

    # image resource
    puts '[Script] copy image resource'
    icon_paths = configuration["images"]["AppIcon"]
    launch_paths = configuration["images"]["LaunchImage"]
    top_asset = "ImagesFor#{code.capitalize}.xcassets"
    top_assets_path = File.join(target_group_path, top_asset)
    ImageAsset.new_assets_group(top_assets_path)
    ImageAsset.new_icon(icon_paths, top_assets_path)
    ImageAsset.new_launch(launch_paths, top_assets_path)
    pending_files << top_asset

    # file resource
    puts '[Script] copy file resource'
    configuration["files"].map { |file, path|
      if not path.empty?
        dest_path = File.join(target_group_path, file)
        FileUtils.cp(path, dest_path)
        pending_files << file
      end
    }

    # plist
    plist_name = "#{code.capitalize}-info.plist"
    dest_plist_path = File.join(target_group_path, plist_name)
    src_build_settings = src_target.build_settings("Distribution")
    src_plist_path = src_build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', project_path)
    plist_hash = Plist.parse_xml(src_plist_path)
    pending_files << plist_name

    plist_hash["CFBundleDisplayName"] = configuration["CFBundleDisplayName"]
    plist_hash["CFBundleShortVersionString"] = configuration["CFBundleShortVersionString"]
    plist_hash["CFBundleVersion"] = configuration["CFBundleVersion"]
    # url types handle
    url_types = Array.new
    types = ['kWechatAppId', 'kTencentQQAppId', 'PRODUCT_BUNDLE_IDENTIFIER']
    types.each do |type|
      if not configuration[type].empty?
        identify, scheme = "", configuration[type]
        case type
        when 'kWechatAppId'
          identify = 'wx'
        when 'kTencentQQAppId'
          identify = 'tencent'
          scheme = 'tencent' + scheme
        when 'PRODUCT_BUNDLE_IDENTIFIER'
          identify = 'product'
        end
        url_type = Hash(
          'CFBundleTypeRole' => 'Editor', 
          'CFBundleURLName' => identify,
          'CFBundleURLSchemes' => Array[scheme]
        )
        url_types << url_type
      end
    end
    plist_hash["CFBundleURLTypes"] = url_types
    IO.write(dest_plist_path, plist_hash.to_plist)

    # header file
    distribution_hash = Hash.new
    ignore_fields = HeadFile.project_fields()
    configuration.each do |key, value|
      unless ignore_fields.include? key
        distribution_hash[key] = value
      end
    end
    headfile_hash = Hash["DISTRIBUTION" => distribution_hash]
    headfile_path = "#{target_group_path}/SCAppConfigFor#{code.capitalize}Butler.h"
    HeadFile.dump(headfile_path, headfile_hash)
    pending_files << "SCAppConfigFor#{code.capitalize}Butler.h"

    # new ref and build file in pbxproj
    pending_resource_refs = Array.new
    puts pending_files
    pending_files.map { |file|
      ref = group.new_reference(file)
      pending_resource_refs << ref unless file.index('.h')
    }
    puts pending_resource_refs
    target.add_resources(pending_resource_refs)

    # build settings
    puts '[Scirpt] build setting config'
    target.build_configurations.each do |config|
      build_settings = config.build_settings
      build_settings["INFOPLIST_FILE"] = dest_plist_path.gsub(project_path, '$(SRCROOT)')
      build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = configuration["PRODUCT_BUNDLE_IDENTIFIER"]
      preprocess_defs = ["$(inherited)", "#{code.upcase}=1"]
      if config.name == 'Release'
        preprocess_defs.push("RELEASE=1")
      elsif config.name == 'Distribution'
        preprocess_defs.push("DISTRIBUTION=1")
      end
      build_settings["GCC_PREPROCESSOR_DEFINITIONS"] = preprocess_defs
    end

    puts '[Scirpt] Edit podfile'
    podfile_add_target(project_path, target_name)

    puts '[Scirpt] Edit CommonConfig'
    config_path = File.join(project_path, 'Butler', 'SCCommonConfig.h')
    config_add_headfile(config_path, code.upcase, "SCAppConfigFor#{code.capitalize}Butler")

    project.save

    # 执行pod install
    puts '[Scirpt] excute pod install'
    # Dir.chdir(project_path)
    # exec 'pod install --silent'

  end

  # allow you to edit project's config, such as http address, project version, build version, etc.
  def XcodeProject.edit_project(project_path, target_name, configuration)
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))
    target = project.targets.find { |item| item.name == target_name }
    raise "[Script] target #{target_name} not exist" unless target
    
  end

  # fetch target info from project
  def XcodeProject.fetch_target_info(proj_path, private_group_name, target_name)
    info = Hash.new

    proj = Xcodeproj::Project.open(xcodeproj_file(proj_path))
    target = proj.targets.find { |target| target.display_name == target_name }
    build_settings = target.build_settings('Distribution')
    
    plist_path = build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', proj_path)
    info_plist = Plist.parse_xml(plist_path)
    fields =['CFBundleDisplayName', 'CFBundleShortVersionString', 'CFBundleVersion']
    fields.each do |field|
      info[field] = info_plist[field]
    end

    private_group = File.join(proj_path, 'Butler', private_group_name)
    headfile_name = Dir.entries(private_group).find { |e| e.index(".h") }
    headfile_path = File.join(private_group, headfile_name)
    headerfile = HeadFile.load(headfile_path)
    info = info.merge(headerfile["DISTRIBUTION"])

    assets_info = Hash.new
    xcassets = File.join(private_group, Dir.entries(private_group).find { |e| e.index("xcassets") })
    Dir.entries(xcassets).each do |entry|
      filename = entry.split('.').first
      extname = entry.split('.').last
      absolute_path = File.join(xcassets, entry)
      if ['appiconset', 'launchimage', 'imageset'].include? extname
        path = File.join(absolute_path, Dir.entries(absolute_path).find { |f| f.index('png') })
        assets_info[filename] = path
      end
    end
    info['images'] = assets_info
    return info    
  end

end