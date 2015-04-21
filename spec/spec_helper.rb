require 'pathname'
require 'open3'
$SPECROOT = Pathname(__FILE__).dirname
require 'tmpdir'
require 'tempfile'
require 'rubygems'
require 'rspec'
require 'pry'

$LOAD_PATH << $SPECROOT.join("..", "lib").expand_path
require 'pliney'


RSpec.configure do |config|
    config.expect_with :rspec do |c|
        c.syntax = [:should, :expect]
    end

    def sample_file(filename)
        $SPECROOT.join("samples", filename)
    end

    def relative_paths(paths, reldir)
        paths.map{|p| Pathname(p).relative_path_from(Pathname(reldir)).to_s}
    end

    def spec_logger
        $logger ||=
            if ENV["SPEC_LOGGING"]
                logger = Logger.new($stdout)
                #logger.level = Logger::INFO
                logger
            end
    end

    def shell_pipe(data, cmd)
        ret=nil
        Open3.popen3(cmd) do |w,r,e|
            w.write data
            w.close
            ret = r.read
            r.close
        end
        return ret
    end
end

if ENV["GC_STRESS"]
  GC.stress = true
end
