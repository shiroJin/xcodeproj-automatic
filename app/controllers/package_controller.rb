require "plist"
require "pty"

class PackageController < ApplicationController
  # project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'

  def package()
    # project_path = '/Users/remain/Desktop/script-work/BusinessAssistantForFusion'
    project_path = '/Users/mashiro_jin/Desktop/LMWork/BusinessAssistantForFusion'
    exec_package(project_path, 'BusinessAssistantForRemain')
  end

  def exec_package(project_path, target, method="enterprise")
    configuation = XcodeProject.build_configuration(project_path, target)

    Dir.chdir(project_path) do
      archive_dir = mkdir_archive()
      export_plist_path = File.join(archive_dir, 'export.plist')
      archive_path = File.join(archive_dir, "#{target}.xcarchive")
      export_path = File.join(archive_dir, target)

      pod_install
      archive(target, archive_path)
      generate_export_plist(configuration, method, export_plist_path)
      ipa_path = export_archive(archive_path, export_plist_path)
    end

    render()
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

  def generate_export_plist(configuration, method)
    sign = configuration["CODE_SIGN_IDENTITY"]
    provision = configuration["PROVISIONING_PROFILE_SPECIFIER"]
    team = configuration["DEVELOPMENT_TEAM"]
    certificate = configuration["CODE_SIGN_IDENTITY"]
    bundle_id = configuration["PRODUCT_BUNDLE_IDENTIFIER"]

    export_hash = Hash.new
    export_hash["signingStyle"] = "manual"
    export_hash["compileBitcode"] = false
    export_hash["method"] = method
    export_hash["teamID"] = team
    export_hash["signingCertificate"] = certificate
    export_hash["provisioningProfiles"] = { bundle_id => provision }

    IO.write(export_plist_path, export_hash.to_plist)
  end

  def pod_install
    gem_home = ENV["GEM_HOME"]
    env = {
      'GEM_HOME' => gem_home,
      'GEM_PATH' => gem_home,
      'BUNDLE_BIN_PATH' => '',
      'BUNDLE_GEMFILE' => '',
    }
    IO.popen(env, "pod install") { |result|
      result.each { |line| print line }
    }
  end

  def archive(scheme, archive_path, configuration="Release")
    workspace = Dir.entries(project_path).find { |e| e.index('workspace') }
    cmd = "xcodebuild clean archive -workspace #{workspace} -scheme #{scheme} -configuration #{configuration} -archivePath #{archive_path}"
    begin
      PTY.spawn(cmd) do |stdout, stdin, pid|
        begin
          stdout.each { |line| print line }
        rescue Errno::EIO
          puts "Errno:EIO error, but this probably just means " + "that the process has finished giving output"
        end
      end
    rescue PTY::ChildExited
      puts "The child process exited!"
    end
    return archive_path
  end

  def export_archive(archive_path, export_plist_path, export_dir="build")
    workspace = Dir.entries(project_path).find { |e| e.index('workspace') }
    export_path = File.join(export_dir, "BusinessAssistantForRemain")
    cmd = "xcodebuild -exportArchive -archivePath #{archive_path} -exportPath #{export_path} -exportOptionsPlist #{export_plist_path}"
    begin
      PTY.spawn(cmd) do |stdout, stdin, pid|
        begin
          stdout.each { |line| print line }
        rescue Errno::EIO
          puts "Errno:EIO error, but this probably just means " + "that the process has finished giving output"
        end
      end
    rescue PTY::ChildExited
      puts "The child process exited!"
    end
  end

end
