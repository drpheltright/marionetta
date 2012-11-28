# `Deployer` is a class for rsyncing your application to a
# remote machine.
# 
# Using a directory structure similar to capistrano `Deployer`
# maintains a folder of releases so you may rollback quickly.
# 
require 'marionetta/command_runner'

module Marionetta
  module Manipulators
    class Deployer

      ### RakeHelper tasks

      # `Deployer` provides two rake tasks when used with
      # `RakeHelper` namely `:deploy` and `:rollback`. When
      # applied through `RakeHelper` they will appear
      # namespaced under `:deployer` and your group name.
      # 
      # With a group name of `:staging` would appear as:
      # 
      #     deployer:staging:deploy
      #     deployer:staging:rollback
      # 
      def self.tasks()
        [:deploy, :rollback]
      end

      ### Server hash requirements

      # The keys `[:deployer][:from]` and `[:deployer][:to]`
      # must be set in your `server` hash in order for
      # `Deployer` to work.
      # 
      def initialize(server)
        @server = server
      end

      # Call `.can?()` to check if the correct keys have be
      # passed in as the server.
      # 
      def can?()
        d = server[:deployer]
        
        if d.has_key?(:from) and d.has_key?(:to)
          return true
        else
          return false
        end
      end

      ### Deploying

      # Call `.deploy()` to run a deploy to your remote
      # server. The process involves:
      # 
      #  - `:from` directory copied to temporary directory
      #  - `:exclude` files are removed
      #  - rsync'd to a releases directory
      #  - `:before_script` run
      #  - release directory symlinked to a current directory
      #  - `:after_script` run
      # 
      # The directory structure under `server[:deployer][:to]`
      # looks something like this:
      # 
      #   current/ -> ./releases/2012-09-20_14:04:39
      #   releases/
      #     2012-09-20_13:59:15
      #     2012-09-20_14:04:39
      # 
      def deploy()
        release = timestamp
        create_tmp_release_dir(release)

        send_files(release)

        run_script(:before, release)
        symlink_release_dir(release)
        run_script(:after, release)
      end

      # To get an array of all releases call `.releases()`.
      # Any release that is subsequently rolled back will not
      # be listed.
      # 
      def releases()
        releases = []

        cmd.ssh("ls -m #{release_dir}") do |stdout|
          stdout.read.split(/[,\s]+/).each do |release|
            releases << release unless release.index('skip-') == 0
          end
        end

        return releases
      end

      # If you push out and need to rollback to the previous
      # version you can use `.rollback()` to do just that.
      # Currently you can only rollback once at a time.
      # 
      def rollback()
        rollback_to_release = releases[-2]

        if rollback_to_release.nil?
          server[:logger].warn('No release to rollback to')
        else
          current_release_dir = release_dir(releases.last)
          skip_current_release_dir = release_dir("skip-#{releases.last}")
          cmd.ssh("mv #{current_release_dir} #{skip_current_release_dir}")
          symlink_release_dir(rollback_to_release)
        end
      end
      
      ### Dependency Injection

      # To use your own alternative to `CommandRunner` you can
      # set an object of your choice via the `.cmd=` method.
      # 
      attr_writer :cmd

    private
      
      attr_reader :server

      def cmd()
        @cmd ||= CommandRunner.new(server)
      end

      def from_dir()
        server[:deployer][:from]
      end

      def tmp_release_dir(release)
        "/tmp/#{server[:hostname]}/#{release}"
      end

      def to_dir()
        server[:deployer][:to]
      end

      def release_dir(release=nil)
        dir = "#{to_dir}/releases"
        dir << "/#{release}" unless release.nil?
        return dir
      end

      def current_dir()
        "#{to_dir}/current"
      end

      def fatal(message)
        server[:logger].fatal(cmd.last)
        server[:logger].fatal(message)
        exit(1)
      end

      def run_script(script, release)
        script_key = "#{script}_script".to_sym

        if server[:deployer].has_key?(script_key)
          script = server[:deployer][script_key]
          cmd.put(script, '/tmp')
          tmp_script = "/tmp/#{File.basename(script)}"
          cmd.ssh("chmod +x #{tmp_script} && exec #{tmp_script} #{release}")
        end
      end

      def create_tmp_release_dir(release)
        tmp_release_dir = tmp_release_dir(release)

        create_tmp_dir_cmds = [
          "mkdir -p #{File.dirname(tmp_release_dir)}",
          "cp -rf #{from_dir} #{tmp_release_dir}",
        ]
        cmd.system(create_tmp_dir_cmds.join(' && '))

        if server[:deployer].has_key?(:exclude)
          exclude_files = server[:deployer][:exclude]
          exclude_files.map! {|f| Dir["#{tmp_release_dir}/#{f}"]}
          exclude_files.flatten!

          cmd.system("rm -rf #{exclude_files.join(' ')}") unless exclude_files.empty?
        end
      end

      def send_files(release)
        cmd.ssh("mkdir -p #{release_dir}")

        unless cmd.put(tmp_release_dir(release), release_dir)
          fatal('Could not rsync release')
        end
      end

      def symlink_release_dir(release)
        release_dir = release_dir(release)

        unless cmd.ssh("rm -f #{current_dir} && ln -s #{release_dir} #{current_dir}")
          fatal('Could not symlink release as current')
        end
      end

      def timestamp()
        Time.new.strftime('%F_%T')
      end
    end
  end
end
