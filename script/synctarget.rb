#!/usr/bin/ruby
require 'xcodeproj'

class Slot
  attr_accessor :value, :file_ref
  def initialize
    @value = 0
    @file_ref = nil
  end
end

def files_diff(files1, files2)
  hash = Hash.new
  files1.map do |file|
    slot = hash[file.file_ref.uuid]
    unless slot
      slot = Slot.new
      slot.file_ref = file.file_ref
      hash[file.file_ref.uuid] = slot
    end
    slot.value += 1
  end

  files2.map do |file|
    slot = hash[file.file_ref.uuid]
    unless slot
      slot = Slot.new
      slot.file_ref = file.file_ref
      hash[file.file_ref.uuid] = slot
    end
    slot.value += 2
  end

  result1, result2 = Array.new, Array.new
  hash.map{ |key,value|
    if value.value == 1
      result1<<value.file_ref
    elsif value.value == 2
      result2<<value.file_ref
    end
  }
  return [result1, result2]
end

ignore_path = 'Butler/ButlerForRemain'

# input
proj_path = Dir.entries(Dir.getwd).find { |f| f.index('xcodeproj') }
raise "this's no xcodeproj" unless proj_path
target1_name, target2_name = ARGV
raise "parameter missing" unless target1_name and target2_name

proj = Xcodeproj::Project.open(proj_path)
target1 = proj.targets.find { |t| t.display_name == target1_name }
target2 = proj.targets.find { |t| t.display_name == target2_name }

raise "target going missing" unless target1 and target2

# build resources
target1_resource = target1.build_phases.find { |p| p.instance_of? Xcodeproj::Project::Object::PBXResourcesBuildPhase }
target2_resource = target2.build_phases.find { |p| p.instance_of? Xcodeproj::Project::Object::PBXResourcesBuildPhase }

result1, result2 = files_diff(target1_resource.files, target2_resource.files)
puts "build resource diff:"
puts ">>>>> #{target1_name}\n#{result1.sort}\n===== #{target2_name}\n#{result2.sort}\n<<<<<"
pending = resutl1.select do |ref|
  !ref.full_path.include? ignore_path
end
target2.add_resources(pending)

# build files
source_1 = target1.build_phases.find { |p| p.instance_of? Xcodeproj::Project::Object::PBXSourcesBuildPhase }
source_2 = target2.build_phases.find { |p| p.instance_of? Xcodeproj::Project::Object::PBXSourcesBuildPhase }
result1, result2 = files_diff(source_1.files, source_2.files)
puts "build source diff:"
puts ">>>>> #{target1_name}\n#{result1.sort}\n===== #{target2_name}\n#{result2.sort}\n<<<<<"
pending = resutl1.select { |ref| !ref.full_path.include? ignore_path }
target2.add_sources(pending)
