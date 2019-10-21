class App
  attr_accessor :display_name, :target_name, :private_group, :assets, :headfile
  def initialize(hash)
    @display_name = hash["DisplayName"]
    @target_name = hash["targetName"]
    @private_group = hash["PrivateGroup"]
    @assets = hash["assets"]
    @headfile = hash["headfile"]
  end
end