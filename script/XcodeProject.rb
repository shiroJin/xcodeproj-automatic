require 'xcodeproj'
require 'json'
require 'plist'
require 'fileutils'
require_relative './HeadFile'
require_relative './ImageAsset'
require_relative './app'

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
  def XcodeProject.create_target_template(project, target_name, company_code, src_name)
    target = project.targets.find { |item| item.name == target_name }
    raise "❗target already existed" if target

    src_target = project.targets.find { |item| item.name == src_name }
    raise "❗src target is not existed" unless src_target

    target = project.new_target(src_target.symbol_type, target_name, src_target.platform_name, src_target.deployment_target)
    target.product_name = target_name
    puts "🐶new target #{target_name}"

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
    puts "🐶copy build phase finished"

    src_target.build_configurations.each do |config|
      dest_config = target.build_configurations.find { |dest| dest.name == config.name }
      dest_config.build_settings.update(config.build_settings)
    end
    puts "🐶copy build setting finished"

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
    puts "connect file indexes finished"
    puts "🐶private files created finished"
    
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
    puts "🍺🍺🍺 project saved, target create succeed"
    return target
  end

  def XcodeProject.edit_target(project, app, update_info)
    target = project.targets.find { |item| item.name == app.target_name }
    # image resource
    assets_path = app.assets
    icon_paths = update_info["images"]["AppIcon"]
    launch_paths = update_info["images"]["LaunchImage"]
    ImageAsset.new_icon(icon_paths, assets_path)
    ImageAsset.new_launch(launch_paths, assets_path)
    # file resource
    pending_files = Array.new
    configuration["files"].map { |file, path|
      if not path.empty?
        dest_path = File.join(target_group_path, file)
        FileUtils.cp(path, dest_path)
        pending_files << file
      end
    }
    target.add_resources(pending_files)
    # info.plist
    build_settings = target.build_settings('Distribution')
    plist_path = build_settings["INFOPLIST_FILE"].gsub('$(SRCROOT)', proj_path)
    info_plist = Plist.parse_xml(plist_path)
    plist_hash["CFBundleDisplayName"] = update_info["CFBundleDisplayName"] if update_info["CFBundleDisplayName"]
    plist_hash["CFBundleShortVersionString"] = configuration["CFBundleShortVersionString"] if update_info["CFBundleShortVersionString"]
    plist_hash["CFBundleVersion"] = configuration["CFBundleVersion"] if update_info["CFBundleVersion"]
    # url types
    url_types = info_plist["CFBundleURLTypes"]
    unless url_types
      url_types = Array.new
      info_plist["CFBundleURLTypes"] = url_types
    end
    types = {
             'kWechatAppId' => 'wx', 
             'kTencentQQAppId' => 'tencent', 
             'PRODUCT_BUNDLE_IDENTIFIER' => 'product'
            }
    types.map { |key, identify|
      scheme = update_info[key]
      if scheme
        url_type = url_types.find { |item| item['CFBundleURLName'] == identify }
        unless url_types
          url_type = {
                      'CFBundleTypeRole' => 'Editor', 
                      'CFBundleURLName' => identify, 
                      'CFBundleURLSchemes' => Array.new
                     }
          url_types << url_type
        end
        scheme = 'tencent' + scheme if identify == 'tencent'
        url_type['CFBundleURLSchemes'] = Array[scheme]
      end
    }
    IO.write(dest_plist_path, plist_hash.to_plist)

    # headfile
    headerfile = HeadFile.load(app.headfile)
    distribution_hash = headfile["DISTRIBUTION"]
    headfile_fields = ['kDistributioneBaseCommonUrl', 'kJPushAppKeyString', 'kJPushChannelID', 'kUMengAppKeyString', 'kUMengChannelID', 'kWechatAppId', 'kWechatAppKey', 'kTencentQQAppId', 'kTencentQQAppKey', 'kAPIVersion', 'kAPISalt', 'kMobiletype', 'kCompanyCode', 'kVersionCheckType', 'kIDCardScanDevcode', 'kPlateNumberScanDevcode']
    headfile_fields.map { |field|
      value = update_info[field]
      value = '' unless value
      distribution_hash[field] = value
    }
    HeadFile.dump(app.headfile, headfile_hash)

    # build settings
    bundle_id = update_info['PRODUCT_BUNDLE_IDENTIFIER']
    if bundle_id
      target.build_configurations.each do |config|
        build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
      end
    end

    project.save
  end

  # create_target method do follow things for you
  # 1. create target from template, copy build phase and build settings from template, igonre template's private 
  #    build files. In addition, method will add a target's pre-preocess macro 
  # 2. make private directory, create plist file and headerfile which contains project's 
  #    configs, such as http address, jpush key, umeng key and etc. In addition, create imagset.
  # 4. edit Podfile file, common config file
  def XcodeProject.new_target(project_path, configuration, template_name="ButlerForRemain")
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))
    company_code = configuration['kCompanyCode']
    target_name = "ButlerFor#{company_code.capitalize}"
    create_target_template(project, target_name, company_code, template_name)
    edit_target()
  end

  # allow you to edit project's config, such as http address, project version, build version, etc.
  def XcodeProject.edit_project(project_path, target_name, update_info)
    project = Xcodeproj::Project.open(xcodeproj_file(project_path))
    target = project.targets.find { |item| item.name == target_name }
    raise "❗target #{target_name} not exist" unless target
    
    edit_project(project)
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