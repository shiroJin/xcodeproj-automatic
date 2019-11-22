class PackageController < ApplicationController
  @@project_path = '/Users/remain/Desktop/script-work/ButlerForFusion'
  
  def git
    @git ||= Git.open(@@project_path)
  end

  def package
    app = App.find_app_with_branch(self.git.current_branch)
    distribution_configuration = XcodeProject.fetch_target_build_configuration(@@project_path, app.target_name)

    puts distribution_configuration
    target = app.target_name
    sign = distribution_configuration["CODE_SIGN_IDENTITY"]
    provision = distribution_configuration["PROVISIONING_PROFILE"]

    pod_install
    clean(target)
    archive_path = archive(target)
    ipa_path = export_archive(archive_path)

    render()
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
