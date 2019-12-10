module XcodeProject

  class TargetConfiguration
    attr_reader :target, :private_group, :image_assets, :headfile

    def initialize(hash)
      @private_group = hash["privateGroup"]
      @image_assets = hash["assets"]
      @headfile = hash["headfile"]
      @target = hash["targetName"]
    end
  end

end
