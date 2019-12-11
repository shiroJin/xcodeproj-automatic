module Repository

  class Repository
    attr_accessor :remote_url, :name
    def initialize(name, remote_url)
      @remote_url = remote_url
      @name = name
    end
  end

end