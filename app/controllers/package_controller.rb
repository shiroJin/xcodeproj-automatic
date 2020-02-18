require "plist"

class PackageController < ApplicationController

  def package()
    project_path = '/Users/panjiafei/freeMyMac/workspace/ButlerForFusion'
    package_result = exec_package(project_path, 'ButlerForRemain')
    render :json => package_result
  end

  def exec_package(project_path, target, method="enterprise")
    unlock_login_keychain
    configuration = XcodeProject.build_configuration(project_path, target)

    result = Hash.new
    Dir.chdir(project_path) do
      archive_dir = mkdir_archive()
      export_plist_path = File.join(archive_dir, 'export.plist')
      archive_path = File.join(archive_dir, "#{target}.xcarchive")
      export_path = File.join(archive_dir, target)

      pod_install

      archive(target, archive_path)
      raise "archive failed" unless File.exist? archive_path

      generate_export_plist(configuration, method, export_plist_path)
      raise "generate export plist failed" unless File.exist? export_plist_path

      export_archive(archive_path, export_plist_path, export_path)
      raise "export archive failed" unless export_path

      result["archivePath"] = archive_path
      result["exportPlist"] = export_plist_path
      result["exportPath"] = export_path
    end

    return result
  end

  def unlock_login_keychain
    cmd = "security unlock-keychain -p Uama123 ~/Library/Keychains/login.keychain"
    IO.popen(cmd) { |std|
      puts std.read
    }
  end

  def generate_export_plist(configuration, method, export_plist_path)
    sign = configuration["CODE_SIGN_IDENTITY"]
    provision = configuration["PROVISIONING_PROFILE_SPECIFIER"]
    team = configuration["DEVELOPMENT_TEAM"]
    bundle_id = configuration["PRODUCT_BUNDLE_IDENTIFIER"]

    export_hash = Hash.new
    export_hash["destination"] = "export"
    export_hash["signingStyle"] = "manual"
    export_hash["compileBitcode"] = false
    export_hash["method"] = method
    export_hash["teamID"] = team
    export_hash["signingCertificate"] = sign
    export_hash["provisioningProfiles"] = { bundle_id => provision }
    export_hash["thinning"] = "<none>"

    IO.write(export_plist_path, export_hash.to_plist)
  end

  def pod_install
    rvm_path = ENV["rvm_path"]
    env = {
      'GEM_HOME' => "#{rvm_path}/gems/ruby-2.6.3",
      'GEM_PATH' => "#{rvm_path}/gems/ruby-2.6.3",
      'BUNDLE_BIN_PATH' => '',
      'BUNDLE_GEMFILE' => '',
    }
    Open3.popen3(env, 'pod install') { |stdin, stdout, stderr, wait_thr|
      stdout.each { |line| print line }
    }
  end

  def archive(scheme, archive_path, configuration="Release")
    workspace = Dir.entries(Dir.pwd).find { |e| e.index('workspace') }
    cmd = "xcodebuild clean archive -workspace #{workspace} -scheme #{scheme} -configuration #{configuration} -archivePath #{archive_path}"
    Open3.popen3(cmd) { |i, o, e, t|
      puts o.each{ |line| print line }
    }
    return archive_path
  end

  def export_archive(archive_path, export_plist_path, export_path)
    cmd = "xcodebuild -exportArchive -archivePath #{archive_path} -exportPath #{export_path} -exportOptionsPlist #{export_plist_path}"
    Open3.popen3(cmd) { |i, o, e, t|
      puts o.each{ |line| print line }
    }
  end

  def mkdir_archive
    build_dir = make_build_dir_if_needed
    time = DateTime.now.strftime('%Y%m%d-%T')
    archive_dir = File.join(build_dir, time)
    unless Dir.exist? archive_dir
      Dir.mkdir(archive_dir)
    end
    return archive_dir
  end

  def make_build_dir_if_needed
    build_dir = File.join(Dir.pwd, 'build')
    unless Dir.exist? build_dir
      Dir.mkdir(build_dir)
    end
    return build_dir
  end

end
