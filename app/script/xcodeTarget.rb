module XcodeProject
  class XcodeTarget
    attr :name, :branch
    def initialize(args)
      @name = args["name"]
      @branch = args["branch"]
    end
  end
end
