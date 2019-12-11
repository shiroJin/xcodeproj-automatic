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

end