require "plist"
require "pty"

class PackageController < ApplicationController
  # @@project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
  @@project_path = '/Users/remain/Desktop/script-work/BusinessAssistantForFusion'
  
  def git
    @git ||= Git.open(@@project_path)
  end

  def package(method="enterprise")
    # app = App.find_app_with_branch(self.git.current_branch)
    # target = app.target_name
    distribution_configuration = XcodeProject.fetch_target_build_configuration(@@project_path, 'BusinessAssistantForRemain')
    export_plist_path = generate_export_plist(distribution_configuration, method)
    target = "BusinessAssistantForRemain"

    Dir.chdir(@@project_path) do
      pod_install
      # archive_path = archive(target)
      # ipa_path = export_archive(archive_path, export_plist_path)
    end

    render()
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

    export_plist_path = "/Users/remain/Desktop/script-work/BusinessAssistantForFusion/build/export.plist"
    IO.write(export_plist_path, export_hash.to_plist)
    return export_plist_path
  end

  def pod_install
    new_env = {
      'GEM_HOME'=>'/Users/remain/.rvm/gems/ruby-2.6.3',
      'GEM_PATH'=>'/Users/remain/.rvm/gems/ruby-2.6.3:/Users/remain/.rvm/gems/ruby-2.6.3@global',
      'BUNDLE_BIN_PATH'=>'',
      'BUNDLE_GEMFILE'=> '',
    }
    IO.popen(new_env, "pod install") { |result|
      result.each { |line| print line }
    }
  end

  def archive(scheme, configuration="Release", archive_dir="build")
    archive_path = File.join(archive_dir, "#{scheme}.xcarchive")
    workspace = Dir.entries(@@project_path).find { |e| e.index('workspace') }
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
    workspace = Dir.entries(@@project_path).find { |e| e.index('workspace') }
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
