require "plist"

class PackageController < ApplicationController
  @@project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
  
  def git
    @git ||= Git.open(@@project_path)
  end

  def package
    app = App.find_app_with_branch(self.git.current_branch)
    distribution_configuration = XcodeProject.fetch_target_build_configuration(@@project_path, app.target_name)
    generate_export_plist(distribution_configuration, "enterprise")
    target = app.target_name

    pod_install
    clean(target)
    archive_path = archive(target)
    ipa_path = export_archive(archive_path)

    render()
  end

  def generate_export_plist(configuration, method)
    sign = configuration["CODE_SIGN_IDENTITY"]
    provision = configuration["PROVISIONING_PROFILE_SPECIFIER"]
    team = configuration["DEVELOPMENT_TEAM"]

    export_map = Map.new

    export_map["method"] = method
    export_map["provisioningProfiles"] = provision
    export_map["teamID"] = team
    export_map["compileBitcode"] = false

    IO.write("", export_map.to_plist)
  end

  def pod_install
    Dir.chdir(@@project_path) do
      IO.popen("pod install") { |result|
        puts result
      }
    end
  end

  def clean(scheme, configuration="Distribution")
    Dir.chdir(@@project_path) do
      workspace = Dir.entries(@@project_path).find { |e| e.index('workspace') }
      cmd = "xcodebuild clean -workspace #{workspace} -scheme #{scheme} -configuration #{configuration}"
      IO.popen(cmd) { |result|
        puts result
      }
    end
  end

  def archive(scheme, configuration="Distribution", archive_dir="~/Desktop")
    archive_path = File.join(archive_dir, "#{scheme}.xcarchive")
    Dir.chdir(@@project_path) do
      workspace = Dir.entries(@@project_path).find { |e| e.index('workspace') }
      cmd = "xcodebuild archive -workspace #{workspace} -scheme #{scheme} -configuration #{configuration} -archivePath #{archive_path}"
      IO.popen(cmd) { |result|
        puts result
      }
    end
    return archive_path
  end

  def export_archive(archive_path, export_dir="~/Desktop")
    Dir.chdir(@@project_path) do
      workspace = Dir.entries(@@project_path).find { |e| e.index('workspace') }
      cmd = "xcodebuild archive -workspace #{workspace} -scheme #{scheme} -configuration #{configuration} -archivePath #{archive_path}"
      IO.popen(cmd) { |result|
        puts result
      }
    end
  end

end
